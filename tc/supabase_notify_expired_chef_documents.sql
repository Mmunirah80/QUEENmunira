-- ============================================================
-- NAHAM — Expired chef document: notification + chef-admin chat (additive)
-- ============================================================
-- Run in Supabase SQL Editor after chef_documents / conversations / messages / notifications exist.
-- Triggered from the chef app via RPC (no cron): see ChefExpiredDocumentsNotify in Flutter.
--
-- Duplicate prevention: chef_documents.expiry_notification_sent_at set per row after send.
-- ============================================================

ALTER TABLE public.chef_documents
  ADD COLUMN IF NOT EXISTS expiry_notification_sent_at timestamptz;

COMMENT ON COLUMN public.chef_documents.expiry_notification_sent_at IS
  'When a Document expired notification + support message was sent for this row (approved + past expiry_date).';

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
    -- chef-admin threads: [customer_id] is required by schema/RLS; reuse chef id as the non-admin
    -- participant key when no separate "admin inbox" customer exists (see app chat routing).
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
END;
$$;

REVOKE ALL ON FUNCTION public.notify_expired_chef_documents () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_expired_chef_documents () TO authenticated;

COMMENT ON FUNCTION public.notify_expired_chef_documents () IS
  'Chef-only (auth.uid): for each approved expired doc row without expiry_notification_sent_at, inserts notification and optional admin support message; marks row.';
