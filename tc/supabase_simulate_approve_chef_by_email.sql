-- ============================================================
-- NAHAM — محاكاة قبول كامل لطبّاخ بالإيميل (تشغيل من Supabase → SQL Editor)
--
-- أنا (الـ AI) ما أقدر أتصل بقاعدة بياناتك. انسخي هذا الملف كامل بعد ما تعدّلي السطر
-- اللي فيه الإيميل، واضغطي Run.
--
-- يحدّث: كل صفوف chef_documents لهذا الطبّاخ → approved
--        و chef_profiles → approved + إلغاء التعليق
-- ============================================================

-- غيّري النص بين علامتي الاقتباس ليطابق إيميل التسجيل (جزء منه يكفي، مثل حقكك3)
-- مثال: '%حقكك3%' أو '%you@gmail.com%'
DO $$
DECLARE
  chef_uuid uuid;
  email_pattern text := '%حقكك3%';  -- ← عدّلي هنا
BEGIN
  SELECT u.id
  INTO chef_uuid
  FROM auth.users u
  WHERE u.email ILIKE email_pattern
  LIMIT 1;

  IF chef_uuid IS NULL THEN
    RAISE EXCEPTION
      'ما لقينا مستخدم بهذا الإيميل. تأكدي من auth.users وعدّلي email_pattern في أعلى الكتلة.';
  END IF;

  UPDATE public.chef_documents
  SET
    status = 'approved',
    rejection_reason = NULL,
    reviewed_at = now(),
    updated_at = now()
  WHERE chef_id = chef_uuid;

  UPDATE public.chef_profiles
  SET
    approval_status = 'approved',
    rejection_reason = NULL,
    suspended = FALSE,
    suspension_reason = NULL
  WHERE id = chef_uuid;

  IF NOT FOUND THEN
    RAISE WARNING 'ما فيه صف chef_profiles لهذا الـ id — تأكدي إن التسجيل كطبّاخ أنشأ الصف.';
  END IF;

  RAISE NOTICE 'تم. chef_id = %', chef_uuid;
END $$;

-- للتحقق بعد التشغيل:
-- SELECT id, email FROM auth.users WHERE email ILIKE '%حقكك3%';
-- SELECT approval_status, suspended FROM public.chef_profiles WHERE id = 'الـ uuid';
-- SELECT document_type, status FROM public.chef_documents WHERE chef_id = 'الـ uuid';
