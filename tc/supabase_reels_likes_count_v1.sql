-- ============================================================
-- NAHAM Reels — denormalized likes_count + trigger
-- Keeps reels row updated when reel_likes changes so Realtime on
-- public.reels reflects like totals without subscribing to reel_likes.
-- Run in Supabase SQL Editor after reel_likes + reels exist.
-- ============================================================

ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.reels.likes_count IS
  'Cached count of reel_likes rows; maintained by trigger reel_likes_sync_reels_count_trg.';

-- One-time backfill (safe to re-run)
UPDATE public.reels r
SET likes_count = COALESCE(
  (SELECT count(*)::integer FROM public.reel_likes l WHERE l.reel_id = r.id),
  0
);

CREATE OR REPLACE FUNCTION public.reel_likes_sync_reels_count ()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.reels
    SET likes_count = COALESCE(likes_count, 0) + 1
    WHERE id = NEW.reel_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.reels
    SET likes_count = GREATEST(COALESCE(likes_count, 0) - 1, 0)
    WHERE id = OLD.reel_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS reel_likes_sync_reels_count_trg ON public.reel_likes;
CREATE TRIGGER reel_likes_sync_reels_count_trg
  AFTER INSERT OR DELETE ON public.reel_likes
  FOR EACH ROW
  EXECUTE PROCEDURE public.reel_likes_sync_reels_count ();

COMMENT ON FUNCTION public.reel_likes_sync_reels_count () IS
  'SECURITY DEFINER: bumps reels.likes_count when likes are added/removed (bypasses RLS).';

REVOKE ALL ON FUNCTION public.reel_likes_sync_reels_count () FROM PUBLIC;

-- Optional: client merges reel_likes stream for instant counts; enable Realtime on reel_likes.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'reel_likes'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.reel_likes;
    END IF;
  END IF;
END $$;
