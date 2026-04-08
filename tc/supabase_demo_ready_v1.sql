-- =============================================================================
-- NAHAM — Demo-ready seed (presentation: orders, chat, inspection, documents)
-- =============================================================================
-- Stable UUID namespace: e0a00001-0000-4000-8de0-00000000*
--
-- Accounts (password for all: NahamDemo2026!)
--   admin2@naham.com              → a001
--   cook_demo@naham.demo          → c001   — orders + chat with customer_demo
--   customer_demo@naham.demo      → c003
--   cook_inspection@naham.demo    → c014   — warning + 3d freeze + inspection history
--   cook_docs@naham.demo          → c015   — ID approved, health doc rejected
--
-- Run after (same order as small demo):
--   supabase_chef_access_documents_v3.sql
--   supabase_chef_documents_two_types_migration_v1.sql
--   supabase_apply_chef_document_review.sql
--   supabase_orders_unified_cancel_v1.sql (optional)
--   supabase_inspection_random_v2.sql (recommended — outcome / chef_violations columns)
--   THIS FILE
--
-- Idempotent: removes prior [demo-ready] rows + conflicting auth emails, then inserts.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS order_id uuid;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS admin_moderation_state text NOT NULL DEFAULT 'none';

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS inspection_violation_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS inspection_penalty_step integer NOT NULL DEFAULT 0;

-- chef_documents type constraint (same as supabase_demo_clean_small_v1.sql)
ALTER TABLE public.chef_documents DROP CONSTRAINT IF EXISTS chef_documents_document_type_allowed;
ALTER TABLE public.chef_documents
  ADD CONSTRAINT chef_documents_document_type_allowed
  CHECK (
    lower(trim(document_type::text)) IN (
      'national_id', 'freelancer_id', 'license',
      'id_document', 'health_or_kitchen_document'
    )
  );

ALTER TABLE public.chef_documents DROP CONSTRAINT IF EXISTS chef_documents_status_allowed;
ALTER TABLE public.chef_documents
  ADD CONSTRAINT chef_documents_status_allowed
  CHECK (
    lower(trim(status::text)) IN (
      'pending_review', 'approved', 'rejected', 'expired'
    )
  );

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_profiles_integrity'
      AND tgrelid = 'public.profiles'::regclass
      AND NOT tgisinternal
  ) THEN
    ALTER TABLE public.profiles DISABLE TRIGGER trg_profiles_integrity;
  END IF;
END $$;

-- Fixed UUIDs
-- a001 admin, c001 cook_demo, c003 customer, c014 inspection cook, c015 docs cook

-- ═══════════════════════════════════════════════════════════════════════════
-- 0) Cleanup — demo-ready fixed ids + legacy small-demo emails (cook_clean / cook_warning)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_expected uuid[] := ARRAY[
    'e0a00001-0000-4000-8de0-00000000a001'::uuid,
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    'e0a00001-0000-4000-8de0-00000000c003'::uuid,
    'e0a00001-0000-4000-8de0-00000000c014'::uuid,
    'e0a00001-0000-4000-8de0-00000000c015'::uuid
  ];
  v_legacy_cook uuid := 'e0a00001-0000-4000-8de0-00000000c002'::uuid;
  v_bad uuid[];
BEGIN
  DELETE FROM public.messages
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000a301'::uuid,
    'e0a00001-0000-4000-8de0-00000000a302'::uuid,
    'e0a00001-0000-4000-8de0-00000000a303'::uuid,
    'e0a00001-0000-4000-8de0-00000000a304'::uuid
  )
  OR conversation_id = 'e0a00001-0000-4000-8de0-00000000f100'::uuid
  OR conversation_id IN (
    'e0a00001-0000-4000-8de0-00000000f001'::uuid,
    'e0a00001-0000-4000-8de0-00000000f002'::uuid
  );

  DELETE FROM public.conversations
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000f100'::uuid,
    'e0a00001-0000-4000-8de0-00000000f001'::uuid,
    'e0a00001-0000-4000-8de0-00000000f002'::uuid
  );

  DELETE FROM public.order_items
  WHERE order_id IN (
    'e0a00001-0000-4000-8de0-00000000b101'::uuid,
    'e0a00001-0000-4000-8de0-00000000b102'::uuid,
    'e0a00001-0000-4000-8de0-00000000b103'::uuid,
    'e0a00001-0000-4000-8de0-00000000b001'::uuid,
    'e0a00001-0000-4000-8de0-00000000b002'::uuid
  )
  OR id IN (
    'e0a00001-0000-4000-8de0-00000000c201'::uuid,
    'e0a00001-0000-4000-8de0-00000000c202'::uuid,
    'e0a00001-0000-4000-8de0-00000000c203'::uuid
  );

  DELETE FROM public.orders
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000b101'::uuid,
    'e0a00001-0000-4000-8de0-00000000b102'::uuid,
    'e0a00001-0000-4000-8de0-00000000b103'::uuid,
    'e0a00001-0000-4000-8de0-00000000b001'::uuid,
    'e0a00001-0000-4000-8de0-00000000b002'::uuid
  )
  OR notes LIKE '[demo-ready]%';

  DELETE FROM public.menu_items
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000d101'::uuid,
    'e0a00001-0000-4000-8de0-00000000d102'::uuid,
    'e0a00001-0000-4000-8de0-00000000d103'::uuid,
    'e0a00001-0000-4000-8de0-00000000d001'::uuid,
    'e0a00001-0000-4000-8de0-00000000d002'::uuid,
    'e0a00001-0000-4000-8de0-00000000d003'::uuid,
    'e0a00001-0000-4000-8de0-00000000d004'::uuid,
    'e0a00001-0000-4000-8de0-00000000d005'::uuid,
    'e0a00001-0000-4000-8de0-00000000d006'::uuid
  )
  OR chef_id IN (
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    v_legacy_cook,
    'e0a00001-0000-4000-8de0-00000000c014'::uuid,
    'e0a00001-0000-4000-8de0-00000000c015'::uuid
  );

  IF to_regclass('public.reel_likes') IS NOT NULL THEN
    DELETE FROM public.reel_likes
    WHERE reel_id IN (SELECT r.id FROM public.reels r WHERE r.chef_id = ANY (ARRAY[
      'e0a00001-0000-4000-8de0-00000000c001'::uuid,
      v_legacy_cook,
      'e0a00001-0000-4000-8de0-00000000c014'::uuid,
      'e0a00001-0000-4000-8de0-00000000c015'::uuid
    ]));
  END IF;

  DELETE FROM public.reels
  WHERE chef_id IN (
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    v_legacy_cook,
    'e0a00001-0000-4000-8de0-00000000c014'::uuid,
    'e0a00001-0000-4000-8de0-00000000c015'::uuid
  );

  IF to_regclass('public.chef_violations') IS NOT NULL THEN
    DELETE FROM public.chef_violations
    WHERE inspection_call_id = 'e0a00001-0000-4000-8de0-00000000ca01'::uuid
       OR chef_id = 'e0a00001-0000-4000-8de0-00000000c014'::uuid
       OR note = '[demo-ready] Ledger row for presentation.';
  END IF;

  IF to_regclass('public.inspection_calls') IS NOT NULL THEN
    DELETE FROM public.inspection_calls
    WHERE id = 'e0a00001-0000-4000-8de0-00000000ca01'::uuid
       OR (chef_id = 'e0a00001-0000-4000-8de0-00000000c014'::uuid AND channel_name LIKE '[demo-ready]%');
  END IF;

  DELETE FROM public.notifications
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000e201'::uuid,
    'e0a00001-0000-4000-8de0-00000000e202'::uuid
  )
  OR title LIKE '[demo-ready]%';

  UPDATE public.chef_documents SET reviewed_by = NULL
  WHERE reviewed_by IN (SELECT unnest(v_expected));

  DELETE FROM public.chef_documents
  WHERE chef_id IN (
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    v_legacy_cook,
    'e0a00001-0000-4000-8de0-00000000c014'::uuid,
    'e0a00001-0000-4000-8de0-00000000c015'::uuid
  );

  IF to_regclass('public.addresses') IS NOT NULL THEN
    DELETE FROM public.addresses WHERE customer_id = 'e0a00001-0000-4000-8de0-00000000c003'::uuid;
  END IF;

  DELETE FROM public.chef_profiles
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    v_legacy_cook,
    'e0a00001-0000-4000-8de0-00000000c014'::uuid,
    'e0a00001-0000-4000-8de0-00000000c015'::uuid
  );

  SELECT COALESCE(array_agg(u.id), ARRAY[]::uuid[]) INTO v_bad
  FROM auth.users u
  WHERE lower(trim(u.email)) IN (
    'admin2@naham.com',
    'cook_demo@naham.demo',
    'cook_inspection@naham.demo',
    'cook_docs@naham.demo',
    'customer_demo@naham.demo',
    'cook_clean@naham.demo',
    'cook_warning@naham.demo'
  )
  AND NOT (u.id = ANY (v_expected));

  IF COALESCE(cardinality(v_bad), 0) > 0 THEN
    DELETE FROM public.messages
    WHERE sender_id = ANY (v_bad)
       OR conversation_id IN (
         SELECT c.id FROM public.conversations c
         WHERE c.customer_id = ANY (v_bad) OR c.chef_id = ANY (v_bad)
       );
    DELETE FROM public.conversations
    WHERE customer_id = ANY (v_bad) OR chef_id = ANY (v_bad);
    IF to_regclass('public.reel_likes') IS NOT NULL THEN
      DELETE FROM public.reel_likes
      WHERE customer_id = ANY (v_bad)
         OR reel_id IN (SELECT r.id FROM public.reels r WHERE r.chef_id = ANY (v_bad));
    END IF;
    DELETE FROM public.reels WHERE chef_id = ANY (v_bad);
    DELETE FROM public.order_items
    WHERE order_id IN (SELECT o.id FROM public.orders o WHERE o.customer_id = ANY (v_bad) OR o.chef_id = ANY (v_bad));
    DELETE FROM public.orders
    WHERE customer_id = ANY (v_bad) OR chef_id = ANY (v_bad);
    DELETE FROM public.notifications
    WHERE customer_id = ANY (v_bad)
       OR chef_document_id IN (SELECT d.id FROM public.chef_documents d WHERE d.chef_id = ANY (v_bad));
    DELETE FROM public.menu_items WHERE chef_id = ANY (v_bad);
    UPDATE public.chef_documents SET reviewed_by = NULL WHERE reviewed_by = ANY (v_bad);
    DELETE FROM public.chef_documents WHERE chef_id = ANY (v_bad);
    IF to_regclass('public.addresses') IS NOT NULL THEN
      DELETE FROM public.addresses WHERE customer_id = ANY (v_bad);
    END IF;
    DELETE FROM public.chef_profiles WHERE id = ANY (v_bad);
    IF to_regclass('public.chef_violations') IS NOT NULL THEN
      DELETE FROM public.chef_violations WHERE admin_id = ANY (v_bad);
    END IF;
    IF to_regclass('public.inspection_calls') IS NOT NULL THEN
      DELETE FROM public.inspection_calls WHERE admin_id = ANY (v_bad);
    END IF;
    DELETE FROM public.profiles WHERE id = ANY (v_bad);
  END IF;

  -- Legacy cook_warning row (c002) when re-seeding from demo-ready
  DELETE FROM public.messages WHERE sender_id = v_legacy_cook;
  DELETE FROM public.conversations WHERE customer_id = v_legacy_cook OR chef_id = v_legacy_cook;
  DELETE FROM public.order_items WHERE order_id IN (SELECT o.id FROM public.orders o WHERE o.chef_id = v_legacy_cook);
  DELETE FROM public.orders WHERE chef_id = v_legacy_cook OR customer_id = v_legacy_cook;
  DELETE FROM public.notifications WHERE customer_id = v_legacy_cook;
  DELETE FROM public.menu_items WHERE chef_id = v_legacy_cook;
  DELETE FROM public.chef_documents WHERE chef_id = v_legacy_cook;
  DELETE FROM public.chef_profiles WHERE id = v_legacy_cook;
  DELETE FROM public.profiles WHERE id = v_legacy_cook;

  DELETE FROM auth.identities
  WHERE user_id IN (
    SELECT u.id FROM auth.users u
    WHERE NOT (u.id = ANY (v_expected))
      AND lower(trim(u.email)) IN (
        'admin2@naham.com',
        'cook_demo@naham.demo',
        'cook_inspection@naham.demo',
        'cook_docs@naham.demo',
        'customer_demo@naham.demo',
        'cook_clean@naham.demo',
        'cook_warning@naham.demo'
      )
  );

  DELETE FROM auth.users
  WHERE id IN (
    SELECT u.id FROM auth.users u
    WHERE NOT (u.id = ANY (v_expected))
      AND lower(trim(u.email)) IN (
        'admin2@naham.com',
        'cook_demo@naham.demo',
        'cook_inspection@naham.demo',
        'cook_docs@naham.demo',
        'customer_demo@naham.demo',
        'cook_clean@naham.demo',
        'cook_warning@naham.demo'
      )
  );

  DELETE FROM public.profiles WHERE id = v_legacy_cook;

  DELETE FROM auth.identities WHERE user_id = v_legacy_cook;
  DELETE FROM auth.users WHERE id = v_legacy_cook;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Auth + identities
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_instance uuid;
  v_pw text;
  r RECORD;
BEGIN
  v_pw := crypt('NahamDemo2026!', gen_salt('bf'));
  SELECT id INTO v_instance FROM auth.instances LIMIT 1;
  IF v_instance IS NULL THEN
    v_instance := '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;

  FOR r IN
    SELECT * FROM (VALUES
      ('e0a00001-0000-4000-8de0-00000000a001'::uuid, 'admin2@naham.com'),
      ('e0a00001-0000-4000-8de0-00000000c001'::uuid, 'cook_demo@naham.demo'),
      ('e0a00001-0000-4000-8de0-00000000c003'::uuid, 'customer_demo@naham.demo'),
      ('e0a00001-0000-4000-8de0-00000000c014'::uuid, 'cook_inspection@naham.demo'),
      ('e0a00001-0000-4000-8de0-00000000c015'::uuid, 'cook_docs@naham.demo')
    ) AS t(uid, em)
  LOOP
    IF EXISTS (SELECT 1 FROM auth.users WHERE id = r.uid OR lower(trim(email)) = lower(trim(r.em))) THEN
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
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Profiles
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.profiles (id, full_name, role, phone, is_blocked)
VALUES
  ('e0a00001-0000-4000-8de0-00000000a001', 'Admin', 'admin', '+966500000001', false),
  ('e0a00001-0000-4000-8de0-00000000c001', 'Noura — Demo Kitchen', 'chef', '+966501000001', false),
  ('e0a00001-0000-4000-8de0-00000000c003', 'Sarah Mohammed', 'customer', '+966501000003', false),
  ('e0a00001-0000-4000-8de0-00000000c014', 'Khalid — Inspection Demo', 'chef', '+966501000014', false),
  ('e0a00001-0000-4000-8de0-00000000c015', 'Layan — Documents Demo', 'chef', '+966501000015', false)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  phone = EXCLUDED.phone,
  is_blocked = false;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Chef profiles
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.chef_profiles (
  id, kitchen_name, is_online, vacation_mode,
  working_hours_start, working_hours_end,
  bank_iban, bank_account_name, bio, kitchen_city,
  approval_status, suspended, initial_approval_at,
  kitchen_latitude, kitchen_longitude, kitchen_timezone,
  freeze_until, freeze_type, freeze_level, warning_count,
  access_level, documents_operational_ok,
  inspection_violation_count, inspection_penalty_step
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000c001',
  'Matbakh Noura — Demo',
  true,
  false,
  '09:00',
  '22:00',
  'SA0380000000000808010189011',
  'Noura — Demo Kitchen',
  'Presentation kitchen: live orders and customer chat.',
  'Riyadh',
  'approved',
  false,
  now() - interval '90 days',
  24.7136,
  46.6753,
  'Asia/Riyadh',
  NULL,
  NULL,
  0,
  0,
  'full_access',
  true,
  0,
  0
),
(
  'e0a00001-0000-4000-8de0-00000000c014',
  'Matbakh Khalid — Inspection',
  false,
  false,
  '10:00',
  '21:00',
  'SA0380000000000808010189014',
  'Khalid — Inspection Demo',
  'Seeded for admin inspection / compliance views (warning + freeze).',
  'Riyadh',
  'approved',
  false,
  now() - interval '120 days',
  24.7200,
  46.6800,
  'Asia/Riyadh',
  (now() + interval '3 days'),
  'soft',
  1,
  1,
  'limited_access',
  true,
  1,
  2
),
(
  'e0a00001-0000-4000-8de0-00000000c015',
  'Matbakh Layan — Documents',
  false,
  false,
  '09:00',
  '20:00',
  'SA0380000000000808010189015',
  'Layan — Documents Demo',
  'One approved ID + one rejected health document for admin review UI.',
  'Jeddah',
  'approved',
  false,
  now() - interval '30 days',
  21.4858,
  39.1925,
  'Asia/Riyadh',
  NULL,
  NULL,
  0,
  0,
  'partial_access',
  false,
  0,
  0
)
ON CONFLICT (id) DO UPDATE SET
  kitchen_name = EXCLUDED.kitchen_name,
  bio = EXCLUDED.bio,
  warning_count = EXCLUDED.warning_count,
  freeze_until = EXCLUDED.freeze_until,
  freeze_type = EXCLUDED.freeze_type,
  freeze_level = EXCLUDED.freeze_level,
  access_level = EXCLUDED.access_level,
  documents_operational_ok = EXCLUDED.documents_operational_ok,
  inspection_violation_count = EXCLUDED.inspection_violation_count,
  inspection_penalty_step = EXCLUDED.inspection_penalty_step,
  is_online = EXCLUDED.is_online,
  approval_status = EXCLUDED.approval_status;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Chef documents
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.chef_documents (
  id, chef_id, document_type, file_url, status, no_expiry, expiry_date,
  rejection_reason, reviewed_at, reviewed_by, created_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000dd11',
  'e0a00001-0000-4000-8de0-00000000c001',
  'id_document',
  'demo/ready/noura/id_document.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '85 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '86 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dd12',
  'e0a00001-0000-4000-8de0-00000000c001',
  'health_or_kitchen_document',
  'demo/ready/noura/health_certificate.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '85 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '86 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dd15a',
  'e0a00001-0000-4000-8de0-00000000c015',
  'id_document',
  'demo/ready/layan/id_document.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '5 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '6 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dd15b',
  'e0a00001-0000-4000-8de0-00000000c015',
  'health_or_kitchen_document',
  'demo/ready/layan/municipality_permit_blur.pdf',
  'rejected',
  false,
  NULL,
  'Image unreadable — please re-upload a clear photo of the full permit.',
  now() - interval '2 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '3 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dd14a',
  'e0a00001-0000-4000-8de0-00000000c014',
  'id_document',
  'demo/ready/khalid/id_document.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '100 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '101 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dd14b',
  'e0a00001-0000-4000-8de0-00000000c014',
  'health_or_kitchen_document',
  'demo/ready/khalid/health.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '100 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '101 days'
)
ON CONFLICT (chef_id, document_type) DO UPDATE SET
  file_url = EXCLUDED.file_url,
  status = EXCLUDED.status,
  no_expiry = EXCLUDED.no_expiry,
  rejection_reason = EXCLUDED.rejection_reason,
  reviewed_at = EXCLUDED.reviewed_at,
  reviewed_by = EXCLUDED.reviewed_by;

DO $$
BEGIN
  PERFORM public.recompute_chef_access_level('e0a00001-0000-4000-8de0-00000000c001'::uuid);
  PERFORM public.recompute_chef_access_level('e0a00001-0000-4000-8de0-00000000c015'::uuid);
  -- c014: keep manual freeze / warning / inspection_penalty_step from INSERT above
END $$;

-- Re-apply inspection demo chef row after recompute (recompute may not touch freeze)
UPDATE public.chef_profiles SET
  warning_count = 1,
  freeze_until = now() + interval '3 days',
  freeze_type = 'soft',
  freeze_level = 1,
  inspection_violation_count = 1,
  inspection_penalty_step = 2,
  is_online = false,
  access_level = 'limited_access',
  documents_operational_ok = true
WHERE id = 'e0a00001-0000-4000-8de0-00000000c014'::uuid;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Inspection history + violation ledger (Admin UI)
-- ═══════════════════════════════════════════════════════════════════════════
-- Best: run supabase_inspection_random_v2.sql first (adds outcome, counted_as_violation, chef_violations).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'inspection_calls' AND column_name = 'outcome'
  ) THEN
    RAISE NOTICE 'demo-ready: skipped inspection_calls — run supabase_inspection_random_v2.sql for full Admin inspection row + chef_violations.';
    RETURN;
  END IF;

  INSERT INTO public.inspection_calls (
    id,
    chef_id,
    admin_id,
    channel_name,
    status,
    outcome,
    counted_as_violation,
    result_action,
    violation_reason,
    result_note,
    chef_result_seen,
    created_at,
    responded_at,
    finalized_at,
    started_at,
    ended_at
  )
  VALUES (
    'e0a00001-0000-4000-8de0-00000000ca01'::uuid,
    'e0a00001-0000-4000-8de0-00000000c014'::uuid,
    'e0a00001-0000-4000-8de0-00000000a001'::uuid,
    '[demo-ready] inspection-khalid-hygiene',
    'completed',
    'kitchen_not_clean',
    true,
    'freeze_3d',
    'hygiene_issue_demo',
    'Demo: random kitchen inspection — cleanliness below standard. Automatic 3-day freeze applied.',
    true,
    now() - interval '2 days',
    now() - interval '2 days' + interval '18 minutes',
    now() - interval '2 days' + interval '25 minutes',
    now() - interval '2 days',
    now() - interval '2 days' + interval '25 minutes'
  );

  IF to_regclass('public.chef_violations') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.chef_violations v
       WHERE v.inspection_call_id = 'e0a00001-0000-4000-8de0-00000000ca01'::uuid
         AND v.chef_id = 'e0a00001-0000-4000-8de0-00000000c014'::uuid
     )
  THEN
    INSERT INTO public.chef_violations (
      chef_id,
      inspection_call_id,
      admin_id,
      violation_index,
      reason,
      action_applied,
      note,
      created_at
    )
    VALUES (
      'e0a00001-0000-4000-8de0-00000000c014'::uuid,
      'e0a00001-0000-4000-8de0-00000000ca01'::uuid,
      'e0a00001-0000-4000-8de0-00000000a001'::uuid,
      2,
      'kitchen_not_clean',
      'freeze_3d',
      '[demo-ready] Ledger row for presentation.',
      now() - interval '2 days'
    );
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) Customer address
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF to_regclass('public.addresses') IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO public.addresses (customer_id, label, street, city, is_default, created_at)
  VALUES (
    'e0a00001-0000-4000-8de0-00000000c003'::uuid,
    'Home',
    'Al Yasmin',
    'Riyadh',
    true,
    now() - interval '90 days'
  );
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) Menu (cook_demo only)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.menu_items (
  id, chef_id, name, description, price, image_url, category,
  daily_quantity, remaining_quantity, is_available, moderation_status, created_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000d101',
  'e0a00001-0000-4000-8de0-00000000c001',
  'Kabsa Dajaj Demo',
  'Chicken kabsa — hero dish for order pipeline demo.',
  34.00,
  NULL,
  'Mains',
  40,
  28,
  true,
  'approved',
  now() - interval '20 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d102',
  'e0a00001-0000-4000-8de0-00000000c001',
  'Marqooq Lahm Demo',
  'Slow-cooked marqooq with lamb.',
  39.00,
  NULL,
  'Mains',
  25,
  20,
  true,
  'approved',
  now() - interval '18 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d103',
  'e0a00001-0000-4000-8de0-00000000c001',
  'Salata House Demo',
  'Fresh house salad side.',
  12.00,
  NULL,
  'Sides',
  50,
  45,
  true,
  'approved',
  now() - interval '10 days'
)
ON CONFLICT (id) DO UPDATE SET
  chef_id = EXCLUDED.chef_id,
  name = EXCLUDED.name,
  price = EXCLUDED.price,
  moderation_status = EXCLUDED.moderation_status;

-- ═══════════════════════════════════════════════════════════════════════════
-- 8) Orders — pending, preparing, completed (customer_demo ↔ cook_demo)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.orders (
  id, customer_id, chef_id, status, total_amount, commission_amount,
  delivery_address, customer_name, chef_name, notes,
  idempotency_key, cancel_reason, created_at, updated_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000b101',
  'e0a00001-0000-4000-8de0-00000000c003',
  'e0a00001-0000-4000-8de0-00000000c001',
  'pending',
  12.00,
  1.20,
  'Riyadh — Al Yasmin — pickup',
  'Sarah Mohammed',
  'Matbakh Noura — Demo',
  '[demo-ready] Pending — salad',
  'a0de0001-0000-4000-8de0-00000000b101'::uuid,
  NULL,
  now() - interval '25 minutes',
  now() - interval '25 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000b102',
  'e0a00001-0000-4000-8de0-00000000c003',
  'e0a00001-0000-4000-8de0-00000000c001',
  'preparing',
  34.00,
  3.40,
  'Riyadh — Al Yasmin — pickup',
  'Sarah Mohammed',
  'Matbakh Noura — Demo',
  '[demo-ready] Preparing — kabsa',
  'a0de0001-0000-4000-8de0-00000000b102'::uuid,
  NULL,
  now() - interval '50 minutes',
  now() - interval '40 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000b103',
  'e0a00001-0000-4000-8de0-00000000c003',
  'e0a00001-0000-4000-8de0-00000000c001',
  'completed',
  39.00,
  3.90,
  'Riyadh — Al Yasmin — pickup',
  'Sarah Mohammed',
  'Matbakh Noura — Demo',
  '[demo-ready] Completed — marqooq',
  'a0de0001-0000-4000-8de0-00000000b103'::uuid,
  NULL,
  now() - interval '3 days',
  now() - interval '3 days'
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  total_amount = EXCLUDED.total_amount,
  notes = EXCLUDED.notes,
  updated_at = EXCLUDED.updated_at;

INSERT INTO public.order_items (id, order_id, menu_item_id, dish_name, quantity, unit_price)
VALUES
(
  'e0a00001-0000-4000-8de0-00000000c201'::uuid,
  'e0a00001-0000-4000-8de0-00000000b101'::uuid,
  'e0a00001-0000-4000-8de0-00000000d103'::uuid,
  'Salata House Demo',
  1,
  12.00
),
(
  'e0a00001-0000-4000-8de0-00000000c202'::uuid,
  'e0a00001-0000-4000-8de0-00000000b102'::uuid,
  'e0a00001-0000-4000-8de0-00000000d101'::uuid,
  'Kabsa Dajaj Demo',
  1,
  34.00
),
(
  'e0a00001-0000-4000-8de0-00000000c203'::uuid,
  'e0a00001-0000-4000-8de0-00000000b103'::uuid,
  'e0a00001-0000-4000-8de0-00000000d102'::uuid,
  'Marqooq Lahm Demo',
  1,
  39.00
)
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- 9) Chat — customer_demo ↔ cook_demo
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.conversations (
  id, customer_id, chef_id, type, order_id, created_at, last_message, last_message_at, admin_moderation_state
) VALUES (
  'e0a00001-0000-4000-8de0-00000000f100'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003',
  'e0a00001-0000-4000-8de0-00000000c001',
  'customer-chef',
  NULL,
  now() - interval '3 hours',
  'Perfect — see you at pickup.',
  now() - interval '3 hours' + interval '9 minutes',
  'none'
)
ON CONFLICT (id) DO UPDATE SET
  last_message = EXCLUDED.last_message,
  last_message_at = EXCLUDED.last_message_at;

INSERT INTO public.messages (id, conversation_id, sender_id, content, is_read, created_at) VALUES
(
  'e0a00001-0000-4000-8de0-00000000a301'::uuid,
  'e0a00001-0000-4000-8de0-00000000f100'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003',
  'Hi — is the kabsa still available for pickup tonight?',
  true,
  now() - interval '3 hours'
),
(
  'e0a00001-0000-4000-8de0-00000000a302'::uuid,
  'e0a00001-0000-4000-8de0-00000000f100'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001',
  'Yes! I can have it ready in about 45 minutes.',
  true,
  now() - interval '3 hours' + interval '4 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000a303'::uuid,
  'e0a00001-0000-4000-8de0-00000000f100'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003',
  'Great, I will place the order now.',
  true,
  now() - interval '3 hours' + interval '6 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000a304'::uuid,
  'e0a00001-0000-4000-8de0-00000000f100'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001',
  'Perfect — see you at pickup.',
  true,
  now() - interval '3 hours' + interval '9 minutes'
)
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;

-- ═══════════════════════════════════════════════════════════════════════════
-- 10) Notifications
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.notifications (
  id, customer_id, title, body, is_read, type, chef_document_id, created_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000e201'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001',
  '[demo-ready] Application approved',
  'Your documents are approved — welcome to Naham.',
  true,
  'chef_account_activated',
  NULL,
  now() - interval '85 days'
),
(
  'e0a00001-0000-4000-8de0-00000000e202'::uuid,
  'e0a00001-0000-4000-8de0-00000000c015',
  '[demo-ready] Document update required',
  'Your health/kitchen permit needs a clearer upload. Open Documents to resubmit.',
  false,
  'info',
  'e0a00001-0000-4000-8de0-00000000dd15b'::uuid,
  now() - interval '2 days'
)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_profiles_integrity'
      AND tgrelid = 'public.profiles'::regclass
      AND NOT tgisinternal
  ) THEN
    ALTER TABLE public.profiles ENABLE TRIGGER trg_profiles_integrity;
  END IF;
  RAISE NOTICE 'demo-ready: admin2@naham.com | cook_demo@naham.demo | customer_demo@naham.demo | cook_inspection@naham.demo | cook_docs@naham.demo — NahamDemo2026!';
END $$;
