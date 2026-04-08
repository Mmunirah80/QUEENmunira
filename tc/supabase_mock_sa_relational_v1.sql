-- ============================================================
-- NAHAM — Saudi relational mock data (English UI, local story)
-- ============================================================
-- Realistic, FK-safe seed for: categories, chefs (mixed compliance),
-- dishes (SAR), documents (national_id + freelancer_id + license health),
-- inspections (passed / failed / open), penalties (warning_1 … freeze_7d),
-- orders (completed + cook / system cancels), Riyadh + nearby coordinates.
--
-- PREREQUISITES (run after core tables + migrations):
--   • supabase_chef_access_documents_v3.sql (access_level, document statuses,
--     unique chef_id+document_type, recompute_chef_access_level)
--   • supabase_inspection_random_v2.sql (inspection_calls.outcome, …)
--   • supabase_orders_cancelled_by_system_v1.sql (legacy; superseded by unified cancel)
--   • supabase_orders_unified_cancel_v1.sql (status=cancelled + cancel_reason)
--
-- Auth: creates demo users if missing (password NahamDemo2026!). Admin resolved
-- like other seeds: admin@naham.app → naham@naham.com → profiles.role=admin.
--
-- After `supabase_orders_unified_cancel_v1.sql`: terminal cancels use status=cancelled + cancel_reason.
-- Notes may still carry operational copy; do not show raw cancel_reason to customers in the app.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Optional columns (idempotent)
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
  ADD COLUMN IF NOT EXISTS rating_avg double precision,
  ADD COLUMN IF NOT EXISTS total_orders integer,
  ADD COLUMN IF NOT EXISTS kitchen_timezone text NOT NULL DEFAULT 'Asia/Riyadh';

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS city text;

ALTER TABLE public.menu_items
  ADD COLUMN IF NOT EXISTS moderation_status text;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS idempotency_key uuid;

ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cancel_reason text;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 0 — Demo Auth users (skip if already present)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_instance uuid;
  v_uid uuid;
  v_email text;
  v_pw text;
  v_emails text[] := ARRAY[
    'chef.sa.salma@naham.mock',
    'chef.sa.kabsa@naham.mock',
    'chef.sa.eastern@naham.mock',
    'chef.sa.heritage@naham.mock',
    'chef.sa.diriyah@naham.mock',
    'chef.sa.kharj@naham.mock',
    'chef.sa.northring@naham.mock',
    'chef.sa.noura@naham.mock',
    'chef.sa.freeze7@naham.mock',
    'customer.sa.fatima@naham.mock',
    'customer.sa.omar@naham.mock',
    'customer.sa.hana@naham.mock'
  ];
BEGIN
  v_pw := crypt('NahamDemo2026!', gen_salt('bf'));
  SELECT id INTO v_instance FROM auth.instances LIMIT 1;
  IF v_instance IS NULL THEN
    v_instance := '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;

  FOREACH v_email IN ARRAY v_emails
  LOOP
    IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = lower(v_email)) THEN
      CONTINUE;
    END IF;

    v_uid := gen_random_uuid();

    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) VALUES (
      v_uid, v_instance, 'authenticated', 'authenticated', v_email, v_pw,
      now(), '{"provider":"email","providers":["email"]}'::jsonb,
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
      WHEN OTHERS THEN RAISE NOTICE 'auth.identities insert for %: %', v_email, SQLERRM;
    END;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'PART 0 user creation failed (create users in Dashboard): %', SQLERRM;
END $$;

DO $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  SELECT u.id, split_part(u.email, '@', 1), 'customer'::text
  FROM auth.users u
  WHERE lower(u.email) IN (
    SELECT lower(x) FROM unnest(ARRAY[
      'chef.sa.salma@naham.mock','chef.sa.kabsa@naham.mock','chef.sa.eastern@naham.mock',
      'chef.sa.heritage@naham.mock','chef.sa.diriyah@naham.mock','chef.sa.kharj@naham.mock',
      'chef.sa.northring@naham.mock','chef.sa.noura@naham.mock','chef.sa.freeze7@naham.mock',
      'customer.sa.fatima@naham.mock','customer.sa.omar@naham.mock','customer.sa.hana@naham.mock'
    ]) AS t(x)
  )
  ON CONFLICT (id) DO NOTHING;
EXCEPTION
  WHEN OTHERS THEN RAISE NOTICE 'profiles stub: %', SQLERRM;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- WIPE (FK-safe)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF to_regclass('public.reel_reports') IS NOT NULL THEN DELETE FROM public.reel_reports; END IF;
  IF to_regclass('public.support_tickets') IS NOT NULL THEN DELETE FROM public.support_tickets; END IF;
END $$;

DELETE FROM public.messages;
DELETE FROM public.conversations;
DELETE FROM public.reel_likes;
DELETE FROM public.reels;

DELETE FROM public.order_items;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_status_events') THEN
    DELETE FROM public.order_status_events;
  END IF;
END $$;

DELETE FROM public.orders;
DELETE FROM public.notifications;
DELETE FROM public.favorites;
DELETE FROM public.addresses;
DELETE FROM public.chef_documents;
DELETE FROM public.menu_items;
DELETE FROM public.chef_profiles;

DO $$
BEGIN
  IF to_regclass('public.chef_violations') IS NOT NULL THEN
    DELETE FROM public.chef_violations;
  END IF;
  IF to_regclass('public.inspection_calls') IS NOT NULL THEN
    DELETE FROM public.inspection_calls;
  END IF;
  IF to_regclass('public.admin_logs') IS NOT NULL THEN
    DELETE FROM public.admin_logs;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SEED
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_admin uuid;
  v_c1 uuid; v_c2 uuid; v_c3 uuid; v_c4 uuid; v_c5 uuid;
  v_c6 uuid; v_c7 uuid; v_c8 uuid; v_c9 uuid;
  v_fatima uuid; v_omar uuid; v_hana uuid;
  missing text;
  -- Fixed inspection + order UUIDs (deterministic, no duplicates)
  ins_pass uuid := 'a1000001-0001-4001-8001-000000000001';
  ins_w1 uuid := 'a1000001-0001-4001-8001-000000000002';
  ins_w2a uuid := 'a1000001-0001-4001-8001-000000000003';
  ins_w2b uuid := 'a1000001-0001-4001-8001-000000000004';
  ins_open uuid := 'a1000001-0001-4001-8001-000000000005';
  ins_f3a uuid := 'a1000001-0001-4001-8001-000000000006';
  ins_f3b uuid := 'a1000001-0001-4001-8001-000000000007';
  ins_f3c uuid := 'a1000001-0001-4001-8001-000000000008';
  ins_f7a uuid := 'a1000001-0001-4001-8001-000000000009';
  ins_f7b uuid := 'a1000001-0001-4001-8001-00000000000a';
  ins_f7c uuid := 'a1000001-0001-4001-8001-00000000000b';
  ins_f7d uuid := 'a1000001-0001-4001-8001-00000000000c';
BEGIN
  SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('admin@naham.app') LIMIT 1;
  IF v_admin IS NULL THEN
    SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('naham@naham.com') LIMIT 1;
  END IF;
  IF v_admin IS NULL THEN
    SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role = 'admin' LIMIT 1;
  END IF;

  SELECT id INTO v_c1 FROM auth.users WHERE lower(email) = lower('chef.sa.salma@naham.mock') LIMIT 1;
  SELECT id INTO v_c2 FROM auth.users WHERE lower(email) = lower('chef.sa.kabsa@naham.mock') LIMIT 1;
  SELECT id INTO v_c3 FROM auth.users WHERE lower(email) = lower('chef.sa.eastern@naham.mock') LIMIT 1;
  SELECT id INTO v_c4 FROM auth.users WHERE lower(email) = lower('chef.sa.heritage@naham.mock') LIMIT 1;
  SELECT id INTO v_c5 FROM auth.users WHERE lower(email) = lower('chef.sa.diriyah@naham.mock') LIMIT 1;
  SELECT id INTO v_c6 FROM auth.users WHERE lower(email) = lower('chef.sa.kharj@naham.mock') LIMIT 1;
  SELECT id INTO v_c7 FROM auth.users WHERE lower(email) = lower('chef.sa.northring@naham.mock') LIMIT 1;
  SELECT id INTO v_c8 FROM auth.users WHERE lower(email) = lower('chef.sa.noura@naham.mock') LIMIT 1;
  SELECT id INTO v_c9 FROM auth.users WHERE lower(email) = lower('chef.sa.freeze7@naham.mock') LIMIT 1;
  SELECT id INTO v_fatima FROM auth.users WHERE lower(email) = lower('customer.sa.fatima@naham.mock') LIMIT 1;
  SELECT id INTO v_omar FROM auth.users WHERE lower(email) = lower('customer.sa.omar@naham.mock') LIMIT 1;
  SELECT id INTO v_hana FROM auth.users WHERE lower(email) = lower('customer.sa.hana@naham.mock') LIMIT 1;

  SELECT string_agg(x.e, ', ' ORDER BY x.e) INTO missing
  FROM (
    SELECT unnest(ARRAY[
      'chef.sa.salma@naham.mock','chef.sa.kabsa@naham.mock','chef.sa.eastern@naham.mock',
      'chef.sa.heritage@naham.mock','chef.sa.diriyah@naham.mock','chef.sa.kharj@naham.mock',
      'chef.sa.northring@naham.mock','chef.sa.noura@naham.mock','chef.sa.freeze7@naham.mock',
      'customer.sa.fatima@naham.mock','customer.sa.omar@naham.mock','customer.sa.hana@naham.mock'
    ]) AS e
  ) x
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(x.e));

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'Create Auth users first (PART 0 or Dashboard), missing: %', missing;
  END IF;

  IF v_admin IS NOT NULL THEN
    UPDATE public.profiles SET role = 'admin' WHERE id = v_admin;
  END IF;

  -- Profiles (English display names; cities for browse / sorting copy)
  UPDATE public.profiles SET role = 'chef', full_name = 'Salma Al-Shammari', phone = '+966501331001', city = 'Riyadh' WHERE id = v_c1;
  UPDATE public.profiles SET role = 'chef', full_name = 'Fahad Al-Mutairi', phone = '+966501331002', city = 'Riyadh' WHERE id = v_c2;
  UPDATE public.profiles SET role = 'chef', full_name = 'Maha Al-Qahtani', phone = '+966501331003', city = 'Riyadh' WHERE id = v_c3;
  UPDATE public.profiles SET role = 'chef', full_name = 'Khalid Al-Dosari', phone = '+966501331004', city = 'Riyadh' WHERE id = v_c4;
  UPDATE public.profiles SET role = 'chef', full_name = 'Noura Al-Harbi', phone = '+966501331005', city = 'Riyadh' WHERE id = v_c5;
  UPDATE public.profiles SET role = 'chef', full_name = 'Abdullah Al-Otaibi', phone = '+966501331006', city = 'Al Kharj' WHERE id = v_c6;
  UPDATE public.profiles SET role = 'chef', full_name = 'Hana Al-Ghamdi', phone = '+966501331007', city = 'Riyadh' WHERE id = v_c7;
  UPDATE public.profiles SET role = 'chef', full_name = 'Reem Al-Zahrani', phone = '+966501331008', city = 'Riyadh' WHERE id = v_c8;
  UPDATE public.profiles SET role = 'chef', full_name = 'Sultan Al-Subaie', phone = '+966501331009', city = 'Riyadh' WHERE id = v_c9;

  UPDATE public.profiles SET role = 'customer', full_name = 'Fatima Al-Rashid', phone = '+966502442001', city = 'Riyadh' WHERE id = v_fatima;
  UPDATE public.profiles SET role = 'customer', full_name = 'Omar Al-Shehri', phone = '+966502442002', city = 'Riyadh' WHERE id = v_omar;
  UPDATE public.profiles SET role = 'customer', full_name = 'Hana Al-Mutlaq', phone = '+966502442003', city = 'Riyadh' WHERE id = v_hana;

  INSERT INTO public.chef_profiles (
    id, kitchen_name, is_online, vacation_mode,
    working_hours_start, working_hours_end,
    bank_iban, bank_account_name, bio, kitchen_city,
    approval_status, suspended, initial_approval_at,
    kitchen_latitude, kitchen_longitude, kitchen_timezone,
    freeze_until, freeze_type, freeze_level, warning_count,
    inspection_penalty_step, inspection_violation_count,
    rating_avg, total_orders
  ) VALUES
    (v_c1, 'Um Salma Kitchen', true, false, '09:00', '22:00',
     'SA0380000000000808010180001', 'Salma Al-Shammari',
     'Najdi home cooking — kabsa and harees from family recipes.',
     'Riyadh', 'approved', false, now() - interval '400 days',
     24.6950, 46.6850, 'Asia/Riyadh',
     NULL, NULL, 0, 0, 0, 0, 4.85, 156),
    (v_c2, 'Bayt Al Kabsa', true, false, '10:00', '23:00',
     'SA0380000000000808010180002', 'Fahad Al-Mutairi',
     'Weekend trays and weekday lunch boxes near the business district.',
     'Riyadh', 'approved', false, now() - interval '260 days',
     24.7200, 46.6880, 'Asia/Riyadh',
     NULL, NULL, 0, 1, 1, 1, 4.55, 64),
    (v_c3, 'Eastern Souq Table', true, false, '11:00', '21:30',
     'SA0380000000000808010180003', 'Maha Al-Qahtani',
     'Eastern Province flavours — saleeg, mandi, and date desserts.',
     'Riyadh', 'approved', false, now() - interval '180 days',
     24.7520, 46.7020, 'Asia/Riyadh',
     NULL, NULL, 0, 2, 2, 2, 4.48, 41),
    (v_c4, 'Najd Heritage Home', false, false, '09:00', '21:00',
     'SA0380000000000808010180004', 'Khalid Al-Dosari',
     'Slow-cooked Najdi dishes — offline during live inspection drill.',
     'Riyadh', 'approved', false, now() - interval '300 days',
     24.7680, 46.7120, 'Asia/Riyadh',
     NULL, NULL, 0, 0, 0, 0, 4.60, 88),
    (v_c5, 'Diriyah Spice Kitchen', false, false, '10:00', '20:00',
     'SA0380000000000808010180005', 'Noura Al-Harbi',
     'New applicant — menu ready while documents are reviewed.',
     'Riyadh', 'pending', false, NULL,
     24.7360, 46.5750, 'Asia/Riyadh',
     NULL, NULL, 0, 0, 0, 0, NULL, NULL),
    (v_c6, 'Kharj Family Oven', false, false, '08:00', '19:00',
     'SA0380000000000808010180006', 'Abdullah Al-Otaibi',
     'South of Riyadh — pickup only; documents need resubmission.',
     'Al Kharj', 'approved', false, now() - interval '120 days',
     24.1550, 47.3050, 'Asia/Riyadh',
     NULL, NULL, 0, 0, 0, 0, 4.10, 22),
    (v_c7, 'North Ring Kitchen', false, true, '09:30', '22:00',
     'SA0380000000000808010180007', 'Hana Al-Ghamdi',
     'Northern dishes and hearty rice — renewal in progress; kitchen on short leave.',
     'Riyadh', 'approved', false, now() - interval '210 days',
     24.8200, 46.6500, 'Asia/Riyadh',
     NULL, NULL, 0, 0, 0, 0, 4.35, 55),
    (v_c8, 'Al Noura Catering', false, false, '08:00', '23:00',
     'SA0380000000000808010180008', 'Reem Al-Zahrani',
     'Catering-sized trays — account on automatic freeze after inspection.',
     'Riyadh', 'approved', false, now() - interval '150 days',
     24.7100, 46.6920, 'Asia/Riyadh',
     now() + interval '2 days', 'soft', 3, 2, 3, 3, 4.20, 33),
    (v_c9, 'Riyadh Gate Kitchen', false, false, '09:00', '22:00',
     'SA0380000000000808010180009', 'Sultan Al-Subaie',
     'Extended freeze after repeated inspection issues — reopening soon.',
     'Riyadh', 'approved', false, now() - interval '190 days',
     24.7050, 46.6780, 'Asia/Riyadh',
     now() + interval '5 days', 'soft', 4, 2, 4, 4, 4.05, 27)
  ON CONFLICT (id) DO UPDATE SET
    kitchen_name = EXCLUDED.kitchen_name,
    is_online = EXCLUDED.is_online,
    vacation_mode = EXCLUDED.vacation_mode,
    bio = EXCLUDED.bio,
    kitchen_city = EXCLUDED.kitchen_city,
    approval_status = EXCLUDED.approval_status,
    suspended = EXCLUDED.suspended,
    initial_approval_at = EXCLUDED.initial_approval_at,
    kitchen_latitude = EXCLUDED.kitchen_latitude,
    kitchen_longitude = EXCLUDED.kitchen_longitude,
    kitchen_timezone = EXCLUDED.kitchen_timezone,
    freeze_until = EXCLUDED.freeze_until,
    freeze_type = EXCLUDED.freeze_type,
    freeze_level = EXCLUDED.freeze_level,
    warning_count = EXCLUDED.warning_count,
    inspection_penalty_step = EXCLUDED.inspection_penalty_step,
    inspection_violation_count = EXCLUDED.inspection_violation_count,
    rating_avg = EXCLUDED.rating_avg,
    total_orders = EXCLUDED.total_orders;

  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, moderation_status, created_at
  ) VALUES
    ('f5d00001-0001-4001-8001-000000000001', v_c1, 'Chicken Kabsa Family Tray', 'Saudi rice, spiced chicken, fried onion — serves 4.', 98.00, NULL, 'Najdi Dishes', 20, 14, true, 'approved', now() - interval '300 days'),
    ('f5d00001-0001-4001-8001-000000000002', v_c1, 'Harees Bowl', 'Slow-cooked wheat with chicken — comfort portion.', 22.00, NULL, 'Najdi Dishes', 35, 24, true, 'approved', now() - interval '280 days'),
    ('f5d00001-0001-4001-8001-000000000003', v_c1, 'Jareesh Side', 'Najdi cracked wheat with yogurt topping.', 16.00, NULL, 'Najdi Dishes', 30, 20, true, 'approved', now() - interval '270 days'),
    ('f5d00001-0001-4001-8001-000000000004', v_c2, 'Lamb Kabsa (Single)', 'Tender lamb shoulder on fragrant rice.', 42.00, NULL, 'Najdi Dishes', 25, 18, true, 'approved', now() - interval '200 days'),
    ('f5d00001-0001-4001-8001-000000000005', v_c2, 'Mutabbaq Snack Box', 'Stuffed pastry — 4 pieces.', 18.00, NULL, 'Others', 40, 30, true, 'approved', now() - interval '190 days'),
    ('f5d00001-0001-4001-8001-000000000006', v_c3, 'Saleeg Plate', 'Creamy rice with chicken — Eastern style.', 28.00, NULL, 'Eastern Region Dishes', 22, 15, true, 'approved', now() - interval '160 days'),
    ('f5d00001-0001-4001-8001-000000000007', v_c3, 'Mandi Half Chicken', 'Charcoal-smoked rice and chicken.', 35.00, NULL, 'Eastern Region Dishes', 18, 10, true, 'approved', now() - interval '155 days'),
    ('f5d00001-0001-4001-8001-000000000008', v_c3, 'Hasawi Rice Side', 'Dark rice with spices — small portion.', 14.00, NULL, 'Eastern Region Dishes', 28, 20, true, 'approved', now() - interval '150 days'),
    ('f5d00001-0001-4001-8001-000000000009', v_c4, 'Qursan with Meat', 'Thin bread layers with slow-cooked meat.', 38.00, NULL, 'Najdi Dishes', 15, 12, true, 'approved', now() - interval '140 days'),
    ('f5d00001-0001-4001-8001-00000000000a', v_c4, 'Kleija (4 pieces)', 'Najdi spiced cookies.', 19.00, NULL, 'Desserts', 25, 18, true, 'approved', now() - interval '130 days'),
    ('f5d00001-0001-4001-8001-00000000000b', v_c5, 'Preview Kabsa Tray', 'For admin review — same-day prep.', 52.00, NULL, 'Others', 8, 8, true, 'pending', now() - interval '5 days'),
    ('f5d00001-0001-4001-8001-00000000000c', v_c6, 'Kharj Roast Chicken', 'Whole bird with spiced rice.', 55.00, NULL, 'Others', 10, 6, true, 'approved', now() - interval '90 days'),
    ('f5d00001-0001-4001-8001-00000000000d', v_c7, 'Haneeth Lamb', 'Slow oven lamb with rice — Northern style.', 65.00, NULL, 'Northern Dishes', 12, 8, true, 'approved', now() - interval '100 days'),
    ('f5d00001-0001-4001-8001-00000000000e', v_c7, 'Kissha Bread Basket', 'Fresh bread with ghee dip.', 12.00, NULL, 'Northern Dishes', 30, 22, true, 'approved', now() - interval '95 days'),
    ('f5d00001-0001-4001-8001-00000000000f', v_c8, 'Corporate Kabsa Tray', 'Large tray — office pickup.', 145.00, NULL, 'Najdi Dishes', 5, 2, true, 'approved', now() - interval '40 days'),
    ('f5d00001-0001-4001-8001-000000000010', v_c9, 'Mixed Grill Box', 'Assorted meats with rice — on hold during freeze.', 78.00, NULL, 'Others', 6, 0, false, 'approved', now() - interval '30 days')
  ON CONFLICT (id) DO UPDATE SET
    chef_id = EXCLUDED.chef_id,
    name = EXCLUDED.name,
    price = EXCLUDED.price,
    category = EXCLUDED.category,
    moderation_status = EXCLUDED.moderation_status;

  -- Documents: national_id + freelancer_id (access gate) + license (health certificate file)
  INSERT INTO public.chef_documents (
    chef_id, document_type, file_url, status, expiry_date, rejection_reason, no_expiry, created_at
  ) VALUES
    -- c1 fully approved
    (v_c1, 'national_id', 'mock/salma/national_id.pdf', 'approved', (CURRENT_DATE + interval '2 years')::date, NULL, false, now() - interval '400 days'),
    (v_c1, 'freelancer_id', 'mock/salma/freelancer_permit.pdf', 'approved', (CURRENT_DATE + interval '1 year')::date, NULL, false, now() - interval '400 days'),
    (v_c1, 'license', 'mock/salma/health_certificate.pdf', 'approved', (CURRENT_DATE + interval '1 year')::date, NULL, false, now() - interval '400 days'),
    -- c2 approved docs; inspection penalty only
    (v_c2, 'national_id', 'mock/kabsa/national_id.pdf', 'approved', (CURRENT_DATE + interval '18 months')::date, NULL, false, now() - interval '260 days'),
    (v_c2, 'freelancer_id', 'mock/kabsa/freelancer_permit.pdf', 'approved', (CURRENT_DATE + interval '11 months')::date, NULL, false, now() - interval '260 days'),
    (v_c2, 'license', 'mock/kabsa/health_certificate.pdf', 'approved', (CURRENT_DATE + interval '11 months')::date, NULL, false, now() - interval '260 days'),
    -- c3
    (v_c3, 'national_id', 'mock/eastern/national_id.pdf', 'approved', (CURRENT_DATE + interval '2 years')::date, NULL, false, now() - interval '180 days'),
    (v_c3, 'freelancer_id', 'mock/eastern/freelancer_permit.pdf', 'approved', (CURRENT_DATE + interval '1 year')::date, NULL, false, now() - interval '180 days'),
    (v_c3, 'license', 'mock/eastern/health_certificate.pdf', 'approved', (CURRENT_DATE + interval '1 year')::date, NULL, false, now() - interval '180 days'),
    -- c4 open inspection — docs ok
    (v_c4, 'national_id', 'mock/heritage/national_id.pdf', 'approved', (CURRENT_DATE + interval '3 years')::date, NULL, false, now() - interval '300 days'),
    (v_c4, 'freelancer_id', 'mock/heritage/freelancer_permit.pdf', 'approved', (CURRENT_DATE + interval '2 years')::date, NULL, false, now() - interval '300 days'),
    (v_c4, 'license', 'mock/heritage/health_certificate.pdf', 'approved', (CURRENT_DATE + interval '14 months')::date, NULL, false, now() - interval '300 days'),
    -- c5 waiting review
    (v_c5, 'national_id', 'mock/diriyah/national_id.pdf', 'pending_review', NULL, NULL, false, now() - interval '4 days'),
    (v_c5, 'freelancer_id', 'mock/diriyah/freelancer_permit.pdf', 'pending_review', NULL, NULL, false, now() - interval '4 days'),
    (v_c5, 'license', 'mock/diriyah/health_certificate.pdf', 'pending_review', NULL, NULL, false, now() - interval '3 days'),
    -- c6 rejected freelancer (health cert unclear scan)
    (v_c6, 'national_id', 'mock/kharj/national_id.pdf', 'approved', (CURRENT_DATE + interval '4 years')::date, NULL, false, now() - interval '120 days'),
    (v_c6, 'freelancer_id', 'mock/kharj/freelancer_permit.pdf', 'rejected', NULL,
     'Freelancer permit image is blurry — please re-upload a clear scan of both sides.', false, now() - interval '10 days'),
    (v_c6, 'license', 'mock/kharj/health_certificate.pdf', 'pending_review', NULL, NULL, false, now() - interval '10 days'),
    -- c7 expired freelancer permit (row status expired)
    (v_c7, 'national_id', 'mock/northring/national_id.pdf', 'approved', (CURRENT_DATE + interval '5 years')::date, NULL, false, now() - interval '210 days'),
    (v_c7, 'freelancer_id', 'mock/northring/freelancer_permit.pdf', 'expired', (CURRENT_DATE - interval '20 days')::date, NULL, false, now() - interval '210 days'),
    (v_c7, 'license', 'mock/northring/health_certificate.pdf', 'approved', (CURRENT_DATE + interval '6 months')::date, NULL, false, now() - interval '210 days'),
    -- c8 frozen 3d — docs approved
    (v_c8, 'national_id', 'mock/noura/national_id.pdf', 'approved', (CURRENT_DATE + interval '2 years')::date, NULL, false, now() - interval '150 days'),
    (v_c8, 'freelancer_id', 'mock/noura/freelancer_permit.pdf', 'approved', (CURRENT_DATE + interval '1 year')::date, NULL, false, now() - interval '150 days'),
    (v_c8, 'license', 'mock/noura/health_certificate.pdf', 'approved', (CURRENT_DATE + interval '1 year')::date, NULL, false, now() - interval '150 days'),
    -- c9 frozen 7d — docs approved
    (v_c9, 'national_id', 'mock/freeze7/national_id.pdf', 'approved', (CURRENT_DATE + interval '3 years')::date, NULL, false, now() - interval '190 days'),
    (v_c9, 'freelancer_id', 'mock/freeze7/freelancer_permit.pdf', 'approved', (CURRENT_DATE + interval '2 years')::date, NULL, false, now() - interval '190 days'),
    (v_c9, 'license', 'mock/freeze7/health_certificate.pdf', 'approved', (CURRENT_DATE + interval '15 months')::date, NULL, false, now() - interval '190 days');

  INSERT INTO public.addresses (customer_id, label, street, city, is_default, created_at) VALUES
    (v_fatima, 'Home', 'Al Olaya, Building 12', 'Riyadh', true, now() - interval '200 days'),
    (v_omar, 'Home', 'Al Malaz, Street 9', 'Riyadh', true, now() - interval '150 days'),
    (v_hana, 'Home', 'Al Yasmin, Villa 3', 'Riyadh', true, now() - interval '80 days');

  INSERT INTO public.favorites (customer_id, item_id, created_at) VALUES
    (v_fatima, 'f5d00001-0001-4001-8001-000000000001', now() - interval '12 days'),
    (v_omar, 'f5d00001-0001-4001-8001-000000000006', now() - interval '9 days'),
    (v_hana, 'f5d00001-0001-4001-8001-00000000000a', now() - interval '4 days');

  INSERT INTO public.orders (id, customer_id, chef_id, status, cancel_reason, total_amount, commission_amount, delivery_address, customer_name, chef_name, notes, idempotency_key, created_at, updated_at) VALUES
    ('f5f00001-0001-4001-8001-000000000001', v_fatima, v_c1, 'completed', NULL, 98.00, 9.80, 'Riyadh — pickup', 'Fatima Al-Rashid', 'Um Salma Kitchen', '[naham-mock] Family tray — Friday dinner', gen_random_uuid(), now() - interval '20 days', now() - interval '19 days'),
    ('f5f00001-0001-4001-8001-000000000002', v_omar, v_c2, 'completed', NULL, 60.00, 6.00, 'Riyadh — pickup', 'Omar Al-Shehri', 'Bayt Al Kabsa', '[naham-mock] Lamb kabsa + mutabbaq', gen_random_uuid(), now() - interval '14 days', now() - interval '13 days'),
    ('f5f00001-0001-4001-8001-000000000003', v_hana, v_c3, 'completed', NULL, 77.00, 7.70, 'Riyadh — pickup', 'Hana Al-Mutlaq', 'Eastern Souq Table', '[naham-mock] Saleeg + mandi + hasawi', gen_random_uuid(), now() - interval '10 days', now() - interval '9 days'),
    ('f5f00001-0001-4001-8001-000000000004', v_fatima, v_c4, 'completed', NULL, 57.00, 5.70, 'Riyadh — pickup', 'Fatima Al-Rashid', 'Najd Heritage Home', '[naham-mock] Qursan + kleija', gen_random_uuid(), now() - interval '7 days', now() - interval '6 days'),
    ('f5f00001-0001-4001-8001-000000000005', v_omar, v_c1, 'cancelled', 'cook_rejected', 42.00, 4.20, 'Riyadh — pickup', 'Omar Al-Shehri', 'Um Salma Kitchen',
     '[naham-mock] Kitchen could not fulfil lamb portion today — please reorder tomorrow.', gen_random_uuid(), now() - interval '5 days', now() - interval '5 days'),
    ('f5f00001-0001-4001-8001-000000000006', v_hana, v_c8, 'cancelled', 'system_cancelled_frozen', 145.00, 14.50, 'Riyadh — pickup', 'Hana Al-Mutlaq', 'Al Noura Catering',
     '[naham-mock] Order voided — kitchen on compliance freeze.', gen_random_uuid(), now() - interval '3 days', now() - interval '3 days'),
    ('f5f00001-0001-4001-8001-000000000007', v_fatima, v_c6, 'cancelled', 'system_cancelled_frozen', 55.00, 5.50, 'Al Kharj — pickup', 'Fatima Al-Rashid', 'Kharj Family Oven', '[naham-mock] System void — legacy checkout rollback sample', gen_random_uuid(), now() - interval '8 days', now() - interval '8 days');

  INSERT INTO public.order_items (order_id, menu_item_id, dish_name, quantity, unit_price) VALUES
    ('f5f00001-0001-4001-8001-000000000001', 'f5d00001-0001-4001-8001-000000000001', 'Chicken Kabsa Family Tray', 1, 98.00),
    ('f5f00001-0001-4001-8001-000000000002', 'f5d00001-0001-4001-8001-000000000004', 'Lamb Kabsa (Single)', 1, 42.00),
    ('f5f00001-0001-4001-8001-000000000002', 'f5d00001-0001-4001-8001-000000000005', 'Mutabbaq Snack Box', 1, 18.00),
    ('f5f00001-0001-4001-8001-000000000003', 'f5d00001-0001-4001-8001-000000000006', 'Saleeg Plate', 1, 28.00),
    ('f5f00001-0001-4001-8001-000000000003', 'f5d00001-0001-4001-8001-000000000007', 'Mandi Half Chicken', 1, 35.00),
    ('f5f00001-0001-4001-8001-000000000003', 'f5d00001-0001-4001-8001-000000000008', 'Hasawi Rice Side', 1, 14.00),
    ('f5f00001-0001-4001-8001-000000000004', 'f5d00001-0001-4001-8001-000000000009', 'Qursan with Meat', 1, 38.00),
    ('f5f00001-0001-4001-8001-000000000004', 'f5d00001-0001-4001-8001-00000000000a', 'Kleija (4 pieces)', 1, 19.00),
    ('f5f00001-0001-4001-8001-000000000005', 'f5d00001-0001-4001-8001-000000000004', 'Lamb Kabsa (Single)', 1, 42.00),
    ('f5f00001-0001-4001-8001-000000000006', 'f5d00001-0001-4001-8001-00000000000f', 'Corporate Kabsa Tray', 1, 145.00),
    ('f5f00001-0001-4001-8001-000000000007', 'f5d00001-0001-4001-8001-00000000000c', 'Kharj Roast Chicken', 1, 55.00);

  -- Inspections + violations (requires v_admin + inspection_calls.outcome from random v2)
  IF v_admin IS NOT NULL
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inspection_calls')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inspection_calls' AND column_name = 'outcome')
  THEN
    INSERT INTO public.inspection_calls (
      id, chef_id, admin_id, channel_name, status, outcome, counted_as_violation,
      result_action, violation_reason, result_note, chef_result_seen,
      created_at, responded_at, finalized_at, ended_at
    ) VALUES
      (ins_pass, v_c1, v_admin, '[mock] inspection-salma-pass', 'completed', 'passed', false,
       'pass', NULL, 'Routine video inspection — prep area organised.', true,
       now() - interval '70 days', now() - interval '70 days', now() - interval '70 days', now() - interval '70 days'),
      (ins_w1, v_c2, v_admin, '[mock] inspection-kabsa-warn1', 'completed', 'kitchen_not_clean', true,
       'warning_1', 'failed_hygiene_check', 'Cutting boards stored incorrectly — corrected on call.', true,
       now() - interval '40 days', now() - interval '40 days', now() - interval '40 days', now() - interval '40 days'),
      (ins_w2a, v_c3, v_admin, '[mock] inspection-eastern-warn1', 'completed', 'no_answer', true,
       'warning_1', 'no_answer', 'First attempt — no answer within window.', true,
       now() - interval '60 days', now() - interval '60 days', now() - interval '60 days', now() - interval '60 days'),
      (ins_w2b, v_c3, v_admin, '[mock] inspection-eastern-warn2', 'completed', 'kitchen_not_clean', true,
       'warning_2', 'failed_hygiene_check', 'Oil residue near fryer — documented.', true,
       now() - interval '25 days', now() - interval '25 days', now() - interval '25 days', now() - interval '25 days'),
      (ins_open, v_c4, v_admin, '[mock] inspection-heritage-open', 'pending', NULL, false,
       NULL, NULL, NULL, false,
       now() - interval '25 minutes', NULL, NULL, NULL),
      (ins_f3a, v_c8, v_admin, '[mock] inspection-noura-w1', 'completed', 'no_answer', true,
       'warning_1', 'no_answer', 'Chef offline briefly.', true,
       now() - interval '90 days', now() - interval '90 days', now() - interval '90 days', now() - interval '90 days'),
      (ins_f3b, v_c8, v_admin, '[mock] inspection-noura-w2', 'completed', 'kitchen_not_clean', true,
       'warning_2', 'failed_hygiene_check', 'Work surface clutter.', true,
       now() - interval '60 days', now() - interval '60 days', now() - interval '60 days', now() - interval '60 days'),
      (ins_f3c, v_c8, v_admin, '[mock] inspection-noura-f3', 'completed', 'refused_inspection', true,
       'freeze_3d', 'declined_call', 'Delayed joining the inspection channel.', true,
       now() - interval '4 days', now() - interval '4 days', now() - interval '4 days', now() - interval '4 days'),
      (ins_f7a, v_c9, v_admin, '[mock] inspection-gate-w1', 'completed', 'no_answer', true,
       'warning_1', 'no_answer', NULL, true,
       now() - interval '100 days', now() - interval '100 days', now() - interval '100 days', now() - interval '100 days'),
      (ins_f7b, v_c9, v_admin, '[mock] inspection-gate-w2', 'completed', 'kitchen_not_clean', true,
       'warning_2', 'failed_hygiene_check', NULL, true,
       now() - interval '70 days', now() - interval '70 days', now() - interval '70 days', now() - interval '70 days'),
      (ins_f7c, v_c9, v_admin, '[mock] inspection-gate-f3', 'completed', 'refused_inspection', true,
       'freeze_3d', 'declined_call', NULL, true,
       now() - interval '45 days', now() - interval '45 days', now() - interval '45 days', now() - interval '45 days'),
      (ins_f7d, v_c9, v_admin, '[mock] inspection-gate-f7', 'completed', 'kitchen_not_clean', true,
       'freeze_7d', 'failed_hygiene_check', 'Repeat hygiene issue — extended freeze.', true,
       now() - interval '8 days', now() - interval '8 days', now() - interval '8 days', now() - interval '8 days');
  END IF;

  IF v_admin IS NOT NULL
     AND to_regclass('public.chef_violations') IS NOT NULL
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inspection_calls' AND column_name = 'outcome')
  THEN
    INSERT INTO public.chef_violations (
      chef_id, inspection_call_id, admin_id, violation_index, reason, action_applied, note, created_at
    ) VALUES
      (v_c2, ins_w1, v_admin, 1, 'kitchen_not_clean', 'warning_1', 'First countable violation.', now() - interval '40 days'),
      (v_c3, ins_w2a, v_admin, 1, 'no_answer', 'warning_1', NULL, now() - interval '60 days'),
      (v_c3, ins_w2b, v_admin, 2, 'kitchen_not_clean', 'warning_2', NULL, now() - interval '25 days'),
      (v_c8, ins_f3a, v_admin, 1, 'no_answer', 'warning_1', NULL, now() - interval '90 days'),
      (v_c8, ins_f3b, v_admin, 2, 'kitchen_not_clean', 'warning_2', NULL, now() - interval '60 days'),
      (v_c8, ins_f3c, v_admin, 3, 'refused_inspection', 'freeze_3d', NULL, now() - interval '4 days'),
      (v_c9, ins_f7a, v_admin, 1, 'no_answer', 'warning_1', NULL, now() - interval '100 days'),
      (v_c9, ins_f7b, v_admin, 2, 'kitchen_not_clean', 'warning_2', NULL, now() - interval '70 days'),
      (v_c9, ins_f7c, v_admin, 3, 'refused_inspection', 'freeze_3d', NULL, now() - interval '45 days'),
      (v_c9, ins_f7d, v_admin, 4, 'kitchen_not_clean', 'freeze_7d', NULL, now() - interval '8 days');
  END IF;

  -- Recompute document gates (access_level, documents_operational_ok)
  PERFORM public.recompute_chef_access_level(v_c1);
  PERFORM public.recompute_chef_access_level(v_c2);
  PERFORM public.recompute_chef_access_level(v_c3);
  PERFORM public.recompute_chef_access_level(v_c4);
  PERFORM public.recompute_chef_access_level(v_c5);
  PERFORM public.recompute_chef_access_level(v_c6);
  PERFORM public.recompute_chef_access_level(v_c7);
  PERFORM public.recompute_chef_access_level(v_c8);
  PERFORM public.recompute_chef_access_level(v_c9);

  RAISE NOTICE 'supabase_mock_sa_relational_v1 complete: 9 chefs, 16 dishes, inspections+violations, 7 orders.';
END $$;
