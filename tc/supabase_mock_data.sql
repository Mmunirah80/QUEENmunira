-- ============================================================
-- NAHAM – MOCK DATA (يحتاج مستخدمين من Authentication أولاً)
-- ============================================================
-- هذا الملف مُعبّأ حالياً بهذه الـ UIDs (عدّلها إن احتجت بيئة أخرى):
--   • عميل: c6a03fc9-5d06-40d6-a037-9ca2174f962a
--   • شيف 1 (Najdi Kitchen): b0704df4-8e2b-4b7b-bb49-a361b7fc907e
--   • شيف 2 (Northern Bites / cook2): 5fff80f0-e881-4788-94c2-7f0075f77a3c
--
-- شغّل الاستعلام كاملاً من SQL Editor بعد التأكد أن المستخدمين موجودين في Auth.
-- ============================================================
--
-- لماذا قد تظهر الشاشة بدون أطباق؟ (عميل Flutter)
--   • customer_browse_supabase_datasource: يخفي أطباق الشيف إن لم يكن
--     chef_profiles.approval_status = 'approved' أو كان suspended = true.
--   • يخفي الطبق إن moderation_status = 'pending' أو 'rejected'.
--   • الشاشة الرئيسية: طبّاخ له kitchen_latitude/longitude خارج
--     ~20 km من نقطة الاستلام لا يُعرض (ما عدا إن الإحداثيات null
--     فيُلحق كـ legacy). لهذا نضبط موافقة + moderation + إحداثيات قريبة
--     من موقع الويب التقريبي الافتراضي (~24.15, 47.32).
-- ============================================================

-- أعمدة الإحداثيات (آمنة إن كانت مضافة مسبقاً)
alter table public.chef_profiles
  add column if not exists kitchen_latitude double precision,
  add column if not exists kitchen_longitude double precision;

-- 1) تحديث profiles للشيفين (غالباً أنشأهما trigger عند إضافة المستخدم)
UPDATE profiles SET role = 'chef', full_name = 'Najdi Kitchen', phone = '+966501111111' WHERE id = 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e';
UPDATE profiles SET role = 'chef', full_name = 'Northern Bites', phone = '+966502222222' WHERE id = '5fff80f0-e881-4788-94c2-7f0075f77a3c';
UPDATE profiles SET role = 'customer', full_name = 'Test Customer', phone = '+966500000000' WHERE id = 'c6a03fc9-5d06-40d6-a037-9ca2174f962a';

-- 2) Chef profiles (يجب أن يكون الـ id موجوداً في profiles = UID من Auth)
INSERT INTO chef_profiles (id, kitchen_name, is_online, vacation_mode, working_hours_start, working_hours_end, bank_iban, bank_account_name, bio, kitchen_city)
VALUES
  ('b0704df4-8e2b-4b7b-bb49-a361b7fc907e', 'Najdi Kitchen', true, false, '09:00', '22:00', 'SA0000000000000000000000', 'Najdi Account', 'Traditional Najdi home cooking.', 'Riyadh'),
  ('5fff80f0-e881-4788-94c2-7f0075f77a3c', 'Northern Bites', true, false, '10:00', '21:00', 'SA0000000000000000000001', 'Northern Account', 'Northern region flavors.', 'Tabuk')
ON CONFLICT (id) DO UPDATE SET kitchen_name = EXCLUDED.kitchen_name, is_online = EXCLUDED.is_online, vacation_mode = EXCLUDED.vacation_mode,
  working_hours_start = EXCLUDED.working_hours_start, working_hours_end = EXCLUDED.working_hours_end, bio = EXCLUDED.bio, kitchen_city = EXCLUDED.kitchen_city;

-- 2b) إظهار الشيف والأطباق في تطبيق العميل (موافقة + غير موقوف + قرب نقطة الاستلام)
UPDATE chef_profiles SET
  approval_status = 'approved',
  suspended = false,
  kitchen_latitude = 24.1530,
  kitchen_longitude = 47.3235
WHERE id = 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e';

UPDATE chef_profiles SET
  approval_status = 'approved',
  suspended = false,
  kitchen_latitude = 24.1524,
  kitchen_longitude = 47.3231
WHERE id = '5fff80f0-e881-4788-94c2-7f0075f77a3c';

-- 3) Menu items (chef_id = شيف 1 أو شيف 2 أعلاه)
INSERT INTO menu_items (id, chef_id, name, description, price, image_url, category, daily_quantity, remaining_quantity, is_available, created_at) VALUES
  ('d1000001-0001-4000-8000-000000000001', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', 'Jareesh', 'Cracked wheat with meat and spices.', 25.00, null, 'Najdi', 20, 15, true, now()),
  ('d1000001-0001-4000-8000-000000000002', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', 'Kabsa', 'Spiced rice with chicken.', 35.00, null, 'Najdi', 15, 10, true, now()),
  ('d1000001-0001-4000-8000-000000000003', '5fff80f0-e881-4788-94c2-7f0075f77a3c', 'Grilled Lamb', 'Tender lamb with spices.', 45.00, null, 'Northern', 10, 8, true, now()),
  ('d1000001-0001-4000-8000-000000000004', '5fff80f0-e881-4788-94c2-7f0075f77a3c', 'Manty', 'Steamed dumplings with meat.', 28.00, null, 'Northern', 12, 12, true, now()),
  ('d1000001-0001-4000-8000-000000000005', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', 'Kleija', 'Date-filled pastry.', 15.00, null, 'Sweets', 25, 20, true, now()),
  ('d1000001-0001-4000-8000-000000000006', '5fff80f0-e881-4788-94c2-7f0075f77a3c', 'Baklava', 'Layered pastry with nuts.', 22.00, null, 'Sweets', 14, 14, true, now())
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, price = EXCLUDED.price, remaining_quantity = EXCLUDED.remaining_quantity, is_available = EXCLUDED.is_available;

-- 3b) مراجعة الأطباق في الواجهة (عمود موجود في مخططات naham الحديثة)
UPDATE menu_items SET moderation_status = 'approved'
WHERE id IN (
  'd1000001-0001-4000-8000-000000000001',
  'd1000001-0001-4000-8000-000000000002',
  'd1000001-0001-4000-8000-000000000003',
  'd1000001-0001-4000-8000-000000000004',
  'd1000001-0001-4000-8000-000000000005',
  'd1000001-0001-4000-8000-000000000006'
);

-- 4) Addresses للعميل التجريبي
INSERT INTO addresses (id, customer_id, label, street, city, is_default, created_at) VALUES
  (gen_random_uuid(), 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'Home', '123 Main St', 'Riyadh', true, now()),
  (gen_random_uuid(), 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'Work', '456 Office Rd', 'Riyadh', false, now());

-- 5) Favorites
INSERT INTO favorites (id, customer_id, item_id, created_at) VALUES
  (gen_random_uuid(), 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'd1000001-0001-4000-8000-000000000001', now()),
  (gen_random_uuid(), 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'd1000001-0001-4000-8000-000000000005', now());

-- 6) Notifications
INSERT INTO notifications (id, customer_id, title, body, is_read, type, created_at) VALUES
  (gen_random_uuid(), 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'Welcome!', 'Thanks for using Naham. Enjoy ordering.', false, 'info', now()),
  (gen_random_uuid(), 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'Order Update', 'Your order #1 is being prepared.', true, 'order', now());

-- 7) Orders
INSERT INTO orders (id, customer_id, chef_id, status, total_amount, commission_amount, delivery_address, customer_name, chef_name, created_at, updated_at) VALUES
  ('01000001-0001-4000-8000-000000000001', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', 'completed', 60.50, 5.50, '123 Main St, Riyadh', 'Test Customer', 'Najdi Kitchen', now() - interval '2 days', now()),
  ('01000001-0001-4000-8000-000000000002', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', '5fff80f0-e881-4788-94c2-7f0075f77a3c', 'paid_waiting_acceptance', 45.00, 4.50, '123 Main St, Riyadh', 'Test Customer', 'Northern Bites', now(), now())
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, updated_at = EXCLUDED.updated_at;

-- 8) Order items (المخطط الحالي: menu_item_id — يطابق customer_orders_supabase_datasource)
INSERT INTO order_items (id, order_id, menu_item_id, dish_name, quantity, unit_price) VALUES
  (gen_random_uuid(), '01000001-0001-4000-8000-000000000001', 'd1000001-0001-4000-8000-000000000001', 'Jareesh', 2, 25.00),
  (gen_random_uuid(), '01000001-0001-4000-8000-000000000001', 'd1000001-0001-4000-8000-000000000005', 'Kleija', 1, 15.00),
  (gen_random_uuid(), '01000001-0001-4000-8000-000000000002', 'd1000001-0001-4000-8000-000000000003', 'Grilled Lamb', 1, 45.00);

-- 9) Health testing mock: mark specific chef with 1 warning
UPDATE chef_profiles
SET warning_count = 1
WHERE id = 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e';

-- 10) Cook orders mock data for cook 5fff80f0-e881-4788-94c2-7f0075f77a3c
-- Delete existing orders + items for this cook, then insert a status set
-- that includes NEW incoming orders (pending / paid_waiting_acceptance).
DELETE FROM order_items
WHERE order_id IN (
  SELECT id FROM orders WHERE chef_id = '5fff80f0-e881-4788-94c2-7f0075f77a3c'
);

DELETE FROM orders
WHERE chef_id = '5fff80f0-e881-4788-94c2-7f0075f77a3c';

INSERT INTO orders (customer_id, chef_id, status, total_amount, notes, created_at)
VALUES
  ('c6a03fc9-5d06-40d6-a037-9ca2174f962a','5fff80f0-e881-4788-94c2-7f0075f77a3c','pending',47,'No spice',now()),
  ('c6a03fc9-5d06-40d6-a037-9ca2174f962a','5fff80f0-e881-4788-94c2-7f0075f77a3c','paid_waiting_acceptance',39,'Ring the bell',now()-interval '2 minutes'),
  ('c6a03fc9-5d06-40d6-a037-9ca2174f962a','5fff80f0-e881-4788-94c2-7f0075f77a3c','accepted',35,'Extra sauce',now()-interval '8 minutes'),
  ('c6a03fc9-5d06-40d6-a037-9ca2174f962a','5fff80f0-e881-4788-94c2-7f0075f77a3c','preparing',60,'On time',now()-interval '20 minutes'),
  ('c6a03fc9-5d06-40d6-a037-9ca2174f962a','5fff80f0-e881-4788-94c2-7f0075f77a3c','completed',45,'',now()-interval '2 hours'),
  ('c6a03fc9-5d06-40d6-a037-9ca2174f962a','5fff80f0-e881-4788-94c2-7f0075f77a3c','cancelled_by_cook',25,'',now()-interval '1 hour');

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, dish_name)
SELECT o.id,
  (SELECT id FROM menu_items WHERE chef_id = '5fff80f0-e881-4788-94c2-7f0075f77a3c' LIMIT 1),
  2,
  25,
  'Chicken Kabsa'
FROM orders o
WHERE o.chef_id = '5fff80f0-e881-4788-94c2-7f0075f77a3c';
