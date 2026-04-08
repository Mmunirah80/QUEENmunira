-- =============================================================================
-- QA / demo — FULL seed: cook documents matrix, restrictions, orders, chats
-- =============================================================================
-- [عربي] إذا «ما يضبط»:
--   1) شغّل أولاً: supabase_qa_diagnose.sql (نفس المجلد) وتأكد الجداول والدوال موجودة.
--   2) نفّذ الترحيلات بالترتيب (كل ملف كامل في SQL Editor):
--        supabase_chef_access_documents_v3.sql
--        supabase_chef_documents_two_types_migration_v1.sql
--        supabase_apply_chef_document_review.sql
--   3) بعدها فقط: هذا الملف (الكامل من السطر الأول).
--   4) انسخ رسالة الخطأ كاملة من Supabase (الكود + DETAIL) إذا احتجت مساعدة.
--   المسار على جهازك: ...\muira hero\naham\tc\
-- =============================================================================
-- Matrix map (kitchen_name prefix "QA …"):
--   DOC d001–d010 — onboarding: pending, both approved, mixed reject, both rejected,
--       approved+pending, rejected+pending, resubmit→approved, expired approved,
--       missing-file placeholder + pending health.
--   RESTR d011–d020 — active, blocked profile, freeze 3/7/14d, warnings 0–3, pending resubmission.
--   Orders — e0a00001-0000-4000-8e00-000000000001–008 on d011 + c001 (pending→expired cancels).
--   Chats — e0a00001-0000-4000-8f00-* conversations: empty, single, many, unread, read-all,
--       order-linked, blocked/frozen cooks, customer-support + admin, chef-admin, duplicate body,
--       failed-send marker, image line, null name / no avatar, out-of-order timestamps, blocked customer.
-- Run ONLY on disposable DBs. Prerequisites:
--   • Core tables (profiles, chef_profiles, orders, conversations, …)
--   • supabase_chef_access_documents_v3.sql + supabase_chef_documents_two_types_migration_v1.sql
--   • supabase_apply_chef_document_review.sql (notifications.chef_document_id)
--   • supabase_orders_unified_cancel_v1.sql (cancel_reason on orders) — optional
--
-- Stable namespace: all primary keys use prefix e0a00001-0000-4000-8*00-…
-- Password for every inserted auth user: NahamDemo2026!
--
-- Inspect in Admin: filter profiles by full_name starting with "QA " or email @naham.qa.demo
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS profile_image_url text;

ALTER TABLE public.conversations
  ALTER COLUMN chef_id DROP NOT NULL;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS kitchen_latitude double precision,
  ADD COLUMN IF NOT EXISTS kitchen_longitude double precision,
  ADD COLUMN IF NOT EXISTS initial_approval_at timestamptz,
  ADD COLUMN IF NOT EXISTS freeze_until timestamptz,
  ADD COLUMN IF NOT EXISTS freeze_type text,
  ADD COLUMN IF NOT EXISTS freeze_level integer,
  ADD COLUMN IF NOT EXISTS warning_count integer,
  ADD COLUMN IF NOT EXISTS inspection_penalty_step integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS inspection_violation_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS kitchen_timezone text NOT NULL DEFAULT 'Asia/Riyadh';

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS order_id uuid,
  ADD COLUMN IF NOT EXISTS last_message text,
  ADD COLUMN IF NOT EXISTS last_message_at timestamptz,
  ADD COLUMN IF NOT EXISTS admin_moderation_state text NOT NULL DEFAULT 'none';

ALTER TABLE public.menu_items
  ADD COLUMN IF NOT EXISTS moderation_status text;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS idempotency_key uuid,
  ADD COLUMN IF NOT EXISTS cancel_reason text;

-- ─── chef_documents: CHECK constraints (canonical 2-slot types + statuses) ──
-- If you see 23514 on document_type: older schemas only allowed national_id /
-- freelancer_id / license. This seed uses id_document + health_or_kitchen_document.
-- (Same rules as supabase_chef_access_documents_v3.sql + two-slot app types.)
UPDATE public.chef_documents
SET status = 'pending_review'
WHERE lower(trim(status::text)) IN ('pending', 'pending_review');

UPDATE public.chef_documents
SET status = lower(trim(status::text))
WHERE status IS NOT NULL;

ALTER TABLE public.chef_documents
  DROP CONSTRAINT IF EXISTS chef_documents_document_type_allowed;

ALTER TABLE public.chef_documents
  ADD CONSTRAINT chef_documents_document_type_allowed
  CHECK (
    lower(trim(document_type::text)) IN (
      'national_id',
      'freelancer_id',
      'license',
      'id_document',
      'health_or_kitchen_document'
    )
  );

ALTER TABLE public.chef_documents
  DROP CONSTRAINT IF EXISTS chef_documents_status_allowed;

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

-- ─── Stable ids (see header) ─────────────────────────────────────────────────
-- Admin
-- e0a00001-0000-4000-8a00-00000000a001
-- Customers c001–c008
-- Chefs d001–d025

-- ═══════════════════════════════════════════════════════════════════════════
-- 0) Remove auth rows that use this seed’s EMAIL but the WRONG UUID (fixes 23503 on public.profiles).
--    Disposable DB only.
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_expected uuid[];
BEGIN
  v_expected :=
    ARRAY[
      'e0a00001-0000-4000-8a00-00000000a001'::uuid,
      'e0a00001-0000-4000-8a00-00000000c001'::uuid,
      'e0a00001-0000-4000-8a00-00000000c002'::uuid,
      'e0a00001-0000-4000-8a00-00000000c003'::uuid,
      'e0a00001-0000-4000-8a00-00000000c004'::uuid,
      'e0a00001-0000-4000-8a00-00000000c005'::uuid,
      'e0a00001-0000-4000-8a00-00000000c006'::uuid,
      'e0a00001-0000-4000-8a00-00000000c007'::uuid,
      'e0a00001-0000-4000-8a00-00000000c008'::uuid
    ]
    || ARRAY(
      SELECT format('e0a00001-0000-4000-8a00-00000000d%s', lpad(n::text, 3, '0'))::uuid
      FROM generate_series(1, 25) AS n
    );

  DELETE FROM auth.identities
  WHERE user_id IN (
    SELECT u.id
    FROM auth.users u
    WHERE NOT (u.id = ANY (v_expected))
      AND (
        lower(trim(u.email)) = 'qa.admin@naham.qa.demo'
        OR lower(trim(u.email)) IN (
          'qa.customer.alpha@naham.qa.demo',
          'qa.customer.beta@naham.qa.demo',
          'qa.customer.gamma@naham.qa.demo',
          'qa.customer.delta@naham.qa.demo',
          'qa.customer.epsilon@naham.qa.demo',
          'qa.customer.noavatar@naham.qa.demo',
          'qa.customer.noname@naham.qa.demo',
          'qa.customer.zeta@naham.qa.demo'
        )
        OR lower(trim(u.email)) IN (
          SELECT format('qa.cook.d%s@naham.qa.demo', lpad(n::text, 3, '0'))
          FROM generate_series(1, 25) AS n
        )
      )
  );

  DELETE FROM auth.users
  WHERE id IN (
    SELECT u.id
    FROM auth.users u
    WHERE NOT (u.id = ANY (v_expected))
      AND (
        lower(trim(u.email)) = 'qa.admin@naham.qa.demo'
        OR lower(trim(u.email)) IN (
          'qa.customer.alpha@naham.qa.demo',
          'qa.customer.beta@naham.qa.demo',
          'qa.customer.gamma@naham.qa.demo',
          'qa.customer.delta@naham.qa.demo',
          'qa.customer.epsilon@naham.qa.demo',
          'qa.customer.noavatar@naham.qa.demo',
          'qa.customer.noname@naham.qa.demo',
          'qa.customer.zeta@naham.qa.demo'
        )
        OR lower(trim(u.email)) IN (
          SELECT format('qa.cook.d%s@naham.qa.demo', lpad(n::text, 3, '0'))
          FROM generate_series(1, 25) AS n
        )
      )
  );
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Auth users (fixed UUIDs) + identities
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_instance uuid;
  v_pw text;
  v_uid uuid;
  v_email text;
  d int;
  r RECORD;
BEGIN
  v_pw := crypt('NahamDemo2026!', gen_salt('bf'));
  SELECT id INTO v_instance FROM auth.instances LIMIT 1;
  IF v_instance IS NULL THEN
    v_instance := '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;

  FOR r IN
    SELECT * FROM (VALUES
      ('e0a00001-0000-4000-8a00-00000000a001'::uuid, 'qa.admin@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c001'::uuid, 'qa.customer.alpha@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c002'::uuid, 'qa.customer.beta@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c003'::uuid, 'qa.customer.gamma@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c004'::uuid, 'qa.customer.delta@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c005'::uuid, 'qa.customer.epsilon@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c006'::uuid, 'qa.customer.noavatar@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c007'::uuid, 'qa.customer.noname@naham.qa.demo'),
      ('e0a00001-0000-4000-8a00-00000000c008'::uuid, 'qa.customer.zeta@naham.qa.demo')
    ) AS t(uid, em)
  LOOP
    -- Skip if this UUID or this email already exists (avoids users_email_partial_key / duplicate email).
    IF EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = r.uid OR lower(trim(email)) = lower(trim(r.em))
    ) THEN
      CONTINUE;
    END IF;
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) VALUES (
      r.uid, v_instance, 'authenticated', 'authenticated',
      r.em, v_pw, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('email', r.em), now(), now()
    );
    BEGIN
      INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id,
        last_sign_in_at, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), r.uid,
        jsonb_build_object('sub', r.uid::text, 'email', r.em),
        'email', r.em, now(), now(), now()
      );
    EXCEPTION
      WHEN unique_violation THEN NULL;
    END;
  END LOOP;

  FOR d IN 1..25 LOOP
    -- Last group = 12 hex chars: 8 zeros + literal d + d001…d025 (matches profiles INSERT below).
    v_uid := format('e0a00001-0000-4000-8a00-00000000d%s', lpad(d::text, 3, '0'))::uuid;
    v_email := format('qa.cook.d%s@naham.qa.demo', lpad(d::text, 3, '0'));
    IF EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = v_uid OR lower(trim(email)) = lower(trim(v_email))
    ) THEN
      CONTINUE;
    END IF;
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) VALUES (
      v_uid, v_instance, 'authenticated', 'authenticated',
      v_email, v_pw, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('email', v_email), now(), now()
    );
    BEGIN
      INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id,
        last_sign_in_at, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), v_uid,
        jsonb_build_object('sub', v_uid::text, 'email', v_email),
        'email', v_email, now(), now(), now()
      );
    EXCEPTION
      WHEN unique_violation THEN NULL;
    END;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Cleanup previous QA seed (same ids only)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  qa uuid[] := ARRAY[
    'e0a00001-0000-4000-8a00-00000000a001'::uuid,
    'e0a00001-0000-4000-8a00-00000000c001'::uuid,
    'e0a00001-0000-4000-8a00-00000000c002'::uuid,
    'e0a00001-0000-4000-8a00-00000000c003'::uuid,
    'e0a00001-0000-4000-8a00-00000000c004'::uuid,
    'e0a00001-0000-4000-8a00-00000000c005'::uuid,
    'e0a00001-0000-4000-8a00-00000000c006'::uuid,
    'e0a00001-0000-4000-8a00-00000000c007'::uuid,
    'e0a00001-0000-4000-8a00-00000000c008'::uuid
  ];
  i int;
BEGIN
  FOR i IN 1..25 LOOP
    qa := qa || format('e0a00001-0000-4000-8a00-00000000d%03s', lpad(i::text, 3, '0'))::uuid;
  END LOOP;

  DELETE FROM public.messages WHERE conversation_id IN (
    SELECT id FROM public.conversations WHERE id::text LIKE 'e0a00001-0000-4000-8f00-%'
  );
  DELETE FROM public.conversations WHERE id::text LIKE 'e0a00001-0000-4000-8f00-%';

  DELETE FROM public.order_items WHERE order_id::text LIKE 'e0a00001-0000-4000-8e00-%';
  IF to_regclass('public.order_status_events') IS NOT NULL THEN
    DELETE FROM public.order_status_events WHERE order_id::text LIKE 'e0a00001-0000-4000-8e00-%';
  END IF;
  DELETE FROM public.orders WHERE id::text LIKE 'e0a00001-0000-4000-8e00-%';

  DELETE FROM public.notifications WHERE id::text LIKE 'e0a00001-0000-4000-8f20-%'
     OR customer_id = ANY (qa);

  DELETE FROM public.chef_documents WHERE chef_id = ANY (qa);
  DELETE FROM public.menu_items WHERE id::text LIKE 'e0a00001-0000-4000-8d10-%';

  DELETE FROM public.chef_profiles WHERE id = ANY (qa);
  DELETE FROM public.profiles WHERE id = ANY (qa);
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Profiles (admin, customers, chefs)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.profiles (id, full_name, role, phone, is_blocked, profile_image_url)
VALUES
  ('e0a00001-0000-4000-8a00-00000000a001', 'QA Admin', 'admin', '+966500000001', false, NULL),
  ('e0a00001-0000-4000-8a00-00000000c001', 'QA Customer Alpha', 'customer', '+966501000001', false, 'https://picsum.photos/seed/qa-c001/128/128'),
  ('e0a00001-0000-4000-8a00-00000000c002', 'QA Customer Beta', 'customer', '+966501000002', false, NULL),
  ('e0a00001-0000-4000-8a00-00000000c003', 'QA Customer Gamma', 'customer', '+966501000003', false, NULL),
  ('e0a00001-0000-4000-8a00-00000000c004', 'QA Customer Delta', 'customer', '+966501000004', false, NULL),
  ('e0a00001-0000-4000-8a00-00000000c005', 'QA Customer Epsilon', 'customer', '+966501000005', false, NULL),
  ('e0a00001-0000-4000-8a00-00000000c006', 'QA Customer NoAvatar', 'customer', '+966501000006', false, NULL),
  ('e0a00001-0000-4000-8a00-00000000c007', NULL, 'customer', '+966501000007', false, NULL),
  ('e0a00001-0000-4000-8a00-00000000c008', 'QA Customer Zeta', 'customer', '+966501000008', true, NULL)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  phone = EXCLUDED.phone,
  profile_image_url = COALESCE(EXCLUDED.profile_image_url, public.profiles.profile_image_url);
-- Do not UPDATE is_blocked here: [enforce_profiles_integrity] forbids changing is_blocked unless is_admin()
-- (auth.uid() is null in SQL editor). Blocked QA users are set on INSERT only (c008, d012 below).

INSERT INTO public.profiles (id, full_name, role, phone, is_blocked)
SELECT
  format('e0a00001-0000-4000-8a00-00000000d%03s', lpad(s.n::text, 3, '0'))::uuid,
  'QA Cook D' || lpad(s.n::text, 3, '0'),
  'chef',
  '+966502' || lpad((100 + s.n)::text, 6, '0'),
  (s.n = 12)
FROM generate_series(1, 25) AS s (n)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  role = 'chef',
  phone = EXCLUDED.phone;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Chef profiles — document demo d001–d010, restrictions d011–d020, chat extras d021–d025
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.chef_profiles (
  id, kitchen_name, is_online, vacation_mode,
  working_hours_start, working_hours_end,
  bank_iban, bank_account_name, bio, kitchen_city,
  approval_status, suspended, initial_approval_at,
  kitchen_latitude, kitchen_longitude, kitchen_timezone,
  freeze_until, freeze_type, freeze_level, warning_count,
  access_level, documents_operational_ok
) VALUES
-- d001 both pending
('e0a00001-0000-4000-8a00-00000000d001', 'QA DOC · both pending', false, false, '09:00', '22:00',
 'SA0380000000000808010180001', 'QA Cook D001', 'Matrix row: id + health pending_review.', 'Riyadh',
 'pending', false, NULL, 24.70, 46.68, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
-- d002 both approved
('e0a00001-0000-4000-8a00-00000000d002', 'QA DOC · both approved', true, false, '09:00', '22:00',
 'SA0380000000000808010180002', 'QA Cook D002', 'Matrix row: both slots approved.', 'Riyadh',
 'approved', false, now() - interval '30 days', 24.71, 46.69, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
-- d003 id ok health rejected
('e0a00001-0000-4000-8a00-00000000d003', 'QA DOC · ID approved · Health rejected', false, false, '09:00', '22:00',
 'SA0380000000000808010180003', 'QA Cook D003', 'Matrix row: health needs resubmission.', 'Riyadh',
 'pending', false, NULL, 24.72, 46.70, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
-- d004 id rejected health ok
('e0a00001-0000-4000-8a00-00000000d004', 'QA DOC · ID rejected · Health approved', false, false, '09:00', '22:00',
 'SA0380000000000808010180004', 'QA Cook D004', 'Matrix row: ID needs resubmission.', 'Riyadh',
 'pending', false, NULL, 24.73, 46.71, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
-- d005 both rejected
('e0a00001-0000-4000-8a00-00000000d005', 'QA DOC · both rejected', false, false, '09:00', '22:00',
 'SA0380000000000808010180005', 'QA Cook D005', 'Matrix row: both rejected.', 'Riyadh',
 'rejected', false, NULL, 24.74, 46.72, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
-- d006 one approved one pending
('e0a00001-0000-4000-8a00-00000000d006', 'QA DOC · ID approved · Health pending', false, false, '09:00', '22:00',
 'SA0380000000000808010180006', 'QA Cook D006', 'Matrix row: mixed pending.', 'Riyadh',
 'pending', false, NULL, 24.75, 46.73, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
-- d007 one rejected one pending
('e0a00001-0000-4000-8a00-00000000d007', 'QA DOC · ID rejected · Health pending', false, false, '09:00', '22:00',
 'SA0380000000000808010180007', 'QA Cook D007', 'Matrix row: ID rejected.', 'Riyadh',
 'pending', false, NULL, 24.76, 46.74, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
-- d008 resubmit narrative (final: both approved)
('e0a00001-0000-4000-8a00-00000000d008', 'QA DOC · Resubmit→Approved (final state)', true, false, '09:00', '22:00',
 'SA0380000000000808010180008', 'QA Cook D008', 'Seed represents post-resubmission approval (both slots).', 'Riyadh',
 'approved', false, now() - interval '5 days', 24.77, 46.75, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
-- d009 expired approved (calendar past)
('e0a00001-0000-4000-8a00-00000000d009', 'QA DOC · Approved but expiry passed', true, false, '09:00', '22:00',
 'SA0380000000000808010180009', 'QA Cook D009', 'Health approved with expiry in the past.', 'Riyadh',
 'approved', false, now() - interval '400 days', 24.78, 46.76, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
-- d010 missing file simulation (sentinel path; storage 404)
('e0a00001-0000-4000-8a00-00000000d010', 'QA DOC · Missing file URL exercise', false, false, '09:00', '22:00',
 'SA0380000000000808010180010', 'QA Cook D010', 'Health row uses qa/demo/MISSING_FILE placeholder.', 'Riyadh',
 'pending', false, NULL, 24.79, 46.77, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false)
ON CONFLICT (id) DO UPDATE SET
  kitchen_name = EXCLUDED.kitchen_name,
  bio = EXCLUDED.bio,
  approval_status = EXCLUDED.approval_status,
  initial_approval_at = EXCLUDED.initial_approval_at,
  access_level = EXCLUDED.access_level,
  documents_operational_ok = EXCLUDED.documents_operational_ok;

INSERT INTO public.chef_profiles (
  id, kitchen_name, is_online, vacation_mode,
  working_hours_start, working_hours_end,
  bank_iban, bank_account_name, bio, kitchen_city,
  approval_status, suspended, initial_approval_at,
  kitchen_latitude, kitchen_longitude, kitchen_timezone,
  freeze_until, freeze_type, freeze_level, warning_count,
  access_level, documents_operational_ok
) VALUES
('e0a00001-0000-4000-8a00-00000000d011', 'QA RESTR · Active approved cook', true, false, '09:00', '22:00',
 'SA0380000000000808010181011', 'QA Cook D011', 'Orders matrix + healthy account.', 'Riyadh',
 'approved', false, now() - interval '200 days', 24.80, 46.78, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d013', 'QA RESTR · Frozen 3 days', true, false, '09:00', '22:00',
 'SA0380000000000808010181013', 'QA Cook D013', 'Soft freeze step.', 'Riyadh',
 'approved', false, now() - interval '100 days', 24.81, 46.79, 'Asia/Riyadh',
 now() + interval '3 days', 'soft', 1, 1, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d014', 'QA RESTR · Frozen 7 days', true, false, '09:00', '22:00',
 'SA0380000000000808010181014', 'QA Cook D014', 'Medium freeze.', 'Riyadh',
 'approved', false, now() - interval '120 days', 24.82, 46.80, 'Asia/Riyadh',
 now() + interval '7 days', 'soft', 2, 2, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d015', 'QA RESTR · Frozen 14 days', true, false, '09:00', '22:00',
 'SA0380000000000808010181015', 'QA Cook D015', 'Long freeze.', 'Riyadh',
 'approved', false, now() - interval '130 days', 24.83, 46.81, 'Asia/Riyadh',
 now() + interval '14 days', 'soft', 3, 3, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d016', 'QA RESTR · Warning count 0', true, false, '09:00', '22:00',
 'SA0380000000000808010181016', 'QA Cook D016', 'Clean warnings.', 'Riyadh',
 'approved', false, now() - interval '90 days', 24.84, 46.82, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d017', 'QA RESTR · Warning count 1', true, false, '09:00', '22:00',
 'SA0380000000000808010181017', 'QA Cook D017', 'Warning 1.', 'Riyadh',
 'approved', false, now() - interval '85 days', 24.85, 46.83, 'Asia/Riyadh', NULL, NULL, 0, 1, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d018', 'QA RESTR · Warning count 2', true, false, '09:00', '22:00',
 'SA0380000000000808010181018', 'QA Cook D018', 'Warning 2.', 'Riyadh',
 'approved', false, now() - interval '80 days', 24.86, 46.84, 'Asia/Riyadh', NULL, NULL, 0, 2, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d019', 'QA RESTR · Warning count 3', true, false, '09:00', '22:00',
 'SA0380000000000808010181019', 'QA Cook D019', 'Warning 3.', 'Riyadh',
 'approved', false, now() - interval '75 days', 24.87, 46.85, 'Asia/Riyadh', NULL, NULL, 0, 3, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d020', 'QA RESTR · Pending resubmission', false, false, '09:00', '22:00',
 'SA0380000000000808010181020', 'QA Cook D020', 'Profile pending + doc rejected.', 'Riyadh',
 'pending', false, NULL, 24.88, 46.86, 'Asia/Riyadh', NULL, NULL, 0, 0, 'partial_access', false),
('e0a00001-0000-4000-8a00-00000000d021', 'QA CHAT · No messages yet', true, false, '09:00', '22:00',
 'SA0380000000000808010181021', 'QA Cook D021', 'Empty thread.', 'Riyadh',
 'approved', false, now() - interval '40 days', 24.89, 46.87, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d022', 'QA CHAT · Single message', true, false, '09:00', '22:00',
 'SA0380000000000808010181022', 'QA Cook D022', 'One message thread.', 'Riyadh',
 'approved', false, now() - interval '35 days', 24.90, 46.88, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d023', 'QA CHAT · Many messages', true, false, '09:00', '22:00',
 'SA0380000000000808010181023', 'QA Cook D023', 'Busy thread.', 'Riyadh',
 'approved', false, now() - interval '60 days', 24.91, 46.89, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d024', 'QA CHAT · Duplicate body test', true, false, '09:00', '22:00',
 'SA0380000000000808010181024', 'QA Cook D024', 'Two rows same copy (dedupe UI).', 'Riyadh',
 'approved', false, now() - interval '20 days', 24.92, 46.90, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true),
('e0a00001-0000-4000-8a00-00000000d025', 'QA CHAT · Out-of-order timestamps', true, false, '09:00', '22:00',
 'SA0380000000000808010181025', 'QA Cook D025', 'Messages inserted with non-chronological created_at.', 'Riyadh',
 'approved', false, now() - interval '18 days', 24.93, 46.91, 'Asia/Riyadh', NULL, NULL, 0, 0, 'full_access', true)
ON CONFLICT (id) DO UPDATE SET
  kitchen_name = EXCLUDED.kitchen_name,
  bio = EXCLUDED.bio,
  approval_status = EXCLUDED.approval_status,
  freeze_until = EXCLUDED.freeze_until,
  warning_count = EXCLUDED.warning_count,
  access_level = EXCLUDED.access_level,
  documents_operational_ok = EXCLUDED.documents_operational_ok;

-- d012 blocked via profile (already is_blocked above)
INSERT INTO public.chef_profiles (
  id, kitchen_name, is_online, vacation_mode,
  working_hours_start, working_hours_end,
  bank_iban, bank_account_name, bio, kitchen_city,
  approval_status, suspended, initial_approval_at,
  kitchen_latitude, kitchen_longitude, kitchen_timezone,
  access_level, documents_operational_ok
) VALUES
('e0a00001-0000-4000-8a00-00000000d012', 'QA RESTR · Blocked cook', false, false, '09:00', '22:00',
 'SA0380000000000808010181012', 'QA Cook D012', 'Blocked at profile level.', 'Riyadh',
 'approved', false, now() - interval '50 days', 24.94, 46.92, 'Asia/Riyadh',
 'blocked_access', false)
ON CONFLICT (id) DO UPDATE SET
  kitchen_name = EXCLUDED.kitchen_name,
  access_level = 'blocked_access';

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) chef_documents (two canonical types)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.chef_documents (
  id, chef_id, document_type, file_url, status, no_expiry, expiry_date,
  rejection_reason, reviewed_at, reviewed_by, created_at
) VALUES
-- d001
('e0a00001-0000-4000-8d00-000000000001', 'e0a00001-0000-4000-8a00-00000000d001', 'id_document',
 'qa/demo/d001/id_pending.pdf', 'pending_review', true, NULL, NULL, NULL, NULL, now()),
('e0a00001-0000-4000-8d00-000000000002', 'e0a00001-0000-4000-8a00-00000000d001', 'health_or_kitchen_document',
 'qa/demo/d001/health_pending.pdf', 'pending_review', true, NULL, NULL, NULL, NULL, now()),
-- d002
('e0a00001-0000-4000-8d00-000000000003', 'e0a00001-0000-4000-8a00-00000000d002', 'id_document',
 'qa/demo/d002/id_ok.pdf', 'approved', true, NULL, NULL, now() - interval '31 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000004', 'e0a00001-0000-4000-8a00-00000000d002', 'health_or_kitchen_document',
 'qa/demo/d002/health_ok.pdf', 'approved', true, NULL, NULL, now() - interval '31 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
-- d003
('e0a00001-0000-4000-8d00-000000000005', 'e0a00001-0000-4000-8a00-00000000d003', 'id_document',
 'qa/demo/d003/id_ok.pdf', 'approved', true, NULL, NULL, now() - interval '10 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000006', 'e0a00001-0000-4000-8a00-00000000d003', 'health_or_kitchen_document',
 'qa/demo/d003/health_bad.pdf', 'rejected', true, NULL, 'Blurry certificate', now() - interval '9 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
-- d004
('e0a00001-0000-4000-8d00-000000000007', 'e0a00001-0000-4000-8a00-00000000d004', 'id_document',
 'qa/demo/d004/id_bad.pdf', 'rejected', true, NULL, 'Name mismatch', now() - interval '8 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000008', 'e0a00001-0000-4000-8a00-00000000d004', 'health_or_kitchen_document',
 'qa/demo/d004/health_ok.pdf', 'approved', true, NULL, NULL, now() - interval '8 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
-- d005
('e0a00001-0000-4000-8d00-000000000009', 'e0a00001-0000-4000-8a00-00000000d005', 'id_document',
 'qa/demo/d005/id_rej.pdf', 'rejected', true, NULL, 'Unreadable', now() - interval '3 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000000a', 'e0a00001-0000-4000-8a00-00000000d005', 'health_or_kitchen_document',
 'qa/demo/d005/health_rej.pdf', 'rejected', true, NULL, 'Wrong document', now() - interval '3 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
-- d006
('e0a00001-0000-4000-8d00-00000000000b', 'e0a00001-0000-4000-8a00-00000000d006', 'id_document',
 'qa/demo/d006/id_ok.pdf', 'approved', true, NULL, NULL, now() - interval '2 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000000c', 'e0a00001-0000-4000-8a00-00000000d006', 'health_or_kitchen_document',
 'qa/demo/d006/health_wait.pdf', 'pending_review', true, NULL, NULL, NULL, NULL, now()),
-- d007
('e0a00001-0000-4000-8d00-00000000000d', 'e0a00001-0000-4000-8a00-00000000d007', 'id_document',
 'qa/demo/d007/id_rej.pdf', 'rejected', true, NULL, 'Expired upload', now() - interval '1 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000000e', 'e0a00001-0000-4000-8a00-00000000d007', 'health_or_kitchen_document',
 'qa/demo/d007/health_wait.pdf', 'pending_review', true, NULL, NULL, NULL, NULL, now()),
-- d008 both approved (resubmit story)
('e0a00001-0000-4000-8d00-00000000000f', 'e0a00001-0000-4000-8a00-00000000d008', 'id_document',
 'qa/demo/d008/id_final.pdf', 'approved', true, NULL, NULL, now() - interval '4 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000010', 'e0a00001-0000-4000-8a00-00000000d008', 'health_or_kitchen_document',
 'qa/demo/d008/health_final.pdf', 'approved', true, NULL, NULL, now() - interval '4 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
-- d009 approved but expiry in the past (calendar)
('e0a00001-0000-4000-8d00-000000000011', 'e0a00001-0000-4000-8a00-00000000d009', 'id_document',
 'qa/demo/d009/id_ok.pdf', 'approved', true, NULL, NULL, now() - interval '400 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000012', 'e0a00001-0000-4000-8a00-00000000d009', 'health_or_kitchen_document',
 'qa/demo/d009/health_expired.pdf', 'approved', false, (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date - 10,
 NULL, now() - interval '400 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
-- d010 sentinel missing blob
('e0a00001-0000-4000-8d00-000000000013', 'e0a00001-0000-4000-8a00-00000000d010', 'id_document',
 'qa/demo/d010/id_ok.pdf', 'approved', true, NULL, NULL, now() - interval '6 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000014', 'e0a00001-0000-4000-8a00-00000000d010', 'health_or_kitchen_document',
 'qa/demo/MISSING_FILE_UPLOAD', 'pending_review', true, NULL, NULL, NULL, NULL, now()),
-- Restriction + orders + chat chefs: mirror approved docs where needed
('e0a00001-0000-4000-8d00-000000000015', 'e0a00001-0000-4000-8a00-00000000d011', 'id_document',
 'qa/demo/d011/id.pdf', 'approved', true, NULL, NULL, now() - interval '200 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000016', 'e0a00001-0000-4000-8a00-00000000d011', 'health_or_kitchen_document',
 'qa/demo/d011/health.pdf', 'approved', true, NULL, NULL, now() - interval '200 days', 'e0a00001-0000-4000-8a00-00000000a001', now())
ON CONFLICT (chef_id, document_type) DO UPDATE SET
  file_url = EXCLUDED.file_url,
  status = EXCLUDED.status,
  no_expiry = EXCLUDED.no_expiry,
  expiry_date = EXCLUDED.expiry_date,
  rejection_reason = EXCLUDED.rejection_reason,
  reviewed_at = EXCLUDED.reviewed_at,
  reviewed_by = EXCLUDED.reviewed_by;

INSERT INTO public.chef_documents (
  id, chef_id, document_type, file_url, status, no_expiry, expiry_date,
  rejection_reason, reviewed_at, reviewed_by, created_at
) VALUES
('e0a00001-0000-4000-8d00-000000000017', 'e0a00001-0000-4000-8a00-00000000d012', 'id_document',
 'qa/demo/d012/id.pdf', 'approved', true, NULL, NULL, now() - interval '50 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000018', 'e0a00001-0000-4000-8a00-00000000d012', 'health_or_kitchen_document',
 'qa/demo/d012/health.pdf', 'approved', true, NULL, NULL, now() - interval '50 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000019', 'e0a00001-0000-4000-8a00-00000000d013', 'id_document',
 'qa/demo/d013/id.pdf', 'approved', true, NULL, NULL, now() - interval '100 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000001a', 'e0a00001-0000-4000-8a00-00000000d013', 'health_or_kitchen_document',
 'qa/demo/d013/health.pdf', 'approved', true, NULL, NULL, now() - interval '100 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000001b', 'e0a00001-0000-4000-8a00-00000000d014', 'id_document',
 'qa/demo/d014/id.pdf', 'approved', true, NULL, NULL, now() - interval '120 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000001c', 'e0a00001-0000-4000-8a00-00000000d014', 'health_or_kitchen_document',
 'qa/demo/d014/health.pdf', 'approved', true, NULL, NULL, now() - interval '120 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000001d', 'e0a00001-0000-4000-8a00-00000000d015', 'id_document',
 'qa/demo/d015/id.pdf', 'approved', true, NULL, NULL, now() - interval '130 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000001e', 'e0a00001-0000-4000-8a00-00000000d015', 'health_or_kitchen_document',
 'qa/demo/d015/health.pdf', 'approved', true, NULL, NULL, now() - interval '130 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000001f', 'e0a00001-0000-4000-8a00-00000000d016', 'id_document',
 'qa/demo/d016/id.pdf', 'approved', true, NULL, NULL, now() - interval '90 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000020', 'e0a00001-0000-4000-8a00-00000000d016', 'health_or_kitchen_document',
 'qa/demo/d016/health.pdf', 'approved', true, NULL, NULL, now() - interval '90 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000021', 'e0a00001-0000-4000-8a00-00000000d017', 'id_document',
 'qa/demo/d017/id.pdf', 'approved', true, NULL, NULL, now() - interval '85 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000022', 'e0a00001-0000-4000-8a00-00000000d017', 'health_or_kitchen_document',
 'qa/demo/d017/health.pdf', 'approved', true, NULL, NULL, now() - interval '85 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000023', 'e0a00001-0000-4000-8a00-00000000d018', 'id_document',
 'qa/demo/d018/id.pdf', 'approved', true, NULL, NULL, now() - interval '80 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000024', 'e0a00001-0000-4000-8a00-00000000d018', 'health_or_kitchen_document',
 'qa/demo/d018/health.pdf', 'approved', true, NULL, NULL, now() - interval '80 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000025', 'e0a00001-0000-4000-8a00-00000000d019', 'id_document',
 'qa/demo/d019/id.pdf', 'approved', true, NULL, NULL, now() - interval '75 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000026', 'e0a00001-0000-4000-8a00-00000000d019', 'health_or_kitchen_document',
 'qa/demo/d019/health.pdf', 'approved', true, NULL, NULL, now() - interval '75 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000027', 'e0a00001-0000-4000-8a00-00000000d021', 'id_document',
 'qa/demo/d021/id.pdf', 'approved', true, NULL, NULL, now() - interval '40 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000028', 'e0a00001-0000-4000-8a00-00000000d021', 'health_or_kitchen_document',
 'qa/demo/d021/health.pdf', 'approved', true, NULL, NULL, now() - interval '40 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000029', 'e0a00001-0000-4000-8a00-00000000d022', 'id_document',
 'qa/demo/d022/id.pdf', 'approved', true, NULL, NULL, now() - interval '35 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000002a', 'e0a00001-0000-4000-8a00-00000000d022', 'health_or_kitchen_document',
 'qa/demo/d022/health.pdf', 'approved', true, NULL, NULL, now() - interval '35 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000002b', 'e0a00001-0000-4000-8a00-00000000d023', 'id_document',
 'qa/demo/d023/id.pdf', 'approved', true, NULL, NULL, now() - interval '60 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000002c', 'e0a00001-0000-4000-8a00-00000000d023', 'health_or_kitchen_document',
 'qa/demo/d023/health.pdf', 'approved', true, NULL, NULL, now() - interval '60 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000002d', 'e0a00001-0000-4000-8a00-00000000d024', 'id_document',
 'qa/demo/d024/id.pdf', 'approved', true, NULL, NULL, now() - interval '20 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000002e', 'e0a00001-0000-4000-8a00-00000000d024', 'health_or_kitchen_document',
 'qa/demo/d024/health.pdf', 'approved', true, NULL, NULL, now() - interval '20 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000002f', 'e0a00001-0000-4000-8a00-00000000d025', 'id_document',
 'qa/demo/d025/id.pdf', 'approved', true, NULL, NULL, now() - interval '18 days', 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-000000000030', 'e0a00001-0000-4000-8a00-00000000d025', 'health_or_kitchen_document',
 'qa/demo/d025/health.pdf', 'approved', true, NULL, NULL, now() - interval '18 days', 'e0a00001-0000-4000-8a00-00000000a001', now())
ON CONFLICT (chef_id, document_type) DO UPDATE SET
  file_url = EXCLUDED.file_url,
  status = EXCLUDED.status,
  no_expiry = EXCLUDED.no_expiry,
  reviewed_at = EXCLUDED.reviewed_at,
  reviewed_by = EXCLUDED.reviewed_by;

-- d020 pending resubmission: one rejected
INSERT INTO public.chef_documents (
  id, chef_id, document_type, file_url, status, no_expiry, rejection_reason, reviewed_at, reviewed_by, created_at
) VALUES
('e0a00001-0000-4000-8d00-000000000099', 'e0a00001-0000-4000-8a00-00000000d020', 'id_document',
 'qa/demo/d020/id_rej.pdf', 'rejected', true, 'Please resubmit clearer photo', now() - interval '2 days',
 'e0a00001-0000-4000-8a00-00000000a001', now()),
('e0a00001-0000-4000-8d00-00000000009a', 'e0a00001-0000-4000-8a00-00000000d020', 'health_or_kitchen_document',
 'qa/demo/d020/health_wait.pdf', 'pending_review', true, NULL, NULL, NULL, now())
ON CONFLICT (chef_id, document_type) DO UPDATE SET
  file_url = EXCLUDED.file_url,
  status = EXCLUDED.status,
  rejection_reason = EXCLUDED.rejection_reason,
  reviewed_at = EXCLUDED.reviewed_at,
  reviewed_by = EXCLUDED.reviewed_by;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) Recompute access (server truth)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT public.recompute_chef_access_level(id)
FROM public.chef_profiles
WHERE id::text LIKE 'e0a00001-0000-4000-8a00-00000000d%';

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) Menu + orders (chef d011, customer c001)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.menu_items (
  id, chef_id, name, description, price, image_url, category,
  daily_quantity, remaining_quantity, is_available, moderation_status, created_at
) VALUES
('e0a00001-0000-4000-8d10-000000000001', 'e0a00001-0000-4000-8a00-00000000d011', 'QA Kabsa Tray',
 'Seeded dish for QA orders.', 55.00, NULL, 'QA', 40, 35, true, 'approved', now() - interval '10 days')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.orders (
  id, customer_id, chef_id, status, total_amount, commission_amount,
  delivery_address, customer_name, chef_name, notes, created_at, updated_at, cancel_reason
) VALUES
('e0a00001-0000-4000-8e00-000000000001', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'pending', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] pending', now() - interval '20 minutes', now() - interval '20 minutes', NULL),
('e0a00001-0000-4000-8e00-000000000002', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'accepted', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] accepted', now() - interval '2 hours', now() - interval '30 minutes', NULL),
('e0a00001-0000-4000-8e00-000000000003', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'preparing', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] preparing', now() - interval '3 hours', now() - interval '10 minutes', NULL),
('e0a00001-0000-4000-8e00-000000000004', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'ready', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] ready', now() - interval '4 hours', now() - interval '5 minutes', NULL),
('e0a00001-0000-4000-8e00-000000000005', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'completed', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] completed', now() - interval '2 days', now() - interval '2 days', NULL),
('e0a00001-0000-4000-8e00-000000000006', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'cancelled', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] cancelled_by_customer', now() - interval '3 days', now() - interval '3 days', 'cancelled_by_customer'),
('e0a00001-0000-4000-8e00-000000000007', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'cancelled', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] cancelled_by_cook', now() - interval '4 days', now() - interval '4 days', 'cancelled_by_cook'),
('e0a00001-0000-4000-8e00-000000000008', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d011',
 'expired', 55.00, 2.75, 'Riyadh QA', 'QA Customer Alpha', 'QA RESTR · Active approved cook',
 '[qa-seed-matrix] expired', now() - interval '5 days', now() - interval '5 days', NULL)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  cancel_reason = EXCLUDED.cancel_reason,
  notes = EXCLUDED.notes;

INSERT INTO public.order_items (id, order_id, menu_item_id, dish_name, quantity, unit_price)
VALUES
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000001', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00),
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000002', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00),
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000003', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00),
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000004', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00),
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000005', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00),
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000006', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00),
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000007', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00),
(gen_random_uuid(), 'e0a00001-0000-4000-8e00-000000000008', 'e0a00001-0000-4000-8d10-000000000001', 'QA Kabsa Tray', 1, 55.00);

-- ═══════════════════════════════════════════════════════════════════════════
-- 8) Conversations + messages (deterministic conv ids e0a00001-0000-4000-8f00-*)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.conversations (
  id, customer_id, chef_id, type, order_id, created_at, last_message, last_message_at, admin_moderation_state
) VALUES
('e0a00001-0000-4000-8f00-000000000001', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d021',
 'customer-chef', NULL, now() - interval '3 days', NULL, NULL, 'none'),
('e0a00001-0000-4000-8f00-000000000002', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d022',
 'customer-chef', NULL, now() - interval '2 days', 'Only message', now() - interval '2 days', 'none'),
('e0a00001-0000-4000-8f00-000000000003', 'e0a00001-0000-4000-8a00-00000000c002', 'e0a00001-0000-4000-8a00-00000000d023',
 'customer-chef', NULL, now() - interval '10 days', 'Last from cook', now() - interval '1 hour', 'none'),
('e0a00001-0000-4000-8f00-000000000004', 'e0a00001-0000-4000-8a00-00000000c003', 'e0a00001-0000-4000-8a00-00000000d011',
 'customer-chef', NULL, now() - interval '6 hours', 'Unread batch', now() - interval '15 minutes', 'none'),
('e0a00001-0000-4000-8f00-000000000005', 'e0a00001-0000-4000-8a00-00000000c004', 'e0a00001-0000-4000-8a00-00000000d011',
 'customer-chef', NULL, now() - interval '1 day', 'All read', now() - interval '20 minutes', 'none'),
('e0a00001-0000-4000-8f00-000000000006', 'e0a00001-0000-4000-8a00-00000000c005', 'e0a00001-0000-4000-8a00-00000000d011',
 'customer-chef', 'e0a00001-0000-4000-8e00-000000000003', now() - interval '3 hours',
 'Order-linked chat', now() - interval '5 minutes', 'none'),
('e0a00001-0000-4000-8f00-000000000007', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d012',
 'customer-chef', NULL, now() - interval '30 days', 'Blocked cook thread', now() - interval '10 days', 'none'),
('e0a00001-0000-4000-8f00-000000000008', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d013',
 'customer-chef', NULL, now() - interval '8 days', 'Frozen cook', now() - interval '2 days', 'none'),
('e0a00001-0000-4000-8f00-000000000009', 'e0a00001-0000-4000-8a00-00000000c001', NULL,
 'customer-support', NULL, now() - interval '12 days', 'Admin reply', now() - interval '11 days', 'none'),
('e0a00001-0000-4000-8f00-00000000000a', 'e0a00001-0000-4000-8a00-00000000d011', 'e0a00001-0000-4000-8a00-00000000d011',
 'chef-admin', NULL, now() - interval '400 days', 'Support thread', now() - interval '1 day', 'none'),
('e0a00001-0000-4000-8f00-00000000000b', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d024',
 'customer-chef', NULL, now() - interval '4 days', 'Duplicate body test', now() - interval '4 days', 'none'),
('e0a00001-0000-4000-8f00-00000000000c', 'e0a00001-0000-4000-8a00-00000000c006', 'e0a00001-0000-4000-8a00-00000000d011',
 'customer-chef', NULL, now() - interval '7 days', 'Avatar fallback demo', now() - interval '7 days', 'none'),
('e0a00001-0000-4000-8f00-00000000000d', 'e0a00001-0000-4000-8a00-00000000c007', 'e0a00001-0000-4000-8a00-00000000d011',
 'customer-chef', NULL, now() - interval '6 days', 'Null display name', now() - interval '6 days', 'none'),
('e0a00001-0000-4000-8f00-00000000000e', 'e0a00001-0000-4000-8a00-00000000c001', 'e0a00001-0000-4000-8a00-00000000d025',
 'customer-chef', NULL, now() - interval '5 days', 'Out-of-order timestamps', now() - interval '5 days', 'none'),
('e0a00001-0000-4000-8f00-00000000000f', 'e0a00001-0000-4000-8a00-00000000c008', 'e0a00001-0000-4000-8a00-00000000d011',
 'customer-chef', NULL, now() - interval '9 days', 'Blocked customer', now() - interval '9 days', 'reported')
ON CONFLICT (id) DO UPDATE SET
  last_message = EXCLUDED.last_message,
  order_id = COALESCE(EXCLUDED.order_id, public.conversations.order_id);

INSERT INTO public.messages (id, conversation_id, sender_id, content, is_read, created_at) VALUES
-- v002 one message
('e0a00001-0000-4000-8f10-000000000001', 'e0a00001-0000-4000-8f00-000000000002', 'e0a00001-0000-4000-8a00-00000000c001',
 'Single customer message for QA.', true, now() - interval '2 days'),
-- v003 many + last from cook
('e0a00001-0000-4000-8f10-000000000002', 'e0a00001-0000-4000-8f00-000000000003', 'e0a00001-0000-4000-8a00-00000000c002', 'Hi — large order?', true, now() - interval '10 days'),
('e0a00001-0000-4000-8f10-000000000003', 'e0a00001-0000-4000-8f00-000000000003', 'e0a00001-0000-4000-8a00-00000000d023', 'Yes we can scale.', true, now() - interval '9 days'),
('e0a00001-0000-4000-8f10-000000000004', 'e0a00001-0000-4000-8f00-000000000003', 'e0a00001-0000-4000-8a00-00000000c002', 'Great — 6pm pickup?', true, now() - interval '8 days'),
('e0a00001-0000-4000-8f10-000000000005', 'e0a00001-0000-4000-8f00-000000000003', 'e0a00001-0000-4000-8a00-00000000d023', 'See you then.', true, now() - interval '7 days'),
('e0a00001-0000-4000-8f10-000000000006', 'e0a00001-0000-4000-8f00-000000000003', 'e0a00001-0000-4000-8a00-00000000d023', 'Last from cook', true, now() - interval '1 hour'),
-- v004 unread mix
('e0a00001-0000-4000-8f10-000000000007', 'e0a00001-0000-4000-8f00-000000000004', 'e0a00001-0000-4000-8a00-00000000c003', 'Unread A', false, now() - interval '50 minutes'),
('e0a00001-0000-4000-8f10-000000000008', 'e0a00001-0000-4000-8f00-000000000004', 'e0a00001-0000-4000-8a00-00000000d011', 'Cook reply B', false, now() - interval '40 minutes'),
('e0a00001-0000-4000-8f10-000000000009', 'e0a00001-0000-4000-8f00-000000000004', 'e0a00001-0000-4000-8a00-00000000c003', 'Unread C', false, now() - interval '15 minutes'),
-- v005 all read
('e0a00001-0000-4000-8f10-00000000000a', 'e0a00001-0000-4000-8f00-000000000005', 'e0a00001-0000-4000-8a00-00000000c004', 'Read thread 1', true, now() - interval '1 day'),
('e0a00001-0000-4000-8f10-00000000000b', 'e0a00001-0000-4000-8f00-000000000005', 'e0a00001-0000-4000-8a00-00000000d011', 'Read thread 2', true, now() - interval '23 hours'),
('e0a00001-0000-4000-8f10-00000000000c', 'e0a00001-0000-4000-8f00-000000000005', 'e0a00001-0000-4000-8a00-00000000c004', 'Read thread 3', true, now() - interval '20 minutes'),
-- v006 order linked + last customer
('e0a00001-0000-4000-8f10-00000000000d', 'e0a00001-0000-4000-8f00-000000000006', 'e0a00001-0000-4000-8a00-00000000d011', 'Prep started', true, now() - interval '2 hours'),
('e0a00001-0000-4000-8f10-00000000000e', 'e0a00001-0000-4000-8f00-000000000006', 'e0a00001-0000-4000-8a00-00000000c005', 'Last from customer — ETA?', false, now() - interval '5 minutes'),
-- v007 blocked cook (historical messages)
('e0a00001-0000-4000-8f10-00000000000f', 'e0a00001-0000-4000-8f00-000000000007', 'e0a00001-0000-4000-8a00-00000000c001', 'Old message before block', true, now() - interval '30 days'),
-- v008 frozen
('e0a00001-0000-4000-8f10-000000000010', 'e0a00001-0000-4000-8f00-000000000008', 'e0a00001-0000-4000-8a00-00000000c001', 'Message while frozen window', true, now() - interval '8 days'),
('e0a00001-0000-4000-8f10-000000000011', 'e0a00001-0000-4000-8f00-000000000008', 'e0a00001-0000-4000-8a00-00000000d013', 'Cook reply (frozen)', true, now() - interval '2 days'),
-- v009 support: customer + admin
('e0a00001-0000-4000-8f10-000000000012', 'e0a00001-0000-4000-8f00-000000000009', 'e0a00001-0000-4000-8a00-00000000c001', 'I need help with a charge.', true, now() - interval '12 days'),
('e0a00001-0000-4000-8f10-000000000013', 'e0a00001-0000-4000-8f00-000000000009', 'e0a00001-0000-4000-8a00-00000000a001', 'Admin: we are on it.', true, now() - interval '11 days 23 hours'),
('e0a00001-0000-4000-8f10-000000000014', 'e0a00001-0000-4000-8f00-000000000009', 'e0a00001-0000-4000-8a00-00000000a001', 'Admin reply — last from admin', true, now() - interval '11 days'),
-- v010 chef-admin support
('e0a00001-0000-4000-8f10-000000000015', 'e0a00001-0000-4000-8f00-00000000000a', 'e0a00001-0000-4000-8a00-00000000a001', 'Your documents look good.', true, now() - interval '2 days'),
-- v011 duplicate bodies
('e0a00001-0000-4000-8f10-000000000016', 'e0a00001-0000-4000-8f00-00000000000b', 'e0a00001-0000-4000-8a00-00000000c001', 'SAME_TEXT_RETRY', true, now() - interval '5 days'),
('e0a00001-0000-4000-8f10-000000000017', 'e0a00001-0000-4000-8f00-00000000000b', 'e0a00001-0000-4000-8a00-00000000d024', 'SAME_TEXT_RETRY', true, now() - interval '4 days'),
-- v012 failed send marker
('e0a00001-0000-4000-8f10-000000000018', 'e0a00001-0000-4000-8f00-00000000000b', 'e0a00001-0000-4000-8a00-00000000c001',
 '[FAILED_SEND] retry demo — tap resend in app', false, now() - interval '4 days'),
-- v013 image attachment
('e0a00001-0000-4000-8f10-000000000019', 'e0a00001-0000-4000-8f00-00000000000c', 'e0a00001-0000-4000-8a00-00000000c006',
 '📎 Image: https://picsum.photos/seed/qa-chat-attach/800/600', true, now() - interval '7 days'),
-- v014 null name + v015 out-of-order (insert second row older timestamp first in list — app sorts)
('e0a00001-0000-4000-8f10-00000000001a', 'e0a00001-0000-4000-8f00-00000000000d', 'e0a00001-0000-4000-8a00-00000000c007', 'Message from null-name customer', true, now() - interval '6 days'),
('e0a00001-0000-4000-8f10-00000000001b', 'e0a00001-0000-4000-8f00-00000000000e', 'e0a00001-0000-4000-8a00-00000000c001', 'Newer message first in DB', true, now() - interval '1 hour'),
('e0a00001-0000-4000-8f10-00000000001c', 'e0a00001-0000-4000-8f00-00000000000e', 'e0a00001-0000-4000-8a00-00000000d025', 'Older message second in DB', true, now() - interval '3 hours'),
-- v016 blocked customer thread
('e0a00001-0000-4000-8f10-00000000001d', 'e0a00001-0000-4000-8f00-00000000000f', 'e0a00001-0000-4000-8a00-00000000c008', 'From blocked customer', true, now() - interval '9 days')
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- 9) Sample notifications (inspect in-app; ties to dedupe tests conceptually)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.notifications (
  id, customer_id, title, body, is_read, type, chef_document_id, created_at
) VALUES
('e0a00001-0000-4000-8f20-000000000001', 'e0a00001-0000-4000-8a00-00000000d002', 'Document approved',
 'Seeded: mirrors admin_document for QA.', false, 'admin_document',
 'e0a00001-0000-4000-8d00-000000000003', now() - interval '31 days'),
('e0a00001-0000-4000-8f20-000000000002', 'e0a00001-0000-4000-8a00-00000000d002', 'Account activated',
 'Seeded: chef_account_activated row.', false, 'chef_account_activated', NULL, now() - interval '31 days')
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  RAISE NOTICE 'QA matrix seed complete. Log in: qa.admin@naham.qa.demo / qa.cook.d011@naham.qa.demo — password NahamDemo2026!';
END $$;
