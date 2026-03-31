-- ============================================================
-- Milestone 2: Test data for Customer Home (menu_items, chef_profiles).
-- Run in Supabase SQL Editor. Ensure tables exist with correct schema.
-- ============================================================

-- 2 chef profiles (is_online=true, vacation_mode=false)
INSERT INTO chef_profiles (
  id,
  kitchen_name,
  is_online,
  vacation_mode,
  working_hours_start,
  working_hours_end,
  bank_iban,
  bank_account_name,
  bio,
  kitchen_city
) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    'Najdi Kitchen',
    true,
    false,
    '09:00',
    '22:00',
    'SA0000000000000000000000',
    'Najdi Kitchen Account',
    'Traditional Najdi home cooking with love.',
    'Riyadh'
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'Northern Bites',
    true,
    false,
    '10:00',
    '21:00',
    'SA0000000000000000000001',
    'Northern Bites Account',
    'Fresh Northern region flavors and grills.',
    'Tabuk'
  )
ON CONFLICT (id) DO UPDATE SET
  kitchen_name = EXCLUDED.kitchen_name,
  is_online = EXCLUDED.is_online,
  vacation_mode = EXCLUDED.vacation_mode,
  working_hours_start = EXCLUDED.working_hours_start,
  working_hours_end = EXCLUDED.working_hours_end,
  bio = EXCLUDED.bio,
  kitchen_city = EXCLUDED.kitchen_city;

-- 6 dishes: 2 Najdi, 2 Northern, 2 Sweets (remaining_quantity > 0, is_available=true)
-- chef_id references chef_profiles.id
INSERT INTO menu_items (
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
  created_at
) VALUES
  -- Najdi (chef 1)
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'Jareesh', 'Cracked wheat slow-cooked with meat and spices.', 25.00, null, 'Najdi', 20, 15, true, now()),
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'Kabsa', 'Traditional spiced rice with chicken and vegetables.', 35.00, null, 'Najdi', 15, 10, true, now()),
  -- Northern (chef 2)
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'Grilled Lamb', 'Tender lamb with Northern spice blend.', 45.00, null, 'Northern', 10, 8, true, now()),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'Manty', 'Steamed dumplings with minced meat and yogurt.', 28.00, null, 'Northern', 12, 12, true, now()),
  -- Sweets (chef 1 and 2)
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'Kleija', 'Date-filled pastry, Najdi style.', 15.00, null, 'Sweets', 25, 20, true, now()),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', 'Baklava', 'Layered pastry with nuts and honey.', 22.00, null, 'Sweets', 14, 14, true, now())
ON CONFLICT (id) DO NOTHING;
