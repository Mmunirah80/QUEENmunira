-- ============================================================
-- NAHAM — Chef verification documents (append-only history)
-- Run in Supabase SQL Editor after backup.
--
-- Goals:
-- - Each upload = new row (no replace of history).
-- - Per-row status + optional expiry_date.
-- - RLS: chef inserts/reads own; admin updates status.
--
-- Storage: app uses bucket `documents`; file_url = object path inside bucket.
-- ============================================================

-- 1) Table (create if missing)
CREATE TABLE IF NOT EXISTS public.chef_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chef_id uuid NOT NULL REFERENCES public.chef_profiles (id) ON DELETE CASCADE,
  document_type text NOT NULL,
  file_url text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  expiry_date date,
  rejection_reason text,
  reviewed_by uuid REFERENCES public.profiles (id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  no_expiry boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chef_documents_document_type_allowed
    CHECK (document_type IN ('national_id', 'freelancer_id', 'license')),
  CONSTRAINT chef_documents_status_allowed
    CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- 2) Drop one-row-per-type constraint if a previous schema added it
ALTER TABLE public.chef_documents
  DROP CONSTRAINT IF EXISTS chef_documents_chef_id_document_type_key;

-- 2a) Legacy: document_type was enum public.doc_type — CHECK('freelancer_id'…) fails (22P02).
--     Cast column to text so app values national_id / freelancer_id / license work.
ALTER TABLE public.chef_documents
  DROP CONSTRAINT IF EXISTS chef_documents_document_type_allowed;

DO $$
BEGIN
  ALTER TABLE public.chef_documents
    ALTER COLUMN document_type TYPE text USING (document_type::text);
EXCEPTION
  WHEN undefined_column THEN
    NULL;
END $$;

-- If enum labels differed from the app, uncomment and adjust (inspect: SELECT DISTINCT document_type FROM chef_documents;):
-- UPDATE public.chef_documents SET document_type = 'freelancer_id' WHERE document_type ILIKE 'freelance%';
-- UPDATE public.chef_documents SET document_type = 'national_id' WHERE document_type ILIKE 'national%';

-- 3) Backfill columns on older manual tables
ALTER TABLE public.chef_documents
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS expiry_date date,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.profiles (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS no_expiry boolean NOT NULL DEFAULT false;

UPDATE public.chef_documents SET id = gen_random_uuid() WHERE id IS NULL;

ALTER TABLE public.chef_documents
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class r ON r.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = r.relnamespace
    WHERE n.nspname = 'public'
      AND r.relname = 'chef_documents'
      AND c.contype = 'p'
  ) THEN
    ALTER TABLE public.chef_documents ADD PRIMARY KEY (id);
  END IF;
END $$;

ALTER TABLE public.chef_documents
  ALTER COLUMN chef_id SET NOT NULL,
  ALTER COLUMN document_type SET NOT NULL,
  ALTER COLUMN file_url SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chef_documents_document_type_allowed'
  ) THEN
    ALTER TABLE public.chef_documents
      ADD CONSTRAINT chef_documents_document_type_allowed
      CHECK (document_type IN ('national_id', 'freelancer_id', 'license'));
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chef_documents_status_allowed'
  ) THEN
    ALTER TABLE public.chef_documents
      ADD CONSTRAINT chef_documents_status_allowed
      CHECK (status IN ('pending', 'approved', 'rejected'));
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS chef_documents_chef_created_idx
  ON public.chef_documents (chef_id, created_at DESC);

CREATE INDEX IF NOT EXISTS chef_documents_pending_idx
  ON public.chef_documents (status)
  WHERE status = 'pending';

-- 4) updated_at trigger
CREATE OR REPLACE FUNCTION public.set_chef_documents_updated_at ()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_chef_documents_updated_at ON public.chef_documents;
CREATE TRIGGER trg_chef_documents_updated_at
  BEFORE UPDATE ON public.chef_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.set_chef_documents_updated_at ();

-- 4b) RLS helpers (required below). Idempotent — matches supabase_rls_authorization_hardening.sql.
--     Run this block if you have not applied the full hardening migration yet.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_blocked boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.auth_role ()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.auth_is_blocked ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT is_blocked FROM public.profiles WHERE id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.auth_is_active_user ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL AND NOT public.auth_is_blocked();
$$;

-- 5) RLS
ALTER TABLE public.chef_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chef_documents_select_own_or_admin ON public.chef_documents;
CREATE POLICY chef_documents_select_own_or_admin
  ON public.chef_documents FOR SELECT
  USING (
    public.is_admin ()
    OR (public.auth_is_active_user () AND auth.uid () = chef_id)
  );

DROP POLICY IF EXISTS chef_documents_insert_own_chef ON public.chef_documents;
CREATE POLICY chef_documents_insert_own_chef
  ON public.chef_documents FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'chef'
    AND auth.uid () = chef_id
  );

DROP POLICY IF EXISTS chef_documents_update_admin ON public.chef_documents;
CREATE POLICY chef_documents_update_admin
  ON public.chef_documents FOR UPDATE
  USING (public.is_admin ())
  WITH CHECK (public.is_admin ());

DROP POLICY IF EXISTS chef_documents_delete_admin ON public.chef_documents;
CREATE POLICY chef_documents_delete_admin
  ON public.chef_documents FOR DELETE
  USING (public.is_admin ());

COMMENT ON TABLE public.chef_documents IS
  'Append-only verification uploads; renew by inserting a new row. Latest row per document_type drives UX.';
