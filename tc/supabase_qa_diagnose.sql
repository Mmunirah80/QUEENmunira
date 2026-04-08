-- =============================================================================
-- تشخيص سريع — شغّل هذا أولاً في Supabase → SQL Editor (ما يغيّر شيء، قراءة فقط)
-- Quick diagnostics — run first; read-only SELECTs
-- =============================================================================

-- 1) هل الجداول الأساسية موجودة؟
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'profiles', 'chef_profiles', 'chef_documents', 'orders', 'conversations',
    'messages', 'notifications', 'menu_items'
  )
ORDER BY table_name;

-- 2) قيود جدول chef_documents (المشكلة الغالبة: document_type أو status)
SELECT c.conname AS constraint_name,
       pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
  AND t.relname = 'chef_documents'
  AND c.contype = 'c'
ORDER BY c.conname;

-- 3) عمود notifications.chef_document_id (مطلوب لـ apply_chef_document_review)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
  AND column_name IN ('chef_document_id', 'customer_id', 'type');

-- 4) دوال مهمة
SELECT proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND proname IN (
    'recompute_chef_access_level',
    'apply_chef_document_review',
    'chef_upsert_document'
  )
ORDER BY proname;

-- إذا نقص جدول أو دالة: شغّل الترحيلات من مجلد naham/tc بالترتيب:
--   1) supabase_chef_access_documents_v3.sql
--   2) supabase_chef_documents_two_types_migration_v1.sql
--   3) supabase_apply_chef_document_review.sql
-- ثم: supabase_qa_seed_cook_onboarding_matrix_v1.sql
