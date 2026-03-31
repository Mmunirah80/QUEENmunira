-- ============================================================
-- NAHAM — Dev / QA: simulate admin approve or reject (SQL Editor)
-- Use on staging only. Replace CHEF_UUID with the cook's auth user id.
-- After updates, the cook app picks up approval via Realtime + refresh (or restart).
--
-- Prefer (cook app buttons): run **supabase_dev_simulate_chef_review_rpc.sql**
-- then use Profile → "Dev: simulate admin review" (debug or COOK_DEV_SIMULATE_REVIEW).
-- ============================================================

-- 1) Simulate FULL APPROVAL (both required doc types approved + account approved)
--    Run the two UPDATE blocks below, then fix any row ids from your chef_documents table.

/*
UPDATE public.chef_documents
SET
  status = 'approved',
  rejection_reason = NULL,
  reviewed_at = now(),
  updated_at = now()
WHERE chef_id = 'CHEF_UUID'
  AND document_type IN ('national_id', 'freelancer_id')
  AND status = 'pending';

-- If you already have approved rows and only need to open the account:
UPDATE public.chef_profiles
SET
  approval_status = 'approved',
  rejection_reason = NULL,
  suspended = FALSE,
  suspension_reason = NULL
WHERE id = 'CHEF_UUID';
*/

-- 2) Simulate DOCUMENT REJECT (keeps account pending; sets suspended for messaging — optional)
/*
UPDATE public.chef_documents
SET
  status = 'rejected',
  rejection_reason = 'محاكاة: صورة غير واضحة',
  reviewed_at = now(),
  updated_at = now()
WHERE id = 'DOCUMENT_ROW_UUID';

UPDATE public.chef_profiles
SET
  suspended = TRUE,
  suspension_reason = 'محاكاة رفض مستند — أعدي الرفع من البروفايل ← المستندات'
WHERE id = 'CHEF_UUID';
*/

-- 3) Insert a fake admin support message (optional) — requires an existing chef-admin conversation
--    and your admin user id for sender_id.

/*
INSERT INTO public.messages (conversation_id, sender_id, content, is_read)
VALUES (
  'CONVERSATION_UUID',
  'ADMIN_AUTH_UID',
  'محاكاة: تمت مراجعة المستندات.',
  FALSE
);
*/
