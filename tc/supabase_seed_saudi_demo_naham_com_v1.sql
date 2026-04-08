-- =============================================================================
-- NAHAM — Saudi realistic demo data (UPSERT only, no deletes)
-- =============================================================================
-- Resolves users by email in auth.users, then upserts:
--   public.profiles, public.chef_profiles, public.chef_documents, public.menu_items
--
-- Expected Auth users (create in Dashboard if missing):
--   admin2@naham.com
--   customer.demo@naham.com
--   chef1@naham.com … chef4@naham.com
--
-- Customer browse visibility (Flutter + RPC chef_orderable_for_customers_batch):
--   • chef_profiles.kitchen_latitude / kitchen_longitude NOT NULL (map pin)
--   • is_online = true, vacation_mode = false, freeze_until NULL
--   • approval_status = 'approved' OR (full_access + documents_operational_ok)
--   • Within working hours in kitchen_timezone (Asia/Riyadh)
--   • menu_items: is_available, remaining_quantity > 0, moderation_status approved
--   • profiles.is_blocked = false for chef
--
-- After chef_documents upsert, calls recompute_chef_access_level per chef (if fn exists).
--
-- Run in Supabase SQL Editor as postgres / service role.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Optional column safety (idempotent)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS city text;

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS kitchen_latitude double precision,
  ADD COLUMN IF NOT EXISTS kitchen_longitude double precision,
  ADD COLUMN IF NOT EXISTS kitchen_timezone text,
  ADD COLUMN IF NOT EXISTS initial_approval_at timestamptz,
  ADD COLUMN IF NOT EXISTS access_level text,
  ADD COLUMN IF NOT EXISTS documents_operational_ok boolean,
  ADD COLUMN IF NOT EXISTS approval_status text,
  ADD COLUMN IF NOT EXISTS suspended boolean,
  ADD COLUMN IF NOT EXISTS rating_avg double precision,
  ADD COLUMN IF NOT EXISTS total_orders integer;

ALTER TABLE public.menu_items
  ADD COLUMN IF NOT EXISTS moderation_status text;

-- ---------------------------------------------------------------------------
-- Main seed
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_admin uuid;
  v_customer uuid;
  v_c1 uuid;
  v_c2 uuid;
  v_c3 uuid;
  v_c4 uuid;
  missing text;
BEGIN
  SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('admin2@naham.com') LIMIT 1;
  SELECT id INTO v_customer FROM auth.users WHERE lower(email) = lower('customer.demo@naham.com') LIMIT 1;
  SELECT id INTO v_c1 FROM auth.users WHERE lower(email) = lower('chef1@naham.com') LIMIT 1;
  SELECT id INTO v_c2 FROM auth.users WHERE lower(email) = lower('chef2@naham.com') LIMIT 1;
  SELECT id INTO v_c3 FROM auth.users WHERE lower(email) = lower('chef3@naham.com') LIMIT 1;
  SELECT id INTO v_c4 FROM auth.users WHERE lower(email) = lower('chef4@naham.com') LIMIT 1;

  IF v_admin IS NULL OR v_customer IS NULL OR v_c1 IS NULL OR v_c2 IS NULL OR v_c3 IS NULL OR v_c4 IS NULL THEN
    SELECT string_agg(x.e, ', ' ORDER BY x.e) INTO missing
    FROM (
      SELECT unnest(ARRAY[
        'admin2@naham.com',
        'customer.demo@naham.com',
        'chef1@naham.com',
        'chef2@naham.com',
        'chef3@naham.com',
        'chef4@naham.com'
      ]) AS e
    ) x
    WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(x.e));
    RAISE EXCEPTION 'Create missing Auth users first (Authentication → Users): %', COALESCE(missing, 'unknown');
  END IF;

  -- ─── profiles (UPSERT) ───────────────────────────────────────────────
  INSERT INTO public.profiles (id, full_name, role, phone, is_blocked, city)
  VALUES
    (v_admin, 'مدير النظام التجريبي', 'admin', '+966500000001', false, NULL),
    (v_customer, 'عميل تجريبي', 'customer', '+966501112233', false, 'الرياض'),
    (v_c1, 'شيف نجد — كبسة', 'chef', '+966502223344', false, 'الرياض'),
    (v_c2, 'شيف التراث النجدي', 'chef', '+966502223355', false, 'الرياض'),
    (v_c3, 'شيف الجنوب', 'chef', '+966502223366', false, 'الرياض'),
    (v_c4, 'شيف منزل متنوع', 'chef', '+966502223377', false, 'الرياض')
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
    is_blocked = false,
    city = COALESCE(EXCLUDED.city, public.profiles.city);

  -- ─── chef_profiles (UPSERT) — Riyadh pins + zones in bio ─────────────
  INSERT INTO public.chef_profiles (
    id,
    kitchen_name,
    is_online,
    vacation_mode,
    working_hours_start,
    working_hours_end,
    kitchen_timezone,
    bank_iban,
    bank_account_name,
    bio,
    kitchen_city,
    approval_status,
    suspended,
    initial_approval_at,
    kitchen_latitude,
    kitchen_longitude,
    freeze_until,
    access_level,
    documents_operational_ok,
    rating_avg,
    total_orders
  ) VALUES
    (
      v_c1,
      'مطبخ نجد التراثي',
      true,
      false,
      '08:00',
      '23:00',
      'Asia/Riyadh',
      'SA0380000000608010169001',
      'مطبخ نجد التراثي',
      'شمال الرياض — كبسة بيتية على أصولها، أرز سيلا وبهارات نجدية.',
      'الرياض',
      'approved',
      false,
      now() - interval '120 days',
      24.8600,
      46.7520,
      NULL,
      NULL,
      false,
      4.82,
      156
    ),
    (
      v_c2,
      'بيت القصيم',
      true,
      false,
      '08:00',
      '23:00',
      'Asia/Riyadh',
      'SA0380000000608010169002',
      'بيت القصيم',
      'شرق الرياض — أطباق نجدية تقليدية: جريش وقرصان يوميًا.',
      'الرياض',
      'approved',
      false,
      now() - interval '90 days',
      24.7235,
      46.8060,
      NULL,
      NULL,
      false,
      4.75,
      98
    ),
    (
      v_c3,
      'سفرة الجنوب',
      true,
      false,
      '08:00',
      '23:00',
      'Asia/Riyadh',
      'SA0380000000608010169003',
      'سفرة الجنوب',
      'غرب الرياض — سليق وحنيذ بأسلوب الجنوب.',
      'الرياض',
      'approved',
      false,
      now() - interval '75 days',
      24.7130,
      46.6120,
      NULL,
      NULL,
      false,
      4.70,
      72
    ),
    (
      v_c4,
      'مطبخ الحجاز الأصيل',
      true,
      false,
      '08:00',
      '23:00',
      'Asia/Riyadh',
      'SA0380000000608010169004',
      'مطبخ الحجاز الأصيل',
      'جنوب الرياض — قائمة منوعة من أطباق السعودية (حجاز ونجد وجنوب).',
      'الرياض',
      'approved',
      false,
      now() - interval '60 days',
      24.5800,
      46.7200,
      NULL,
      NULL,
      false,
      4.68,
      64
    )
  ON CONFLICT (id) DO UPDATE SET
    kitchen_name = EXCLUDED.kitchen_name,
    is_online = EXCLUDED.is_online,
    vacation_mode = EXCLUDED.vacation_mode,
    working_hours_start = EXCLUDED.working_hours_start,
    working_hours_end = EXCLUDED.working_hours_end,
    kitchen_timezone = COALESCE(EXCLUDED.kitchen_timezone, public.chef_profiles.kitchen_timezone),
    bio = EXCLUDED.bio,
    kitchen_city = EXCLUDED.kitchen_city,
    approval_status = EXCLUDED.approval_status,
    suspended = EXCLUDED.suspended,
    initial_approval_at = COALESCE(public.chef_profiles.initial_approval_at, EXCLUDED.initial_approval_at),
    kitchen_latitude = EXCLUDED.kitchen_latitude,
    kitchen_longitude = EXCLUDED.kitchen_longitude,
    freeze_until = EXCLUDED.freeze_until,
    -- Avoid client-side "full_access + documents_operational_ok=false" gate: clear access_level so approval_status drives browse.
    access_level = NULL,
    documents_operational_ok = false,
    rating_avg = COALESCE(EXCLUDED.rating_avg, public.chef_profiles.rating_avg),
    total_orders = COALESCE(EXCLUDED.total_orders, public.chef_profiles.total_orders);

  -- ─── chef_documents (UPSERT) — approved + no_expiry for recompute ─────
  INSERT INTO public.chef_documents (chef_id, document_type, file_url, status, no_expiry)
  VALUES
    (v_c1, 'national_id', 'demo/saudi-seed/chef1/national_id.pdf', 'approved', true),
    (v_c1, 'freelancer_id', 'demo/saudi-seed/chef1/freelancer.pdf', 'approved', true),
    (v_c2, 'national_id', 'demo/saudi-seed/chef2/national_id.pdf', 'approved', true),
    (v_c2, 'freelancer_id', 'demo/saudi-seed/chef2/freelancer.pdf', 'approved', true),
    (v_c3, 'national_id', 'demo/saudi-seed/chef3/national_id.pdf', 'approved', true),
    (v_c3, 'freelancer_id', 'demo/saudi-seed/chef3/freelancer.pdf', 'approved', true),
    (v_c4, 'national_id', 'demo/saudi-seed/chef4/national_id.pdf', 'approved', true),
    (v_c4, 'freelancer_id', 'demo/saudi-seed/chef4/freelancer.pdf', 'approved', true)
  ON CONFLICT (chef_id, document_type) DO UPDATE SET
    status = 'approved',
    no_expiry = true,
    file_url = COALESCE(EXCLUDED.file_url, public.chef_documents.file_url);

  -- Sync access flags if migration installed recompute (safe no-op if missing)
  BEGIN
    PERFORM public.recompute_chef_access_level(v_c1);
    PERFORM public.recompute_chef_access_level(v_c2);
    PERFORM public.recompute_chef_access_level(v_c3);
    PERFORM public.recompute_chef_access_level(v_c4);
  EXCEPTION
    WHEN undefined_function THEN
      RAISE NOTICE 'recompute_chef_access_level not found; skipped (set access manually if needed).';
  END;

  -- If recompute set full_access, ensure documents_operational_ok true for Flutter browse rule
  UPDATE public.chef_profiles cp
  SET
    documents_operational_ok = true,
    approval_status = 'approved'
  WHERE cp.id IN (v_c1, v_c2, v_c3, v_c4)
    AND lower(trim(coalesce(cp.access_level, ''))) = 'full_access';

  -- ─── menu_items (stable UUIDs; UPSERT) ────────────────────────────────
  -- chef1 — كبسة وأرز
  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, moderation_status, created_at
  ) VALUES
    ('ea000001-0001-4001-8001-000000000101', v_c1, 'كبسة دجاج',
     'أرز كبسة أصفر مع دجاج طري وبهارات نجدية، مع صلصة دقة.', 32.00, NULL, 'كبسة',
     40, 35, true, 'approved', now() - interval '30 days'),
    ('ea000001-0001-4001-8001-000000000102', v_c1, 'كبسة لحم',
     'لحم ضأن مع أرز كبسة ومكسرات، طبق عائلي.', 55.00, NULL, 'كبسة',
     25, 22, true, 'approved', now() - interval '28 days'),
    ('ea000001-0001-4001-8001-000000000103', v_c1, 'دبيازة',
     'لحم مطبوخ ببطء مع الخبز الرقيق والمرق الغني.', 42.00, NULL, 'مأكولات تقليدية',
     20, 18, true, 'approved', now() - interval '20 days'),
    ('ea000001-0001-4001-8001-000000000104', v_c1, 'مرقوق',
     'خبز رقيق على مرق الخضار واللحم حسب الطلب.', 28.00, NULL, 'مأكولات تقليدية',
     30, 28, true, 'approved', now() - interval '18 days'),
    ('ea000001-0001-4001-8001-000000000105', v_c1, 'مطازيز',
     'طبق تقليدي من الخبز والمرق واللحم.', 26.00, NULL, 'مأكولات تقليدية',
     25, 24, true, 'approved', now() - interval '15 days')
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

  -- chef2 — نجد
  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, moderation_status, created_at
  ) VALUES
    ('ea000001-0001-4001-8001-000000000201', v_c2, 'جريش',
     'جريش نجدي باللبن والبرغل مع لحم مفروم وبهارات خفيفة.', 22.00, NULL, 'نجد',
     35, 32, true, 'approved', now() - interval '25 days'),
    ('ea000001-0001-4001-8001-000000000202', v_c2, 'قرصان',
     'خبز رقيق مع مرق الدجاج أو اللحم والخضار.', 24.00, NULL, 'نجد',
     35, 30, true, 'approved', now() - interval '24 days'),
    ('ea000001-0001-4001-8001-000000000203', v_c2, 'عصيدة',
     'عصيدة تمر بالسمن البري، حلاوة بسيطة وشعبية.', 18.00, NULL, 'حلويات',
     40, 38, true, 'approved', now() - interval '22 days'),
    ('ea000001-0001-4001-8001-000000000204', v_c2, 'مثلوثة',
     'خبز رقيق طبقات مع حشوة لحم بصل وبهارات.', 20.00, NULL, 'نجد',
     30, 28, true, 'approved', now() - interval '20 days'),
    ('ea000001-0001-4001-8001-000000000205', v_c2, 'كليجا القصيم',
     'كليجا محشوة تمر أو عجوة، طازجة من الفرن.', 35.00, NULL, 'حلويات',
     50, 45, true, 'approved', now() - interval '10 days')
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

  -- chef3 — جنوب
  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, moderation_status, created_at
  ) VALUES
    ('ea000001-0001-4001-8001-000000000301', v_c3, 'سليق',
     'سليق أبيض بالدجاج أو اللحم، أسلوب جنوبي مع مرق خفيف.', 30.00, NULL, 'جنوب',
     28, 25, true, 'approved', now() - interval '18 days'),
    ('ea000001-0001-4001-8001-000000000302', v_c3, 'حنيذ',
     'لحم محنيذ في الفرن الطيني بنكهة مدخنة خفيفة (توصيل ساخن).', 58.00, NULL, 'جنوب',
     15, 12, true, 'approved', now() - interval '16 days'),
    ('ea000001-0001-4001-8001-000000000303', v_c3, 'مطازيز',
     'نسخة جنوبية من المطازيز مع مرق غني.', 27.00, NULL, 'جنوب',
     22, 20, true, 'approved', now() - interval '14 days'),
    ('ea000001-0001-4001-8001-000000000304', v_c3, 'تمر سكري مُحضّر',
     'صحن تمر سكري فاخر مع القهوة العربية (حجم عائلي صغير).', 25.00, NULL, 'مرافقات',
     60, 55, true, 'approved', now() - interval '12 days')
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

  -- chef4 — mixed
  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, moderation_status, created_at
  ) VALUES
    ('ea000001-0001-4001-8001-000000000401', v_c4, 'كبسة دجاج',
     'كبسة دجاج يومية، أرز معكرون وليمون مجفف.', 34.00, NULL, 'منوع',
     35, 30, true, 'approved', now() - interval '8 days'),
    ('ea000001-0001-4001-8001-000000000402', v_c4, 'جريش',
     'جريش خفيف باللبن مع صحن صغير سلطة.', 23.00, NULL, 'منوع',
     25, 22, true, 'approved', now() - interval '7 days'),
    ('ea000001-0001-4001-8001-000000000403', v_c4, 'سليق',
     'سليق بالدجاج، يقدم مع شطة بيتية.', 31.00, NULL, 'منوع',
     22, 20, true, 'approved', now() - interval '6 days'),
    ('ea000001-0001-4001-8001-000000000404', v_c4, 'حنيذ',
     'حنيذ لحم مع أرز بسمتي ومكسرات.', 62.00, NULL, 'منوع',
     12, 10, true, 'approved', now() - interval '5 days'),
    ('ea000001-0001-4001-8001-000000000405', v_c4, 'كليجا القصيم',
     'كليجا محشوة تمر، علبة متوسطة.', 38.00, NULL, 'حلويات',
     45, 40, true, 'approved', now() - interval '4 days'),
    ('ea000001-0001-4001-8001-000000000406', v_c4, 'تمر سكري مُحضّر',
     'تمر سكري محشي مكسرات (حسب التوفر).', 40.00, NULL, 'حلويات',
     30, 28, true, 'approved', now() - interval '3 days')
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

  RAISE NOTICE 'Saudi demo seed OK. chefs: % % % % customer: % admin: %',
    v_c1, v_c2, v_c3, v_c4, v_customer, v_admin;
END;
$$;
