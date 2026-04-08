-- ============================================================
-- NAHAM v3 — Chef access_level, document statuses, one row per type,
-- recompute RPCs, inspection penalty ladder (warning_1 … blocked).
-- Run in Supabase SQL Editor (owner). Apply after core tables exist.
-- ============================================================

BEGIN;

-- ----------------------------------------------------------------
-- 1) chef_profiles: access_level + operational flag
-- ----------------------------------------------------------------
ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS access_level text,
  ADD COLUMN IF NOT EXISTS documents_operational_ok boolean NOT NULL DEFAULT false;

ALTER TABLE public.chef_profiles DROP CONSTRAINT IF EXISTS chef_profiles_access_level_check;
ALTER TABLE public.chef_profiles
  ADD CONSTRAINT chef_profiles_access_level_check
  CHECK (
    access_level IS NULL
    OR access_level IN ('partial_access', 'full_access', 'blocked_access')
  );

COMMENT ON COLUMN public.chef_profiles.access_level IS
  'partial_access | full_access | blocked_access — single shell gate; separate from document row status.';
COMMENT ON COLUMN public.chef_profiles.documents_operational_ok IS
  'False when required docs missing, rejected, pending review, or expired (storefront/orders gate).';

-- ----------------------------------------------------------------
-- 2) chef_documents: dedupe → one row per (chef_id, document_type)
-- ----------------------------------------------------------------
-- Drop legacy CHECK first: old schema only allowed pending|approved|rejected.
-- Updating to pending_review would violate the old constraint if we did not drop it here.
ALTER TABLE public.chef_documents DROP CONSTRAINT IF EXISTS chef_documents_status_allowed;

UPDATE public.chef_documents
SET status = 'pending_review'
WHERE lower(trim(status::text)) IN ('pending', 'pending_review');

UPDATE public.chef_documents
SET status = lower(trim(status::text));

DELETE FROM public.chef_documents a
WHERE EXISTS (
  SELECT 1
  FROM public.chef_documents b
  WHERE b.chef_id = a.chef_id
    AND b.document_type = a.document_type
    AND (
      b.created_at > a.created_at
      OR (b.created_at = a.created_at AND b.id::text > a.id::text)
    )
);

ALTER TABLE public.chef_documents
  ADD CONSTRAINT chef_documents_status_allowed
  CHECK (
    lower(trim(status::text)) IN (
      'pending_review',
      'approved',
      'rejected',
      'expired'
    )
  );

DROP INDEX IF EXISTS public.chef_documents_chef_id_document_type_uidx;
ALTER TABLE public.chef_documents DROP CONSTRAINT IF EXISTS chef_documents_chef_id_document_type_key;
ALTER TABLE public.chef_documents
  ADD CONSTRAINT chef_documents_chef_id_document_type_key UNIQUE (chef_id, document_type);

-- ----------------------------------------------------------------
-- 3) Core recompute (SECURITY DEFINER)
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recompute_chef_access_level (p_chef_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked boolean := false;
  v_initial timestamptz;
  v_established boolean;
  v_n text;
  v_f text;
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
  v_bad boolean;
  v_any_expired boolean;
  v_all_fresh boolean;
BEGIN
  IF auth.uid () IS NOT NULL
     AND auth.uid () IS DISTINCT FROM p_chef_id
     AND NOT public.is_admin (auth.uid ()) THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

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
  WHERE d.chef_id = p_chef_id AND d.document_type = 'national_id';

  SELECT lower(trim(coalesce(d.status::text, '')))
  INTO v_f
  FROM public.chef_documents d
  WHERE d.chef_id = p_chef_id AND d.document_type = 'freelancer_id';

  v_bad :=
    (v_n IS NULL OR v_n IN ('pending_review', 'rejected'))
    OR (v_f IS NULL OR v_f IN ('pending_review', 'rejected'));

  v_any_expired := (v_n = 'expired') OR (v_f = 'expired');

  v_all_fresh :=
    (v_n = 'approved')
    AND (v_f = 'approved')
    AND NOT EXISTS (
      SELECT 1
      FROM public.chef_documents d
      WHERE d.chef_id = p_chef_id
        AND d.document_type IN ('national_id', 'freelancer_id')
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

  -- Established chef: calendar past expiry but row still `approved` (notify job not run yet)
  IF v_established AND NOT v_bad THEN
    IF EXISTS (
      SELECT 1
      FROM public.chef_documents d
      WHERE d.chef_id = p_chef_id
        AND d.document_type IN ('national_id', 'freelancer_id')
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

REVOKE ALL ON FUNCTION public.recompute_chef_access_level (uuid) FROM PUBLIC;

-- ----------------------------------------------------------------
-- 4) Chef upsert document (single row per type; backend-only)
-- ----------------------------------------------------------------
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

  IF lower(trim(p_document_type)) NOT IN ('national_id', 'freelancer_id', 'license') THEN
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
    lower(trim(p_document_type)),
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

REVOKE ALL ON FUNCTION public.chef_upsert_document (text, text, boolean, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chef_upsert_document (text, text, boolean, date) TO authenticated;

-- ----------------------------------------------------------------
-- 5) apply_chef_document_review — per document; no simulation path
-- ----------------------------------------------------------------
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
  v_body_approve constant text := 'Your document was approved. Thank you.';
  v_msg text;
  v_conv_id uuid;
  v_reviewer uuid;
  v_msg_sender uuid;
  v_now timestamptz := now();
  v_doc_status text;
  v_send_activation boolean := false;
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

  SELECT chef_id, lower(trim(status::text))
  INTO v_chef_id, v_doc_status
  FROM public.chef_documents
  WHERE id = p_document_id;

  IF v_chef_id IS NULL THEN
    RAISE EXCEPTION 'Document not found';
  END IF;

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
        'Document rejected',
        v_reason_text,
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
        'Account activated',
        'All required documents are approved. You now have full access to the cook app.',
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
      'Rejection reason: ' || v_reason_text || E'\n\n'
      || 'Please open Profile → Documents and upload a corrected file. — Naham team';
  ELSE
    v_msg :=
      'Your uploaded document was approved. Thank you.' || E'\n'
      || '— Naham team';
  END IF;

  INSERT INTO public.messages (conversation_id, sender_id, content, is_read)
  VALUES (v_conv_id, v_msg_sender, v_msg, false);

  IF v_send_activation THEN
    INSERT INTO public.messages (conversation_id, sender_id, content, is_read)
    SELECT
      v_conv_id,
      v_msg_sender,
      'Your account is now fully activated. All required documents are approved. You can use Home, Orders, Menu, and Reels. Welcome to Naham.',
      false
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.messages m
      WHERE m.conversation_id = v_conv_id
        AND m.content LIKE 'Your account is now fully activated.%'
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_chef_document_review (uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_chef_document_review (uuid, text, text) TO authenticated;

-- Drop simulation helpers (no chef-side review)
DROP FUNCTION IF EXISTS public.chef_document_review_simulation_enabled ();
DO $$
BEGIN
  IF to_regclass('public.dev_feature_flags') IS NOT NULL THEN
    DELETE FROM public.dev_feature_flags WHERE key = 'chef_document_review_simulation';
  END IF;
END $$;

-- ----------------------------------------------------------------
-- 6) Expired documents: mark expired + recompute (no access downgrade for established)
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_expired_chef_documents ()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_chef uuid := auth.uid ();
  r record;
  v_conv uuid;
  v_admin uuid;
  v_label text;
  v_body text;
  v_msg text;
  v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date;
BEGIN
  IF v_chef IS NULL THEN
    RETURN;
  END IF;

  SELECT p.id
  INTO v_admin
  FROM public.profiles p
  WHERE lower(trim(p.role::text)) = 'admin'
    AND COALESCE(p.is_blocked, false) = false
  ORDER BY p.created_at ASC NULLS LAST, p.id ASC
  LIMIT 1;

  SELECT c.id
  INTO v_conv
  FROM public.conversations c
  WHERE c.chef_id = v_chef
    AND c.type = 'chef-admin'
  LIMIT 1;

  IF v_conv IS NULL THEN
    INSERT INTO public.conversations (type, chef_id, customer_id)
    VALUES ('chef-admin', v_chef, v_chef)
    RETURNING id INTO v_conv;
  END IF;

  FOR r IN
    SELECT d.id, d.document_type, d.expiry_date
    FROM public.chef_documents d
    WHERE d.chef_id = v_chef
      AND lower(trim(d.status::text)) = 'approved'
      AND d.expiry_date IS NOT NULL
      AND d.expiry_date < v_today
      AND d.expiry_notification_sent_at IS NULL
  LOOP
    v_label := CASE lower(trim(coalesce(r.document_type::text, '')))
      WHEN 'national_id' THEN 'National ID'
      WHEN 'freelancer_id' THEN 'Freelancer ID'
      WHEN 'license' THEN 'License'
      ELSE initcap(replace(trim(coalesce(r.document_type::text, 'document')), '_', ' '))
    END;

    v_body := 'Your ' || v_label || ' has expired. Please upload a new one.';
    v_msg := 'Your ' || v_label || ' has expired. Please upload a new document.';

    UPDATE public.chef_documents
    SET status = 'expired'
    WHERE id = r.id;

    INSERT INTO public.notifications (customer_id, title, body, is_read, type)
    VALUES (
      v_chef,
      'Document expired',
      v_body,
      false,
      'document_expired'
    );

    IF v_admin IS NOT NULL THEN
      INSERT INTO public.messages (conversation_id, sender_id, content, is_read)
      VALUES (v_conv, v_admin, v_msg, false);
    END IF;

    UPDATE public.chef_documents
    SET expiry_notification_sent_at = now()
    WHERE id = r.id;
  END LOOP;

  PERFORM public.recompute_chef_access_level (v_chef);
END;
$$;

REVOKE ALL ON FUNCTION public.notify_expired_chef_documents () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_expired_chef_documents () TO authenticated;

-- ----------------------------------------------------------------
-- 7) Inspection penalty step + finalize (replace ladder)
-- ----------------------------------------------------------------
ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS inspection_penalty_step integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.chef_profiles.inspection_penalty_step IS
  '0–6: warning_1, warning_2, freeze_3d, freeze_7d, freeze_14d, blocked (monotonic).';

UPDATE public.chef_profiles cp
SET inspection_penalty_step = LEAST (GREATEST (coalesce(cp.inspection_violation_count, 0), 0), 6)
WHERE inspection_penalty_step = 0;

CREATE OR REPLACE FUNCTION public.finalize_inspection_outcome (
  p_call_id uuid,
  p_outcome text,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_call public.inspection_calls;
  v_out text := lower(trim(coalesce(p_outcome, '')));
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_chef uuid;
  v_now timestamptz := clock_timestamp();
  v_step int;
  v_action text;
  v_freeze_until timestamptz;
  v_counted boolean := false;
  v_result_action text;
  v_violation_legacy text;
BEGIN
  PERFORM public.ensure_admin ();
  PERFORM set_config('app.inspection_finalize_ctx', '1', true);

  IF p_call_id IS NULL THEN
    RAISE EXCEPTION 'call_id is required';
  END IF;

  IF v_out NOT IN (
    'passed',
    'no_answer',
    'kitchen_not_clean',
    'refused_inspection',
    'admin_technical_issue'
  ) THEN
    RAISE EXCEPTION 'invalid outcome';
  END IF;

  SELECT *
  INTO v_call
  FROM public.inspection_calls
  WHERE id = p_call_id;

  IF v_call.id IS NULL THEN
    RAISE EXCEPTION 'inspection call not found';
  END IF;

  IF v_call.status = 'completed' THEN
    RETURN jsonb_build_object(
      'call_id', v_call.id,
      'already_completed', true,
      'outcome', v_call.outcome
    );
  END IF;

  IF v_call.status = 'cancelled' THEN
    RAISE EXCEPTION 'inspection call was cancelled';
  END IF;

  v_chef := v_call.chef_id;

  IF v_out IN ('no_answer', 'kitchen_not_clean', 'refused_inspection') THEN
    v_counted := true;
  END IF;

  v_violation_legacy := CASE v_out
    WHEN 'no_answer' THEN 'no_answer'
    WHEN 'kitchen_not_clean' THEN 'failed_hygiene_check'
    WHEN 'refused_inspection' THEN 'declined_call'
    ELSE NULL
  END;

  IF NOT v_counted THEN
    v_result_action := CASE WHEN v_out = 'passed' THEN 'pass' ELSE 'admin_technical_issue' END;

    UPDATE public.inspection_calls
    SET
      status = 'completed',
      outcome = v_out,
      counted_as_violation = false,
      result_action = v_result_action,
      violation_reason = NULL,
      result_note = v_note,
      chef_result_seen = false,
      finalized_at = v_now,
      ended_at = v_now
    WHERE id = p_call_id;

    RETURN jsonb_build_object(
      'call_id', p_call_id,
      'outcome', v_out,
      'result_action', v_result_action,
      'counted_as_violation', false
    );
  END IF;

  UPDATE public.chef_profiles cp
  SET
    inspection_penalty_step = LEAST (coalesce(cp.inspection_penalty_step, 0) + 1, 6),
    inspection_violation_count = coalesce(cp.inspection_violation_count, 0) + 1
  WHERE cp.id = v_chef
  RETURNING inspection_penalty_step INTO v_step;

  IF v_step IS NULL THEN
    RAISE EXCEPTION 'chef profile not found';
  END IF;

  v_action := CASE v_step
    WHEN 1 THEN 'warning_1'
    WHEN 2 THEN 'warning_2'
    WHEN 3 THEN 'freeze_3d'
    WHEN 4 THEN 'freeze_7d'
    WHEN 5 THEN 'freeze_14d'
    WHEN 6 THEN 'blocked'
    ELSE 'freeze_14d'
  END;

  IF v_step IN (1, 2) THEN
    UPDATE public.chef_profiles
    SET warning_count = coalesce(warning_count, 0) + 1
    WHERE id = v_chef;
  END IF;

  IF v_step IN (3, 4, 5) THEN
    v_freeze_until := v_now + CASE v_step
      WHEN 3 THEN interval '3 days'
      WHEN 4 THEN interval '7 days'
      WHEN 5 THEN interval '14 days'
      ELSE interval '14 days'
    END;
    UPDATE public.chef_profiles
    SET
      freeze_until = v_freeze_until,
      freeze_started_at = v_now,
      freeze_type = 'soft',
      freeze_reason = coalesce(
        v_note,
        'Automatic freeze from random kitchen inspection (step ' || v_step::text || ')'
      ),
      is_online = false
    WHERE id = v_chef;
  END IF;

  IF v_step = 6 THEN
    UPDATE public.profiles
    SET is_blocked = true
    WHERE id = v_chef;
    PERFORM public.recompute_chef_access_level (v_chef);
  END IF;

  INSERT INTO public.chef_violations (
    chef_id,
    inspection_call_id,
    admin_id,
    violation_index,
    reason,
    action_applied,
    note
  )
  VALUES (
    v_chef,
    p_call_id,
    auth.uid (),
    v_step,
    v_out,
    v_action,
    v_note
  );

  UPDATE public.inspection_calls
  SET
    status = 'completed',
    outcome = v_out,
    counted_as_violation = true,
    result_action = v_action,
    violation_reason = v_violation_legacy,
    result_note = v_note,
    chef_result_seen = false,
    finalized_at = v_now,
    ended_at = v_now
  WHERE id = p_call_id;

  RETURN jsonb_build_object(
    'call_id', p_call_id,
    'outcome', v_out,
    'result_action', v_action,
    'inspection_penalty_step', v_step,
    'freeze_until', v_freeze_until,
    'counted_as_violation', true
  );
END;
$$;

ALTER TABLE public.inspection_calls DROP CONSTRAINT IF EXISTS inspection_calls_result_action_allowed;
ALTER TABLE public.inspection_calls
  ADD CONSTRAINT inspection_calls_result_action_allowed
  CHECK (
    result_action IS NULL
    OR result_action IN (
      'pass',
      'warning_1',
      'warning_2',
      'freeze_3d',
      'freeze_7d',
      'freeze_14d',
      'blocked',
      'admin_technical_issue'
    )
  );

-- ----------------------------------------------------------------
-- 8) Eligibility snapshot: operational + access_level
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chef_inspection_eligibility_snapshot (p_chef_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := clock_timestamp();
  cp record;
  v_blocked boolean;
  v_last_completed timestamptz;
  v_last_started timestamptz;
  v_hours_since_completed numeric;
  v_count_30d int;
  v_has_active boolean;
  v_cooldown_ok boolean;
  v_frequency_ok boolean;
  v_session_gap_ok boolean;
  v_min_interval interval := interval '7 days';
  v_min_session_gap interval := interval '48 hours';
  v_max_per_30 int := 3;
  v_eligible boolean := true;
  v_reasons text[] := ARRAY[]::text[];
  v_pass text[] := ARRAY[]::text[];
  v_hours_ok boolean;
BEGIN
  IF p_chef_id IS NULL THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'evaluated_at', v_now,
      'failure_reasons', jsonb_build_array('null_chef_id')
    );
  END IF;

  SELECT coalesce(is_blocked, false) INTO v_blocked FROM public.profiles WHERE id = p_chef_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('eligible', false, 'evaluated_at', v_now, 'failure_reasons', jsonb_build_array('no_profile'));
  END IF;
  IF v_blocked THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'profile_blocked');
  END IF;

  SELECT
    lower(trim(coalesce(approval_status, ''))) AS approval_status,
    initial_approval_at,
    coalesce(is_online, false) AS is_online,
    coalesce(suspended, false) AS suspended,
    coalesce(vacation_mode, false) AS vacation_mode,
    vacation_start,
    vacation_end,
    freeze_until,
    coalesce(kitchen_timezone, 'UTC') AS kitchen_tz,
    coalesce(access_level, '') AS access_level,
    coalesce(documents_operational_ok, false) AS documents_operational_ok
  INTO cp
  FROM public.chef_profiles
  WHERE id = p_chef_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('eligible', false, 'evaluated_at', v_now, 'failure_reasons', jsonb_build_array('no_chef_profile'));
  END IF;

  IF cp.access_level IS DISTINCT FROM 'full_access' THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'not_full_access');
  END IF;

  IF NOT cp.documents_operational_ok THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'documents_not_operational');
  END IF;

  IF cp.initial_approval_at IS NULL THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'initial_approval_missing');
  END IF;

  IF NOT cp.is_online THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'not_online');
  END IF;

  IF cp.suspended THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'suspended');
  END IF;

  IF cp.vacation_mode THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'vacation_mode');
  END IF;

  IF cp.vacation_start IS NOT NULL AND cp.vacation_end IS NOT NULL THEN
    IF (v_now::date >= cp.vacation_start::date AND v_now::date <= cp.vacation_end::date) THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'scheduled_vacation');
    END IF;
  END IF;

  IF cp.freeze_until IS NOT NULL AND cp.freeze_until > v_now THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'frozen');
  END IF;

  v_hours_ok := public.chef_is_within_working_hours_now (p_chef_id);
  IF NOT v_hours_ok THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'outside_working_hours');
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.inspection_calls c
    WHERE c.chef_id = p_chef_id
      AND c.status IN ('pending', 'accepted')
  ) INTO v_has_active;
  IF v_has_active THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'active_inspection_call');
  END IF;

  SELECT MAX(c.finalized_at)
  INTO v_last_completed
  FROM public.inspection_calls c
  WHERE c.chef_id = p_chef_id
    AND c.status = 'completed'
    AND c.finalized_at IS NOT NULL;

  IF v_last_completed IS NULL THEN
    v_hours_since_completed := NULL;
    v_cooldown_ok := true;
  ELSE
    v_hours_since_completed := EXTRACT(EPOCH FROM (v_now - v_last_completed)) / 3600.0;
    v_cooldown_ok := (v_now - v_last_completed) >= v_min_interval;
    IF NOT v_cooldown_ok THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'cooldown_not_met_since_last_completed');
    END IF;
  END IF;

  SELECT COUNT(*)::int
  INTO v_count_30d
  FROM public.inspection_calls c
  WHERE c.chef_id = p_chef_id
    AND c.status = 'completed'
    AND c.finalized_at IS NOT NULL
    AND c.finalized_at > v_now - interval '30 days';

  v_frequency_ok := (v_count_30d < v_max_per_30);
  IF NOT v_frequency_ok THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'max_inspections_per_30_days');
  END IF;

  SELECT MAX(c.started_at)
  INTO v_last_started
  FROM public.inspection_calls c
  WHERE c.chef_id = p_chef_id
    AND c.started_at IS NOT NULL;

  IF v_last_started IS NULL THEN
    v_session_gap_ok := true;
  ELSE
    v_session_gap_ok := (v_now - v_last_started) >= v_min_session_gap;
    IF NOT v_session_gap_ok THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'min_session_gap_since_last_started_not_met');
    END IF;
  END IF;

  IF v_eligible THEN
    v_pass := array_append(v_pass, 'eligible_pool');
  END IF;

  RETURN jsonb_build_object(
    'eligible', v_eligible,
    'evaluated_at', v_now,
    'why_eligible', to_jsonb(v_pass),
    'policy', jsonb_build_object(
      'min_interval_between_completed', v_min_interval::text,
      'min_interval_between_session_starts', v_min_session_gap::text,
      'max_completed_inspections_per_30_days', v_max_per_30
    ),
    'checks', jsonb_build_object(
      'profile_not_blocked', NOT coalesce(v_blocked, false),
      'access_level_full', cp.access_level = 'full_access',
      'documents_operational_ok', cp.documents_operational_ok,
      'initial_approval_at_set', cp.initial_approval_at IS NOT NULL,
      'is_online', cp.is_online,
      'not_suspended', NOT cp.suspended,
      'within_working_hours', v_hours_ok,
      'no_active_pending_or_accepted_call', NOT v_has_active,
      'cooldown_since_last_completed_ok', v_cooldown_ok,
      'under_30_day_frequency_cap', v_frequency_ok,
      'session_start_gap_ok', v_session_gap_ok
    ),
    'failure_reasons', COALESCE(to_jsonb(v_reasons), '[]'::jsonb)
  );
END;
$$;

-- ----------------------------------------------------------------
-- 9) Chef: recompute access after registration uploads (self only)
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chef_recompute_access_for_self ()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.recompute_chef_access_level (auth.uid ());
END;
$$;

REVOKE ALL ON FUNCTION public.chef_recompute_access_for_self () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chef_recompute_access_for_self () TO authenticated;

-- ----------------------------------------------------------------
-- 10) Backfill access for all chefs
-- ----------------------------------------------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT id FROM public.chef_profiles
  LOOP
    PERFORM public.recompute_chef_access_level (r.id);
  END LOOP;
END $$;

COMMIT;
