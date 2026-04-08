-- ============================================================
-- NAHAM — notifications.chef_document_id (if you deploy RPC patch only)
-- supabase_apply_chef_document_review.sql adds this column inline; use this
-- file alone when you only need the column before replacing the function.
-- ============================================================

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS chef_document_id uuid;

COMMENT ON COLUMN public.notifications.chef_document_id IS
  'Source chef_documents.id for admin_document notifications; dedup on review retry.';
