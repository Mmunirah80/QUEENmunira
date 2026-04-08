-- =============================================================================
-- DEV ONLY — Option B when you cannot use SUPABASE_SERVICE_ROLE_KEY in the app.
-- Disables RLS on chat + order tables so debug auth bypass (no auth.uid()) works.
-- DO NOT run on production. Re-enable RLS and restore policies after local QA.
-- =============================================================================

ALTER TABLE IF EXISTS public.conversations DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.order_items DISABLE ROW LEVEL SECURITY;

-- To revert (after testing), re-enable and re-apply your normal migration scripts:
-- ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
