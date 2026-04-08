-- =============================================================================
-- NAHAM — Small clean demo seed (4 accounts, minimal rows)
-- =============================================================================
-- Stable UUID namespace: e0a00001-0000-4000-8de0-00000000* (hex-safe suffixes only)
--
-- Run order (after core app migrations / schema exists):
--   1) supabase_qa_diagnose.sql (optional, read-only)
--   2) supabase_chef_access_documents_v3.sql
--   3) supabase_chef_documents_two_types_migration_v1.sql
--   4) supabase_apply_chef_document_review.sql
--   5) supabase_orders_unified_cancel_v1.sql (optional; cancel_reason column)
--   6) THIS FILE — full script from line 1
--
-- Password for all auth users inserted here: NahamDemo2026!
-- Idempotent: deletes prior rows for this namespace + these emails, then re-inserts.
-- Disposable / staging only.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Align optional columns with main Naham migrations (safe no-ops if already present).
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS order_id uuid;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS admin_moderation_state text NOT NULL DEFAULT 'none';
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

-- chef_documents CHECK: older DBs may only allow national_id / freelancer_id / license.
-- Canonical two-slot types need id_document + health_or_kitchen_document (same as
-- supabase_demo_evaluation_seed_v1.sql + supabase_chef_documents_two_types_migration_v1.sql).
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

-- In SQL Editor, auth.uid() is NULL so public.is_admin() is false. Trigger
-- trg_profiles_integrity (supabase_rls_authorization_hardening.sql) would reject
-- ON CONFLICT UPDATE that sets role=admin or touches is_blocked. Disable for this seed only.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_profiles_integrity'
      AND tgrelid = 'public.profiles'::regclass
      AND NOT tgisinternal
  ) THEN
    ALTER TABLE public.profiles DISABLE TRIGGER trg_profiles_integrity;
  END IF;
END $$;

-- ─── Expected auth ids (fixed) ─────────────────────────────────────────────
-- admin2@naham.com           → e0a00001-0000-4000-8de0-00000000a001
-- cook_clean@naham.demo      → e0a00001-0000-4000-8de0-00000000c001
-- cook_warning@naham.demo    → e0a00001-0000-4000-8de0-00000000c002
-- customer_demo@naham.demo   → e0a00001-0000-4000-8de0-00000000c003

-- ═══════════════════════════════════════════════════════════════════════════
-- 0) Idempotent cleanup — app rows first, then conflicting auth by email
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_ids uuid[] := ARRAY[
    'e0a00001-0000-4000-8de0-00000000a001'::uuid,
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    'e0a00001-0000-4000-8de0-00000000c002'::uuid,
    'e0a00001-0000-4000-8de0-00000000c003'::uuid
  ];
  v_expected uuid[];
  v_bad uuid[];
BEGIN
  v_expected := v_ids;

  DELETE FROM public.messages
  WHERE conversation_id IN (
    'e0a00001-0000-4000-8de0-00000000f001'::uuid,
    'e0a00001-0000-4000-8de0-00000000f002'::uuid
  );

  DELETE FROM public.conversations
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000f001'::uuid,
    'e0a00001-0000-4000-8de0-00000000f002'::uuid
  );

  IF to_regclass('public.reel_likes') IS NOT NULL THEN
    DELETE FROM public.reel_likes
    WHERE reel_id IN (
      SELECT unnest(ARRAY[
        'e0a00001-0000-4000-8de0-00000000e001'::uuid,
        'e0a00001-0000-4000-8de0-00000000e002'::uuid,
        'e0a00001-0000-4000-8de0-00000000e003'::uuid,
        'e0a00001-0000-4000-8de0-00000000e004'::uuid,
        'e0a00001-0000-4000-8de0-00000000e005'::uuid,
        'e0a00001-0000-4000-8de0-00000000e006'::uuid
      ])
    );
  END IF;

  DELETE FROM public.reels
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000e001'::uuid,
    'e0a00001-0000-4000-8de0-00000000e002'::uuid,
    'e0a00001-0000-4000-8de0-00000000e003'::uuid,
    'e0a00001-0000-4000-8de0-00000000e004'::uuid,
    'e0a00001-0000-4000-8de0-00000000e005'::uuid,
    'e0a00001-0000-4000-8de0-00000000e006'::uuid
  );

  DELETE FROM public.order_items
  WHERE order_id IN (
    'e0a00001-0000-4000-8de0-00000000b001'::uuid,
    'e0a00001-0000-4000-8de0-00000000b002'::uuid
  );

  DELETE FROM public.orders
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000b001'::uuid,
    'e0a00001-0000-4000-8de0-00000000b002'::uuid
  );

  DELETE FROM public.notifications
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000d101'::uuid,
    'e0a00001-0000-4000-8de0-00000000d102'::uuid
  );

  DELETE FROM public.menu_items
  WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000d001'::uuid,
    'e0a00001-0000-4000-8de0-00000000d002'::uuid,
    'e0a00001-0000-4000-8de0-00000000d003'::uuid,
    'e0a00001-0000-4000-8de0-00000000d004'::uuid,
    'e0a00001-0000-4000-8de0-00000000d005'::uuid,
    'e0a00001-0000-4000-8de0-00000000d006'::uuid
  );

  DELETE FROM public.chef_documents
  WHERE chef_id IN (
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    'e0a00001-0000-4000-8de0-00000000c002'::uuid
  );

  IF to_regclass('public.addresses') IS NOT NULL THEN
    DELETE FROM public.addresses WHERE customer_id = 'e0a00001-0000-4000-8de0-00000000c003'::uuid;
  END IF;

  DELETE FROM public.chef_profiles WHERE id IN (
    'e0a00001-0000-4000-8de0-00000000c001'::uuid,
    'e0a00001-0000-4000-8de0-00000000c002'::uuid
  );

  DELETE FROM public.profiles WHERE id = ANY (v_ids);

  -- Same emails as the seed but a different auth id (e.g. first signup UUID) must be
  -- fully detached before deleting auth.users, or FKs (e.g. messages.sender_id → profiles) fail.
  SELECT COALESCE(array_agg(u.id), ARRAY[]::uuid[]) INTO v_bad
  FROM auth.users u
  WHERE lower(trim(u.email)) IN (
    'admin2@naham.com',
    'cook_clean@naham.demo',
    'cook_warning@naham.demo',
    'customer_demo@naham.demo'
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
    WHERE order_id IN (
      SELECT o.id FROM public.orders o
      WHERE o.customer_id = ANY (v_bad) OR o.chef_id = ANY (v_bad)
    );

    DELETE FROM public.orders
    WHERE customer_id = ANY (v_bad) OR chef_id = ANY (v_bad);

    DELETE FROM public.notifications
    WHERE customer_id = ANY (v_bad)
      OR chef_document_id IN (
        SELECT d.id FROM public.chef_documents d WHERE d.chef_id = ANY (v_bad)
      );

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

    IF to_regclass('public.admin_logs') IS NOT NULL THEN
      DELETE FROM public.admin_logs WHERE admin_id = ANY (v_bad);
    END IF;

    DELETE FROM public.profiles WHERE id = ANY (v_bad);
  END IF;

  DELETE FROM auth.identities
  WHERE user_id IN (
    SELECT u.id
    FROM auth.users u
    WHERE NOT (u.id = ANY (v_expected))
      AND (
        lower(trim(u.email)) IN (
          'admin2@naham.com',
          'cook_clean@naham.demo',
          'cook_warning@naham.demo',
          'customer_demo@naham.demo'
        )
      )
  );

  DELETE FROM auth.users
  WHERE id IN (
    SELECT u.id
    FROM auth.users u
    WHERE NOT (u.id = ANY (v_expected))
      AND (
        lower(trim(u.email)) IN (
          'admin2@naham.com',
          'cook_clean@naham.demo',
          'cook_warning@naham.demo',
          'customer_demo@naham.demo'
        )
      )
  );
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Auth users + identities
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
      ('e0a00001-0000-4000-8de0-00000000c001'::uuid, 'cook_clean@naham.demo'),
      ('e0a00001-0000-4000-8de0-00000000c002'::uuid, 'cook_warning@naham.demo'),
      ('e0a00001-0000-4000-8de0-00000000c003'::uuid, 'customer_demo@naham.demo')
    ) AS t(uid, em)
  LOOP
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
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Profiles
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.profiles (id, full_name, role, phone, is_blocked)
VALUES
  ('e0a00001-0000-4000-8de0-00000000a001', 'Admin', 'admin', '+966500000001', false),
  ('e0a00001-0000-4000-8de0-00000000c001', 'Noura Alotaibi', 'chef', '+966501000001', false),
  ('e0a00001-0000-4000-8de0-00000000c002', 'Huda Alqahtani', 'chef', '+966501000002', false),
  ('e0a00001-0000-4000-8de0-00000000c003', 'Sarah Mohammed', 'customer', '+966501000003', false)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  phone = EXCLUDED.phone;

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
  access_level, documents_operational_ok
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000c001',
  'Matbakh Noura Albaytiya',
  true,
  false,
  '09:00',
  '22:00',
  'SA0380000000000808010189001',
  'Noura Alotaibi',
  'Home-style Saudi meals made with care and clean presentation.',
  'Riyadh',
  'approved',
  false,
  now() - interval '60 days',
  24.7136,
  46.6753,
  'Asia/Riyadh',
  NULL,
  NULL,
  0,
  0,
  'full_access',
  true
),
(
  'e0a00001-0000-4000-8de0-00000000c002',
  'Rokn Huda Alshaabi',
  true,
  false,
  '09:00',
  '22:00',
  'SA0380000000000808010189002',
  'Huda Alqahtani',
  'Daily traditional meals with a local homemade touch.',
  'Riyadh',
  'approved',
  false,
  now() - interval '45 days',
  24.7200,
  46.6800,
  'Asia/Riyadh',
  NULL,
  NULL,
  0,
  1,
  'full_access',
  true
)
ON CONFLICT (id) DO UPDATE SET
  kitchen_name = EXCLUDED.kitchen_name,
  bio = EXCLUDED.bio,
  warning_count = EXCLUDED.warning_count,
  access_level = EXCLUDED.access_level,
  documents_operational_ok = EXCLUDED.documents_operational_ok,
  approval_status = EXCLUDED.approval_status,
  initial_approval_at = EXCLUDED.initial_approval_at;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Chef documents (canonical two types, both approved)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.chef_documents (
  id, chef_id, document_type, file_url, status, no_expiry, expiry_date,
  rejection_reason, reviewed_at, reviewed_by, created_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000dc01',
  'e0a00001-0000-4000-8de0-00000000c001',
  'id_document',
  'demo/clean/noura/id_document.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '61 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '61 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dc02',
  'e0a00001-0000-4000-8de0-00000000c001',
  'health_or_kitchen_document',
  'demo/clean/noura/health.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '61 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '61 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dc03',
  'e0a00001-0000-4000-8de0-00000000c002',
  'id_document',
  'demo/clean/huda/id_document.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '46 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '46 days'
),
(
  'e0a00001-0000-4000-8de0-00000000dc04',
  'e0a00001-0000-4000-8de0-00000000c002',
  'health_or_kitchen_document',
  'demo/clean/huda/health.pdf',
  'approved',
  true,
  NULL,
  NULL,
  now() - interval '46 days',
  'e0a00001-0000-4000-8de0-00000000a001',
  now() - interval '46 days'
)
ON CONFLICT (chef_id, document_type) DO UPDATE SET
  file_url = EXCLUDED.file_url,
  status = EXCLUDED.status,
  no_expiry = EXCLUDED.no_expiry,
  reviewed_at = EXCLUDED.reviewed_at,
  reviewed_by = EXCLUDED.reviewed_by;

-- RETURNS void — SELECT shows blank columns in SQL Editor; PERFORM avoids that.
DO $$
BEGIN
  PERFORM public.recompute_chef_access_level('e0a00001-0000-4000-8de0-00000000c001'::uuid);
  PERFORM public.recompute_chef_access_level('e0a00001-0000-4000-8de0-00000000c002'::uuid);
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Customer address (if table exists)
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
-- 6) Menu items
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.menu_items (
  id, chef_id, name, description, price, image_url, category,
  daily_quantity, remaining_quantity, is_available, moderation_status, created_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000d001',
  'e0a00001-0000-4000-8de0-00000000c001',
  'Kabsa Dajaj Baytiya',
  'Home-style chicken kabsa with rice and side salad.',
  32.00,
  NULL,
  'Mains',
  40,
  30,
  true,
  'approved',
  now() - interval '30 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d002',
  'e0a00001-0000-4000-8de0-00000000c001',
  'Marqooq Lahm',
  'Traditional marqooq with vegetables and slow-cooked meat.',
  38.00,
  NULL,
  'Mains',
  25,
  18,
  true,
  'approved',
  now() - interval '28 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d003',
  'e0a00001-0000-4000-8de0-00000000c001',
  'Samosa Mushakkala',
  'Crispy assorted samosas with mixed fillings.',
  18.00,
  NULL,
  'Snacks',
  50,
  40,
  true,
  'approved',
  now() - interval '25 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d004',
  'e0a00001-0000-4000-8de0-00000000c002',
  'Jareesh Bil Dajaj',
  'Creamy homemade jareesh with seasoned chicken.',
  29.00,
  NULL,
  'Traditional',
  35,
  20,
  true,
  'approved',
  now() - interval '20 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d005',
  'e0a00001-0000-4000-8de0-00000000c002',
  'Mutabbaq Khodar',
  'Light mutabbaq stuffed with fresh vegetables.',
  16.00,
  NULL,
  'Snacks',
  45,
  35,
  true,
  'approved',
  now() - interval '18 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d006',
  'e0a00001-0000-4000-8de0-00000000c002',
  'Qursan Lahm',
  'Traditional qursan with rich sauce, meat, and vegetables.',
  35.00,
  NULL,
  'Mains',
  22,
  15,
  true,
  'approved',
  now() - interval '15 days'
)
ON CONFLICT (id) DO UPDATE SET
  chef_id = EXCLUDED.chef_id,
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  moderation_status = EXCLUDED.moderation_status;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) Orders (cancel_reason NULL for non-cancelled rows)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.orders (
  id, customer_id, chef_id, status, total_amount, commission_amount,
  delivery_address, customer_name, chef_name, notes,
  idempotency_key, cancel_reason, created_at, updated_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000b001',
  'e0a00001-0000-4000-8de0-00000000c003',
  'e0a00001-0000-4000-8de0-00000000c001',
  'preparing',
  32.00,
  3.20,
  'Riyadh — Al Yasmin — pickup',
  'Sarah Mohammed',
  'Matbakh Noura Albaytiya',
  '[demo-clean-small] preparing — Kabsa Dajaj Baytiya',
  'a0de0001-0000-4000-8de0-000000000001'::uuid,
  NULL,
  now() - interval '40 minutes',
  now() - interval '35 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000b002',
  'e0a00001-0000-4000-8de0-00000000c003',
  'e0a00001-0000-4000-8de0-00000000c002',
  'completed',
  29.00,
  2.90,
  'Riyadh — Al Yasmin — pickup',
  'Sarah Mohammed',
  'Rokn Huda Alshaabi',
  '[demo-clean-small] completed — Jareesh Bil Dajaj',
  'a0de0001-0000-4000-8de0-000000000002'::uuid,
  NULL,
  now() - interval '3 days',
  now() - interval '3 days'
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  total_amount = EXCLUDED.total_amount,
  commission_amount = EXCLUDED.commission_amount,
  cancel_reason = EXCLUDED.cancel_reason,
  notes = EXCLUDED.notes,
  updated_at = EXCLUDED.updated_at;

INSERT INTO public.order_items (id, order_id, menu_item_id, dish_name, quantity, unit_price)
VALUES
(
  'e0a00001-0000-4000-8de0-00000000a201'::uuid,
  'e0a00001-0000-4000-8de0-00000000b001'::uuid,
  'e0a00001-0000-4000-8de0-00000000d001'::uuid,
  'Kabsa Dajaj Baytiya',
  1,
  32.00
),
(
  'e0a00001-0000-4000-8de0-00000000a202'::uuid,
  'e0a00001-0000-4000-8de0-00000000b002'::uuid,
  'e0a00001-0000-4000-8de0-00000000d004'::uuid,
  'Jareesh Bil Dajaj',
  1,
  29.00
);

-- ═══════════════════════════════════════════════════════════════════════════
-- 8) Reels (sample video URLs — same CDN pattern as other demo seeds)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.reels (
  id, chef_id, video_url, thumbnail_url, caption, dish_id, created_at, likes_count
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000e001'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001'::uuid,
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
  $reel$Today's chicken kabsa is fresh and ready 😋$reel$,
  'e0a00001-0000-4000-8de0-00000000d001'::uuid,
  now() - interval '2 days',
  0
),
(
  'e0a00001-0000-4000-8de0-00000000e002'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001'::uuid,
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
  $reel$Marqooq with real homemade flavor ✨$reel$,
  'e0a00001-0000-4000-8de0-00000000d002'::uuid,
  now() - interval '1 day',
  0
),
(
  'e0a00001-0000-4000-8de0-00000000e003'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001'::uuid,
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg',
  $reel$Crispy samosas ready for orders 🔥$reel$,
  'e0a00001-0000-4000-8de0-00000000d003'::uuid,
  now() - interval '12 hours',
  0
),
(
  'e0a00001-0000-4000-8de0-00000000e004'::uuid,
  'e0a00001-0000-4000-8de0-00000000c002'::uuid,
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg',
  $reel$Fresh jareesh today with limited quantity 🌿$reel$,
  'e0a00001-0000-4000-8de0-00000000d004'::uuid,
  now() - interval '2 days',
  0
),
(
  'e0a00001-0000-4000-8de0-00000000e005'::uuid,
  'e0a00001-0000-4000-8de0-00000000c002'::uuid,
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg',
  $reel$Light mutabbaq for a quick traditional bite 😍$reel$,
  'e0a00001-0000-4000-8de0-00000000d005'::uuid,
  now() - interval '1 day',
  0
),
(
  'e0a00001-0000-4000-8de0-00000000e006'::uuid,
  'e0a00001-0000-4000-8de0-00000000c002'::uuid,
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMob.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMob.jpg',
  $reel$Qursan meat dish with rich homemade taste$reel$,
  'e0a00001-0000-4000-8de0-00000000d006'::uuid,
  now() - interval '8 hours',
  0
)
ON CONFLICT (id) DO UPDATE SET
  caption = EXCLUDED.caption,
  dish_id = EXCLUDED.dish_id,
  video_url = EXCLUDED.video_url,
  thumbnail_url = EXCLUDED.thumbnail_url;

-- ═══════════════════════════════════════════════════════════════════════════
-- 9) Conversations + messages
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.conversations (
  id, customer_id, chef_id, type, order_id, created_at, last_message, last_message_at, admin_moderation_state
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000f001'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001'::uuid,
  'customer-chef',
  NULL,
  now() - interval '5 days',
  $conv$Hayak Allah 🌷$conv$,
  now() - interval '5 days' + interval '12 minutes',
  'none'
),
(
  'e0a00001-0000-4000-8de0-00000000f002'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003'::uuid,
  'e0a00001-0000-4000-8de0-00000000c002'::uuid,
  'customer-chef',
  NULL,
  now() - interval '4 days',
  'Tamam, batlub bad shway.',
  now() - interval '4 days' + interval '8 minutes',
  'none'
)
ON CONFLICT (id) DO UPDATE SET
  last_message = EXCLUDED.last_message,
  last_message_at = EXCLUDED.last_message_at;

INSERT INTO public.messages (id, conversation_id, sender_id, content, is_read, created_at) VALUES
(
  'e0a00001-0000-4000-8de0-00000000a301'::uuid,
  'e0a00001-0000-4000-8de0-00000000f001'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003'::uuid,
  'Alsalam alaykum, mata yajhaz altalab?',
  true,
  now() - interval '5 days'
),
(
  'e0a00001-0000-4000-8de0-00000000a302'::uuid,
  'e0a00001-0000-4000-8de0-00000000f001'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001'::uuid,
  'Wa alaykum alsalam, khilal 45 daqiqah in shaa Allah.',
  true,
  now() - interval '5 days' + interval '3 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000a303'::uuid,
  'e0a00001-0000-4000-8de0-00000000f001'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003'::uuid,
  'Mumtaz, shukran.',
  true,
  now() - interval '5 days' + interval '8 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000a304'::uuid,
  'e0a00001-0000-4000-8de0-00000000f001'::uuid,
  'e0a00001-0000-4000-8de0-00000000c001'::uuid,
  $msg$Hayak Allah 🌷$msg$,
  true,
  now() - interval '5 days' + interval '12 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000a305'::uuid,
  'e0a00001-0000-4000-8de0-00000000f002'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003'::uuid,
  'Hal aljareesh mutawafir alyawm?',
  true,
  now() - interval '4 days'
),
(
  'e0a00001-0000-4000-8de0-00000000a306'::uuid,
  'e0a00001-0000-4000-8de0-00000000f002'::uuid,
  'e0a00001-0000-4000-8de0-00000000c002'::uuid,
  'Naam mutawafir, lakin alkamiyah mahdudah.',
  true,
  now() - interval '4 days' + interval '4 minutes'
),
(
  'e0a00001-0000-4000-8de0-00000000a307'::uuid,
  'e0a00001-0000-4000-8de0-00000000f002'::uuid,
  'e0a00001-0000-4000-8de0-00000000c003'::uuid,
  'Tamam, batlub bad shway.',
  true,
  now() - interval '4 days' + interval '8 minutes'
)
ON CONFLICT (id) DO UPDATE SET
  content = EXCLUDED.content,
  is_read = EXCLUDED.is_read;

-- ═══════════════════════════════════════════════════════════════════════════
-- 10) Sample notifications
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO public.notifications (
  id, customer_id, title, body, is_read, type, chef_document_id, created_at
) VALUES
(
  'e0a00001-0000-4000-8de0-00000000d101',
  'e0a00001-0000-4000-8de0-00000000c001',
  'Application approved',
  'Your documents were approved. You can now access the cook app.',
  true,
  'chef_account_activated',
  NULL,
  now() - interval '61 days'
),
(
  'e0a00001-0000-4000-8de0-00000000d102',
  'e0a00001-0000-4000-8de0-00000000c002',
  'Application approved',
  'Your documents were approved. You can now access the cook app.',
  true,
  'chef_account_activated',
  NULL,
  now() - interval '46 days'
)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_profiles_integrity'
      AND tgrelid = 'public.profiles'::regclass
      AND NOT tgisinternal
  ) THEN
    ALTER TABLE public.profiles ENABLE TRIGGER trg_profiles_integrity;
  END IF;
  RAISE NOTICE 'demo-clean-small: admin2@naham.com | cook_clean@naham.demo | cook_warning@naham.demo | customer_demo@naham.demo — password NahamDemo2026!';
END $$;

-- If execution stopped before the block above, restore the trigger manually:
--   ALTER TABLE public.profiles ENABLE TRIGGER trg_profiles_integrity;
