-- ============================================================
-- DEPRECATED — منطق "أدمن غير محظور" مدمج الآن في:
--   supabase_rls_authorization_hardening.sql
-- (دالة is_admin(uuid) + is_admin() بدون تعارض overload)
--
-- لا تشغّل هذا الملف إن كان قد نُفّذ hardening المحدّث.
-- إن كان عندك خطأ 42725، استخدم: supabase_repair_broken_migrations.sql
-- ثم أعد تشغيل hardening كاملًا.
-- ============================================================

select 1 as skip_deprecated_patch;
