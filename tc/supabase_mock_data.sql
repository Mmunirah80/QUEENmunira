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
-- تنويع مُدمَج في هذا الملف:
--   • مسافات مطابخ مختلفة من نقطة الاستلام المرجعية (~24.1530, 47.3235):
--       شيف 1 ≈ 0.7–1.2 كم | شيف 2 ≈ 6–7 كم (ترتيب بالبُعد في Home واضح).
--   • أطباق: أسعار متفاوتة، daily_quantity / remaining_quantity (وفرة / قليل / نفاد)، أصناف متعددة.
--   • طلبات: pending، paid_waiting_acceptance، accepted، preparing، ready، completed،
--       cancelled_by_customer، cancelled_by_cook، expired — موزعة على الشيفين.
--
-- لماذا قد تظهر الشاشة بدون أطباق؟ (عميل Flutter)
--   • customer_browse: شيف غير approved / suspended / إجازة.
--   • طبق: moderation_status pending/rejected أو remaining <= 0 أو غير متاح.
--   • مسافة المطبخ > ~20 km من نقطة الاستلام.
-- ============================================================

-- أعمدة الإحداثيات (آمنة إن كانت مضافة مسبقاً)
alter table public.chef_profiles
  add column if not exists kitchen_latitude double precision,
  add column if not exists kitchen_longitude double precision;

-- 1) تحديث profiles — أسماء سعودية واقعية
UPDATE profiles SET role = 'chef', full_name = N'أحمد القحطاني', phone = '+966501111111' WHERE id = 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e';
UPDATE profiles SET role = 'chef', full_name = N'فيصل الدوسري', phone = '+966502222222' WHERE id = '5fff80f0-e881-4788-94c2-7f0075f77a3c';
UPDATE profiles SET role = 'customer', full_name = N'نورة العتيبي', phone = '+966500000000' WHERE id = 'c6a03fc9-5d06-40d6-a037-9ca2174f962a';

-- 2) Chef profiles (يجب أن يكون الـ id موجوداً في profiles = UID من Auth)
INSERT INTO chef_profiles (id, kitchen_name, is_online, vacation_mode, working_hours_start, working_hours_end, bank_iban, bank_account_name, bio, kitchen_city)
VALUES
  ('b0704df4-8e2b-4b7b-bb49-a361b7fc907e', N'مطبخ أم فهد — نجد', true, false, '09:00', '22:00', 'SA0000000000000000000000', N'أسرة أم فهد', N'أطباق نجدية منزلية يومية.', N'الرياض'),
  ('5fff80f0-e881-4788-94c2-7f0075f77a3c', N'مطبخ أم راشد — الشرقية', true, false, '10:00', '21:00', 'SA0000000000000000000001', N'أسرة أم راشد', N'مجبوس ومأكولات شرقية وسمك.', N'الدمام')
ON CONFLICT (id) DO UPDATE SET kitchen_name = EXCLUDED.kitchen_name, is_online = EXCLUDED.is_online, vacation_mode = EXCLUDED.vacation_mode,
  working_hours_start = EXCLUDED.working_hours_start, working_hours_end = EXCLUDED.working_hours_end, bio = EXCLUDED.bio, kitchen_city = EXCLUDED.kitchen_city;

-- 2b) موافقة + إحداثيات بمسافات مختلفة من مرجع الاستلام الافتراضي (~24.1530, 47.3235)
--     Najdi: قريب جداً | Northern: ~6+ كم شمالاً (يظهر ترتيب أوضح في واجهة العميل)
UPDATE chef_profiles SET
  approval_status = 'approved',
  suspended = false,
  kitchen_latitude = 24.1546,
  kitchen_longitude = 47.3252
WHERE id = 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e';

UPDATE chef_profiles SET
  approval_status = 'approved',
  suspended = false,
  kitchen_latitude = 24.2110,
  kitchen_longitude = 47.3165
WHERE id = '5fff80f0-e881-4788-94c2-7f0075f77a3c';

-- 3) أطباق واقعية — فئات: نجدي / شرقي / حلويات / سريعة (تظهر في واجهة العميل كـ category)
INSERT INTO menu_items (id, chef_id, name, description, price, image_url, category, daily_quantity, remaining_quantity, is_available, created_at) VALUES
  ('d1000001-0001-4000-8000-000000000001', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', N'جريش نجدي', N'جريش لحم ناعم على الطريقة النجدية.', 18.00, null, N'نجدي', 40, 36, true, now()),
  ('d1000001-0001-4000-8000-000000000002', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', N'قرصان باللحم', N'قرصان محمّر مع لحم ناعم.', 22.00, null, N'نجدي', 22, 4, true, now()),
  ('d1000001-0001-4000-8000-000000000003', '5fff80f0-e881-4788-94c2-7f0075f77a3c', N'مجبوس دجاج', N'أرز مجبوس دجاج بتوابل الشرقية.', 25.00, null, N'شرقي', 16, 10, true, now()),
  ('d1000001-0001-4000-8000-000000000004', '5fff80f0-e881-4788-94c2-7f0075f77a3c', N'سمك مشوي', N'سمك حمور مشوي مع بهارات خفيفة.', 30.00, null, N'شرقي', 12, 0, true, now()),
  ('d1000001-0001-4000-8000-000000000005', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', N'لقيمات بالعسل', N'لقيمات طرية مع عسل سدر.', 12.00, null, N'حلويات', 55, 48, true, now()),
  ('d1000001-0001-4000-8000-000000000006', '5fff80f0-e881-4788-94c2-7f0075f77a3c', N'كيك تمر', N'كيك تمر طازج — حبة وسط.', 15.00, null, N'حلويات', 30, 24, true, now()),
  ('d1000001-0001-4000-8000-000000000007', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', N'برجر لحم منزلي', N'برجر لحم طازج مع صوص منزلي.', 17.00, null, N'سريعة', 35, 30, true, now()),
  ('d1000001-0001-4000-8000-000000000008', '5fff80f0-e881-4788-94c2-7f0075f77a3c', N'شاورما دجاج', N'شاورما دجاج مع توم وبطاطس.', 14.00, null, N'سريعة', 45, 40, true, now())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  daily_quantity = EXCLUDED.daily_quantity,
  remaining_quantity = EXCLUDED.remaining_quantity,
  is_available = EXCLUDED.is_available;

-- 3b) مراجعة الأطباق في الواجهة
UPDATE menu_items SET moderation_status = 'approved'
WHERE id IN (
  'd1000001-0001-4000-8000-000000000001',
  'd1000001-0001-4000-8000-000000000002',
  'd1000001-0001-4000-8000-000000000003',
  'd1000001-0001-4000-8000-000000000004',
  'd1000001-0001-4000-8000-000000000005',
  'd1000001-0001-4000-8000-000000000006',
  'd1000001-0001-4000-8000-000000000007',
  'd1000001-0001-4000-8000-000000000008'
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

-- 7–8) طلبات موحّدة بتنويع الحالات + الشيفين (حذف ثم إعادة إدراج آمن بوسم notes)
DELETE FROM public.order_items WHERE order_id IN (
  SELECT id FROM public.orders
  WHERE customer_id = 'c6a03fc9-5d06-40d6-a037-9ca2174f962a'
    AND chef_id IN (
      'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
      '5fff80f0-e881-4788-94c2-7f0075f77a3c'
    )
    AND (
      notes = '[naham-mock-pipeline]'
      OR id IN (
        '01000001-0001-4000-8000-000000000001',
        '01000001-0001-4000-8000-000000000002'
      )
    )
);

DELETE FROM public.orders
WHERE customer_id = 'c6a03fc9-5d06-40d6-a037-9ca2174f962a'
  AND chef_id IN (
    'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    '5fff80f0-e881-4788-94c2-7f0075f77a3c'
  )
  AND (
    notes = '[naham-mock-pipeline]'
    OR id IN (
      '01000001-0001-4000-8000-000000000001',
      '01000001-0001-4000-8000-000000000002'
    )
  );

INSERT INTO public.orders (
  id, customer_id, chef_id, status, total_amount, commission_amount,
  delivery_address, customer_name, chef_name, notes, created_at, updated_at
) VALUES
  -- مطبخ أم فهد — مسارات متنوعة (أسعار متوافقة مع menu_items أعلاه)
  ('02000001-0001-4000-8000-000000000001', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'paid_waiting_acceptance', 22.00, 2.20, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now(), now()),
  ('02000001-0001-4000-8000-000000000002', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'pending', 36.00, 3.60, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now() - interval '3 minutes', now() - interval '3 minutes'),
  ('02000001-0001-4000-8000-000000000003', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'accepted', 22.00, 2.20, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now() - interval '12 minutes', now() - interval '10 minutes'),
  ('02000001-0001-4000-8000-000000000004', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'preparing', 56.00, 5.60, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now() - interval '25 minutes', now() - interval '20 minutes'),
  ('02000001-0001-4000-8000-000000000005', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'ready', 30.00, 3.00, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now() - interval '40 minutes', now() - interval '35 minutes'),
  ('02000001-0001-4000-8000-000000000006', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'completed', 34.00, 3.40, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now() - interval '2 days', now() - interval '2 days' + interval '1 hour'),
  ('02000001-0001-4000-8000-000000000007', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'cancelled_by_customer', 28.00, 2.80, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now() - interval '3 hours', now() - interval '3 hours'),
  ('02000001-0001-4000-8000-000000000008', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
    'expired', 18.00, 1.80, N'الرياض — حي الياسمين — استلام من المطبخ', N'نورة العتيبي', N'مطبخ أم فهد — نجد',
    '[naham-mock-pipeline]', now() - interval '1 day', now() - interval '1 day'),
  -- مطبخ أم راشد — الشرقية
  ('02000001-0001-4000-8000-000000000009', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', '5fff80f0-e881-4788-94c2-7f0075f77a3c',
    'paid_waiting_acceptance', 25.00, 2.50, N'الدمام — حي الفيصلية — استلام', N'نورة العتيبي', N'مطبخ أم راشد — الشرقية',
    '[naham-mock-pipeline]', now() - interval '1 minute', now() - interval '1 minute'),
  ('02000001-0001-4000-8000-000000000010', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', '5fff80f0-e881-4788-94c2-7f0075f77a3c',
    'preparing', 30.00, 3.00, N'الدمام — حي الفيصلية — استلام', N'نورة العتيبي', N'مطبخ أم راشد — الشرقية',
    '[naham-mock-pipeline]', now() - interval '18 minutes', now() - interval '15 minutes'),
  ('02000001-0001-4000-8000-000000000011', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', '5fff80f0-e881-4788-94c2-7f0075f77a3c',
    'completed', 44.00, 4.40, N'الدمام — حي الفيصلية — استلام', N'نورة العتيبي', N'مطبخ أم راشد — الشرقية',
    '[naham-mock-pipeline]', now() - interval '5 hours', now() - interval '4 hours'),
  ('02000001-0001-4000-8000-000000000012', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a', '5fff80f0-e881-4788-94c2-7f0075f77a3c',
    'cancelled_by_cook', 14.00, 1.40, N'الدمام — حي الفيصلية — استلام', N'نورة العتيبي', N'مطبخ أم راشد — الشرقية',
    '[naham-mock-pipeline]', now() - interval '90 minutes', now() - interval '85 minutes')
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  total_amount = EXCLUDED.total_amount,
  commission_amount = EXCLUDED.commission_amount,
  notes = EXCLUDED.notes,
  updated_at = EXCLUDED.updated_at;

DELETE FROM public.order_items WHERE order_id IN (
  '02000001-0001-4000-8000-000000000001',
  '02000001-0001-4000-8000-000000000002',
  '02000001-0001-4000-8000-000000000003',
  '02000001-0001-4000-8000-000000000004',
  '02000001-0001-4000-8000-000000000005',
  '02000001-0001-4000-8000-000000000006',
  '02000001-0001-4000-8000-000000000007',
  '02000001-0001-4000-8000-000000000008',
  '02000001-0001-4000-8000-000000000009',
  '02000001-0001-4000-8000-000000000010',
  '02000001-0001-4000-8000-000000000011',
  '02000001-0001-4000-8000-000000000012'
);

INSERT INTO public.order_items (id, order_id, menu_item_id, dish_name, quantity, unit_price) VALUES
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000001', 'd1000001-0001-4000-8000-000000000002', N'قرصان باللحم', 1, 22.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000002', 'd1000001-0001-4000-8000-000000000001', N'جريش نجدي', 2, 18.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000003', 'd1000001-0001-4000-8000-000000000002', N'قرصان باللحم', 1, 22.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000004', 'd1000001-0001-4000-8000-000000000002', N'قرصان باللحم', 1, 22.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000004', 'd1000001-0001-4000-8000-000000000007', N'برجر لحم منزلي', 2, 17.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000005', 'd1000001-0001-4000-8000-000000000001', N'جريش نجدي', 1, 18.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000005', 'd1000001-0001-4000-8000-000000000005', N'لقيمات بالعسل', 1, 12.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000006', 'd1000001-0001-4000-8000-000000000002', N'قرصان باللحم', 1, 22.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000006', 'd1000001-0001-4000-8000-000000000005', N'لقيمات بالعسل', 1, 12.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000007', 'd1000001-0001-4000-8000-000000000008', N'شاورما دجاج', 2, 14.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000008', 'd1000001-0001-4000-8000-000000000001', N'جريش نجدي', 1, 18.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000009', 'd1000001-0001-4000-8000-000000000003', N'مجبوس دجاج', 1, 25.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000010', 'd1000001-0001-4000-8000-000000000004', N'سمك مشوي', 1, 30.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000011', 'd1000001-0001-4000-8000-000000000006', N'كيك تمر', 2, 15.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000011', 'd1000001-0001-4000-8000-000000000008', N'شاورما دجاج', 1, 14.00),
  (gen_random_uuid(), '02000001-0001-4000-8000-000000000012', 'd1000001-0001-4000-8000-000000000008', N'شاورما دجاج', 1, 14.00);

-- 10) محادثات عميل–شيف للمراقبة (يتطلب عمود conversations.order_id — نفّذ supabase_conversations_order_id.sql إن لم يكن موجوداً)
DO $conv$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'conversations' AND column_name = 'order_id'
  ) THEN
    DELETE FROM public.messages WHERE conversation_id IN (
      'caff0001-0001-4000-8000-000000000001'::uuid,
      'caff0001-0001-4000-8000-000000000002'::uuid
    );
    DELETE FROM public.conversations WHERE id IN (
      'caff0001-0001-4000-8000-000000000001'::uuid,
      'caff0001-0001-4000-8000-000000000002'::uuid
    );
    INSERT INTO public.conversations (id, customer_id, chef_id, type, order_id, created_at)
    VALUES
      ('caff0001-0001-4000-8000-000000000001', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a',
       'b0704df4-8e2b-4b7b-bb49-a361b7fc907e', 'customer-chef',
       '02000001-0001-4000-8000-000000000003', now() - interval '25 minutes'),
      ('caff0001-0001-4000-8000-000000000002', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a',
       '5fff80f0-e881-4788-94c2-7f0075f77a3c', 'customer-chef',
       '02000001-0001-4000-8000-000000000010', now() - interval '14 minutes')
    ON CONFLICT (id) DO UPDATE SET
      order_id = EXCLUDED.order_id,
      customer_id = EXCLUDED.customer_id,
      chef_id = EXCLUDED.chef_id,
      type = EXCLUDED.type;

    INSERT INTO public.messages (id, conversation_id, sender_id, content, is_read, created_at)
    VALUES
      (gen_random_uuid(), 'caff0001-0001-4000-8000-000000000001', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a',
       N'السلام عليكم، متى يكون الطلب جاهز؟', true, now() - interval '22 minutes'),
      (gen_random_uuid(), 'caff0001-0001-4000-8000-000000000001', 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e',
       N'تمام، جهّزت الطلب — متبقي حوالي ١٠ دقائق.', true, now() - interval '18 minutes'),
      (gen_random_uuid(), 'caff0001-0001-4000-8000-000000000002', 'c6a03fc9-5d06-40d6-a037-9ca2174f962a',
       N'متى يوصل الطلب؟', true, now() - interval '12 minutes'),
      (gen_random_uuid(), 'caff0001-0001-4000-8000-000000000002', '5fff80f0-e881-4788-94c2-7f0075f77a3c',
       N'الطلب جاهز للاستلام من المطبخ.', true, now() - interval '9 minutes');
  END IF;
END
$conv$;

-- 9) Health testing mock: تنبيهات مختلفة بين الشيفين (واحد بتحذير، واحد نظيف)
UPDATE chef_profiles SET warning_count = 2 WHERE id = 'b0704df4-8e2b-4b7b-bb49-a361b7fc907e';
UPDATE chef_profiles SET warning_count = 0 WHERE id = '5fff80f0-e881-4788-94c2-7f0075f77a3c';
