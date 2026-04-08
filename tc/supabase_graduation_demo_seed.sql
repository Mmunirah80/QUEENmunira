-- ============================================================
-- NAHAM — Graduation demo seed (existing admin + 5 Auth users by email)
-- Saudi kitchen naming: see DEMO_SAUDI_KITCHEN_NAMES.md (مطبخ أم فيصل، وردة الوردات، …)
-- ============================================================
-- Resolves ALL person IDs from auth.users (lower(email) match).
-- No hardcoded user UUIDs. All other row IDs use gen_random_uuid().
-- Idempotent: safe to re-run; does NOT DELETE any rows.
--
-- Prerequisites:
--   1) Existing admin: naham@naham.com (must exist in auth.users).
--   2) Create these five Auth users (any password; confirm email off OK):
--        demo-chef-saffron@naham.grad
--        demo-chef-rustafa@naham.grad
--        demo-chef-pending@naham.grad
--        demo-customer-omar@naham.grad   → fresh customer (no seeded orders/chat/notifications)
--        demo-customer-huda@naham.grad   → rich notifications + order/support history
--   3) Each has a public.profiles row (signup / trigger / first login).
--   4) Core tables + migrations applied (orders.notes, chef_documents, reels, RLS, etc.).
--
-- Run in Supabase SQL Editor as postgres (bypasses RLS).
-- Does NOT modify the admin profile row (only uses admin id for messages).
-- ============================================================

ALTER TABLE public.conversations
  ALTER COLUMN chef_id DROP NOT NULL;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS kitchen_latitude double precision,
  ADD COLUMN IF NOT EXISTS kitchen_longitude double precision,
  ADD COLUMN IF NOT EXISTS initial_approval_at timestamptz;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS city text;

DO $$
DECLARE
  v_admin uuid;
  v_chef1 uuid;
  v_chef2 uuid;
  v_chef3 uuid;
  v_c1 uuid;
  v_c2 uuid;
  missing text;
  v_d_mut uuid;
  v_d_taw uuid;
  v_d_fat uuid;
  v_o_done uuid;
  v_conv_sup uuid;
BEGIN
  SELECT id INTO v_admin FROM auth.users WHERE lower(email) = lower('naham@naham.com') LIMIT 1;
  SELECT id INTO v_chef1 FROM auth.users WHERE lower(email) = lower('demo-chef-saffron@naham.grad') LIMIT 1;
  SELECT id INTO v_chef2 FROM auth.users WHERE lower(email) = lower('demo-chef-rustafa@naham.grad') LIMIT 1;
  SELECT id INTO v_chef3 FROM auth.users WHERE lower(email) = lower('demo-chef-pending@naham.grad') LIMIT 1;
  SELECT id INTO v_c1 FROM auth.users WHERE lower(email) = lower('demo-customer-omar@naham.grad') LIMIT 1;
  SELECT id INTO v_c2 FROM auth.users WHERE lower(email) = lower('demo-customer-huda@naham.grad') LIMIT 1;

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin not found: sign in or create auth user naham@naham.com first.';
  END IF;

  SELECT string_agg(x.e, ', ' ORDER BY x.e) INTO missing
  FROM (
    SELECT unnest(ARRAY[
      'demo-chef-saffron@naham.grad',
      'demo-chef-rustafa@naham.grad',
      'demo-chef-pending@naham.grad',
      'demo-customer-omar@naham.grad',
      'demo-customer-huda@naham.grad'
    ]) AS e
  ) x
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = lower(x.e));

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing Auth users (create them first): %', missing;
  END IF;

  -- Chefs & customers only (never alter existing admin profile here)
  UPDATE public.profiles SET role = 'chef', full_name = 'Badr Al-Mutairi', phone = '+966502000001' WHERE id = v_chef1;
  UPDATE public.profiles SET role = 'chef', full_name = 'Maha Al-Qahtani', phone = '+966502000002' WHERE id = v_chef2;
  UPDATE public.profiles SET role = 'chef', full_name = 'Omar Al-Mutairi', phone = '+966502000003' WHERE id = v_chef3;
  UPDATE public.profiles SET role = 'customer', full_name = 'Omar Al-Farsi', phone = '+966503000001', city = 'Riyadh' WHERE id = v_c1;
  UPDATE public.profiles SET role = 'customer', full_name = 'Huda Al-Mutairi', phone = '+966503000002', city = 'Riyadh' WHERE id = v_c2;

  INSERT INTO public.chef_profiles (
    id, kitchen_name, is_online, vacation_mode,
    working_hours_start, working_hours_end,
    bank_iban, bank_account_name, bio, kitchen_city,
    approval_status, suspended, kitchen_latitude, kitchen_longitude
  ) VALUES
    (v_chef1, 'مطبخ أم فيصل', true, false, '10:00', '22:00',
     'SA0380000000000808010167520', 'مطبخ أم فيصل — بدر',
     'طبخ منزلي بأسلوب نجد — كبسة، لقيمات، وحنيني.', 'Riyadh',
     'approved', false, 24.1530, 47.3235),
    (v_chef2, 'وردة الوردات', true, false, '11:00', '23:00',
     'SA0380000000000808010167521', 'وردة الوردات — مها',
     'مشاوي وسلطات بأسلوب شرقي — مناسبة للعائلة.', 'Riyadh',
     'approved', false, 24.1524, 47.3231),
    (v_chef3, 'مطبخ أم خالد', false, false, '09:00', '21:00',
     'SA0380000000000808010167522', 'مطبخ أم خالد — عمر',
     'قيد المراجعة — القائمة تفتح بعد تفعيل الحساب.', 'Riyadh',
     'pending', false, NULL, NULL)
  ON CONFLICT (id) DO UPDATE SET
    kitchen_name = EXCLUDED.kitchen_name,
    is_online = EXCLUDED.is_online,
    vacation_mode = EXCLUDED.vacation_mode,
    working_hours_start = EXCLUDED.working_hours_start,
    working_hours_end = EXCLUDED.working_hours_end,
    bio = EXCLUDED.bio,
    kitchen_city = EXCLUDED.kitchen_city,
    approval_status = EXCLUDED.approval_status,
    suspended = false,
    kitchen_latitude = COALESCE(EXCLUDED.kitchen_latitude, public.chef_profiles.kitchen_latitude),
    kitchen_longitude = COALESCE(EXCLUDED.kitchen_longitude, public.chef_profiles.kitchen_longitude);

  UPDATE public.chef_profiles SET
    initial_approval_at = COALESCE(initial_approval_at, now() - interval '30 days')
  WHERE id IN (v_chef1, v_chef2);

  UPDATE public.chef_profiles SET initial_approval_at = NULL WHERE id = v_chef3;

  -- Omar = fresh customer: remove any previous grad-seed order/chat for this pair (safe re-run).
  DELETE FROM public.order_items WHERE order_id IN (
    SELECT id FROM public.orders WHERE notes = '[naham-grad-seed] omar-active-v1'
  );
  DELETE FROM public.orders WHERE notes = '[naham-grad-seed] omar-active-v1';
  DELETE FROM public.messages WHERE conversation_id IN (
    SELECT c.id FROM public.conversations c
    WHERE c.customer_id = v_c1 AND c.chef_id = v_chef1 AND c.type = 'customer-chef'
  );
  DELETE FROM public.conversations
  WHERE customer_id = v_c1 AND chef_id = v_chef1 AND type = 'customer-chef';

  -- Dishes (idempotent by chef_id + name)
  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, created_at
  )
  SELECT gen_random_uuid(), v_chef1, 'Mutabbaq sajiyya', 'Crispy saj parcels with cheese and fresh herbs.', 18.00, NULL, 'Mains',
    24, 18, true, now()
  WHERE NOT EXISTS (SELECT 1 FROM public.menu_items mi WHERE mi.chef_id = v_chef1 AND mi.name = 'Mutabbaq sajiyya');

  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, created_at
  )
  SELECT gen_random_uuid(), v_chef1, 'Hanini jar', 'Warm wheat dessert with ghee and dates — single portion.', 14.00, NULL, 'Dessert',
    30, 24, true, now()
  WHERE NOT EXISTS (SELECT 1 FROM public.menu_items mi WHERE mi.chef_id = v_chef1 AND mi.name = 'Hanini jar');

  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, created_at
  )
  SELECT gen_random_uuid(), v_chef2, 'Shish tawook family tray', 'Marinated chicken skewers, garlic dip, and flatbread.', 89.00, NULL, 'Grill',
    12, 9, true, now()
  WHERE NOT EXISTS (SELECT 1 FROM public.menu_items mi WHERE mi.chef_id = v_chef2 AND mi.name = 'Shish tawook family tray');

  INSERT INTO public.menu_items (
    id, chef_id, name, description, price, image_url, category,
    daily_quantity, remaining_quantity, is_available, created_at
  )
  SELECT gen_random_uuid(), v_chef2, 'Fattoush in a jar', 'Chopped salad, toasted bread, sumac dressing — chilled.', 22.00, NULL, 'Salads',
    20, 16, true, now()
  WHERE NOT EXISTS (SELECT 1 FROM public.menu_items mi WHERE mi.chef_id = v_chef2 AND mi.name = 'Fattoush in a jar');

  UPDATE public.menu_items SET moderation_status = 'approved'
  WHERE chef_id IN (v_chef1, v_chef2);

  SELECT id INTO v_d_mut FROM public.menu_items WHERE chef_id = v_chef1 AND name = 'Mutabbaq sajiyya' ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_d_taw FROM public.menu_items WHERE chef_id = v_chef2 AND name = 'Shish tawook family tray' ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_d_fat FROM public.menu_items WHERE chef_id = v_chef2 AND name = 'Fattoush in a jar' ORDER BY created_at DESC LIMIT 1;

  -- One reel for Chef 1 (public sample media; replace with your bucket URLs if needed)
  INSERT INTO public.reels (id, chef_id, video_url, thumbnail_url, caption, dish_id, created_at)
  SELECT gen_random_uuid(), v_chef1,
    'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
    'من السج — لفّ المطبّق على الطريقة المنزلية.',
    v_d_mut,
    now() - interval '1 day'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.reels r
    WHERE r.chef_id = v_chef1
      AND r.caption = 'من السج — لفّ المطبّق على الطريقة المنزلية.'
  );

  -- Chef documents (sentinel file_url for idempotency)
  INSERT INTO public.chef_documents (id, chef_id, document_type, file_url, status, created_at)
  SELECT gen_random_uuid(), v_chef1, 'national_id', 'grad-demo-naham/saffron/national_id.pdf', 'approved', now() - interval '40 days'
  WHERE NOT EXISTS (SELECT 1 FROM public.chef_documents d WHERE d.chef_id = v_chef1 AND d.file_url = 'grad-demo-naham/saffron/national_id.pdf');

  INSERT INTO public.chef_documents (id, chef_id, document_type, file_url, status, created_at)
  SELECT gen_random_uuid(), v_chef1, 'freelancer_id', 'grad-demo-naham/saffron/freelancer.pdf', 'approved', now() - interval '40 days'
  WHERE NOT EXISTS (SELECT 1 FROM public.chef_documents d WHERE d.chef_id = v_chef1 AND d.file_url = 'grad-demo-naham/saffron/freelancer.pdf');

  INSERT INTO public.chef_documents (id, chef_id, document_type, file_url, status, created_at)
  SELECT gen_random_uuid(), v_chef2, 'national_id', 'grad-demo-naham/rustafa/national_id.pdf', 'approved', now() - interval '35 days'
  WHERE NOT EXISTS (SELECT 1 FROM public.chef_documents d WHERE d.chef_id = v_chef2 AND d.file_url = 'grad-demo-naham/rustafa/national_id.pdf');

  INSERT INTO public.chef_documents (id, chef_id, document_type, file_url, status, created_at)
  SELECT gen_random_uuid(), v_chef2, 'freelancer_id', 'grad-demo-naham/rustafa/freelancer.pdf', 'approved', now() - interval '35 days'
  WHERE NOT EXISTS (SELECT 1 FROM public.chef_documents d WHERE d.chef_id = v_chef2 AND d.file_url = 'grad-demo-naham/rustafa/freelancer.pdf');

  INSERT INTO public.chef_documents (id, chef_id, document_type, file_url, status, created_at)
  SELECT gen_random_uuid(), v_chef3, 'national_id', 'grad-demo-naham/pending/national_id.pdf', 'pending', now() - interval '2 days'
  WHERE NOT EXISTS (SELECT 1 FROM public.chef_documents d WHERE d.chef_id = v_chef3 AND d.file_url = 'grad-demo-naham/pending/national_id.pdf');

  INSERT INTO public.chef_documents (id, chef_id, document_type, file_url, status, created_at)
  SELECT gen_random_uuid(), v_chef3, 'freelancer_id', 'grad-demo-naham/pending/freelancer.pdf', 'pending', now() - interval '2 days'
  WHERE NOT EXISTS (SELECT 1 FROM public.chef_documents d WHERE d.chef_id = v_chef3 AND d.file_url = 'grad-demo-naham/pending/freelancer.pdf');

  -- Orders (idempotent via fixed notes tag; Omar intentionally has no seeded orders — see above)
  IF NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.notes = '[naham-grad-seed] huda-completed-v1') THEN
    INSERT INTO public.orders (
      id, customer_id, chef_id, status, total_amount, commission_amount,
      delivery_address, customer_name, chef_name, notes, created_at, updated_at
    ) VALUES (
      gen_random_uuid(),
      v_c2,
      v_chef2,
      'completed',
      111.00,
      11.10,
      'الرياض — حي النرجس (استلام)',
      'Huda Al-Mutairi',
      'وردة الوردات',
      '[naham-grad-seed] huda-completed-v1',
      now() - interval '5 days',
      now() - interval '4 days'
    );
  END IF;

  SELECT id INTO v_o_done FROM public.orders WHERE notes = '[naham-grad-seed] huda-completed-v1' LIMIT 1;

  INSERT INTO public.order_items (id, order_id, menu_item_id, dish_name, quantity, unit_price)
  SELECT gen_random_uuid(), v_o_done, v_d_taw, 'Shish tawook family tray', 1, 89.00
  WHERE v_o_done IS NOT NULL AND v_d_taw IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.order_items oi WHERE oi.order_id = v_o_done AND oi.menu_item_id = v_d_taw);

  INSERT INTO public.order_items (id, order_id, menu_item_id, dish_name, quantity, unit_price)
  SELECT gen_random_uuid(), v_o_done, v_d_fat, 'Fattoush in a jar', 1, 22.00
  WHERE v_o_done IS NOT NULL AND v_d_fat IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.order_items oi WHERE oi.order_id = v_o_done AND oi.menu_item_id = v_d_fat);

  -- Customer ↔ Support (admin replies as naham@naham.com). Omar has no seeded cook thread (fresh account).
  SELECT c.id INTO v_conv_sup
  FROM public.conversations c
  WHERE c.customer_id = v_c2 AND c.type = 'customer-support' AND c.chef_id IS NULL
  ORDER BY c.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_conv_sup IS NULL THEN
    INSERT INTO public.conversations (id, customer_id, chef_id, type, created_at)
    VALUES (gen_random_uuid(), v_c2, NULL, 'customer-support', now() - interval '3 days')
    RETURNING id INTO v_conv_sup;
  END IF;

  INSERT INTO public.messages (id, conversation_id, sender_id, content, is_read, created_at)
  SELECT gen_random_uuid(), v_conv_sup, v_c2, 'Hello, I need help understanding a charge on my last order.', true, now() - interval '2 days'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.conversation_id = v_conv_sup AND m.sender_id = v_c2
      AND m.content = 'Hello, I need help understanding a charge on my last order.'
  );

  INSERT INTO public.messages (id, conversation_id, sender_id, content, is_read, created_at)
  SELECT gen_random_uuid(), v_conv_sup, v_admin, 'Hi Huda — I can review that with you. Which order date should we check?', true, now() - interval '47 hours'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.conversation_id = v_conv_sup AND m.sender_id = v_admin
      AND m.content = 'Hi Huda — I can review that with you. Which order date should we check?'
  );

  -- In-app notifications (recipient id = customer_id). Huda: past + upcoming-style mix. Chefs: none here (see inspection_calls).
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'created_at'
  ) THEN
    INSERT INTO public.notifications (id, customer_id, title, body, is_read, type, created_at)
    SELECT gen_random_uuid(), v_c2,
      '[naham-grad-seed] Order completed',
      'طلبك من وردة الوردات (ديمو التخرج) اكتمل. شكراً لاستخدامك نهام!',
      true, 'order', now() - interval '4 days'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = v_c2 AND n.title = '[naham-grad-seed] Order completed'
    );

    INSERT INTO public.notifications (id, customer_id, title, body, is_read, type, created_at)
    SELECT gen_random_uuid(), v_c2,
      '[naham-grad-seed] Pickup reminder',
      'Set your pickup pin on Home before you browse — we sort kitchens by distance.',
      false, 'info', now() - interval '1 hour'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = v_c2 AND n.title = '[naham-grad-seed] Pickup reminder'
    );

    INSERT INTO public.notifications (id, customer_id, title, body, is_read, type, created_at)
    SELECT gen_random_uuid(), v_c2,
      '[naham-grad-seed] Support follow-up',
      'Reply in Support chat when you can — we can explain the commission line on your receipt.',
      false, 'info', now() - interval '30 minutes'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = v_c2 AND n.title = '[naham-grad-seed] Support follow-up'
    );

  ELSE
    -- Same rows without created_at if column missing
    INSERT INTO public.notifications (id, customer_id, title, body, is_read, type)
    SELECT gen_random_uuid(), v_c2,
      '[naham-grad-seed] Order completed',
      'طلبك من وردة الوردات (ديمو التخرج) اكتمل. شكراً لاستخدامك نهام!',
      true, 'order'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = v_c2 AND n.title = '[naham-grad-seed] Order completed'
    );

    INSERT INTO public.notifications (id, customer_id, title, body, is_read, type)
    SELECT gen_random_uuid(), v_c2,
      '[naham-grad-seed] Pickup reminder',
      'Set your pickup pin on Home before you browse — we sort kitchens by distance.',
      false, 'info'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = v_c2 AND n.title = '[naham-grad-seed] Pickup reminder'
    );

    INSERT INTO public.notifications (id, customer_id, title, body, is_read, type)
    SELECT gen_random_uuid(), v_c2,
      '[naham-grad-seed] Support follow-up',
      'Reply in Support chat when you can — we can explain the commission line on your receipt.',
      false, 'info'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = v_c2 AND n.title = '[naham-grad-seed] Support follow-up'
    );

  END IF;
  END IF;

  -- Surprise inspections: Khalid = past (completed) + new pending; other chefs = pending only (incoming demo).
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inspection_calls') THEN
    INSERT INTO public.inspection_calls (
      id, chef_id, admin_id, channel_name, status,
      result_action, result_note, chef_result_seen,
      created_at, responded_at, finalized_at
    )
    SELECT gen_random_uuid(), v_chef1, v_admin,
      '[naham-grad-seed] ic-saffron-done',
      'completed',
      'pass',
      'Grad demo: earlier inspection — documented pass.',
      true,
      now() - interval '20 days',
      now() - interval '20 days',
      now() - interval '20 days'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inspection_calls ic WHERE ic.channel_name = '[naham-grad-seed] ic-saffron-done'
    );

    INSERT INTO public.inspection_calls (
      id, chef_id, admin_id, channel_name, status,
      chef_result_seen, created_at
    )
    SELECT gen_random_uuid(), v_chef1, v_admin,
      '[naham-grad-seed] ic-saffron-pending',
      'pending',
      false,
      now() - interval '15 minutes'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inspection_calls ic WHERE ic.channel_name = '[naham-grad-seed] ic-saffron-pending'
    );

    INSERT INTO public.inspection_calls (
      id, chef_id, admin_id, channel_name, status,
      chef_result_seen, created_at
    )
    SELECT gen_random_uuid(), v_chef2, v_admin,
      '[naham-grad-seed] ic-rustafa-pending',
      'pending',
      false,
      now() - interval '9 minutes'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inspection_calls ic WHERE ic.channel_name = '[naham-grad-seed] ic-rustafa-pending'
    );

    INSERT INTO public.inspection_calls (
      id, chef_id, admin_id, channel_name, status,
      chef_result_seen, created_at
    )
    SELECT gen_random_uuid(), v_chef3, v_admin,
      '[naham-grad-seed] ic-pendingchef-pending',
      'pending',
      false,
      now() - interval '4 minutes'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inspection_calls ic WHERE ic.channel_name = '[naham-grad-seed] ic-pendingchef-pending'
    );
  END IF;
END $$;
