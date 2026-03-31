-- ============================================================
-- NAHAM — Single pipeline for chef document approve / reject
-- Admin app + cook simulation both call this RPC (no duplicate Dart logic).
--
-- 1) Run in Supabase SQL Editor (owner).
-- 2) Enable cook-side simulation in DB (staging only):
--      UPDATE public.dev_feature_flags SET enabled = true
--      WHERE key = 'chef_document_review_simulation';
--    Production: keep enabled = false (or REVOKE EXECUTE from authenticated
--    if you expose a tighter role model).
-- 3) App flag (UI): kDebugMode or --dart-define=COOK_SIMULATE_ADMIN_REVIEW=true
--    (see CookDevReview.simulationModeEnabled).
--
-- Replaces: public.dev_simulate_chef_review(text) — dropped at end of file.
-- ============================================================

-- Align with Flutter inserts
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;

-- Staging toggle for chef self-service simulation (see chef_document_review_simulation_enabled)
CREATE TABLE IF NOT EXISTS public.dev_feature_flags (
  key text PRIMARY KEY,
  enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.dev_feature_flags (key, enabled)
VALUES ('chef_document_review_simulation', false)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.chef_document_review_simulation_enabled ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dev_feature_flags
    WHERE key = 'chef_document_review_simulation'
      AND enabled = true
  );
$$;

REVOKE ALL ON FUNCTION public.chef_document_review_simulation_enabled () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chef_document_review_simulation_enabled () TO authenticated;

-- Mirrors lib/features/cook/data/chef_documents_compliance.dart (national_id + freelancer_id).
CREATE OR REPLACE FUNCTION public._chef_type_allows_ops (p_chef_id uuid, p_doc_type text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  latest_status text;
  r record;
BEGIN
  SELECT lower(trim(status::text))
  INTO latest_status
  FROM public.chef_documents
  WHERE chef_id = p_chef_id
    AND document_type = p_doc_type
  ORDER BY created_at DESC
  LIMIT 1;

  IF latest_status IS NULL THEN
    RETURN false;
  END IF;

  IF latest_status = 'rejected' THEN
    RETURN false;
  END IF;

  FOR r IN
    SELECT status, expiry_date
    FROM public.chef_documents
    WHERE chef_id = p_chef_id
      AND document_type = p_doc_type
    ORDER BY created_at DESC
  LOOP
    IF lower(trim(r.status::text)) <> 'approved' THEN
      CONTINUE;
    END IF;
    IF r.expiry_date IS NOT NULL AND r.expiry_date < (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date THEN
      CONTINUE;
    END IF;
    RETURN true;
  END LOOP;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public._chef_compliance_can_receive_orders (p_chef_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT public._chef_type_allows_ops (p_chef_id, 'national_id')
    AND public._chef_type_allows_ops (p_chef_id, 'freelancer_id');
$$;

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
  v_body_approve constant text := 'تم قبول المستند. يمكنك متابعة استخدام التطبيق.';
  v_msg text;
  v_conv_id uuid;
  v_reviewer uuid;
  v_msg_sender uuid;
  v_now timestamptz := now();
  v_doc_status text;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;

  SELECT chef_id, lower(trim(status::text))
  INTO v_chef_id, v_doc_status
  FROM public.chef_documents
  WHERE id = p_document_id;

  IF v_chef_id IS NULL THEN
    RAISE EXCEPTION 'Document not found';
  END IF;

  IF public.is_admin (v_actor) THEN
    v_reviewer := v_actor;
  ELSIF v_chef_id = v_actor AND public.chef_document_review_simulation_enabled () THEN
    IF v_doc_status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION 'Simulation only allowed on pending documents';
    END IF;
    SELECT p.id
    INTO v_reviewer
    FROM public.profiles p
    WHERE lower(trim(p.role::text)) = 'admin'
      AND (p.is_blocked IS NULL OR p.is_blocked = false)
    ORDER BY p.id
    LIMIT 1;
  ELSE
    RAISE EXCEPTION 'Forbidden';
  END IF;

  IF v_status = 'rejected' THEN
    v_reason := nullif(trim(coalesce(p_rejection_reason, '')), '');
    IF v_reason IS NULL THEN
      v_reason := 'Rejected';
    END IF;
    v_reason_text := v_reason;
  END IF;

  -- Support chat + reviewed_by: real admin uses auth.uid(); simulation may have no profiles row
  -- with role=admin — fall back to the acting user so the message row always inserts (RLS-safe sender).
  v_msg_sender := coalesce(v_reviewer, v_actor);

  UPDATE public.chef_documents
  SET
    status = v_status,
    reviewed_at = v_now,
    reviewed_by = v_msg_sender,
    rejection_reason = CASE WHEN v_status = 'approved' THEN NULL ELSE v_reason END
  WHERE id = p_document_id;

  IF v_status = 'rejected' THEN
    UPDATE public.chef_profiles
    SET
      suspended = true,
      suspension_reason = v_reason_text
    WHERE id = v_chef_id;
  ELSIF v_status = 'approved' THEN
    -- chef_profiles fields used by the app:
    -- • Router limitedShell uses UserEntity (approval_status, rejection_reason) + ChefDocModel (approval_status, suspended).
    -- • Document reject sets suspended=true; we must clear that on ANY approve so re-approval / renewal is not stuck.
    -- • Full unlock (Home/Orders/Menu/Reels) needs approval_status='approved' + compliance (national_id + freelancer_id).
    IF public._chef_compliance_can_receive_orders (v_chef_id) THEN
      UPDATE public.chef_profiles
      SET
        approval_status = 'approved',
        rejection_reason = NULL,
        suspended = false,
        suspension_reason = NULL
      WHERE id = v_chef_id;
    ELSE
      -- Partial approval: clear doc-review suspension (was only cleared inside compliance branch before).
      -- If the account was fully rejected, move back to pending so UserEntity.isChefRejected is false after refresh.
      UPDATE public.chef_profiles
      SET
        suspended = false,
        suspension_reason = NULL,
        approval_status = CASE
          WHEN lower(trim(coalesce(approval_status, ''))) = 'rejected' THEN 'pending'
          ELSE approval_status
        END,
        rejection_reason = CASE
          WHEN lower(trim(coalesce(approval_status, ''))) = 'rejected' THEN NULL
          ELSE rejection_reason
        END
      WHERE id = v_chef_id;
    END IF;
  END IF;

  IF v_status = 'rejected' THEN
    INSERT INTO public.notifications (customer_id, title, body, is_read, type)
    VALUES (
      v_chef_id,
      'تم رفض مستند',
      v_reason_text,
      false,
      'admin_document'
    );
  ELSE
    INSERT INTO public.notifications (customer_id, title, body, is_read, type)
    VALUES (
      v_chef_id,
      'تم قبول مستند',
      v_body_approve,
      false,
      'admin_document'
    );
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
      'بخصوص مستنداتك: ' || v_reason_text || E'\n'
      || 'الرجاء فتح البروفايل ← المستندات وإعادة رفع الملف الصحيح. شكراً لتفهمك — فريق نهام.' || E'\n'
      || '—' || E'\n'
      || 'Document update: ' || v_reason_text || E'\n'
      || 'Please open Profile → Documents and upload a corrected file. — Naham team';
  ELSE
    v_msg :=
      'تم قبول المستند المرفوع. شكراً لك.' || E'\n'
      || '—' || E'\n'
      || 'Your uploaded document was approved. Thank you! — Naham';
  END IF;

  INSERT INTO public.messages (conversation_id, sender_id, content, is_read)
  VALUES (v_conv_id, v_msg_sender, v_msg, false);
END;
$$;

REVOKE ALL ON FUNCTION public.apply_chef_document_review (uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_chef_document_review (uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.apply_chef_document_review (uuid, text, text) IS
  'Approve/reject one chef_documents row; updates chef_profiles, notifications, Support (chef-admin) thread. '
  'Admins: any document. Chefs: pending docs only when dev_feature_flags.chef_document_review_simulation is on.';

DROP FUNCTION IF EXISTS public.dev_simulate_chef_review (text);

REVOKE ALL ON FUNCTION public._chef_type_allows_ops (uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._chef_compliance_can_receive_orders (uuid) FROM PUBLIC;
