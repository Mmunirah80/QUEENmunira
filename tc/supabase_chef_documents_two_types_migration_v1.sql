-- =============================================================================
-- Cook onboarding: exactly TWO required document types (id + health/kitchen).
-- Canonical: id_document, health_or_kitchen_document
-- Legacy still honored in SQL: national_id → id slot, freelancer_id/license → health slot
-- Apply after supabase_chef_access_documents_v3.sql
-- =============================================================================

CREATE OR REPLACE FUNCTION public.recompute_chef_access_level (p_chef_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked boolean;
  v_initial timestamptz;
  v_established boolean;
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_n text;
  v_h text;
  v_bad boolean;
  v_any_expired boolean;
  v_all_fresh boolean;
BEGIN
  SELECT coalesce(p.is_blocked, false)
  INTO v_blocked
  FROM public.profiles p
  WHERE p.id = p_chef_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_blocked THEN
    UPDATE public.chef_profiles cp
    SET
      access_level = 'blocked_access',
      documents_operational_ok = false
    WHERE cp.id = p_chef_id;
    RETURN;
  END IF;

  SELECT cp.initial_approval_at
  INTO v_initial
  FROM public.chef_profiles cp
  WHERE cp.id = p_chef_id;

  v_established := (v_initial IS NOT NULL);

  SELECT lower(trim(coalesce(d.status::text, '')))
  INTO v_n
  FROM public.chef_documents d
  WHERE d.chef_id = p_chef_id
    AND lower(trim(d.document_type::text)) IN ('id_document', 'national_id')
  ORDER BY
    CASE WHEN lower(trim(d.document_type::text)) = 'id_document' THEN 0 ELSE 1 END,
    d.created_at DESC NULLS LAST
  LIMIT 1;

  SELECT lower(trim(coalesce(d.status::text, '')))
  INTO v_h
  FROM public.chef_documents d
  WHERE d.chef_id = p_chef_id
    AND lower(trim(d.document_type::text)) IN ('health_or_kitchen_document', 'freelancer_id', 'license')
  ORDER BY
    CASE WHEN lower(trim(d.document_type::text)) = 'health_or_kitchen_document' THEN 0 ELSE 1 END,
    d.created_at DESC NULLS LAST
  LIMIT 1;

  v_bad :=
    (v_n IS NULL OR v_n IN ('pending_review', 'rejected'))
    OR (v_h IS NULL OR v_h IN ('pending_review', 'rejected'));

  v_any_expired := (v_n = 'expired') OR (v_h = 'expired');

  v_all_fresh :=
    (v_n = 'approved')
    AND (v_h = 'approved')
    AND NOT EXISTS (
      SELECT 1
      FROM public.chef_documents d
      WHERE d.chef_id = p_chef_id
        AND lower(trim(d.document_type::text)) IN (
          'id_document',
          'national_id',
          'health_or_kitchen_document',
          'freelancer_id',
          'license'
        )
        AND lower(trim(d.status::text)) = 'approved'
        AND coalesce(d.no_expiry, false) IS NOT TRUE
        AND d.expiry_date IS NOT NULL
        AND d.expiry_date < v_today
    );

  IF v_all_fresh THEN
    UPDATE public.chef_profiles cp
    SET
      access_level = 'full_access',
      documents_operational_ok = true,
      initial_approval_at = coalesce(cp.initial_approval_at, now()),
      approval_status = 'approved',
      suspended = false,
      suspension_reason = NULL,
      rejection_reason = NULL
    WHERE cp.id = p_chef_id;
    RETURN;
  END IF;

  IF v_established AND NOT v_bad THEN
    IF EXISTS (
      SELECT 1
      FROM public.chef_documents d
      WHERE d.chef_id = p_chef_id
        AND lower(trim(d.document_type::text)) IN (
          'id_document',
          'national_id',
          'health_or_kitchen_document',
          'freelancer_id',
          'license'
        )
        AND lower(trim(d.status::text)) = 'approved'
        AND coalesce(d.no_expiry, false) IS NOT TRUE
        AND d.expiry_date IS NOT NULL
        AND d.expiry_date < v_today
    ) THEN
      UPDATE public.chef_profiles cp
      SET
        access_level = 'full_access',
        documents_operational_ok = false,
        approval_status = 'approved',
        suspended = false,
        suspension_reason = NULL
      WHERE cp.id = p_chef_id;
      RETURN;
    END IF;
  END IF;

  IF v_established AND v_any_expired AND NOT v_bad THEN
    UPDATE public.chef_profiles cp
    SET
      access_level = 'full_access',
      documents_operational_ok = false,
      approval_status = 'approved',
      suspended = false,
      suspension_reason = NULL
    WHERE cp.id = p_chef_id;
    RETURN;
  END IF;

  IF v_bad OR v_any_expired OR NOT v_all_fresh THEN
    UPDATE public.chef_profiles cp
    SET
      access_level = 'partial_access',
      documents_operational_ok = false,
      approval_status = 'pending',
      suspended = false,
      suspension_reason = NULL
    WHERE cp.id = p_chef_id;
    RETURN;
  END IF;

  UPDATE public.chef_profiles cp
  SET access_level = 'partial_access', documents_operational_ok = false
  WHERE cp.id = p_chef_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- chef_upsert_document — allow canonical + legacy types
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chef_upsert_document (
  p_document_type text,
  p_file_url text,
  p_no_expiry boolean,
  p_expiry_date date DEFAULT NULL
)
RETURNS public.chef_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_chef uuid := auth.uid ();
  v_row public.chef_documents;
  v_norm text;
BEGIN
  IF v_chef IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_document_type IS NULL OR trim(p_document_type) = '' THEN
    RAISE EXCEPTION 'document_type required';
  END IF;

  IF p_file_url IS NULL OR trim(p_file_url) = '' THEN
    RAISE EXCEPTION 'file_url required';
  END IF;

  v_norm := lower(trim(p_document_type));

  IF v_norm NOT IN (
    'id_document',
    'health_or_kitchen_document',
    'national_id',
    'freelancer_id',
    'license'
  ) THEN
    RAISE EXCEPTION 'Invalid document_type';
  END IF;

  INSERT INTO public.chef_documents (
    chef_id,
    document_type,
    file_url,
    status,
    no_expiry,
    expiry_date
  )
  VALUES (
    v_chef,
    v_norm,
    trim(p_file_url),
    'pending_review',
    coalesce(p_no_expiry, false),
    CASE WHEN coalesce(p_no_expiry, false) THEN NULL ELSE p_expiry_date END
  )
  ON CONFLICT (chef_id, document_type)
  DO UPDATE SET
    file_url = excluded.file_url,
    status = 'pending_review',
    no_expiry = excluded.no_expiry,
    expiry_date = excluded.expiry_date,
    rejection_reason = NULL,
    reviewed_at = NULL,
    reviewed_by = NULL,
    expiry_notification_sent_at = NULL
  RETURNING * INTO v_row;

  PERFORM public.recompute_chef_access_level (v_chef);

  RETURN v_row;
END;
$$;

-- ---------------------------------------------------------------------------
-- apply_chef_document_review — notification + message copy (dedupe preserved)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_chef_document_review (
  p_document_id uuid,
  p_status text,
  p_rejection_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid ();
  v_chef_id uuid;
  v_status text := lower(trim(p_status));
  v_reason text;
  v_reason_text text;
  v_body_approve constant text := 'Your documents were approved. You can now access the cook app.';
  v_msg text;
  v_conv_id uuid;
  v_reviewer uuid;
  v_msg_sender uuid;
  v_now timestamptz := now();
  v_doc_status text;
  v_send_activation boolean := false;
  v_doc_type text;
  v_doc_label text;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;

  IF NOT public.is_admin (v_actor) THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  v_reviewer := v_actor;
  v_msg_sender := v_reviewer;

  SELECT chef_id, lower(trim(status::text)), lower(trim(document_type::text))
  INTO v_chef_id, v_doc_status, v_doc_type
  FROM public.chef_documents
  WHERE id = p_document_id;

  IF v_chef_id IS NULL THEN
    RAISE EXCEPTION 'Document not found';
  END IF;

  v_doc_label := CASE v_doc_type
    WHEN 'id_document' THEN 'ID document'
    WHEN 'national_id' THEN 'ID document'
    WHEN 'health_or_kitchen_document' THEN 'Health or kitchen document'
    WHEN 'freelancer_id' THEN 'Health or kitchen document'
    WHEN 'license' THEN 'Health or kitchen document'
    ELSE initcap(replace(v_doc_type, '_', ' '))
  END;

  IF v_status = 'rejected' THEN
    v_reason := nullif(trim(coalesce(p_rejection_reason, '')), '');
    IF v_reason IS NULL THEN
      RAISE EXCEPTION 'Rejection reason is required';
    END IF;
    IF char_length(v_reason) < 5 THEN
      RAISE EXCEPTION 'Rejection reason must be at least 5 characters';
    END IF;
    v_reason_text := v_reason;
  END IF;

  UPDATE public.chef_documents
  SET
    status = CASE WHEN v_status = 'approved' THEN 'approved' ELSE 'rejected' END,
    reviewed_at = v_now,
    reviewed_by = v_msg_sender,
    rejection_reason = CASE WHEN v_status = 'approved' THEN NULL ELSE v_reason END
  WHERE id = p_document_id;

  PERFORM public.recompute_chef_access_level (v_chef_id);

  SELECT
    access_level = 'full_access'
    AND documents_operational_ok IS TRUE
    AND initial_approval_at IS NOT NULL
  INTO v_send_activation
  FROM public.chef_profiles
  WHERE id = v_chef_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.customer_id = v_chef_id
      AND n.type = 'admin_document'
      AND n.chef_document_id = p_document_id
  ) THEN
    IF v_status = 'rejected' THEN
      INSERT INTO public.notifications (customer_id, title, body, is_read, type, chef_document_id)
      VALUES (
        v_chef_id,
        'Documents need update',
        v_doc_label || E'\n' || v_reason_text,
        false,
        'admin_document',
        p_document_id
      );
    ELSE
      INSERT INTO public.notifications (customer_id, title, body, is_read, type, chef_document_id)
      VALUES (
        v_chef_id,
        'Document approved',
        v_body_approve,
        false,
        'admin_document',
        p_document_id
      );
    END IF;
  END IF;

  IF v_send_activation THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.notifications n
      WHERE n.customer_id = v_chef_id
        AND n.type = 'chef_account_activated'
    ) THEN
      INSERT INTO public.notifications (customer_id, title, body, is_read, type)
      VALUES (
        v_chef_id,
        'Application approved',
        'Your documents were approved. You can now access the cook app.',
        false,
        'chef_account_activated'
      );
    END IF;
  END IF;

  SELECT c.id
  INTO v_conv_id
  FROM public.conversations c
  WHERE c.chef_id = v_chef_id
    AND c.type = 'chef-admin'
  LIMIT 1;

  IF v_conv_id IS NULL THEN
    INSERT INTO public.conversations (type, chef_id, customer_id)
    VALUES ('chef-admin', v_chef_id, v_chef_id)
    RETURNING id INTO v_conv_id;
  END IF;

  IF v_status = 'rejected' THEN
    v_msg :=
      'Document: ' || v_doc_label || E'\n'
      || 'Rejection reason: ' || v_reason_text || E'\n\n'
      || 'Please re-upload only the document that needs correction in Profile → Documents. — Naham team';
  ELSE
    v_msg :=
      'Your uploaded document was approved. Thank you.' || E'\n'
      || '— Naham team';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.messages m
    WHERE m.conversation_id = v_conv_id
      AND m.sender_id = v_msg_sender
      AND m.content = v_msg
      AND m.created_at > v_now - interval '2 minutes'
  ) THEN
    INSERT INTO public.messages (conversation_id, sender_id, content, is_read)
    VALUES (v_conv_id, v_msg_sender, v_msg, false);
  END IF;

  IF v_send_activation THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.messages m
      WHERE m.conversation_id = v_conv_id
        AND m.content LIKE 'Your application has been approved.%'
    ) THEN
      INSERT INTO public.messages (conversation_id, sender_id, content, is_read)
      VALUES (
        v_conv_id,
        v_msg_sender,
        'Your application has been approved. You can now start using the cook app.',
        false
      );
    END IF;
  END IF;
END;
$$;
