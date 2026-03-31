-- ============================================================
-- NAHAM Reels — schema additions + RLS + storage notes
-- Run in Supabase SQL editor after base tables exist (see supabase_customer_migrations.sql).
-- ============================================================

-- 1) Columns (safe to re-run)
ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT ARRAY[]::TEXT[];

ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS dish_id UUID;

CREATE INDEX IF NOT EXISTS idx_reels_chef_id ON public.reels(chef_id);
CREATE INDEX IF NOT EXISTS idx_reels_dish_id ON public.reels(dish_id);

-- FK to menu_items (safe if table exists; skips if constraint already there)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'menu_items')
     AND NOT EXISTS (
       SELECT 1 FROM pg_constraint WHERE conname = 'reels_dish_id_fkey'
     ) THEN
    ALTER TABLE public.reels
      ADD CONSTRAINT reels_dish_id_fkey
      FOREIGN KEY (dish_id) REFERENCES public.menu_items(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 2) Row Level Security
ALTER TABLE public.reels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reel_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reels_select_all ON public.reels;
CREATE POLICY reels_select_all
  ON public.reels FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS reels_insert_own ON public.reels;
CREATE POLICY reels_insert_own
  ON public.reels FOR INSERT
  TO authenticated
  WITH CHECK (chef_id = auth.uid());

DROP POLICY IF EXISTS reels_update_own ON public.reels;
CREATE POLICY reels_update_own
  ON public.reels FOR UPDATE
  TO authenticated
  USING (chef_id = auth.uid())
  WITH CHECK (chef_id = auth.uid());

DROP POLICY IF EXISTS reels_delete_own ON public.reels;
CREATE POLICY reels_delete_own
  ON public.reels FOR DELETE
  TO authenticated
  USING (chef_id = auth.uid());

DROP POLICY IF EXISTS reels_delete_admin ON public.reels;
CREATE POLICY reels_delete_admin
  ON public.reels FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

DROP POLICY IF EXISTS reel_likes_select ON public.reel_likes;
CREATE POLICY reel_likes_select
  ON public.reel_likes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS reel_likes_insert_own ON public.reel_likes;
CREATE POLICY reel_likes_insert_own
  ON public.reel_likes FOR INSERT
  TO authenticated
  WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS reel_likes_delete_own ON public.reel_likes;
CREATE POLICY reel_likes_delete_own
  ON public.reel_likes FOR DELETE
  TO authenticated
  USING (customer_id = auth.uid());

-- 4) Storage bucket + policies (video_player / Image.network need SELECT; chefs upload under {uid}/...)
INSERT INTO storage.buckets (id, name, public)
VALUES ('reels', 'reels', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

DROP POLICY IF EXISTS reels_storage_select_public ON storage.objects;
CREATE POLICY reels_storage_select_public
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'reels');

DROP POLICY IF EXISTS reels_storage_insert_authenticated_own_folder ON storage.objects;
CREATE POLICY reels_storage_insert_authenticated_own_folder
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'reels'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS reels_storage_update_authenticated_own_folder ON storage.objects;
CREATE POLICY reels_storage_update_authenticated_own_folder
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'reels'
    AND split_part(name, '/', 1) = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'reels'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS reels_storage_delete_authenticated_own_or_admin ON storage.objects;
CREATE POLICY reels_storage_delete_authenticated_own_or_admin
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'reels'
    AND (
      split_part(name, '/', 1) = auth.uid()::text
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin'
      )
    )
  );
