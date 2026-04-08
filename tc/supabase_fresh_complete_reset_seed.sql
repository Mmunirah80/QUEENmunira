-- ============================================================
-- NAHAM — COMPLETE DATABASE RESET + FRESH DEMO SEED (English)
-- ============================================================
-- Run in Supabase SQL Editor as postgres / service role (bypasses RLS).
--
-- ⚠️  WARNING — FULL DATA WIPE
--     Part 1 deletes ALL rows from the listed public tables (not only demo tags).
--     Use ONLY on a dev/staging project or a database you are willing to empty.
--     Backup first (Dashboard → Database → Backups, or pg_dump).
--
-- PREREQUISITES — Create these Auth users BEFORE running (Authentication → Users):
--   Admin (must already exist):
--     naham@naham.com
--   Chefs (5):
--     chef.olivia@naham.seed
--     chef.david@naham.seed
--     chef.nina@naham.seed
--     chef.paul@naham.seed
--     chef.hannah@naham.seed
--   Customers (5):
--     customer.rachel@naham.seed   — active, many orders
--     customer.michael@naham.seed  — orders from multiple chefs
--     customer.newbie@naham.seed   — new user, few orders
--     customer.lisa@naham.seed     — favorites / “saved for later” (cart proxy)
--     customer.tom@naham.seed      — light usage
--
-- OUTPUT DOCUMENTATION (see bottom of file for full lists):
--   1) Deletion order (FK-safe)
--   2) Insertion order
--   3) Relationship narrative
--   4) Schema assumptions
-- ============================================================

-- ─── Optional columns (idempotent; matches Flutter + migrations) ─────────
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
  ADD COLUMN IF NOT EXISTS rating_avg double precision,
  ADD COLUMN IF NOT EXISTS total_orders integer;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS city text;

ALTER TABLE public.menu_items
  ADD COLUMN IF NOT EXISTS moderation_status text;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS idempotency_key uuid;

ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1 — DELETE ALL APP DATA (FK-safe order; children before parents)
-- ═══════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2 — SEED (requires Auth users + profiles rows from signup trigger)
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_admin uuid;
  v_olivia uuid;
  v_david uuid;
  v_nina uuid;
  v_paul uuid;
  v_hannah uuid;
  v_rachel uuid;
  v_michael uuid;
  v_newbie uuid;
  v_lisa uuid;
  v_tom uuid;
  missing text;
  conv_rachel_olivia uuid;
  conv_michael_david uuid;
  conv_rachel_sup uuid;
  conv_newbie_nina uuid;
  conv_lisa_nina uuid;
  conv_michael_olivia uuid;
  conv_tom_david uuid;
BEGIN
  SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('naham@naham.com') LIMIT 1;
  SELECT id INTO v_olivia FROM auth.users WHERE lower(email) = lower('chef.olivia@naham.seed') LIMIT 1;
  SELECT id INTO v_david FROM auth.users WHERE lower(email) = lower('chef.david@naham.seed') LIMIT 1;
  SELECT id INTO v_nina FROM auth.users WHERE lower(email) = lower('chef.nina@naham.seed') LIMIT 1;
  SELECT id INTO v_paul FROM auth.users WHERE lower(email) = lower('chef.paul@naham.seed') LIMIT 1;
  SELECT id INTO v_hannah FROM auth.users WHERE lower(email) = lower('chef.hannah@naham.seed') LIMIT 1;
  SELECT id INTO v_rachel FROM auth.users WHERE lower(email) = lower('customer.rachel@naham.seed') LIMIT 1;
  SELECT id INTO v_michael FROM auth.users WHERE lower(email) = lower('customer.michael@naham.seed') LIMIT 1;
  SELECT id INTO v_newbie FROM auth.users WHERE lower(email) = lower('customer.newbie@naham.seed') LIMIT 1;
  SELECT id INTO v_lisa FROM auth.users WHERE lower(email) = lower('customer.lisa@naham.seed') LIMIT 1;
  SELECT id INTO v_tom FROM auth.users WHERE lower(email) = lower('customer.tom@naham.seed') LIMIT 1;

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin not found: create auth user naham@naham.com first.';
  END IF;

  SELECT string_agg(x.e, ', ' ORDER BY x.e) INTO missing
  FROM (
    SELECT unnest(ARRAY[
      'chef.olivia@naham.seed','chef.david@naham.seed','chef.nina@naham.seed',
      'chef.paul@naham.seed','chef.hannah@naham.seed',
      'customer.rachel@naham.seed','customer.michael@naham.seed','customer.newbie@naham.seed',
      'customer.lisa@naham.seed','customer.tom@naham.seed'
    ]) AS e
  ) x
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(x.e));

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'Create these Auth users first (then re-run): %', missing;
  END IF;

  UPDATE public.profiles SET role = 'admin' WHERE id = v_admin;

  UPDATE public.profiles SET role = 'chef', full_name = 'Olivia Hayes', phone = '+966501100001', city = 'Riyadh' WHERE id = v_olivia;
  UPDATE public.profiles SET role = 'chef', full_name = 'David Okonkwo', phone = '+966501100002', city = 'Riyadh' WHERE id = v_david;
  UPDATE public.profiles SET role = 'chef', full_name = 'Nina Petrova', phone = '+966501100003', city = 'Riyadh' WHERE id = v_nina;
  UPDATE public.profiles SET role = 'chef', full_name = 'Paul Nguyen', phone = '+966501100004', city = 'Riyadh' WHERE id = v_paul;
  UPDATE public.profiles SET role = 'chef', full_name = 'Hannah Weiss', phone = '+966501100005', city = 'Riyadh' WHERE id = v_hannah;

  UPDATE public.profiles SET role = 'customer', full_name = 'Rachel Adams', phone = '+966502200001', city = 'Riyadh' WHERE id = v_rachel;
  UPDATE public.profiles SET role = 'customer', full_name = 'Michael Brown', phone = '+966502200002', city = 'Riyadh' WHERE id = v_michael;
  UPDATE public.profiles SET role = 'customer', full_name = 'Chris Reed', phone = '+966502200003', city = 'Riyadh' WHERE id = v_newbie;
  UPDATE public.profiles SET role = 'customer', full_name = 'Lisa Park', phone = '+966502200004', city = 'Riyadh' WHERE id = v_lisa;
  UPDATE public.profiles SET role = 'customer', full_name = 'Tom Silva', phone = '+966502200005', city = 'Riyadh' WHERE id = v_tom;

  INSERT INTO public.chef_profiles (
    id, kitchen_name, is_online, vacation_mode,
    working_hours_start, working_hours_end,
    bank_iban, bank_account_name, bio, kitchen_city,
    approval_status, suspended, initial_approval_at,
    kitchen_latitude, kitchen_longitude,
    freeze_until, freeze_type, freeze_level, warning_count,
    rating_avg, total_orders
  ) VALUES
    (v_olivia, 'Olivia''s Home Kitchen', true, false, '09:00', '22:00',
     'SA0380000000000808010169001', 'Olivia Hayes',
     'Neighborhood kitchen since 2022 — family trays and weekday lunch boxes.',
     'Riyadh', 'approved', false, now() - interval '420 days',
     24.7200, 46.6850, NULL, NULL, 0, 0, 4.88, 210),
    (v_david, 'David''s Grill House', true, false, '10:00', '23:00',
     'SA0380000000000808010169002', 'David Okonkwo',
     'Grill-focused menu near business district — office catering welcome.',
     'Riyadh', 'approved', false, now() - interval '140 days',
     24.7480, 46.7020, NULL, NULL, 0, 0, 4.65, 78),
    (v_nina, 'Nina''s Corner Kitchen', true, false, '11:00', '21:00',
     'SA0380000000000808010169003', 'Nina Petrova',
     'Opened last month — burgers and sides with short pickup windows.',
     'Riyadh', 'approved', false, now() - interval '18 days',
     24.7310, 46.6980, NULL, NULL, 0, 0, 4.52, 19),
    (v_paul, 'River Oak Kitchen', false, false, '09:00', '20:00',
     'SA0380000000000808010169004', 'Paul Nguyen',
     'New applicant — menu visible for admin review until documents are approved.',
     'Riyadh', 'pending', false, NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, NULL),
    (v_hannah, 'Weiss Catering Co.', false, false, '10:00', '22:00',
     'SA0380000000000808010169005', 'Hannah Weiss',
     'Established caterer — account frozen during a compliance review.',
     'Riyadh', 'approved', true, now() - interval '220 days',
     24.7600, 46.7100, now() + interval '7 days', 'soft', 2, 2, 4.05, 48)
  ON CONFLICT (id) DO UPDATE SET
    kitchen_name = EXCLUDED.kitchen_name,
    is_online = EXCLUDED.is_online,
    bio = EXCLUDED.bio,
    kitchen_city = EXCLUDED.kitchen_city,
    approval_status = EXCLUDED.approval_status,
    suspended = EXCLUDED.suspended,
    initial_approval_at = EXCLUDED.initial_approval_at,
    kitchen_latitude = EXCLUDED.kitchen_latitude,
    kitchen_longitude = EXCLUDED.kitchen_longitude,
    freeze_until = EXCLUDED.freeze_until,
    freeze_type = EXCLUDED.freeze_type,
    freeze_level = EXCLUDED.freeze_level,
    warning_count = EXCLUDED.warning_count,
    rating_avg = EXCLUDED.rating_avg,
    total_orders = EXCLUDED.total_orders;

  INSERT INTO public.menu_items (id, chef_id, name, description, price, image_url, category, daily_quantity, remaining_quantity, is_available, moderation_status, created_at) VALUES
    ('f2d00001-0001-4001-8001-000000000001', v_olivia, 'Herb Roast Chicken', 'Half chicken, roasted vegetables, jus.', 44.00, NULL, 'Mains', 30, 22, true, 'approved', now() - interval '400 days'),
    ('f2d00001-0001-4001-8001-000000000002', v_olivia, 'Wild Rice Pilaf', 'Side portion, feeds two.', 14.00, NULL, 'Sides', 40, 30, true, 'approved', now() - interval '380 days'),
    ('f2d00001-0001-4001-8001-000000000003', v_olivia, 'Seasonal Soup', 'Chef''s soup of the day, 350ml.', 12.00, NULL, 'Soups', 35, 20, true, 'approved', now() - interval '360 days'),
    ('f2d00001-0001-4001-8001-000000000004', v_olivia, 'House Salad', 'Greens, vinaigrette, croutons.', 13.00, NULL, 'Salads', 28, 18, true, 'approved', now() - interval '340 days'),
    ('f2d00001-0001-4001-8001-000000000005', v_olivia, 'Chocolate Tart', 'Single slice.', 16.00, NULL, 'Desserts', 25, 15, true, 'approved', now() - interval '320 days'),
    ('f2d00001-0001-4001-8001-000000000006', v_olivia, 'Fresh Lemonade', '500ml.', 8.00, NULL, 'Drinks', 50, 40, true, 'approved', now() - interval '300 days'),
    ('f2d00001-0001-4001-8001-000000000007', v_olivia, 'Family Feast Tray', 'Chicken, rice, two sides — serves 4.', 118.00, NULL, 'Trays', 12, 8, true, 'approved', now() - interval '280 days'),
    ('f2d00001-0001-4001-8001-000000000008', v_olivia, 'Breakfast Box', 'Eggs, bread, jam, juice.', 22.00, NULL, 'Breakfast', 20, 12, true, 'approved', now() - interval '260 days'),
    ('f2d00001-0001-4001-8001-000000000009', v_david, 'Smoked Beef Skewers', 'Four skewers, pickles, dip.', 36.00, NULL, 'Grill', 28, 18, true, 'approved', now() - interval '130 days'),
    ('f2d00001-0001-4001-8001-000000000010', v_david, 'Grilled Sea Bass', 'Herb butter, lemon, greens.', 54.00, NULL, 'Grill', 18, 10, true, 'approved', now() - interval '120 days'),
    ('f2d00001-0001-4001-8001-000000000011', v_david, 'Mezze Plate', 'Hummus, moutabal, olives, bread.', 24.00, NULL, 'Starters', 30, 22, true, 'approved', now() - interval '110 days'),
    ('f2d00001-0001-4001-8001-000000000012', v_david, 'Fattoush Bowl', 'Chopped salad, sumac.', 17.00, NULL, 'Salads', 26, 16, true, 'approved', now() - interval '100 days'),
    ('f2d00001-0001-4001-8001-000000000013', v_david, 'Spiced Rice', 'Large side.', 9.00, NULL, 'Sides', 40, 30, true, 'approved', now() - interval '95 days'),
    ('f2d00001-0001-4001-8001-000000000014', v_david, 'Mint Iced Tea', '500ml.', 7.00, NULL, 'Drinks', 45, 35, true, 'approved', now() - interval '90 days'),
    ('f2d00001-0001-4001-8001-000000000015', v_david, 'Chef''s Mixed Grill', 'Assorted meats, two sides.', 72.00, NULL, 'Mains', 15, 9, true, 'approved', now() - interval '85 days'),
    ('f2d00001-0001-4001-8001-000000000016', v_david, 'Kunafa Slice', 'Single portion.', 14.00, NULL, 'Desserts', 22, 14, true, 'approved', now() - interval '80 days'),
    ('f2d00001-0001-4001-8001-000000000017', v_nina, 'Classic Beef Burger', 'Beef patty, cheddar, brioche.', 23.00, NULL, 'Burgers', 35, 24, true, 'approved', now() - interval '16 days'),
    ('f2d00001-0001-4001-8001-000000000018', v_nina, 'Crispy Chicken Sandwich', 'Slaw, pickles, brioche.', 20.00, NULL, 'Sandwiches', 32, 20, true, 'approved', now() - interval '15 days'),
    ('f2d00001-0001-4001-8001-000000000019', v_nina, 'Seasoned Fries', 'Large.', 10.00, NULL, 'Sides', 40, 30, true, 'approved', now() - interval '14 days'),
    ('f2d00001-0001-4001-8001-000000000020', v_nina, 'Cola', '330ml can.', 4.00, NULL, 'Drinks', 60, 50, true, 'approved', now() - interval '14 days'),
    ('f2d00001-0001-4001-8001-000000000021', v_paul, 'Tasting Tray (Preview)', 'Admin review sample.', 48.00, NULL, 'Trays', 10, 10, true, 'pending', now() - interval '4 days'),
    ('f2d00001-0001-4001-8001-000000000022', v_paul, 'Weekend Box (Preview)', 'Seasonal preview for reviewers.', 32.00, NULL, 'Boxes', 12, 12, true, 'pending', now() - interval '3 days'),
    ('f2d00001-0001-4001-8001-000000000023', v_paul, 'Chef Story Card', 'Printed menu card.', 5.00, NULL, 'Add-ons', 40, 40, true, 'pending', now() - interval '3 days'),
    ('f2d00001-0001-4001-8001-000000000024', v_paul, 'Sample Soup Cup', 'Small taster.', 8.00, NULL, 'Soups', 20, 20, true, 'pending', now() - interval '2 days'),
    ('f2d00001-0001-4001-8001-000000000025', v_hannah, 'Legacy Catering Tray', 'Archived listing.', 55.00, NULL, 'Trays', 5, 0, false, 'approved', now() - interval '90 days'),
    ('f2d00001-0001-4001-8001-000000000026', v_hannah, 'Cold Storage Pack', 'Frozen inventory sample.', 40.00, NULL, 'Add-ons', 5, 0, false, 'approved', now() - interval '85 days'),
    ('f2d00001-0001-4001-8001-000000000027', v_hannah, 'Compliance Hold SKU', 'Placeholder.', 0.00, NULL, 'Other', 1, 0, false, 'approved', now() - interval '80 days'),
    ('f2d00001-0001-4001-8001-000000000028', v_hannah, 'Seasonal Bundle', 'Off-menu hold.', 38.00, NULL, 'Boxes', 5, 0, false, 'approved', now() - interval '75 days')
  ON CONFLICT (id) DO UPDATE SET
    chef_id = EXCLUDED.chef_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    daily_quantity = EXCLUDED.daily_quantity,
    remaining_quantity = EXCLUDED.remaining_quantity,
    is_available = EXCLUDED.is_available,
    moderation_status = EXCLUDED.moderation_status;

  INSERT INTO public.chef_documents (chef_id, document_type, file_url, status, created_at) VALUES
    (v_olivia, 'national_id', 'seed/olivia/national_id.pdf', 'approved', now() - interval '420 days'),
    (v_olivia, 'freelancer_id', 'seed/olivia/freelancer.pdf', 'approved', now() - interval '420 days'),
    (v_david, 'national_id', 'seed/david/national_id.pdf', 'approved', now() - interval '140 days'),
    (v_david, 'freelancer_id', 'seed/david/freelancer.pdf', 'approved', now() - interval '140 days'),
    (v_nina, 'national_id', 'seed/nina/national_id.pdf', 'approved', now() - interval '18 days'),
    (v_nina, 'freelancer_id', 'seed/nina/freelancer.pdf', 'approved', now() - interval '18 days'),
    (v_paul, 'national_id', 'seed/paul/national_id.pdf', 'pending', now() - interval '3 days'),
    (v_paul, 'freelancer_id', 'seed/paul/freelancer.pdf', 'pending', now() - interval '3 days'),
    (v_hannah, 'national_id', 'seed/hannah/national_id.pdf', 'approved', now() - interval '220 days'),
    (v_hannah, 'freelancer_id', 'seed/hannah/freelancer.pdf', 'approved', now() - interval '220 days');

  INSERT INTO public.addresses (customer_id, label, street, city, is_default, created_at) VALUES
    (v_rachel, 'Home', 'Al Olaya District, Building 7', 'Riyadh', true, now() - interval '400 days'),
    (v_rachel, 'Office', 'King Fahd Road, Tower C', 'Riyadh', false, now() - interval '250 days'),
    (v_michael, 'Home', 'Al Malaz, Street 22', 'Riyadh', true, now() - interval '200 days'),
    (v_newbie, 'Home', 'Al Yasmin, Block 4', 'Riyadh', true, now() - interval '25 days'),
    (v_lisa, 'Home', 'Al Nakheel, Villa 9', 'Riyadh', true, now() - interval '40 days'),
    (v_lisa, 'Gym', 'Northern Ring Road, Mall pickup point', 'Riyadh', false, now() - interval '10 days'),
    (v_tom, 'Home', 'Al Sulaimaniyah, Apartment 12B', 'Riyadh', true, now() - interval '120 days');

  INSERT INTO public.favorites (customer_id, item_id, created_at) VALUES
    (v_lisa, 'f2d00001-0001-4001-8001-000000000001', now() - interval '8 days'),
    (v_lisa, 'f2d00001-0001-4001-8001-000000000009', now() - interval '7 days'),
    (v_lisa, 'f2d00001-0001-4001-8001-000000000017', now() - interval '6 days'),
    (v_lisa, 'f2d00001-0001-4001-8001-000000000010', now() - interval '5 days'),
    (v_lisa, 'f2d00001-0001-4001-8001-000000000011', now() - interval '4 days'),
    (v_rachel, 'f2d00001-0001-4001-8001-000000000007', now() - interval '30 days'),
    (v_michael, 'f2d00001-0001-4001-8001-000000000015', now() - interval '20 days');

  INSERT INTO public.orders (id, customer_id, chef_id, status, total_amount, commission_amount, delivery_address, customer_name, chef_name, notes, idempotency_key, created_at, updated_at) VALUES
    ('f2f00001-0001-4001-8001-000000000001', v_rachel, v_olivia, 'completed', 118.00, 11.80, 'Riyadh — pickup', 'Rachel Adams', 'Olivia''s Home Kitchen', '[naham-seed] Family dinner — feast tray', gen_random_uuid(), now() - interval '110 days', now() - interval '109 days'),
    ('f2f00001-0001-4001-8001-000000000002', v_rachel, v_olivia, 'completed', 61.00, 6.10, 'Riyadh — pickup', 'Rachel Adams', 'Olivia''s Home Kitchen', '[naham-seed] Breakfast box, soup, rice, salad', gen_random_uuid(), now() - interval '85 days', now() - interval '84 days'),
    ('f2f00001-0001-4001-8001-000000000003', v_rachel, v_olivia, 'completed', 81.00, 8.10, 'Riyadh — pickup', 'Rachel Adams', 'Olivia''s Home Kitchen', '[naham-seed] Salad, lemonade, tart, roast chicken', gen_random_uuid(), now() - interval '60 days', now() - interval '59 days'),
    ('f2f00001-0001-4001-8001-000000000004', v_michael, v_olivia, 'completed', 58.00, 5.80, 'Riyadh — pickup', 'Michael Brown', 'Olivia''s Home Kitchen', '[naham-seed] After-work pickup — roast chicken and pilaf', gen_random_uuid(), now() - interval '55 days', now() - interval '54 days'),
    ('f2f00001-0001-4001-8001-000000000005', v_michael, v_david, 'completed', 119.00, 11.90, 'Riyadh — pickup', 'Michael Brown', 'David''s Grill House', '[naham-seed] Office team order — mixed grill and sides', gen_random_uuid(), now() - interval '48 days', now() - interval '47 days'),
    ('f2f00001-0001-4001-8001-000000000006', v_michael, v_david, 'completed', 71.00, 7.10, 'Riyadh — pickup', 'Michael Brown', 'David''s Grill House', '[naham-seed] Sea bass, rice, fattoush', gen_random_uuid(), now() - interval '35 days', now() - interval '34 days'),
    ('f2f00001-0001-4001-8001-000000000007', v_michael, v_nina, 'completed', 47.00, 4.70, 'Riyadh — pickup', 'Michael Brown', 'Nina''s Corner Kitchen', '[naham-seed] Burger, sandwich, cola — first Nina order', gen_random_uuid(), now() - interval '12 days', now() - interval '11 days'),
    ('f2f00001-0001-4001-8001-000000000008', v_newbie, v_nina, 'completed', 34.00, 3.40, 'Riyadh — pickup', 'Chris Reed', 'Nina''s Corner Kitchen', '[naham-seed] New user — chicken sandwich and fries', gen_random_uuid(), now() - interval '8 days', now() - interval '7 days'),
    ('f2f00001-0001-4001-8001-000000000009', v_tom, v_david, 'completed', 31.00, 3.10, 'Riyadh — pickup', 'Tom Silva', 'David''s Grill House', '[naham-seed] Light user — mezze plate and iced tea', gen_random_uuid(), now() - interval '20 days', now() - interval '19 days'),
    ('f2f00001-0001-4001-8001-000000000010', v_rachel, v_nina, 'pending', 27.00, 2.70, 'Riyadh — pickup', 'Rachel Adams', 'Nina''s Corner Kitchen', '[naham-seed] Waiting for kitchen — burger and cola', gen_random_uuid(), now() - interval '40 minutes', now() - interval '38 minutes'),
    ('f2f00001-0001-4001-8001-000000000011', v_lisa, v_david, 'paid_waiting_acceptance', 81.00, 8.10, 'Riyadh — pickup', 'Lisa Park', 'David''s Grill House', '[naham-seed] Paid — awaiting cook confirmation', gen_random_uuid(), now() - interval '25 minutes', now() - interval '24 minutes'),
    ('f2f00001-0001-4001-8001-000000000012', v_lisa, v_olivia, 'accepted', 47.00, 4.70, 'Riyadh — pickup', 'Lisa Park', 'Olivia''s Home Kitchen', '[naham-seed] Accepted — soup, salad, lemonade, rice', gen_random_uuid(), now() - interval '3 hours', now() - interval '2 hours'),
    ('f2f00001-0001-4001-8001-000000000013', v_michael, v_david, 'preparing', 72.00, 7.20, 'Riyadh — pickup', 'Michael Brown', 'David''s Grill House', '[naham-seed] Mixed grill in preparation', gen_random_uuid(), now() - interval '50 minutes', now() - interval '45 minutes'),
    ('f2f00001-0001-4001-8001-000000000014', v_rachel, v_olivia, 'preparing', 60.00, 6.00, 'Riyadh — pickup', 'Rachel Adams', 'Olivia''s Home Kitchen', '[naham-seed] Breakfast boxes for office', gen_random_uuid(), now() - interval '40 minutes', now() - interval '35 minutes'),
    ('f2f00001-0001-4001-8001-000000000015', v_michael, v_nina, 'ready', 33.00, 3.30, 'Riyadh — pickup', 'Michael Brown', 'Nina''s Corner Kitchen', '[naham-seed] Ready — burger and fries', gen_random_uuid(), now() - interval '22 minutes', now() - interval '18 minutes'),
    ('f2f00001-0001-4001-8001-000000000016', v_newbie, v_olivia, 'ready', 30.00, 3.00, 'Riyadh — pickup', 'Chris Reed', 'Olivia''s Home Kitchen', '[naham-seed] Ready — breakfast box and lemonade', gen_random_uuid(), now() - interval '18 minutes', now() - interval '14 minutes'),
    ('f2f00001-0001-4001-8001-000000000017', v_lisa, v_david, 'cancelled_by_customer', 24.00, 2.40, 'Riyadh — pickup', 'Lisa Park', 'David''s Grill House', '[naham-seed] Customer cancelled — meeting moved', gen_random_uuid(), now() - interval '9 days', now() - interval '8 days'),
    ('f2f00001-0001-4001-8001-000000000018', v_tom, v_olivia, 'cancelled_by_cook', 58.00, 5.80, 'Riyadh — pickup', 'Tom Silva', 'Olivia''s Home Kitchen', '[naham-seed] Declined by kitchen — short on ingredients (UI: rejected)', gen_random_uuid(), now() - interval '14 days', now() - interval '13 days'),
    ('f2f00001-0001-4001-8001-000000000019', v_rachel, v_nina, 'expired', 33.00, 3.30, 'Riyadh — pickup', 'Rachel Adams', 'Nina''s Corner Kitchen', '[naham-seed] No response within window — expired', gen_random_uuid(), now() - interval '9 days', now() - interval '9 days' + interval '6 minutes'),
    ('f2f00001-0001-4001-8001-000000000020', v_michael, v_olivia, 'completed', 118.00, 11.80, 'Riyadh — pickup', 'Michael Brown', 'Olivia''s Home Kitchen', '[naham-seed] Weekend tray order', gen_random_uuid(), now() - interval '22 days', now() - interval '21 days');

  INSERT INTO public.order_items (order_id, menu_item_id, dish_name, quantity, unit_price) VALUES
    ('f2f00001-0001-4001-8001-000000000001', 'f2d00001-0001-4001-8001-000000000007', 'Family Feast Tray', 1, 118.00),
    ('f2f00001-0001-4001-8001-000000000002', 'f2d00001-0001-4001-8001-000000000008', 'Breakfast Box', 1, 22.00),
    ('f2f00001-0001-4001-8001-000000000002', 'f2d00001-0001-4001-8001-000000000003', 'Seasonal Soup', 1, 12.00),
    ('f2f00001-0001-4001-8001-000000000002', 'f2d00001-0001-4001-8001-000000000002', 'Wild Rice Pilaf', 1, 14.00),
    ('f2f00001-0001-4001-8001-000000000002', 'f2d00001-0001-4001-8001-000000000004', 'House Salad', 1, 13.00),
    ('f2f00001-0001-4001-8001-000000000003', 'f2d00001-0001-4001-8001-000000000004', 'House Salad', 1, 13.00),
    ('f2f00001-0001-4001-8001-000000000003', 'f2d00001-0001-4001-8001-000000000006', 'Fresh Lemonade', 1, 8.00),
    ('f2f00001-0001-4001-8001-000000000003', 'f2d00001-0001-4001-8001-000000000005', 'Chocolate Tart', 1, 16.00),
    ('f2f00001-0001-4001-8001-000000000003', 'f2d00001-0001-4001-8001-000000000001', 'Herb Roast Chicken', 1, 44.00),
    ('f2f00001-0001-4001-8001-000000000004', 'f2d00001-0001-4001-8001-000000000001', 'Herb Roast Chicken', 1, 44.00),
    ('f2f00001-0001-4001-8001-000000000004', 'f2d00001-0001-4001-8001-000000000002', 'Wild Rice Pilaf', 1, 14.00),
    ('f2f00001-0001-4001-8001-000000000005', 'f2d00001-0001-4001-8001-000000000015', 'Chef''s Mixed Grill', 1, 72.00),
    ('f2f00001-0001-4001-8001-000000000005', 'f2d00001-0001-4001-8001-000000000011', 'Mezze Plate', 1, 24.00),
    ('f2f00001-0001-4001-8001-000000000005', 'f2d00001-0001-4001-8001-000000000013', 'Spiced Rice', 1, 9.00),
    ('f2f00001-0001-4001-8001-000000000005', 'f2d00001-0001-4001-8001-000000000016', 'Kunafa Slice', 1, 14.00),
    ('f2f00001-0001-4001-8001-000000000006', 'f2d00001-0001-4001-8001-000000000010', 'Grilled Sea Bass', 1, 54.00),
    ('f2f00001-0001-4001-8001-000000000006', 'f2d00001-0001-4001-8001-000000000012', 'Fattoush Bowl', 1, 17.00),
    ('f2f00001-0001-4001-8001-000000000007', 'f2d00001-0001-4001-8001-000000000017', 'Classic Beef Burger', 1, 23.00),
    ('f2f00001-0001-4001-8001-000000000007', 'f2d00001-0001-4001-8001-000000000018', 'Crispy Chicken Sandwich', 1, 20.00),
    ('f2f00001-0001-4001-8001-000000000007', 'f2d00001-0001-4001-8001-000000000020', 'Cola', 1, 4.00),
    ('f2f00001-0001-4001-8001-000000000008', 'f2d00001-0001-4001-8001-000000000018', 'Crispy Chicken Sandwich', 1, 20.00),
    ('f2f00001-0001-4001-8001-000000000008', 'f2d00001-0001-4001-8001-000000000019', 'Seasoned Fries', 1, 10.00),
    ('f2f00001-0001-4001-8001-000000000008', 'f2d00001-0001-4001-8001-000000000020', 'Cola', 1, 4.00),
    ('f2f00001-0001-4001-8001-000000000009', 'f2d00001-0001-4001-8001-000000000011', 'Mezze Plate', 1, 24.00),
    ('f2f00001-0001-4001-8001-000000000009', 'f2d00001-0001-4001-8001-000000000014', 'Mint Iced Tea', 1, 7.00),
    ('f2f00001-0001-4001-8001-000000000010', 'f2d00001-0001-4001-8001-000000000017', 'Classic Beef Burger', 1, 23.00),
    ('f2f00001-0001-4001-8001-000000000010', 'f2d00001-0001-4001-8001-000000000020', 'Cola', 1, 4.00),
    ('f2f00001-0001-4001-8001-000000000011', 'f2d00001-0001-4001-8001-000000000009', 'Smoked Beef Skewers', 1, 36.00),
    ('f2f00001-0001-4001-8001-000000000011', 'f2d00001-0001-4001-8001-000000000011', 'Mezze Plate', 1, 24.00),
    ('f2f00001-0001-4001-8001-000000000011', 'f2d00001-0001-4001-8001-000000000016', 'Kunafa Slice', 1, 14.00),
    ('f2f00001-0001-4001-8001-000000000011', 'f2d00001-0001-4001-8001-000000000014', 'Mint Iced Tea', 1, 7.00),
    ('f2f00001-0001-4001-8001-000000000012', 'f2d00001-0001-4001-8001-000000000003', 'Seasonal Soup', 1, 12.00),
    ('f2f00001-0001-4001-8001-000000000012', 'f2d00001-0001-4001-8001-000000000004', 'House Salad', 1, 13.00),
    ('f2f00001-0001-4001-8001-000000000012', 'f2d00001-0001-4001-8001-000000000006', 'Fresh Lemonade', 1, 8.00),
    ('f2f00001-0001-4001-8001-000000000012', 'f2d00001-0001-4001-8001-000000000002', 'Wild Rice Pilaf', 1, 14.00),
    ('f2f00001-0001-4001-8001-000000000013', 'f2d00001-0001-4001-8001-000000000015', 'Chef''s Mixed Grill', 1, 72.00),
    ('f2f00001-0001-4001-8001-000000000014', 'f2d00001-0001-4001-8001-000000000008', 'Breakfast Box', 1, 22.00),
    ('f2f00001-0001-4001-8001-000000000014', 'f2d00001-0001-4001-8001-000000000008', 'Breakfast Box', 1, 22.00),
    ('f2f00001-0001-4001-8001-000000000014', 'f2d00001-0001-4001-8001-000000000006', 'Fresh Lemonade', 1, 8.00),
    ('f2f00001-0001-4001-8001-000000000014', 'f2d00001-0001-4001-8001-000000000006', 'Fresh Lemonade', 1, 8.00),
    ('f2f00001-0001-4001-8001-000000000015', 'f2d00001-0001-4001-8001-000000000017', 'Classic Beef Burger', 1, 23.00),
    ('f2f00001-0001-4001-8001-000000000015', 'f2d00001-0001-4001-8001-000000000019', 'Seasoned Fries', 1, 10.00),
    ('f2f00001-0001-4001-8001-000000000016', 'f2d00001-0001-4001-8001-000000000008', 'Breakfast Box', 1, 22.00),
    ('f2f00001-0001-4001-8001-000000000016', 'f2d00001-0001-4001-8001-000000000006', 'Fresh Lemonade', 1, 8.00),
    ('f2f00001-0001-4001-8001-000000000017', 'f2d00001-0001-4001-8001-000000000011', 'Mezze Plate', 1, 24.00),
    ('f2f00001-0001-4001-8001-000000000018', 'f2d00001-0001-4001-8001-000000000001', 'Herb Roast Chicken', 1, 44.00),
    ('f2f00001-0001-4001-8001-000000000018', 'f2d00001-0001-4001-8001-000000000002', 'Wild Rice Pilaf', 1, 14.00),
    ('f2f00001-0001-4001-8001-000000000019', 'f2d00001-0001-4001-8001-000000000003', 'Seasonal Soup', 1, 12.00),
    ('f2f00001-0001-4001-8001-000000000019', 'f2d00001-0001-4001-8001-000000000004', 'House Salad', 1, 13.00),
    ('f2f00001-0001-4001-8001-000000000019', 'f2d00001-0001-4001-8001-000000000006', 'Fresh Lemonade', 1, 8.00),
    ('f2f00001-0001-4001-8001-000000000020', 'f2d00001-0001-4001-8001-000000000007', 'Family Feast Tray', 1, 118.00);

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_rachel, v_olivia, 'customer-chef', now() - interval '40 days', 'See you at pickup.', now() - interval '1 day')
  RETURNING id INTO conv_rachel_olivia;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_michael, v_david, 'customer-chef', now() - interval '50 days', 'Thanks for the quick prep.', now() - interval '2 days')
  RETURNING id INTO conv_michael_david;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_rachel, NULL, 'customer-support', now() - interval '15 days', 'Let us know if you need anything else.', now() - interval '12 days')
  RETURNING id INTO conv_rachel_sup;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_newbie, v_nina, 'customer-chef', now() - interval '10 days', 'First order was smooth — same pickup door?', now() - interval '8 days')
  RETURNING id INTO conv_newbie_nina;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_lisa, v_nina, 'customer-chef', now() - interval '6 days', 'Will try the burger combo next.', now() - interval '4 days')
  RETURNING id INTO conv_lisa_nina;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_michael, v_olivia, 'customer-chef', now() - interval '25 days', 'Tray order for Saturday — noted.', now() - interval '22 days')
  RETURNING id INTO conv_michael_olivia;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_tom, v_david, 'customer-chef', now() - interval '21 days', 'Light lunch worked well.', now() - interval '19 days')
  RETURNING id INTO conv_tom_david;

  INSERT INTO public.messages (conversation_id, sender_id, content, is_read, created_at) VALUES
    (conv_rachel_olivia, v_rachel, 'Can I request extra napkins with large trays?', true, now() - interval '40 days'),
    (conv_rachel_olivia, v_olivia, 'Yes — I will add them to the bag.', true, now() - interval '40 days' + interval '5 minutes'),
    (conv_rachel_olivia, v_rachel, 'Running ten minutes late today.', true, now() - interval '5 days'),
    (conv_rachel_olivia, v_olivia, 'No problem — I will hold it at the counter.', true, now() - interval '5 days' + interval '3 minutes'),
    (conv_rachel_olivia, v_rachel, 'See you at pickup.', true, now() - interval '1 day'),
    (conv_michael_david, v_michael, 'Is the mixed grill spicy by default?', true, now() - interval '50 days'),
    (conv_michael_david, v_david, 'Mild — we can add chili sauce on the side.', true, now() - interval '50 days' + interval '4 minutes'),
    (conv_michael_david, v_michael, 'Perfect for the office order.', true, now() - interval '2 days'),
    (conv_michael_david, v_david, 'Thanks for the quick prep.', true, now() - interval '2 days' + interval '2 minutes'),
    (conv_rachel_sup, v_rachel, 'Question about the commission line on my receipt.', true, now() - interval '15 days'),
    (conv_rachel_sup, v_admin, 'Happy to explain — which order total should we reference?', true, now() - interval '15 days' + interval '20 minutes'),
    (conv_rachel_sup, v_rachel, 'The large Olivia tray from last quarter.', true, now() - interval '14 days'),
    (conv_rachel_sup, v_admin, 'That line is the platform fee on the subtotal.', true, now() - interval '14 days' + interval '10 minutes'),
    (conv_rachel_sup, v_admin, 'Let us know if you need anything else.', true, now() - interval '12 days'),
    (conv_newbie_nina, v_newbie, 'First time ordering — same pickup as on the map?', true, now() - interval '10 days'),
    (conv_newbie_nina, v_nina, 'Yes — side entrance, ring the bell.', true, now() - interval '10 days' + interval '3 minutes'),
    (conv_newbie_nina, v_newbie, 'First order was smooth — same pickup door?', true, now() - interval '8 days'),
    (conv_lisa_nina, v_lisa, 'Do you offer sesame-free prep on the bowl?', true, now() - interval '6 days'),
    (conv_lisa_nina, v_nina, 'Yes — note it on the order.', true, now() - interval '6 days' + interval '2 minutes'),
    (conv_lisa_nina, v_lisa, 'Will try the burger combo next.', true, now() - interval '4 days'),
    (conv_michael_olivia, v_michael, 'Is the feast tray available Friday evening?', true, now() - interval '25 days'),
    (conv_michael_olivia, v_olivia, 'Yes until 9 PM — order before 7 PM.', true, now() - interval '25 days' + interval '4 minutes'),
    (conv_michael_olivia, v_michael, 'Tray order for Saturday — noted.', true, now() - interval '22 days'),
    (conv_tom_david, v_tom, 'Is the fattoush dairy-free?', true, now() - interval '21 days'),
    (conv_tom_david, v_david, 'No cheese in that build.', true, now() - interval '21 days' + interval '2 minutes'),
    (conv_tom_david, v_tom, 'Light lunch worked well.', true, now() - interval '19 days');

  INSERT INTO public.reels (id, chef_id, video_url, thumbnail_url, caption, dish_id, created_at, likes_count) VALUES
    ('f2e00001-0001-4001-8001-000000000001', v_olivia,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
     'Family trays — same recipe the neighborhood orders every Friday.', 'f2d00001-0001-4001-8001-000000000007', now() - interval '12 days', 0),
    ('f2e00001-0001-4001-8001-000000000002', v_olivia,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
     'Roast chicken prep — weekday lunch boxes.', 'f2d00001-0001-4001-8001-000000000001', now() - interval '9 days', 0),
    ('f2e00001-0001-4001-8001-000000000003', v_david,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg',
     'Office tower runs — skewers go fast.', 'f2d00001-0001-4001-8001-000000000009', now() - interval '8 days', 0),
    ('f2e00001-0001-4001-8001-000000000004', v_david,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMob.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMob.jpg',
     'Sea bass plate — light dinner option.', 'f2d00001-0001-4001-8001-000000000010', now() - interval '5 days', 0),
    ('f2e00001-0001-4001-8001-000000000005', v_nina,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/SubaruOutbackOnStreetAndDirt.jpg',
     'New kitchen — same burger recipe as the pop-up.', 'f2d00001-0001-4001-8001-000000000017', now() - interval '7 days', 0),
    ('f2e00001-0001-4001-8001-000000000006', v_nina,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg',
     'Sandwich line during evening rush.', 'f2d00001-0001-4001-8001-000000000018', now() - interval '4 days', 0),
    ('f2e00001-0001-4001-8001-000000000007', v_hannah,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/VolkswagenGTIReview.jpg',
     'Archived reel — account on compliance hold.', 'f2d00001-0001-4001-8001-000000000025', now() - interval '80 days', 0);

  INSERT INTO public.reel_likes (reel_id, customer_id, created_at) VALUES
    ('f2e00001-0001-4001-8001-000000000001', v_rachel, now() - interval '11 days'),
    ('f2e00001-0001-4001-8001-000000000001', v_michael, now() - interval '11 days'),
    ('f2e00001-0001-4001-8001-000000000001', v_lisa, now() - interval '10 days'),
    ('f2e00001-0001-4001-8001-000000000002', v_rachel, now() - interval '8 days'),
    ('f2e00001-0001-4001-8001-000000000002', v_newbie, now() - interval '8 days'),
    ('f2e00001-0001-4001-8001-000000000003', v_michael, now() - interval '7 days'),
    ('f2e00001-0001-4001-8001-000000000003', v_rachel, now() - interval '7 days'),
    ('f2e00001-0001-4001-8001-000000000003', v_tom, now() - interval '6 days'),
    ('f2e00001-0001-4001-8001-000000000004', v_lisa, now() - interval '4 days'),
    ('f2e00001-0001-4001-8001-000000000004', v_michael, now() - interval '4 days'),
    ('f2e00001-0001-4001-8001-000000000005', v_rachel, now() - interval '6 days'),
    ('f2e00001-0001-4001-8001-000000000005', v_newbie, now() - interval '6 days'),
    ('f2e00001-0001-4001-8001-000000000005', v_lisa, now() - interval '5 days'),
    ('f2e00001-0001-4001-8001-000000000006', v_michael, now() - interval '3 days'),
    ('f2e00001-0001-4001-8001-000000000006', v_tom, now() - interval '3 days'),
    ('f2e00001-0001-4001-8001-000000000007', v_rachel, now() - interval '75 days'),
    ('f2e00001-0001-4001-8001-000000000007', v_michael, now() - interval '75 days');

  UPDATE public.reels SET likes_count = s.c FROM (
    SELECT 'f2e00001-0001-4001-8001-000000000001'::uuid AS id, 3 AS c UNION ALL
    SELECT 'f2e00001-0001-4001-8001-000000000002', 2 UNION ALL
    SELECT 'f2e00001-0001-4001-8001-000000000003', 3 UNION ALL
    SELECT 'f2e00001-0001-4001-8001-000000000004', 2 UNION ALL
    SELECT 'f2e00001-0001-4001-8001-000000000005', 3 UNION ALL
    SELECT 'f2e00001-0001-4001-8001-000000000006', 2 UNION ALL
    SELECT 'f2e00001-0001-4001-8001-000000000007', 2
  ) s WHERE public.reels.id = s.id;

  INSERT INTO public.notifications (customer_id, title, body, is_read, type, created_at) VALUES
    (v_rachel, '[naham-seed] Order completed', 'Your Olivia''s Home Kitchen tray order is complete.', true, 'order', now() - interval '84 days'),
    (v_michael, '[naham-seed] Pickup reminder', 'Add a pickup pin so distance ranking stays accurate.', false, 'info', now() - interval '1 hour'),
    (v_newbie, '[naham-seed] Welcome', 'Welcome to Naham — your Nina order used the side entrance.', false, 'info', now() - interval '8 days'),
    (v_lisa, '[naham-seed] Saved dishes', 'Items in your favorites are still available to order.', false, 'info', now() - interval '3 days'),
    (v_tom, '[naham-seed] Light activity', 'Your last David order was light — explore mixed grill next.', false, 'info', now() - interval '18 days');

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inspection_calls') THEN
    INSERT INTO public.inspection_calls (
      chef_id, admin_id, channel_name, status, result_action, result_note, chef_result_seen,
      created_at, responded_at, finalized_at
    ) VALUES
      (v_olivia, v_admin, '[naham-seed] inspection-olivia-pass', 'completed', 'pass', 'Routine inspection — documentation complete.', true,
       now() - interval '55 days', now() - interval '55 days', now() - interval '55 days'),
      (v_david, v_admin, '[naham-seed] inspection-david-pending', 'pending', NULL, NULL, false, now() - interval '3 hours', NULL, NULL);
  END IF;

  RAISE NOTICE 'Fresh reset seed complete: 28 menu items, 20 orders, 7 conversations, 26 messages, 7 reels, 17 likes.';
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- DOCUMENTATION (same file — copy for runbooks)
-- ═══════════════════════════════════════════════════════════════════════════
--
-- (1) DELETION ORDER (children → parents; avoids FK violations)
--     • reel_reports, support_tickets (if tables exist)
--     • messages → conversations
--     • reel_likes → reels
--     • order_items → order_status_events (if exists) → orders
--     • notifications, favorites, addresses
--     • chef_documents → menu_items → chef_profiles
--     • inspection_calls, support_tickets, admin_logs (if present)
--
-- (2) INSERTION ORDER
--     • profiles: UPDATE only (Auth + trigger must exist first)
--     • chef_profiles
--     • menu_items
--     • chef_documents
--     • addresses, favorites
--     • orders → order_items
--     • conversations → messages
--     • reels → reel_likes → UPDATE reels.likes_count
--     • notifications
--     • inspection_calls (optional table)
--
-- (3) RELATIONSHIP NARRATIVE
--     • Rachel: long-time Olivia customer; also orders Nina; support thread with admin.
--     • Michael: multi-chef (Olivia, David, Nina); office-style large orders.
--     • Chris (newbie): first Nina order; light chat with Nina.
--     • Lisa: favorites across chefs = “saved cart” proxy; paid_waiting + accepted pipelines.
--     • Tom: single completed order + one cook-cancelled order; minimal notifications.
--     • Olivia / David / Nina: approved kitchens with realistic volumes.
--     • Paul: pending approval; menu items moderation_status pending.
--     • Hannah: frozen/suspended; legacy reels + unavailable menu rows.
--
-- (4) SCHEMA ASSUMPTIONS
--     • orders.status uses CHECK from supabase_order_state_machine.sql (includes expired,
--       cancelled_by_*, paid_waiting_acceptance). There is NO separate DB value "rejected":
--       cook decline = cancelled_by_cook (app maps to OrderStatus.rejected).
--     • order_items uses column menu_item_id (Flutter + presentation seeds). If your DB only
--       has dish_id, rename or add menu_item_id to match the app.
--     • Reviews: no dedicated reviews table in stock Naham migrations — aggregate ratings are
--       chef_profiles.rating_avg / total_orders. Per-order star reviews would need a new table.
--     • Shopping cart: client-local in Flutter — favorites + narrative stand in for “cart user”.
--     • Auth: this script does NOT insert auth.users; create users in Dashboard first.
--     • profiles rows must exist for each Auth user (signup trigger / first login).
--     • Commission stored as 10% of total_amount in seeded rows (presentation convention).
--
-- (5) OPTIONAL SCHEMA (NOT APPLIED HERE)
--     If you add public.reviews later, DELETE/INSERT it after orders and before notifications,
--     with FK to orders and profiles as appropriate.
-- ═══════════════════════════════════════════════════════════════════════════
