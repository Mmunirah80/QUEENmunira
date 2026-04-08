-- ============================================================
-- NAHAM — Presentation-ready mock dataset (English UI copy only)
-- ============================================================
-- Balanced demo volumes (approx.): 30 menu items, 24 orders, 55 order
-- items, 8 conversations, 55 messages, 9 reels, 28 reel likes.
--
-- NARRATIVE (same data, reads like one real community — not random noise):
-- • Elena — First customer arc: Sarah for family meals since early days; she told colleague
--   Alex about both Sarah and Marcus, which explains Alex ordering both kitchens. Elena
--   tried James Bites after seeing a reel. One Sarah order cancelled (meeting ran over).
--   Support chat is about the platform fee on her largest Sarah order (this seed’s o01).
-- • Alex — Works near Elena; started with Sarah lunches, then Marcus after Elena’s tip;
--   salmon order led to the five‑star chat. One mandi order cancelled by cook (short on rice).
-- • Sam — New user: first James pickup ~9 days ago; chat matches “first order” story; two
--   active orders today for the demo pipeline.
-- • Riley — New to the area (address 30d ago); favorites mirror dishes Elena and neighbors
--   rave about; sesame allergy in chat matches the quinoa bowl swap with Marcus.
-- • Maya — Mostly Sarah salads + Marcus bowls; messages about “two salads tomorrow” tie to
--   her standing lunch order with Sarah.
-- • Chefs — Sarah = long‑running home kitchen; Marcus = opened after office pop‑ups; James =
--   brick‑and‑mortar from weekend market; pending + frozen = admin edge cases.
-- Message rows are inserted oldest→newest per thread so sorting by time matches a real inbox.
--
-- Run in Supabase SQL Editor as postgres / service role (bypasses RLS).
--
-- BEFORE YOU RUN — BACKUP (pick one):
--   • Dashboard → Database → Backups (scheduled / PITR), OR
--   • pg_dump your project, OR
--   • Export critical tables to CSV from Table Editor.
--
-- This script:
--   1) Deletes ONLY rows tagged with [naham-present] (orders, notifications, inspection_calls)
--      and all app data tied to the listed @naham.present Auth users (chefs + customers).
--   2) Re-seeds realistic English data for professor demo.
--
-- PREREQUISITES — Create these Auth users first (Authentication → Users):
--   Admin (must exist):     naham@naham.com
--   Chefs:
--     chef.sarah@naham.present, chef.marcus@naham.present, chef.james@naham.present,
--     chef.pending@naham.present, chef.frozen@naham.present
--   Customers:
--     customer.elena@naham.present, customer.alex@naham.present, customer.sam@naham.present,
--     customer.riley@naham.present, customer.maya@naham.present
--
-- SCHEMA: Matches OrderDbStatus + orders_status_allowed_values (supabase_order_state_machine.sql).
-- CART: Flutter keeps cart in memory — log in as Riley and add dishes manually for “cart” demo.
-- ============================================================

-- ─── Optional columns (safe re-run) ─────────────────────────────
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

-- ─── Remove previous presentation seed (FK-safe order) ─────────
DO $$
DECLARE
  v_ids uuid[];
BEGIN
  SELECT array_agg(u.id) INTO v_ids
  FROM auth.users u
  WHERE lower(u.email) IN (
    lower('chef.sarah@naham.present'),
    lower('chef.marcus@naham.present'),
    lower('chef.james@naham.present'),
    lower('chef.pending@naham.present'),
    lower('chef.frozen@naham.present'),
    lower('customer.elena@naham.present'),
    lower('customer.alex@naham.present'),
    lower('customer.sam@naham.present'),
    lower('customer.riley@naham.present'),
    lower('customer.maya@naham.present')
  );

  IF v_ids IS NULL THEN
    RAISE NOTICE 'No @naham.present users found — skip delete block (first run).';
    RETURN;
  END IF;

  DELETE FROM public.messages
  WHERE conversation_id IN (
    SELECT c.id FROM public.conversations c
    WHERE c.customer_id = ANY (v_ids) OR c.chef_id = ANY (v_ids)
  );

  DELETE FROM public.conversations
  WHERE customer_id = ANY (v_ids) OR chef_id = ANY (v_ids);

  DELETE FROM public.reel_likes
  WHERE customer_id = ANY (v_ids)
     OR reel_id IN (SELECT r.id FROM public.reels r WHERE r.chef_id = ANY (v_ids));

  DELETE FROM public.reels WHERE chef_id = ANY (v_ids);

  DELETE FROM public.order_items
  WHERE order_id IN (SELECT o.id FROM public.orders o WHERE o.notes LIKE '[naham-present%');

  DELETE FROM public.order_status_events
  WHERE order_id IN (SELECT o.id FROM public.orders o WHERE o.notes LIKE '[naham-present%');

  DELETE FROM public.orders WHERE notes LIKE '[naham-present%';

  DELETE FROM public.notifications
  WHERE title LIKE '[naham-present%';

  DELETE FROM public.inspection_calls
  WHERE channel_name LIKE '[naham-present%';

  DELETE FROM public.favorites WHERE customer_id = ANY (v_ids);
  DELETE FROM public.addresses WHERE customer_id = ANY (v_ids);
  DELETE FROM public.chef_documents WHERE chef_id = ANY (v_ids);
  DELETE FROM public.menu_items WHERE chef_id = ANY (v_ids);
  DELETE FROM public.chef_profiles WHERE id = ANY (v_ids);
END $$;

-- ─── Main seed ───────────────────────────────────────────────────
DO $$
DECLARE
  v_admin uuid;
  v_sarah uuid;
  v_marcus uuid;
  v_james uuid;
  v_pending uuid;
  v_frozen uuid;
  v_elena uuid;
  v_alex uuid;
  v_sam uuid;
  v_riley uuid;
  v_maya uuid;
  missing text;
  conv_elena_sarah uuid;
  conv_alex_marcus uuid;
  conv_elena_sup uuid;
  conv_sam_james uuid;
  conv_riley_marcus uuid;
  conv_maya_sarah uuid;
  conv_alex_sarah uuid;
  conv_riley_james uuid;
BEGIN
  SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('naham@naham.com') LIMIT 1;
  SELECT id INTO v_sarah FROM auth.users WHERE lower(email) = lower('chef.sarah@naham.present') LIMIT 1;
  SELECT id INTO v_marcus FROM auth.users WHERE lower(email) = lower('chef.marcus@naham.present') LIMIT 1;
  SELECT id INTO v_james FROM auth.users WHERE lower(email) = lower('chef.james@naham.present') LIMIT 1;
  SELECT id INTO v_pending FROM auth.users WHERE lower(email) = lower('chef.pending@naham.present') LIMIT 1;
  SELECT id INTO v_frozen FROM auth.users WHERE lower(email) = lower('chef.frozen@naham.present') LIMIT 1;
  SELECT id INTO v_elena FROM auth.users WHERE lower(email) = lower('customer.elena@naham.present') LIMIT 1;
  SELECT id INTO v_alex FROM auth.users WHERE lower(email) = lower('customer.alex@naham.present') LIMIT 1;
  SELECT id INTO v_sam FROM auth.users WHERE lower(email) = lower('customer.sam@naham.present') LIMIT 1;
  SELECT id INTO v_riley FROM auth.users WHERE lower(email) = lower('customer.riley@naham.present') LIMIT 1;
  SELECT id INTO v_maya FROM auth.users WHERE lower(email) = lower('customer.maya@naham.present') LIMIT 1;

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin not found: create auth user naham@naham.com first.';
  END IF;

  UPDATE public.profiles SET role = 'admin' WHERE id = v_admin;

  SELECT string_agg(x.e, ', ' ORDER BY x.e) INTO missing
  FROM (
    SELECT unnest(ARRAY[
      'chef.sarah@naham.present','chef.marcus@naham.present','chef.james@naham.present',
      'chef.pending@naham.present','chef.frozen@naham.present',
      'customer.elena@naham.present','customer.alex@naham.present','customer.sam@naham.present',
      'customer.riley@naham.present','customer.maya@naham.present'
    ]) AS e
  ) x
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(x.e));

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'Create these Auth users first: %', missing;
  END IF;

  UPDATE public.profiles SET role = 'chef', full_name = 'Sarah Mitchell', phone = '+966501000001', city = 'Riyadh' WHERE id = v_sarah;
  UPDATE public.profiles SET role = 'chef', full_name = 'Marcus Chen', phone = '+966501000002', city = 'Riyadh' WHERE id = v_marcus;
  UPDATE public.profiles SET role = 'chef', full_name = 'James Porter', phone = '+966501000003', city = 'Riyadh' WHERE id = v_james;
  UPDATE public.profiles SET role = 'chef', full_name = 'Alex Rivera', phone = '+966501000004', city = 'Riyadh' WHERE id = v_pending;
  UPDATE public.profiles SET role = 'chef', full_name = 'Jordan Lee', phone = '+966501000005', city = 'Riyadh' WHERE id = v_frozen;
  UPDATE public.profiles SET role = 'customer', full_name = 'Elena Wright', phone = '+966502000001', city = 'Riyadh' WHERE id = v_elena;
  UPDATE public.profiles SET role = 'customer', full_name = 'Alex Thompson', phone = '+966502000002', city = 'Riyadh' WHERE id = v_alex;
  UPDATE public.profiles SET role = 'customer', full_name = 'Sam Brooks', phone = '+966502000003', city = 'Riyadh' WHERE id = v_sam;
  UPDATE public.profiles SET role = 'customer', full_name = 'Riley Morgan', phone = '+966502000004', city = 'Riyadh' WHERE id = v_riley;
  UPDATE public.profiles SET role = 'customer', full_name = 'Maya Singh', phone = '+966502000005', city = 'Riyadh' WHERE id = v_maya;

  INSERT INTO public.chef_profiles (
    id, kitchen_name, is_online, vacation_mode,
    working_hours_start, working_hours_end,
    bank_iban, bank_account_name, bio, kitchen_city,
    approval_status, suspended, initial_approval_at,
    kitchen_latitude, kitchen_longitude,
    freeze_until, freeze_type, freeze_level, warning_count,
    rating_avg, total_orders
  ) VALUES
    (v_sarah, 'Sarah''s Home Kitchen', true, false, '09:00', '22:00',
     'SA0380000000000808010169001', 'Sarah Mitchell',
     'Home kitchen since 2023 — same-day pickup if you order before 6 PM. Many regulars started as neighbor referrals.',
     'Riyadh', 'approved', false, now() - interval '400 days',
     24.7200, 46.6850, NULL, NULL, 0, 0, 4.85, 186),
    (v_marcus, 'Grill & Greens', true, false, '10:00', '23:00',
     'SA0380000000000808010169002', 'Marcus Chen',
     'Started as office-building pop-ups; now a fixed grill counter. Regulars bring colleagues from nearby towers.',
     'Riyadh', 'approved', false, now() - interval '120 days',
     24.7480, 46.7020, NULL, NULL, 0, 0, 4.62, 72),
    (v_james, 'James Bites', true, false, '11:00', '21:00',
     'SA0380000000000808010169003', 'James Porter',
     'Weekend market stall turned small shop — same recipes, shorter queue for pickup.',
     'Riyadh', 'approved', false, now() - interval '12 days',
     24.7310, 46.6980, NULL, NULL, 0, 0, 4.55, 28),
    (v_pending, 'River Oak Kitchen', false, false, '09:00', '20:00',
     'SA0380000000000808010169004', 'Alex Rivera',
     'New applicant — dishes visible for admin review only until documents are approved.',
     'Riyadh', 'pending', false, NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, NULL),
    (v_frozen, 'Northside Catering', false, false, '10:00', '22:00',
     'SA0380000000000808010169005', 'Jordan Lee',
     'Long-time caterer — account frozen during a compliance review; old reels remain for audit.',
     'Riyadh', 'approved', true, now() - interval '200 days',
     24.7600, 46.7100, now() + interval '5 days', 'soft', 2, 3, 4.1, 42)
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

  -- 30 menu_items (ids b1000001-…-001 … 030)
  INSERT INTO public.menu_items (id, chef_id, name, description, price, image_url, category, daily_quantity, remaining_quantity, is_available, moderation_status, created_at) VALUES
    ('b1000001-0001-4001-8001-000000000001', v_sarah, 'Slow-Cooked Lamb Kabsa', 'Fragrant rice, spiced lamb, roasted nuts.', 42.00, NULL, 'Mains', 40, 28, true, 'approved', now() - interval '300 days'),
    ('b1000001-0001-4001-8001-000000000002', v_sarah, 'Date and Walnut Cake', 'Single-portion dessert.', 16.00, NULL, 'Desserts', 35, 22, true, 'approved', now() - interval '300 days'),
    ('b1000001-0001-4001-8001-000000000003', v_sarah, 'Saj Bread Snack Box', 'Cheese and zaatar saj — 4 pieces.', 19.00, NULL, 'Snacks', 50, 40, true, 'approved', now() - interval '200 days'),
    ('b1000001-0001-4001-8001-000000000004', v_sarah, 'Garden Fattoush', 'Chopped salad, sumac dressing.', 14.00, NULL, 'Salads', 30, 18, true, 'approved', now() - interval '100 days'),
    ('b1000001-0001-4001-8001-000000000005', v_sarah, 'Chicken Mandi Plate', 'Fragrant rice, tender chicken, house yogurt.', 48.00, NULL, 'Mains', 25, 15, true, 'approved', now() - interval '250 days'),
    ('b1000001-0001-4001-8001-000000000006', v_sarah, 'Lentil Soup', 'Warm soup with lemon — 350ml.', 12.00, NULL, 'Soups', 40, 30, true, 'approved', now() - interval '180 days'),
    ('b1000001-0001-4001-8001-000000000007', v_sarah, 'Kunafa Bites', 'Two pieces, light syrup.', 18.00, NULL, 'Desserts', 30, 20, true, 'approved', now() - interval '120 days'),
    ('b1000001-0001-4001-8001-000000000008', v_sarah, 'Fresh Orange Juice', 'Cold-pressed, 300ml.', 8.00, NULL, 'Drinks', 60, 45, true, 'approved', now() - interval '90 days'),
    ('b1000001-0001-4001-8001-000000000009', v_marcus, 'Charred Chicken Skewers', 'Marinated chicken, garlic dip, pickles.', 38.00, NULL, 'Grill', 25, 15, true, 'approved', now() - interval '90 days'),
    ('b1000001-0001-4001-8001-000000000010', v_marcus, 'Quinoa Power Bowl', 'Quinoa, roasted vegetables, tahini.', 29.00, NULL, 'Bowls', 20, 12, true, 'approved', now() - interval '90 days'),
    ('b1000001-0001-4001-8001-000000000011', v_marcus, 'Grilled Salmon Fillet', 'Herb butter, seasonal greens.', 52.00, NULL, 'Grill', 18, 10, true, 'approved', now() - interval '85 days'),
    ('b1000001-0001-4001-8001-000000000012', v_marcus, 'Halloumi Wrap', 'Grilled halloumi, greens, tahini wrap.', 22.00, NULL, 'Wraps', 22, 14, true, 'approved', now() - interval '80 days'),
    ('b1000001-0001-4001-8001-000000000013', v_marcus, 'Greek Salad', 'Feta, olives, cucumber, oregano.', 18.00, NULL, 'Salads', 25, 16, true, 'approved', now() - interval '75 days'),
    ('b1000001-0001-4001-8001-000000000014', v_marcus, 'Garlic Aioli Trio', 'Three dips — garlic, chili, herb.', 9.00, NULL, 'Sides', 40, 28, true, 'approved', now() - interval '70 days'),
    ('b1000001-0001-4001-8001-000000000015', v_marcus, 'Lemon Mint Cooler', 'Iced, 400ml.', 7.00, NULL, 'Drinks', 50, 35, true, 'approved', now() - interval '65 days'),
    ('b1000001-0001-4001-8001-000000000016', v_james, 'Classic Beef Burger', 'Beef patty, cheddar, house sauce.', 24.00, NULL, 'Burgers', 30, 20, true, 'approved', now() - interval '10 days'),
    ('b1000001-0001-4001-8001-000000000017', v_james, 'Crispy Chicken Sandwich', 'Buttermilk chicken, slaw, brioche.', 20.00, NULL, 'Sandwiches', 28, 18, true, 'approved', now() - interval '10 days'),
    ('b1000001-0001-4001-8001-000000000018', v_james, 'Sweet Potato Fries', 'Sea salt, smoked paprika.', 11.00, NULL, 'Sides', 35, 25, true, 'approved', now() - interval '9 days'),
    ('b1000001-0001-4001-8001-000000000019', v_james, 'Vanilla Shake', '12oz.', 14.00, NULL, 'Drinks', 25, 18, true, 'approved', now() - interval '9 days'),
    ('b1000001-0001-4001-8001-000000000020', v_james, 'Garden Side Salad', 'Mixed greens, vinaigrette.', 10.00, NULL, 'Salads', 20, 14, true, 'approved', now() - interval '8 days'),
    ('b1000001-0001-4001-8001-000000000021', v_james, 'Spicy Buffalo Wings', 'Six pieces, blue cheese dip.', 18.00, NULL, 'Sides', 22, 12, true, 'approved', now() - interval '8 days'),
    ('b1000001-0001-4001-8001-000000000022', v_pending, 'Sample Family Tray', 'Placeholder dish for admin review.', 55.00, NULL, 'Trays', 10, 10, true, 'pending', now() - interval '3 days'),
    ('b1000001-0001-4001-8001-000000000023', v_pending, 'Tasting Platter', 'Chef selection — pending moderation.', 45.00, NULL, 'Trays', 8, 8, true, 'pending', now() - interval '3 days'),
    ('b1000001-0001-4001-8001-000000000024', v_pending, 'Weekend Preview Box', 'Seasonal preview for reviewers.', 30.00, NULL, 'Boxes', 12, 12, true, 'pending', now() - interval '2 days'),
    ('b1000001-0001-4001-8001-000000000025', v_pending, 'Chef Notes Card', 'Printed menu story card.', 5.00, NULL, 'Add-ons', 50, 50, true, 'pending', now() - interval '2 days'),
    ('b1000001-0001-4001-8001-000000000026', v_frozen, 'Frozen Demo Platter', 'Not available — demo only.', 40.00, NULL, 'Trays', 5, 0, false, 'approved', now() - interval '60 days'),
    ('b1000001-0001-4001-8001-000000000027', v_frozen, 'Legacy Tray Set', 'Archived listing.', 35.00, NULL, 'Trays', 5, 0, false, 'approved', now() - interval '55 days'),
    ('b1000001-0001-4001-8001-000000000028', v_frozen, 'Seasonal Bundle', 'Off-menu hold.', 42.00, NULL, 'Boxes', 5, 0, false, 'approved', now() - interval '50 days'),
    ('b1000001-0001-4001-8001-000000000029', v_frozen, 'Cold Storage Pack', 'Frozen inventory sample.', 33.00, NULL, 'Add-ons', 5, 0, false, 'approved', now() - interval '45 days'),
    ('b1000001-0001-4001-8001-000000000030', v_frozen, 'Compliance Hold Item', 'Placeholder SKU.', 0.00, NULL, 'Other', 1, 0, false, 'approved', now() - interval '40 days')
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
    (v_sarah, 'national_id', 'present/sarah/national_id.pdf', 'approved', now() - interval '400 days'),
    (v_sarah, 'freelancer_id', 'present/sarah/freelancer.pdf', 'approved', now() - interval '400 days'),
    (v_marcus, 'national_id', 'present/marcus/national_id.pdf', 'approved', now() - interval '120 days'),
    (v_marcus, 'freelancer_id', 'present/marcus/freelancer.pdf', 'approved', now() - interval '120 days'),
    (v_james, 'national_id', 'present/james/national_id.pdf', 'approved', now() - interval '12 days'),
    (v_james, 'freelancer_id', 'present/james/freelancer.pdf', 'approved', now() - interval '12 days'),
    (v_pending, 'national_id', 'present/pending/national_id.pdf', 'pending', now() - interval '2 days'),
    (v_pending, 'freelancer_id', 'present/pending/freelancer.pdf', 'pending', now() - interval '2 days'),
    (v_frozen, 'national_id', 'present/frozen/national_id.pdf', 'approved', now() - interval '200 days'),
    (v_frozen, 'freelancer_id', 'present/frozen/freelancer.pdf', 'approved', now() - interval '200 days');

  INSERT INTO public.addresses (customer_id, label, street, city, is_default, created_at) VALUES
    (v_elena, 'Home', 'Al Olaya District, Building 12', 'Riyadh', true, now() - interval '300 days'),
    (v_elena, 'Office', 'King Fahd Road, Tower B', 'Riyadh', false, now() - interval '200 days'),
    (v_alex, 'Home', 'Al Malaz, Street 45', 'Riyadh', true, now() - interval '90 days'),
    (v_riley, 'Home', 'Al Nakheel, Villa 3', 'Riyadh', true, now() - interval '30 days');

  INSERT INTO public.favorites (customer_id, item_id, created_at) VALUES
    (v_riley, 'b1000001-0001-4001-8001-000000000001', now() - interval '5 days'),
    (v_riley, 'b1000001-0001-4001-8001-000000000009', now() - interval '4 days'),
    (v_riley, 'b1000001-0001-4001-8001-000000000016', now() - interval '3 days'),
    (v_maya, 'b1000001-0001-4001-8001-000000000007', now() - interval '6 days'),
    (v_elena, 'b1000001-0001-4001-8001-000000000011', now() - interval '20 days');

  -- 24 orders — totals match line sums; commission 10% of total
  INSERT INTO public.orders (id, customer_id, chef_id, status, total_amount, commission_amount, delivery_address, customer_name, chef_name, notes, idempotency_key, created_at, updated_at) VALUES
    ('c1000001-0001-4001-8001-000000000001', v_elena, v_sarah, 'completed', 106.00, 10.60, 'Riyadh — pickup', 'Elena Wright', 'Sarah''s Home Kitchen', '[naham-present] Family dinner — kabsa, mandi, cake (same order as support thread)', gen_random_uuid(), now() - interval '120 days', now() - interval '119 days'),
    ('c1000001-0001-4001-8001-000000000002', v_elena, v_sarah, 'completed', 61.00, 6.10, 'Riyadh — pickup', 'Elena Wright', 'Sarah''s Home Kitchen', '[naham-present] Smaller Sarah order — weekday lunch from office', gen_random_uuid(), now() - interval '95 days', now() - interval '94 days'),
    ('c1000001-0001-4001-8001-000000000003', v_elena, v_marcus, 'completed', 119.00, 11.90, 'Riyadh — pickup', 'Elena Wright', 'Grill & Greens', '[naham-present] Catered team lunch — four desks at King Fahd tower', gen_random_uuid(), now() - interval '88 days', now() - interval '87 days'),
    ('c1000001-0001-4001-8001-000000000004', v_elena, v_marcus, 'completed', 27.00, 2.70, 'Riyadh — pickup', 'Elena Wright', 'Grill & Greens', '[naham-present] Light dinner after gym — salad + dip', gen_random_uuid(), now() - interval '70 days', now() - interval '69 days'),
    ('c1000001-0001-4001-8001-000000000005', v_alex, v_sarah, 'completed', 26.00, 2.60, 'Riyadh — pickup', 'Alex Thompson', 'Sarah''s Home Kitchen', '[naham-present] First Sarah order after Elena’s recommendation — soup + salad', gen_random_uuid(), now() - interval '60 days', now() - interval '59 days'),
    ('c1000001-0001-4001-8001-000000000006', v_alex, v_marcus, 'completed', 67.00, 6.70, 'Riyadh — pickup', 'Alex Thompson', 'Grill & Greens', '[naham-present] Same combo Elena likes — skewers + wrap + cooler', gen_random_uuid(), now() - interval '52 days', now() - interval '51 days'),
    ('c1000001-0001-4001-8001-000000000007', v_maya, v_sarah, 'completed', 26.00, 2.60, 'Riyadh — pickup', 'Maya Singh', 'Sarah''s Home Kitchen', '[naham-present] WFH lunch — kunafa + OJ break', gen_random_uuid(), now() - interval '40 days', now() - interval '39 days'),
    ('c1000001-0001-4001-8001-000000000008', v_riley, v_marcus, 'completed', 81.00, 8.10, 'Riyadh — pickup', 'Riley Morgan', 'Grill & Greens', '[naham-present] New to Al Nakheel — neighbors said try the salmon bowl', gen_random_uuid(), now() - interval '35 days', now() - interval '34 days'),
    ('c1000001-0001-4001-8001-000000000009', v_sam, v_james, 'completed', 55.00, 5.50, 'Riyadh — pickup', 'Sam Brooks', 'James Bites', '[naham-present] First James order — saw stall at weekend market', gen_random_uuid(), now() - interval '28 days', now() - interval '27 days'),
    ('c1000001-0001-4001-8001-000000000010', v_elena, v_sarah, 'cancelled_by_customer', 58.00, 5.80, 'Riyadh — pickup', 'Elena Wright', 'Sarah''s Home Kitchen', '[naham-present] Cancelled — board call ran over, could not pick up', gen_random_uuid(), now() - interval '22 days', now() - interval '21 days'),
    ('c1000001-0001-4001-8001-000000000011', v_alex, v_sarah, 'cancelled_by_cook', 62.00, 6.20, 'Riyadh — pickup', 'Alex Thompson', 'Sarah''s Home Kitchen', '[naham-present] Cancelled by kitchen — short on rice for mandi that evening', gen_random_uuid(), now() - interval '18 days', now() - interval '17 days'),
    ('c1000001-0001-4001-8001-000000000012', v_sam, v_james, 'pending', 34.00, 3.40, 'Riyadh — pickup', 'Sam Brooks', 'James Bites', '[naham-present] Before class — burger + side salad', gen_random_uuid(), now() - interval '45 minutes', now() - interval '40 minutes'),
    ('c1000001-0001-4001-8001-000000000013', v_riley, v_james, 'pending', 32.00, 3.20, 'Riyadh — pickup', 'Riley Morgan', 'James Bites', '[naham-present] Friends coming over — wings + shake', gen_random_uuid(), now() - interval '30 minutes', now() - interval '28 minutes'),
    ('c1000001-0001-4001-8001-000000000014', v_alex, v_sarah, 'accepted', 33.00, 3.30, 'Riyadh — pickup', 'Alex Thompson', 'Sarah''s Home Kitchen', '[naham-present] Saj + fattoush — sharing with roommate', gen_random_uuid(), now() - interval '3 hours', now() - interval '2 hours'),
    ('c1000001-0001-4001-8001-000000000015', v_maya, v_marcus, 'accepted', 47.00, 4.70, 'Riyadh — pickup', 'Maya Singh', 'Grill & Greens', '[naham-present] Usual bowl + Greek salad — chat referenced this kitchen', gen_random_uuid(), now() - interval '2 hours', now() - interval '90 minutes'),
    ('c1000001-0001-4001-8001-000000000016', v_elena, v_marcus, 'preparing', 112.00, 11.20, 'Riyadh — pickup', 'Elena Wright', 'Grill & Greens', '[naham-present] Another office lunch — same building as order #3', gen_random_uuid(), now() - interval '50 minutes', now() - interval '45 minutes'),
    ('c1000001-0001-4001-8001-000000000017', v_alex, v_marcus, 'preparing', 16.00, 1.60, 'Riyadh — pickup', 'Alex Thompson', 'Grill & Greens', '[naham-present] Extra dips + drink — goes with accepted order pipeline', gen_random_uuid(), now() - interval '40 minutes', now() - interval '35 minutes'),
    ('c1000001-0001-4001-8001-000000000018', v_riley, v_sarah, 'preparing', 60.00, 6.00, 'Riyadh — pickup', 'Riley Morgan', 'Sarah''s Home Kitchen', '[naham-present] Parents visiting — kabsa + kunafa like Elena orders', gen_random_uuid(), now() - interval '35 minutes', now() - interval '30 minutes'),
    ('c1000001-0001-4001-8001-000000000019', v_sam, v_james, 'accepted', 44.00, 4.40, 'Riyadh — pickup', 'Sam Brooks', 'James Bites', '[naham-present] Two sandwiches after shift — matches chat “see you soon”', gen_random_uuid(), now() - interval '90 minutes', now() - interval '80 minutes'),
    ('c1000001-0001-4001-8001-000000000020', v_maya, v_sarah, 'ready', 26.00, 2.60, 'Riyadh — pickup', 'Maya Singh', 'Sarah''s Home Kitchen', '[naham-present] Light lunch — fattoush + soup (tomorrow’s salads in chat)', gen_random_uuid(), now() - interval '25 minutes', now() - interval '20 minutes'),
    ('c1000001-0001-4001-8001-000000000021', v_alex, v_sarah, 'ready', 67.00, 6.70, 'Riyadh — pickup', 'Alex Thompson', 'Sarah''s Home Kitchen', '[naham-present] Family table — mandi + saj (chat asked about 8 PM — this pickup)', gen_random_uuid(), now() - interval '20 minutes', now() - interval '15 minutes'),
    ('c1000001-0001-4001-8001-000000000022', v_riley, v_marcus, 'completed', 103.00, 10.30, 'Riyadh — pickup', 'Riley Morgan', 'Grill & Greens', '[naham-present] Photo night — salmon + bowl + wrap (sesame swapped in chat)', gen_random_uuid(), now() - interval '14 days', now() - interval '13 days'),
    ('c1000001-0001-4001-8001-000000000023', v_elena, v_james, 'completed', 25.00, 2.50, 'Riyadh — pickup', 'Elena Wright', 'James Bites', '[naham-present] Tried James after Sarah reel — fries + shake on the way home', gen_random_uuid(), now() - interval '10 days', now() - interval '9 days'),
    ('c1000001-0001-4001-8001-000000000024', v_maya, v_james, 'completed', 42.00, 4.20, 'Riyadh — pickup', 'Maya Singh', 'James Bites', '[naham-present] Movie night — burger + wings', gen_random_uuid(), now() - interval '6 days', now() - interval '5 days');

  -- 55 order_items (menu_item_id 001–021 only)
  INSERT INTO public.order_items (order_id, menu_item_id, dish_name, quantity, unit_price) VALUES
    ('c1000001-0001-4001-8001-000000000001', 'b1000001-0001-4001-8001-000000000001', 'Slow-Cooked Lamb Kabsa', 1, 42.00),
    ('c1000001-0001-4001-8001-000000000001', 'b1000001-0001-4001-8001-000000000002', 'Date and Walnut Cake', 1, 16.00),
    ('c1000001-0001-4001-8001-000000000001', 'b1000001-0001-4001-8001-000000000005', 'Chicken Mandi Plate', 1, 48.00),
    ('c1000001-0001-4001-8001-000000000002', 'b1000001-0001-4001-8001-000000000001', 'Slow-Cooked Lamb Kabsa', 1, 42.00),
    ('c1000001-0001-4001-8001-000000000002', 'b1000001-0001-4001-8001-000000000003', 'Saj Bread Snack Box', 1, 19.00),
    ('c1000001-0001-4001-8001-000000000003', 'b1000001-0001-4001-8001-000000000009', 'Charred Chicken Skewers', 1, 38.00),
    ('c1000001-0001-4001-8001-000000000003', 'b1000001-0001-4001-8001-000000000010', 'Quinoa Power Bowl', 1, 29.00),
    ('c1000001-0001-4001-8001-000000000003', 'b1000001-0001-4001-8001-000000000011', 'Grilled Salmon Fillet', 1, 52.00),
    ('c1000001-0001-4001-8001-000000000004', 'b1000001-0001-4001-8001-000000000013', 'Greek Salad', 1, 18.00),
    ('c1000001-0001-4001-8001-000000000004', 'b1000001-0001-4001-8001-000000000014', 'Garlic Aioli Trio', 1, 9.00),
    ('c1000001-0001-4001-8001-000000000005', 'b1000001-0001-4001-8001-000000000004', 'Garden Fattoush', 1, 14.00),
    ('c1000001-0001-4001-8001-000000000005', 'b1000001-0001-4001-8001-000000000006', 'Lentil Soup', 1, 12.00),
    ('c1000001-0001-4001-8001-000000000006', 'b1000001-0001-4001-8001-000000000009', 'Charred Chicken Skewers', 1, 38.00),
    ('c1000001-0001-4001-8001-000000000006', 'b1000001-0001-4001-8001-000000000012', 'Halloumi Wrap', 1, 22.00),
    ('c1000001-0001-4001-8001-000000000006', 'b1000001-0001-4001-8001-000000000015', 'Lemon Mint Cooler', 1, 7.00),
    ('c1000001-0001-4001-8001-000000000007', 'b1000001-0001-4001-8001-000000000007', 'Kunafa Bites', 1, 18.00),
    ('c1000001-0001-4001-8001-000000000007', 'b1000001-0001-4001-8001-000000000008', 'Fresh Orange Juice', 1, 8.00),
    ('c1000001-0001-4001-8001-000000000008', 'b1000001-0001-4001-8001-000000000010', 'Quinoa Power Bowl', 1, 29.00),
    ('c1000001-0001-4001-8001-000000000008', 'b1000001-0001-4001-8001-000000000011', 'Grilled Salmon Fillet', 1, 52.00),
    ('c1000001-0001-4001-8001-000000000009', 'b1000001-0001-4001-8001-000000000016', 'Classic Beef Burger', 1, 24.00),
    ('c1000001-0001-4001-8001-000000000009', 'b1000001-0001-4001-8001-000000000017', 'Crispy Chicken Sandwich', 1, 20.00),
    ('c1000001-0001-4001-8001-000000000009', 'b1000001-0001-4001-8001-000000000018', 'Sweet Potato Fries', 1, 11.00),
    ('c1000001-0001-4001-8001-000000000010', 'b1000001-0001-4001-8001-000000000001', 'Slow-Cooked Lamb Kabsa', 1, 42.00),
    ('c1000001-0001-4001-8001-000000000010', 'b1000001-0001-4001-8001-000000000002', 'Date and Walnut Cake', 1, 16.00),
    ('c1000001-0001-4001-8001-000000000011', 'b1000001-0001-4001-8001-000000000004', 'Garden Fattoush', 1, 14.00),
    ('c1000001-0001-4001-8001-000000000011', 'b1000001-0001-4001-8001-000000000005', 'Chicken Mandi Plate', 1, 48.00),
    ('c1000001-0001-4001-8001-000000000012', 'b1000001-0001-4001-8001-000000000016', 'Classic Beef Burger', 1, 24.00),
    ('c1000001-0001-4001-8001-000000000012', 'b1000001-0001-4001-8001-000000000020', 'Garden Side Salad', 1, 10.00),
    ('c1000001-0001-4001-8001-000000000013', 'b1000001-0001-4001-8001-000000000021', 'Spicy Buffalo Wings', 1, 18.00),
    ('c1000001-0001-4001-8001-000000000013', 'b1000001-0001-4001-8001-000000000019', 'Vanilla Shake', 1, 14.00),
    ('c1000001-0001-4001-8001-000000000014', 'b1000001-0001-4001-8001-000000000003', 'Saj Bread Snack Box', 1, 19.00),
    ('c1000001-0001-4001-8001-000000000014', 'b1000001-0001-4001-8001-000000000004', 'Garden Fattoush', 1, 14.00),
    ('c1000001-0001-4001-8001-000000000015', 'b1000001-0001-4001-8001-000000000010', 'Quinoa Power Bowl', 1, 29.00),
    ('c1000001-0001-4001-8001-000000000015', 'b1000001-0001-4001-8001-000000000013', 'Greek Salad', 1, 18.00),
    ('c1000001-0001-4001-8001-000000000016', 'b1000001-0001-4001-8001-000000000009', 'Charred Chicken Skewers', 1, 38.00),
    ('c1000001-0001-4001-8001-000000000016', 'b1000001-0001-4001-8001-000000000011', 'Grilled Salmon Fillet', 1, 52.00),
    ('c1000001-0001-4001-8001-000000000016', 'b1000001-0001-4001-8001-000000000012', 'Halloumi Wrap', 1, 22.00),
    ('c1000001-0001-4001-8001-000000000017', 'b1000001-0001-4001-8001-000000000014', 'Garlic Aioli Trio', 1, 9.00),
    ('c1000001-0001-4001-8001-000000000017', 'b1000001-0001-4001-8001-000000000015', 'Lemon Mint Cooler', 1, 7.00),
    ('c1000001-0001-4001-8001-000000000018', 'b1000001-0001-4001-8001-000000000001', 'Slow-Cooked Lamb Kabsa', 1, 42.00),
    ('c1000001-0001-4001-8001-000000000018', 'b1000001-0001-4001-8001-000000000007', 'Kunafa Bites', 1, 18.00),
    ('c1000001-0001-4001-8001-000000000019', 'b1000001-0001-4001-8001-000000000016', 'Classic Beef Burger', 1, 24.00),
    ('c1000001-0001-4001-8001-000000000019', 'b1000001-0001-4001-8001-000000000017', 'Crispy Chicken Sandwich', 1, 20.00),
    ('c1000001-0001-4001-8001-000000000020', 'b1000001-0001-4001-8001-000000000004', 'Garden Fattoush', 1, 14.00),
    ('c1000001-0001-4001-8001-000000000020', 'b1000001-0001-4001-8001-000000000006', 'Lentil Soup', 1, 12.00),
    ('c1000001-0001-4001-8001-000000000021', 'b1000001-0001-4001-8001-000000000005', 'Chicken Mandi Plate', 1, 48.00),
    ('c1000001-0001-4001-8001-000000000021', 'b1000001-0001-4001-8001-000000000003', 'Saj Bread Snack Box', 1, 19.00),
    ('c1000001-0001-4001-8001-000000000022', 'b1000001-0001-4001-8001-000000000011', 'Grilled Salmon Fillet', 1, 52.00),
    ('c1000001-0001-4001-8001-000000000022', 'b1000001-0001-4001-8001-000000000010', 'Quinoa Power Bowl', 1, 29.00),
    ('c1000001-0001-4001-8001-000000000022', 'b1000001-0001-4001-8001-000000000012', 'Halloumi Wrap', 1, 22.00),
    ('c1000001-0001-4001-8001-000000000023', 'b1000001-0001-4001-8001-000000000018', 'Sweet Potato Fries', 1, 11.00),
    ('c1000001-0001-4001-8001-000000000023', 'b1000001-0001-4001-8001-000000000019', 'Vanilla Shake', 1, 14.00),
    ('c1000001-0001-4001-8001-000000000024', 'b1000001-0001-4001-8001-000000000016', 'Classic Beef Burger', 1, 24.00),
    ('c1000001-0001-4001-8001-000000000024', 'b1000001-0001-4001-8001-000000000021', 'Spicy Buffalo Wings', 1, 18.00);

  -- 8 conversations — first_message_time / preview text align with narrative below
  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_elena, v_sarah, 'customer-chef', now() - interval '32 days', 'See you at pickup!', now() - interval '1 day')
  RETURNING id INTO conv_elena_sarah;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_alex, v_marcus, 'customer-chef', now() - interval '52 days', 'Sounds great — we will have it ready.', now() - interval '1 day' + interval '4 minutes')
  RETURNING id INTO conv_alex_marcus;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_elena, NULL, 'customer-support', now() - interval '12 days', 'Email us anytime if anything else is unclear.', now() - interval '10 days')
  RETURNING id INTO conv_elena_sup;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_sam, v_james, 'customer-chef', now() - interval '9 days', 'First order went smooth — will recommend.', now() - interval '8 days' + interval '20 minutes')
  RETURNING id INTO conv_sam_james;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_riley, v_marcus, 'customer-chef', now() - interval '7 days', 'You are welcome — enjoy.', now() - interval '6 days' + interval '2 minutes')
  RETURNING id INTO conv_riley_marcus;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_maya, v_sarah, 'customer-chef', now() - interval '6 days', 'See you tomorrow for the two salads!', now() - interval '4 days' + interval '2 hours')
  RETURNING id INTO conv_maya_sarah;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_alex, v_sarah, 'customer-chef', now() - interval '4 days', 'You got it!', now() - interval '3 days' + interval '6 minutes')
  RETURNING id INTO conv_alex_sarah;

  INSERT INTO public.conversations (customer_id, chef_id, type, created_at, last_message, last_message_at)
  VALUES (v_riley, v_james, 'customer-chef', now() - interval '3 days', 'Looking forward to it!', now() - interval '2 days' + interval '31 minutes')
  RETURNING id INTO conv_riley_james;

  -- 55 messages — chronological within each thread (oldest first); ties to orders & bios above
  INSERT INTO public.messages (conversation_id, sender_id, content, is_read, created_at) VALUES
    (conv_elena_sarah, v_elena, 'Do you sell small gift cards for colleagues? I work near King Fahd Tower.', true, now() - interval '32 days'),
    (conv_elena_sarah, v_sarah, 'Yes — SAR 50 and 100. I can add a short handwritten note.', true, now() - interval '32 days' + interval '6 minutes'),
    (conv_elena_sarah, v_elena, 'Hi Sarah — can I pick up 15 minutes late today?', true, now() - interval '25 days'),
    (conv_elena_sarah, v_sarah, 'Yes — I will leave the bag at the desk.', true, now() - interval '25 days' + interval '5 minutes'),
    (conv_elena_sarah, v_elena, 'Traffic was heavier than expected — thanks for waiting.', true, now() - interval '24 days'),
    (conv_elena_sarah, v_sarah, 'All good — enjoy your meal.', true, now() - interval '24 days' + interval '2 minutes'),
    (conv_elena_sarah, v_elena, 'The kabsa was excellent — same spread as the big family order the office keeps mentioning.', true, now() - interval '20 days'),
    (conv_elena_sarah, v_sarah, 'That means a lot — see you on the next one.', true, now() - interval '20 days' + interval '3 minutes'),
    (conv_elena_sarah, v_elena, 'See you at pickup!', true, now() - interval '1 day'),
    (conv_alex_marcus, v_alex, 'Five stars on the salmon bowl — same tray Elena ordered for her team.', true, now() - interval '52 days'),
    (conv_alex_marcus, v_marcus, 'Thank you — tell Elena we said hi.', true, now() - interval '52 days' + interval '4 minutes'),
    (conv_alex_marcus, v_alex, 'Extra garlic dip if possible — thank you!', true, now() - interval '18 days'),
    (conv_alex_marcus, v_marcus, 'Added to your bag. See you soon.', true, now() - interval '18 days' + interval '2 minutes'),
    (conv_alex_marcus, v_alex, 'Running five minutes late — still OK?', true, now() - interval '17 days'),
    (conv_alex_marcus, v_marcus, 'Yes — holding at the counter.', true, now() - interval '17 days' + interval '1 minute'),
    (conv_alex_marcus, v_alex, 'Thanks for the quick prep!', true, now() - interval '2 days'),
    (conv_alex_marcus, v_marcus, 'Anytime — good evening.', true, now() - interval '2 days' + interval '1 minute'),
    (conv_alex_marcus, v_alex, 'Will order the quinoa bowl again next week.', true, now() - interval '1 day'),
    (conv_alex_marcus, v_marcus, 'Sounds great — we will have it ready.', true, now() - interval '1 day' + interval '4 minutes'),
    (conv_elena_sup, v_elena, 'Hi — the commission line on my receipt for the big Sarah order confuses me.', true, now() - interval '12 days'),
    (conv_elena_sup, v_admin, 'Happy to help — which order total should we look at?', true, now() - interval '12 days' + interval '30 minutes'),
    (conv_elena_sup, v_elena, 'The SAR 106 family dinner from Sarah — kabsa, mandi, and cake (about four months ago).', true, now() - interval '12 days' + interval '45 minutes'),
    (conv_elena_sup, v_admin, 'That line is the platform fee — 10% of the order subtotal.', true, now() - interval '12 days' + interval '50 minutes'),
    (conv_elena_sup, v_elena, 'Got it — matches what I back-calculated.', true, now() - interval '11 days'),
    (conv_elena_sup, v_admin, 'I can send a one-page PDF that breaks out each line if useful.', true, now() - interval '11 days'),
    (conv_elena_sup, v_admin, 'Email us anytime if anything else is unclear.', true, now() - interval '10 days'),
    (conv_sam_james, v_sam, 'First app order — same side door as the weekend market stall?', true, now() - interval '9 days'),
    (conv_sam_james, v_james, 'Same door — ring the James Bites bell.', true, now() - interval '9 days' + interval '3 minutes'),
    (conv_sam_james, v_sam, 'On my way — class ends in twenty.', true, now() - interval '8 days'),
    (conv_sam_james, v_james, 'Bag ready — napkins and wipes inside.', true, now() - interval '8 days' + interval '2 minutes'),
    (conv_sam_james, v_sam, 'Pickup in twenty — perfect.', true, now() - interval '8 days' + interval '15 minutes'),
    (conv_sam_james, v_james, 'See you soon!', true, now() - interval '8 days' + interval '16 minutes'),
    (conv_sam_james, v_sam, 'First order went smooth — will recommend to classmates.', true, now() - interval '8 days' + interval '20 minutes'),
    (conv_riley_marcus, v_riley, 'Allergic to sesame — skip tahini on the quinoa bowl?', true, now() - interval '7 days'),
    (conv_riley_marcus, v_marcus, 'Swapped for lemon dressing — on the ticket.', true, now() - interval '7 days' + interval '4 minutes'),
    (conv_riley_marcus, v_riley, 'Extra garlic dip helped — neighbors said you are the best near Al Nakheel.', true, now() - interval '6 days'),
    (conv_riley_marcus, v_marcus, 'You are welcome — enjoy.', true, now() - interval '6 days' + interval '2 minutes'),
    (conv_maya_sarah, v_maya, 'Is the fattoush dairy-free? I grab light lunches most weeks.', true, now() - interval '6 days'),
    (conv_maya_sarah, v_sarah, 'No cheese in that one — same build as your last order.', true, now() - interval '6 days' + interval '3 minutes'),
    (conv_maya_sarah, v_maya, 'Ordering two for lunch tomorrow — one for me, one for my partner.', true, now() - interval '5 days'),
    (conv_maya_sarah, v_sarah, 'We will prep both fresh in the morning.', true, now() - interval '5 days' + interval '2 minutes'),
    (conv_maya_sarah, v_maya, 'Salad was crisp — thank you.', true, now() - interval '5 days' + interval '1 hour'),
    (conv_maya_sarah, v_sarah, 'Thank you for sticking with us.', true, now() - interval '5 days' + interval '1 hour' + interval '2 minutes'),
    (conv_maya_sarah, v_maya, 'See you tomorrow for the two salads!', true, now() - interval '4 days' + interval '2 hours'),
    (conv_alex_sarah, v_alex, 'Mandi still available after 8 PM? Elena said you are flexible.', true, now() - interval '4 days'),
    (conv_alex_sarah, v_sarah, 'Kitchen until 10 PM — mandi usually on.', true, now() - interval '4 days' + interval '2 minutes'),
    (conv_alex_sarah, v_alex, 'Can I swap dessert for juice on the next order?', true, now() - interval '3 days'),
    (conv_alex_sarah, v_sarah, 'Yes — put it in the notes.', true, now() - interval '3 days' + interval '3 minutes'),
    (conv_alex_sarah, v_alex, 'Will do — thanks Sarah.', true, now() - interval '3 days' + interval '5 minutes'),
    (conv_alex_sarah, v_sarah, 'You got it!', true, now() - interval '3 days' + interval '6 minutes'),
    (conv_riley_james, v_riley, 'Default patty doneness?', true, now() - interval '3 days'),
    (conv_riley_james, v_james, 'Well-done unless you ask — food safety.', true, now() - interval '3 days' + interval '2 minutes'),
    (conv_riley_james, v_riley, 'Works for me — Sam said the same.', true, now() - interval '2 days'),
    (conv_riley_james, v_james, 'See you at pickup.', true, now() - interval '2 days' + interval '1 minute'),
    (conv_riley_james, v_riley, 'Burger was great — same next week.', true, now() - interval '2 days' + interval '30 minutes'),
    (conv_riley_james, v_james, 'Looking forward to it!', true, now() - interval '2 days' + interval '31 minutes');

  -- 9 reels + 28 reel likes
  INSERT INTO public.reels (id, chef_id, video_url, thumbnail_url, caption, dish_id, created_at, likes_count) VALUES
    ('e1000001-0001-4001-8001-000000000001', v_sarah,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
     'Still our #1 pickup — regulars know this one.', 'b1000001-0001-4001-8001-000000000001', now() - interval '14 days', 0),
    ('e1000001-0001-4001-8001-000000000002', v_sarah,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
     'Mandi night — same rice you saw on office lunch orders.', 'b1000001-0001-4001-8001-000000000005', now() - interval '11 days', 0),
    ('e1000001-0001-4001-8001-000000000003', v_sarah,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg',
     'Dessert pass — date cake slices.', 'b1000001-0001-4001-8001-000000000002', now() - interval '8 days', 0),
    ('e1000001-0001-4001-8001-000000000004', v_sarah,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg',
     'Shout-out to everyone who brought a colleague — you know who you are.', NULL, now() - interval '5 days', 0),
    ('e1000001-0001-4001-8001-000000000005', v_marcus,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg',
     'Office tower lunch runs — skewers never sit long.', 'b1000001-0001-4001-8001-000000000009', now() - interval '10 days', 0),
    ('e1000001-0001-4001-8001-000000000006', v_marcus,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMob.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMob.jpg',
     'Sesame-free swap available — ask when you order the bowl.', 'b1000001-0001-4001-8001-000000000010', now() - interval '6 days', 0),
    ('e1000001-0001-4001-8001-000000000007', v_james,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/SubaruOutbackOnStreetAndDirt.jpg',
     'Same burgers as the market stall — shorter walk now.', 'b1000001-0001-4001-8001-000000000016', now() - interval '7 days', 0),
    ('e1000001-0001-4001-8001-000000000008', v_james,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg',
     'Wings and fries — Friday rush.', 'b1000001-0001-4001-8001-000000000021', now() - interval '4 days', 0),
    ('e1000001-0001-4001-8001-000000000009', v_frozen,
     'https://storage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4',
     'https://storage.googleapis.com/gtv-videos-bucket/sample/images/VolkswagenGTIReview.jpg',
     'Archived reel — account on hold.', 'b1000001-0001-4001-8001-000000000026', now() - interval '90 days', 0);

  INSERT INTO public.reel_likes (reel_id, customer_id, created_at) VALUES
    ('e1000001-0001-4001-8001-000000000001', v_elena, now() - interval '13 days'),
    ('e1000001-0001-4001-8001-000000000001', v_alex, now() - interval '13 days'),
    ('e1000001-0001-4001-8001-000000000001', v_maya, now() - interval '12 days'),
    ('e1000001-0001-4001-8001-000000000002', v_elena, now() - interval '10 days'),
    ('e1000001-0001-4001-8001-000000000002', v_riley, now() - interval '10 days'),
    ('e1000001-0001-4001-8001-000000000002', v_sam, now() - interval '9 days'),
    ('e1000001-0001-4001-8001-000000000003', v_alex, now() - interval '7 days'),
    ('e1000001-0001-4001-8001-000000000003', v_maya, now() - interval '7 days'),
    ('e1000001-0001-4001-8001-000000000003', v_riley, now() - interval '6 days'),
    ('e1000001-0001-4001-8001-000000000004', v_elena, now() - interval '4 days'),
    ('e1000001-0001-4001-8001-000000000004', v_sam, now() - interval '4 days'),
    ('e1000001-0001-4001-8001-000000000005', v_elena, now() - interval '9 days'),
    ('e1000001-0001-4001-8001-000000000005', v_alex, now() - interval '9 days'),
    ('e1000001-0001-4001-8001-000000000005', v_maya, now() - interval '8 days'),
    ('e1000001-0001-4001-8001-000000000005', v_riley, now() - interval '8 days'),
    ('e1000001-0001-4001-8001-000000000006', v_elena, now() - interval '5 days'),
    ('e1000001-0001-4001-8001-000000000006', v_alex, now() - interval '5 days'),
    ('e1000001-0001-4001-8001-000000000006', v_sam, now() - interval '5 days'),
    ('e1000001-0001-4001-8001-000000000007', v_sam, now() - interval '6 days'),
    ('e1000001-0001-4001-8001-000000000007', v_riley, now() - interval '6 days'),
    ('e1000001-0001-4001-8001-000000000007', v_maya, now() - interval '6 days'),
    ('e1000001-0001-4001-8001-000000000007', v_elena, now() - interval '5 days'),
    ('e1000001-0001-4001-8001-000000000008', v_alex, now() - interval '3 days'),
    ('e1000001-0001-4001-8001-000000000008', v_riley, now() - interval '3 days'),
    ('e1000001-0001-4001-8001-000000000008', v_sam, now() - interval '3 days'),
    ('e1000001-0001-4001-8001-000000000008', v_maya, now() - interval '2 days'),
    ('e1000001-0001-4001-8001-000000000009', v_elena, now() - interval '85 days'),
    ('e1000001-0001-4001-8001-000000000009', v_alex, now() - interval '85 days');

  UPDATE public.reels SET likes_count = s.c FROM (
    SELECT 'e1000001-0001-4001-8001-000000000001'::uuid AS id, 3 AS c UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000002', 3 UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000003', 3 UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000004', 2 UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000005', 4 UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000006', 3 UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000007', 4 UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000008', 4 UNION ALL
    SELECT 'e1000001-0001-4001-8001-000000000009', 2
  ) s WHERE public.reels.id = s.id;

  INSERT INTO public.notifications (customer_id, title, body, is_read, type, created_at) VALUES
    (v_elena, '[naham-present] Order completed', 'Your Sarah''s Home Kitchen order is complete — thanks for being one of our longest regulars.', true, 'order', now() - interval '94 days'),
    (v_alex, '[naham-present] Pickup reminder', 'Set your pickup pin so we rank kitchens the same way Elena sees them near the tower.', false, 'info', now() - interval '1 hour'),
    (v_sam, '[naham-present] Welcome', 'Welcome — your James Bites pickup is the same door as the weekend stall.', false, 'info', now() - interval '9 days'),
    (v_maya, '[naham-present] Sarah posted', 'Sarah''s Home Kitchen shared a new reel — your usual fattoush is in today''s prep story.', false, 'info', now() - interval '2 days'),
    (v_riley, '[naham-present] Saved dishes', 'Your saved kabsa and skewers are still in stock — tap Favorites to reorder.', false, 'info', now() - interval '3 days');

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inspection_calls') THEN
    INSERT INTO public.inspection_calls (
      chef_id, admin_id, channel_name, status, result_action, result_note, chef_result_seen,
      created_at, responded_at, finalized_at
    ) VALUES
      (v_sarah, v_admin, '[naham-present] inspection-sarah-pass', 'completed', 'pass', 'Routine inspection — documentation complete.', true,
       now() - interval '60 days', now() - interval '60 days', now() - interval '60 days'),
      (v_marcus, v_admin, '[naham-present] inspection-marcus-pending', 'pending', NULL, NULL, false, now() - interval '2 hours', NULL, NULL);
  END IF;

  RAISE NOTICE 'Presentation seed complete (30 menus, 24 orders, 55 lines, 8 chats, 55 msgs, 9 reels, 28 likes).';
END $$;
