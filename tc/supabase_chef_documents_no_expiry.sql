-- ============================================================
-- NAHAM — chef_documents.no_expiry (explicit metadata)
-- Run in Supabase SQL Editor after backup.
--
-- When [no_expiry] is true, [expiry_date] must be null (enforced in app).
-- When [no_expiry] is false, the chef chose "has expiry" and must set [expiry_date].
-- Legacy rows: [no_expiry] false and [expiry_date] null = treat as unspecified / no date on file.
-- ============================================================

ALTER TABLE public.chef_documents
  ADD COLUMN IF NOT EXISTS no_expiry boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.chef_documents.no_expiry IS
  'True when the upload is explicitly marked as non-expiring (no expiry_date).';
