-- ============================================================
-- NAHAM — Saudi professional demo story (EN copy + SA names)
-- ============================================================
-- Ready mock for presentations: established vs new chefs, frozen/pending,
-- active vs new customers, cart via favorites, chat + reels + likes.
--
-- Run as postgres / service role. BACKUP first on non-dev DBs.
--
-- For unified order status + cancel_reason + enum label `cancelled`, apply first:
--   supabase_orders_unified_cancel_v1.sql
-- For chef_documents pending_review + access_level, apply:
--   supabase_chef_access_documents_v3.sql
--
-- Auth users: this script CREATES the 10 demo emails if missing (PART 0).
-- Login password for all: NahamDemo2026!  — change after first login.
-- If PART 0 fails (hosting policy), create the same emails in Dashboard.
--
-- Admin (first match wins):
--   admin@naham.app  OR  naham@naham.com  OR  any user with profiles.role = 'admin'
-- Chefs:
--   chef.nora@naham.app
--   chef.laila@naham.app
--   chef.dana@naham.app
--   chef.reem@naham.app
--   chef.huda@naham.app
-- Customers:
--   customer.sarah@naham.app
--   customer.reem@naham.app
--   customer.laila@naham.app
--   customer.noor@naham.app
--   customer.dana@naham.app
--
-- Reviews: no standard reviews table in stock schema — four demo snippets
-- are stored as notifications (title prefix [demo-review]) so they surface
-- in the customer notification list. Remove or replace when you add a
-- proper reviews table.
-- ============================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 0 — Create demo Auth users + identities (pgcrypto + auth schema)
-- Password for all new accounts: NahamDemo2026!
-- ═══════════════════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_instance uuid;
  v_uid uuid;
  v_email text;
  v_pw text;
  v_emails text[] := ARRAY[
    'chef.nora@naham.app',
    'chef.laila@naham.app',
    'chef.dana@naham.app',
    'chef.reem@naham.app',
    'chef.huda@naham.app',
    'customer.sarah@naham.app',
    'customer.reem@naham.app',
    'customer.laila@naham.app',
    'customer.noor@naham.app',
    'customer.dana@naham.app'
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
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    ) VALUES (
      v_uid,
      v_instance,
      'authenticated',
      'authenticated',
      v_email,
      v_pw,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('email', v_email),
      now(),
      now()
    );

    -- Email provider login requires a row in auth.identities (schema may vary slightly by Supabase version).
    BEGIN
      INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
      ) VALUES (
        gen_random_uuid(),
        v_uid,
        jsonb_build_object('sub', v_uid::text, 'email', v_email),
        'email',
        v_email,
        now(),
        now(),
        now()
      );
    EXCEPTION
      WHEN unique_violation THEN
        NULL;
      WHEN OTHERS THEN
        RAISE NOTICE 'auth.identities insert for %: %', v_email, SQLERRM;
    END;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'PART 0 failed (create users in Authentication → Users instead): %', SQLERRM;
END $$;

-- Stub profiles so later UPDATEs apply (skip if trigger already created the row)
DO $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  SELECT u.id, split_part(u.email, '@', 1), 'customer'::text
  FROM auth.users u
  WHERE lower(u.email) IN (
    SELECT lower(x)
    FROM unnest(ARRAY[
      'chef.nora@naham.app',
      'chef.laila@naham.app',
      'chef.dana@naham.app',
      'chef.reem@naham.app',
      'chef.huda@naham.app',
      'customer.sarah@naham.app',
      'customer.reem@naham.app',
      'customer.laila@naham.app',
      'customer.noor@naham.app',
      'customer.dana@naham.app'
    ]) AS t(x)
  )
  ON CONFLICT (id) DO NOTHING;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'profiles stub skipped: %', SQLERRM;
END $$;

ALTER TABLE public.conversations
  ALTER COLUMN chef_id DROP NOT NULL;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS last_message text,
  ADD COLUMN IF NOT EXISTS last_message_at timestamptz;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

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
  ADD COLUMN IF NOT EXISTS total_orders integer;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS city text;

ALTER TABLE public.menu_items
  ADD COLUMN IF NOT EXISTS moderation_status text;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS idempotency_key uuid;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cancel_reason text;

ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

-- ─── Full wipe (same order as supabase_fresh_complete_reset_seed.sql) ───
DO $$
BEGIN
  IF to_regclass('public.reel_reports') IS NOT NULL THEN
    DELETE FROM public.reel_reports;
  END IF;
  IF to_regclass('public.support_tickets') IS NOT NULL THEN
    DELETE FROM public.support_tickets;
  END IF;
END $$;

DELETE FROM public.messages;
DELETE FROM public.conversations;
DELETE FROM public.reel_likes;
DELETE FROM public.reels;
DELETE FROM public.order_items;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'order_status_events'
  ) THEN
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
  IF to_regclass('public.inspection_calls') IS NOT NULL THEN
    DELETE FROM public.inspection_calls;
  END IF;
  IF to_regclass('public.admin_logs') IS NOT NULL THEN
    DELETE FROM public.admin_logs;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_admin uuid;
  v_nora uuid;
  v_laila uuid;
  v_dana uuid;
  v_reem uuid;
  v_huda uuid;
  v_sarah uuid;
  v_reem_c uuid;
  v_laila_omar uuid;
  v_noor uuid;
  v_dana_f uuid;
  missing text;
  conv_sarah_nora uuid;
BEGIN
  -- Resolve admin: prefer explicit emails, then any existing admin profile (matches older seeds).
  SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('admin@naham.app') LIMIT 1;
  IF v_admin IS NULL THEN
    SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('naham@naham.com') LIMIT 1;
  END IF;
  IF v_admin IS NULL THEN
    SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role = 'admin' LIMIT 1;
  END IF;

  SELECT id INTO v_nora FROM auth.users WHERE lower(email) = lower('chef.nora@naham.app') LIMIT 1;
  SELECT id INTO v_laila FROM auth.users WHERE lower(email) = lower('chef.laila@naham.app') LIMIT 1;
  SELECT id INTO v_dana FROM auth.users WHERE lower(email) = lower('chef.dana@naham.app') LIMIT 1;
  SELECT id INTO v_reem FROM auth.users WHERE lower(email) = lower('chef.reem@naham.app') LIMIT 1;
  SELECT id INTO v_huda FROM auth.users WHERE lower(email) = lower('chef.huda@naham.app') LIMIT 1;
  SELECT id INTO v_sarah FROM auth.users WHERE lower(email) = lower('customer.sarah@naham.app') LIMIT 1;
  SELECT id INTO v_reem_c FROM auth.users WHERE lower(email) = lower('customer.reem@naham.app') LIMIT 1;
  SELECT id INTO v_laila_omar FROM auth.users WHERE lower(email) = lower('customer.laila@naham.app') LIMIT 1;
  SELECT id INTO v_noor FROM auth.users WHERE lower(email) = lower('customer.noor@naham.app') LIMIT 1;
  SELECT id INTO v_dana_f FROM auth.users WHERE lower(email) = lower('customer.dana@naham.app') LIMIT 1;

  SELECT string_agg(x.e, ', ' ORDER BY x.e) INTO missing
  FROM (
    SELECT unnest(ARRAY[
      'chef.nora@naham.app','chef.laila@naham.app','chef.dana@naham.app',
      'chef.reem@naham.app','chef.huda@naham.app',
      'customer.sarah@naham.app','customer.reem@naham.app','customer.laila@naham.app',
      'customer.noor@naham.app','customer.dana@naham.app'
    ]) AS e
  ) x
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(x.e));

  IF missing IS NOT NULL THEN
    RAISE NOTICE 'Some demo emails are still missing after PART 0 (create them in Dashboard): %', missing;
  END IF;

  IF v_nora IS NULL OR v_sarah IS NULL THEN
    RAISE EXCEPTION 'Demo seed needs at least chef.nora@naham.app and customer.sarah@naham.app. Error: PART 0 may have failed — check NOTICES above and create Auth users manually.';
  END IF;

  IF v_admin IS NOT NULL THEN
    UPDATE public.profiles SET role = 'admin' WHERE id = v_admin;
  END IF;

  UPDATE public.profiles SET role = 'chef', full_name = 'Nora Al-Qahtani', phone = '+966501111001', city = 'Riyadh' WHERE id = v_nora;
  UPDATE public.profiles SET role = 'chef', full_name = 'Laila Al-Dossari', phone = '+966501111002', city = 'Riyadh' WHERE id = v_laila;
  UPDATE public.profiles SET role = 'chef', full_name = 'Dana Al-Harbi', phone = '+966501111003', city = 'Riyadh' WHERE id = v_dana;
  UPDATE public.profiles SET role = 'chef', full_name = 'Reem Al-Otaibi', phone = '+966501111004', city = 'Jeddah' WHERE id = v_reem;
  UPDATE public.profiles SET role = 'chef', full_name = 'Huda Al-Shammari', phone = '+966501111005', city = 'Dammam' WHERE id = v_huda;

  UPDATE public.profiles SET role = 'customer', full_name = 'Sarah Al-Qahtani', phone = '+966502222001', city = 'Riyadh' WHERE id = v_sarah;
  UPDATE public.profiles SET role = 'customer', full_name = 'Reem Al-Harbi', phone = '+966502222002', city = 'Riyadh' WHERE id = v_reem_c;
  UPDATE public.profiles SET role = 'customer', full_name = 'Laila Omar', phone = '+966502222003', city = 'Riyadh' WHERE id = v_laila_omar;
  UPDATE public.profiles SET role = 'customer', full_name = 'Noor Salem', phone = '+966502222004', city = 'Jeddah' WHERE id = v_noor;
  UPDATE public.profiles SET role = 'customer', full_name = 'Dana Fahad', phone = '+966502222005', city = 'Dammam' WHERE id = v_dana_f;

  INSERT INTO public.chef_profiles (
    id, kitchen_name, is_online, vacation_mode,
    working_hours_start, working_hours_end,
    bank_iban, bank_account_name, bio, kitchen_city,
    approval_status, suspended, initial_approval_at,
    kitchen_latitude, kitchen_longitude,
    freeze_until, freeze_type, freeze_level, warning_count,
    rating_avg, total_orders
  ) VALUES
    (v_nora, 'Nora''s Kitchen', true, false, '09:00', '22:00',
     'SA0380000000000808010170001', 'Nora Al-Qahtani',
     'Traditional homemade Saudi food with authentic taste.',
     'Riyadh', 'approved', false, now() - interval '500 days',
     24.7136, 46.6753, NULL, NULL, 0, 0, 4.80, 120),
    (v_laila, 'Home Taste by Laila', true, false, '10:00', '23:00',
     'SA0380000000000808010170002', 'Laila Al-Dossari',
     'Family recipes and daily specials — pickup near central Riyadh.',
     'Riyadh', 'approved', false, now() - interval '200 days',
     24.7480, 46.7020, NULL, NULL, 0, 0, 4.60, 85),
    (v_dana, 'Dana''s Homemade Kitchen', true, false, '11:00', '21:00',
     'SA0380000000000808010170003', 'Dana Al-Harbi',
     'New kitchen — small batches, same-day prep.',
     'Riyadh', 'approved', false, now() - interval '21 days',
     24.7310, 46.6980, NULL, NULL, 0, 0, 0.00, 3),
    (v_reem, 'Warm Table Kitchen', false, false, '09:00', '20:00',
     'SA0380000000000808010170004', 'Reem Al-Otaibi',
     'Jeddah-based — awaiting document approval before going live.',
     'Jeddah', 'pending', false, NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, NULL),
    (v_huda, 'Najd Flavors', false, false, '10:00', '22:00',
     'SA0380000000000808010170005', 'Huda Al-Shammari',
     'Account frozen after hygiene inspection — legacy listings kept for audit.',
     'Dammam', 'approved', true, now() - interval '300 days',
     26.4207, 50.0888, now() + interval '14 days', 'soft', 3, 2, 4.00, 42)
  ON CONFLICT (id) DO UPDATE SET
    kitchen_name = EXCLUDED.kitchen_name,
    bio = EXCLUDED.bio,
    kitchen_city = EXCLUDED.kitchen_city,
    approval_status = EXCLUDED.approval_status,
    suspended = EXCLUDED.suspended,
    rating_avg = EXCLUDED.rating_avg,
    total_orders = EXCLUDED.total_orders,
    freeze_until = EXCLUDED.freeze_until,
    freeze_type = EXCLUDED.freeze_type;

  INSERT INTO public.menu_items (id, chef_id, name, description, price, image_url, category, daily_quantity, remaining_quantity, is_available, moderation_status, created_at) VALUES
    ('f4d00001-0001-4001-8001-000000000001', v_nora, 'Chicken Kabsa', 'Fragrant rice and spiced chicken — family portion.', 25.00, NULL, 'Mains', 40, 28, true, 'approved', now() - interval '400 days'),
    ('f4d00001-0001-4001-8001-000000000002', v_nora, 'Jareesh', 'Slow-cooked wheat with yogurt — comfort dish.', 20.00, NULL, 'Traditional', 30, 20, true, 'approved', now() - interval '380 days'),
    ('f4d00001-0001-4001-8001-000000000003', v_nora, 'Qursan', 'Thin bread layers with meat — Najdi style.', 22.00, NULL, 'Traditional', 25, 15, true, 'approved', now() - interval '360 days'),
    ('f4d00001-0001-4001-8001-000000000004', v_nora, 'Sambosa', 'Crispy pastry with spiced filling — 6 pieces.', 12.00, NULL, 'Snacks', 50, 35, true, 'approved', now() - interval '350 days'),
    ('f4d00001-0001-4001-8001-000000000005', v_nora, 'Date Maamoul', 'Soft cookies with date filling — 4 pieces.', 15.00, NULL, 'Desserts', 35, 22, true, 'approved', now() - interval '340 days'),
    ('f4d00001-0001-4001-8001-000000000006', v_laila, 'Saleeg', 'Creamy rice with chicken — Hijazi favorite.', 23.00, NULL, 'Mains', 28, 18, true, 'approved', now() - interval '180 days'),
    ('f4d00001-0001-4001-8001-000000000007', v_laila, 'Chicken Mandi', 'Smoky rice and tender chicken.', 28.00, NULL, 'Mains', 24, 14, true, 'approved', now() - interval '175 days'),
    ('f4d00001-0001-4001-8001-000000000008', v_laila, 'Stuffed Grape Leaves', 'Rice and herbs — dozen pieces.', 18.00, NULL, 'Sides', 30, 20, true, 'approved', now() - interval '170 days'),
    ('f4d00001-0001-4001-8001-000000000009', v_laila, 'Baked Pasta', 'Cheese-topped — single portion.', 20.00, NULL, 'Mains', 22, 12, true, 'approved', now() - interval '165 days'),
    ('f4d00001-0001-4001-8001-000000000010', v_dana, 'Chicken Kabsa', 'Smaller batch — same-day prep.', 24.00, NULL, 'Mains', 15, 10, true, 'approved', now() - interval '20 days'),
    ('f4d00001-0001-4001-8001-000000000011', v_dana, 'Sambosa', 'Six pieces — limited daily run.', 10.00, NULL, 'Snacks', 20, 12, true, 'approved', now() - interval '18 days'),
    ('f4d00001-0001-4001-8001-000000000012', v_reem, 'Preview Tray', 'For admin review only.', 40.00, NULL, 'Trays', 5, 5, true, 'pending', now() - interval '5 days'),
    ('f4d00001-0001-4001-8001-000000000013', v_huda, 'Legacy Kabsa Tray', 'Unavailable — frozen kitchen.', 60.00, NULL, 'Trays', 0, 0, false, 'approved', now() - interval '90 days')
  ON CONFLICT (id) DO UPDATE SET
    chef_id = EXCLUDED.chef_id,
    name = EXCLUDED.name,
    price = EXCLUDED.price,
    moderation_status = EXCLUDED.moderation_status;

  INSERT INTO public.chef_documents (chef_id, document_type, file_url, status, created_at) VALUES
    (v_nora, 'national_id', 'demo/nora/national_id.pdf', 'approved', now() - interval '500 days'),
    (v_nora, 'freelancer_id', 'demo/nora/freelancer.pdf', 'approved', now() - interval '500 days'),
    (v_laila, 'national_id', 'demo/laila/national_id.pdf', 'approved', now() - interval '200 days'),
    (v_laila, 'freelancer_id', 'demo/laila/freelancer.pdf', 'approved', now() - interval '200 days'),
    (v_dana, 'national_id', 'demo/dana/national_id.pdf', 'approved', now() - interval '21 days'),
    (v_dana, 'freelancer_id', 'demo/dana/freelancer.pdf', 'approved', now() - interval '21 days'),
    (v_reem, 'national_id', 'demo/reem/national_id.pdf', 'pending', now() - interval '4 days'),
    (v_reem, 'freelancer_id', 'demo/reem/freelancer.pdf', 'pending', now() - interval '4 days'),
    (v_huda, 'national_id', 'demo/huda/national_id.pdf', 'approved', now() - interval '300 days'),
    (v_huda, 'freelancer_id', 'demo/huda/freelancer.pdf', 'approved', now() - interval '300 days');

  INSERT INTO public.addresses (customer_id, label, street, city, is_default, created_at) VALUES
    (v_sarah, 'Home', 'Al Olaya District, Building 3', 'Riyadh', true, now() - interval '400 days'),
    (v_reem_c, 'Home', 'Al Malaz, Street 18', 'Riyadh', true, now() - interval '200 days'),
    (v_noor, 'Home', 'Al Rawdah, Villa 14', 'Jeddah', true, now() - interval '90 days'),
    (v_dana_f, 'Home', 'Al Faisaliyah, Block 7', 'Dammam', true, now() - interval '60 days');

  INSERT INTO public.favorites (customer_id, item_id, created_at) VALUES
    (v_noor, 'f4d00001-0001-4001-8001-000000000001', now() - interval '2 days'),
    (v_noor, 'f4d00001-0001-4001-8001-000000000004', now() - interval '2 days'),
    (v_noor, 'f4d00001-0001-4001-8001-000000000002', now() - interval '1 day'),
    (v_sarah, 'f4d00001-0001-4001-8001-000000000001', now() - interval '30 days'),
    (v_laila_omar, 'f4d00001-0001-4001-8001-000000000005', now() - interval '5 days');

  -- Story orders (line totals = total_amount; commission 10%)
  -- Unified cancel: terminal rows use status=cancelled + cancel_reason (legacy customer cancel → system_cancelled_frozen).
  INSERT INTO public.orders (
    id, customer_id, chef_id, status, total_amount, commission_amount,
    delivery_address, customer_name, chef_name, notes, idempotency_key,
    cancel_reason, created_at, updated_at
  ) VALUES
    ('f4f00001-0001-4001-8001-000000000001', v_sarah, v_nora, 'completed', 45.00, 4.50, 'Riyadh — pickup', 'Sarah Al-Qahtani', 'Nora''s Kitchen', '[naham-demo] Order 1 — Sarah + Nora — completed', gen_random_uuid(), NULL, now() - interval '14 days', now() - interval '13 days'),
    ('f4f00001-0001-4001-8001-000000000002', v_reem_c, v_laila, 'preparing', 51.00, 5.10, 'Riyadh — pickup', 'Reem Al-Harbi', 'Home Taste by Laila', '[naham-demo] Order 2 — Reem + Laila — preparing', gen_random_uuid(), NULL, now() - interval '35 minutes', now() - interval '30 minutes'),
    ('f4f00001-0001-4001-8001-000000000003', v_sarah, v_dana, 'pending', 34.00, 3.40, 'Riyadh — pickup', 'Sarah Al-Qahtani', 'Dana''s Homemade Kitchen', '[naham-demo] Order 3 — Sarah + Dana — pending', gen_random_uuid(), NULL, now() - interval '25 minutes', now() - interval '24 minutes'),
    ('f4f00001-0001-4001-8001-000000000004', v_noor, v_nora, 'cancelled', 25.00, 2.50, 'Jeddah — pickup', 'Noor Salem', 'Nora''s Kitchen', '[naham-demo] Order 4 — Noor + Nora — legacy convenience cancel (mapped to system)', gen_random_uuid(), 'system_cancelled_frozen', now() - interval '5 days', now() - interval '5 days'),
    ('f4f00001-0001-4001-8001-000000000005', v_laila_omar, v_nora, 'accepted', 34.00, 3.40, 'Riyadh — pickup', 'Laila Omar', 'Nora''s Kitchen', '[naham-demo] Order 5 — Laila Omar + Nora — accepted', gen_random_uuid(), NULL, now() - interval '2 hours', now() - interval '90 minutes');

  INSERT INTO public.order_items (order_id, menu_item_id, dish_name, quantity, unit_price) VALUES
    ('f4f00001-0001-4001-8001-000000000001', 'f4d00001-0001-4001-8001-000000000001', 'Chicken Kabsa', 1, 25.00),
    ('f4f00001-0001-4001-8001-000000000001', 'f4d00001-0001-4001-8001-000000000002', 'Jareesh', 1, 20.00),
    ('f4f00001-0001-4001-8001-000000000002', 'f4d00001-0001-4001-8001-000000000006', 'Saleeg', 1, 23.00),
    ('f4f00001-0001-4001-8001-000000000002', 'f4d00001-0001-4001-8001-000000000007', 'Chicken Mandi', 1, 28.00),
    ('f4f00001-0001-4001-8001-000000000003', 'f4d00001-0001-4001-8001-000000000010', 'Chicken Kabsa', 1, 24.00),
    ('f4f00001-0001-4001-8001-000000000003', 'f4d00001-0001-4001-8001-000000000011', 'Sambosa', 1, 10.00),
    ('f4f00001-0001-4001-8001-000000000004', 'f4d00001-0001-4001-8001-000000000001', 'Chicken Kabsa', 1, 25.00),
    ('f4f00001-0001-4001-8001-000000000005', 'f4d00001-0001-4001-8001-000000000003', 'Qursan', 1, 22.00),
    ('f4f00001-0001-4001-8001-000000000005', 'f4d00001-0001-4001-8001-000000000004', 'Sambosa', 1, 12.00);

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_sarah, v_nora, 'customer-chef', now() - interval '3 days', 'Thank you, I will place the order.', now() - interval '3 days' + interval '12 minutes')
  RETURNING id INTO conv_sarah_nora;

  INSERT INTO public.messages (conversation_id, sender_id, content, is_read, created_at) VALUES
    (conv_sarah_nora, v_sarah, 'Hi, is Chicken Kabsa available today?', true, now() - interval '3 days'),
    (conv_sarah_nora, v_nora, 'Yes, it is available.', true, now() - interval '3 days' + interval '2 minutes'),
    (conv_sarah_nora, v_sarah, 'Can you prepare it by 6 PM?', true, now() - interval '3 days' + interval '5 minutes'),
    (conv_sarah_nora, v_nora, 'Yes, I can.', true, now() - interval '3 days' + interval '8 minutes'),
    (conv_sarah_nora, v_sarah, 'Thank you, I will place the order.', true, now() - interval '3 days' + interval '12 minutes');

  INSERT INTO public.reels (id, chef_id, video_url, thumbnail_url, caption, dish_id, created_at, likes_count) VALUES
    ('f4e00001-0001-4001-8001-000000000001', v_nora,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
     'Fresh Chicken Kabsa ready today — from Nora''s Kitchen.', 'f4d00001-0001-4001-8001-000000000001', now() - interval '2 days', 0),
    ('f4e00001-0001-4001-8001-000000000002', v_nora,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
     'Homemade Sambosa — limited quantity.', 'f4d00001-0001-4001-8001-000000000004', now() - interval '2 days', 0),
    ('f4e00001-0001-4001-8001-000000000003', v_nora,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg',
     'Preparing Jareesh with a traditional method — warm and filling.', 'f4d00001-0001-4001-8001-000000000002', now() - interval '1 day', 0),
    ('f4e00001-0001-4001-8001-000000000004', v_nora,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg',
     'Fresh daily cooking from Nora''s Kitchen.', NULL, now() - interval '12 hours', 0);

  INSERT INTO public.reel_likes (reel_id, customer_id, created_at) VALUES
    ('f4e00001-0001-4001-8001-000000000001', v_sarah, now() - interval '1 day'),
    ('f4e00001-0001-4001-8001-000000000001', v_noor, now() - interval '1 day'),
    ('f4e00001-0001-4001-8001-000000000002', v_reem_c, now() - interval '20 hours');

  UPDATE public.reels SET likes_count = s.c FROM (
    SELECT 'f4e00001-0001-4001-8001-000000000001'::uuid AS id, 2 AS c UNION ALL
    SELECT 'f4e00001-0001-4001-8001-000000000002', 1 UNION ALL
    SELECT 'f4e00001-0001-4001-8001-000000000003', 0 UNION ALL
    SELECT 'f4e00001-0001-4001-8001-000000000004', 0
  ) s WHERE public.reels.id = s.id;

  INSERT INTO public.notifications (customer_id, title, body, is_read, type, created_at) VALUES
    (v_sarah, '[demo-review] Nora''s Kitchen', 'Very tasty and clean packaging.', true, 'info', now() - interval '12 days'),
    (v_reem_c, '[demo-review] Home Taste by Laila', 'Food arrived hot and fresh.', true, 'info', now() - interval '8 days'),
    (v_noor, '[demo-review] Nora''s Kitchen', 'Authentic Saudi taste — highly recommended.', false, 'info', now() - interval '3 days'),
    (v_laila_omar, '[demo-review] General', 'Fast pickup and great quality.', true, 'info', now() - interval '6 days');

  IF v_admin IS NOT NULL AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inspection_calls') THEN
    INSERT INTO public.inspection_calls (
      chef_id, admin_id, channel_name, status, result_action, result_note, violation_reason, chef_result_seen,
      created_at, responded_at, finalized_at
    ) VALUES
      (v_huda, v_admin, '[naham-demo] inspection-huda-hygiene', 'completed', 'freeze_14d',
       'Hygiene inspection failed — account frozen pending retraining.', 'failed_hygiene_check', true,
       now() - interval '20 days', now() - interval '19 days', now() - interval '19 days');
  ELSIF v_admin IS NULL THEN
    RAISE NOTICE 'No admin user found (admin@naham.app / naham@naham.com / profiles.role=admin). Skipped inspection_calls row for Huda.';
  END IF;

  RAISE NOTICE 'Saudi demo seed done: Nora/Laila/Dana/Reem/Huda + 5 story orders + chat + 4 reels + likes + demo reviews as notifications.';
END $$;

-- Demo story (Arabic summary for presenters)
-- الطباخة نورا: مطبخ قديم، تقييم عالٍ، طلبات كثيرة في الملف.
-- ليلى: مطبخ نشط في الرياض.
-- دانا: مطبخ جديد، طلبات قليلة.
-- ريم (شيف): قيد المراجعة — جدة.
-- هدى: مجمّد بسبب فحص النظافة — الدمام.
-- سارة: عميلة نشطة؛ ريم عميلة تطلب من أكثر من مطبخ؛ ليلى عمر جديدة؛ نور لديها مفضلات (سلة); دانا فهد نشاط خفيف.
