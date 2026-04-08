-- ============================================================
-- Milestone 2: Test data for Customer Home (menu_items, chef_profiles)
-- ============================================================
-- Run in Supabase SQL Editor (postgres role — bypasses RLS).
--
-- Prerequisites:
--   1) Core schema + admin migrations applied (chef_profiles.approval_status, menu_items.moderation_status, etc.).
--   2) Create TWO Auth users (Authentication → Users). Set their emails exactly:
--        milestone2-najdi@naham.test
--        milestone2-northern@naham.test
--      Confirm email can be off. Password: any.
--   3) Set public.profiles.role = 'chef' for both (or use your signup flow so role is chef).
--
-- This script resolves chef IDs from auth.users by email — no hardcoded chef UUIDs.
-- Idempotent: safe to re-run (upserts chef_profiles; upserts menu_items by fixed dish UUIDs).
-- ============================================================

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS kitchen_latitude double precision,
  ADD COLUMN IF NOT EXISTS kitchen_longitude double precision,
  ADD COLUMN IF NOT EXISTS initial_approval_at timestamptz,
  ADD COLUMN IF NOT EXISTS freeze_until timestamptz;

ALTER TABLE public.menu_items
  ADD COLUMN IF NOT EXISTS moderation_status text;

DO $$
DECLARE
  v_najdi uuid;
  v_north uuid;
  missing text;
  -- Fixed dish ids for idempotent menu upserts
  d1 uuid := 'a1111111-1111-4111-8111-111111111101';
  d2 uuid := 'a1111111-1111-4111-8111-111111111102';
  d3 uuid := 'a2222222-2222-4222-8222-222222222201';
  d4 uuid := 'a2222222-2222-4222-8222-222222222202';
  d5 uuid := 'a1111111-1111-4111-8111-111111111103';
  d6 uuid := 'a2222222-2222-4222-8222-222222222203';
BEGIN
  SELECT id INTO v_najdi FROM auth.users WHERE lower(email) = lower('milestone2-najdi@naham.test') LIMIT 1;
  SELECT id INTO v_north FROM auth.users WHERE lower(email) = lower('milestone2-northern@naham.test') LIMIT 1;

  IF v_najdi IS NULL OR v_north IS NULL THEN
    SELECT string_agg(x.e, ', ' ORDER BY x.e) INTO missing
    FROM (
      SELECT unnest(ARRAY[
        'milestone2-najdi@naham.test',
        'milestone2-northern@naham.test'
      ]) AS e
    ) x
    WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(x.e));
    RAISE EXCEPTION 'Create these Auth users first (Authentication → Users): %', COALESCE(missing, 'unknown');
  END IF;

  UPDATE public.profiles SET role = 'chef' WHERE id IN (v_najdi, v_north);

  INSERT INTO public.chef_profiles (
    id,
    kitchen_name,
    is_online,
    vacation_mode,
    working_hours_start,
    working_hours_end,
    bank_iban,
    bank_account_name,
    bio,
    kitchen_city,
    approval_status,
    suspended,
    initial_approval_at,
    kitchen_latitude,
    kitchen_longitude,
    freeze_until
  ) VALUES
    (
      v_najdi,
      'Najdi Kitchen',
      true,
      false,
      '09:00',
      '22:00',
      'SA0000000000000000000000',
      'Najdi Kitchen Account',
      'Traditional Najdi home cooking with love.',
      'Riyadh',
      'approved',
      false,
      now() - interval '30 days',
      24.7136,
      46.6753,
      NULL
    ),
    (
      v_north,
      'Northern Bites',
      true,
      false,
      '10:00',
      '21:00',
      'SA0000000000000000000001',
      'Northern Bites Account',
      'Fresh Northern region flavors and grills.',
      'Tabuk',
      'approved',
      false,
      now() - interval '30 days',
      28.3838,
      36.5662,
      NULL
    )
  ON CONFLICT (id) DO UPDATE SET
    kitchen_name = EXCLUDED.kitchen_name,
    is_online = EXCLUDED.is_online,
    vacation_mode = EXCLUDED.vacation_mode,
    working_hours_start = EXCLUDED.working_hours_start,
    working_hours_end = EXCLUDED.working_hours_end,
    bio = EXCLUDED.bio,
    kitchen_city = EXCLUDED.kitchen_city,
    approval_status = EXCLUDED.approval_status,
    suspended = EXCLUDED.suspended,
    initial_approval_at = COALESCE(public.chef_profiles.initial_approval_at, EXCLUDED.initial_approval_at),
    kitchen_latitude = COALESCE(EXCLUDED.kitchen_latitude, public.chef_profiles.kitchen_latitude),
    kitchen_longitude = COALESCE(EXCLUDED.kitchen_longitude, public.chef_profiles.kitchen_longitude),
    freeze_until = EXCLUDED.freeze_until;

  INSERT INTO public.menu_items (
    id,
    chef_id,
    name,
    description,
    price,
    image_url,
    category,
    daily_quantity,
    remaining_quantity,
    is_available,
    moderation_status,
    created_at
  ) VALUES
    (d1, v_najdi, 'Jareesh', 'Cracked wheat slow-cooked with meat and spices.', 25.00, NULL, 'Najdi', 20, 15, true, 'approved', now()),
    (d2, v_najdi, 'Kabsa', 'Traditional spiced rice with chicken and vegetables.', 35.00, NULL, 'Najdi', 15, 10, true, 'approved', now()),
    (d3, v_north, 'Grilled Lamb', 'Tender lamb with Northern spice blend.', 45.00, NULL, 'Northern', 10, 8, true, 'approved', now()),
    (d4, v_north, 'Manty', 'Steamed dumplings with minced meat and yogurt.', 28.00, NULL, 'Northern', 12, 12, true, 'approved', now()),
    (d5, v_najdi, 'Kleija', 'Date-filled pastry, Najdi style.', 15.00, NULL, 'Sweets', 25, 20, true, 'approved', now()),
    (d6, v_north, 'Baklava', 'Layered pastry with nuts and honey.', 22.00, NULL, 'Sweets', 14, 14, true, 'approved', now())
  ON CONFLICT (id) DO UPDATE SET
    chef_id = EXCLUDED.chef_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    category = EXCLUDED.category,
    daily_quantity = EXCLUDED.daily_quantity,
    remaining_quantity = EXCLUDED.remaining_quantity,
    is_available = EXCLUDED.is_available,
    moderation_status = EXCLUDED.moderation_status;

  RAISE NOTICE 'Milestone 2 seed OK. Najdi chef_id=%, Northern chef_id=%', v_najdi, v_north;
END;
$$;
