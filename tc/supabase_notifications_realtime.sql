-- ============================================================
-- NAHAM — Realtime: notifications (chef + customer in-app list)
-- Run once in Supabase SQL Editor. Safe to re-run (skips if already added).
-- ============================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'notifications'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
  END IF;
END $$;

COMMENT ON TABLE public.notifications IS 'Recipient id in customer_id (legacy name). Realtime enabled for in-app notification streams.';
