-- ============================================================
-- Admin moderation: reels visibility, conversation queues, audit reads
-- Run in Supabase SQL editor after core RLS exists.
-- Idempotent (safe to re-run).
-- ============================================================

-- 1) Reels: hide from feed without deleting storage (app must filter is_hidden in customer queries)
ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_reels_is_hidden ON public.reels (is_hidden) WHERE is_hidden = true;

COMMENT ON COLUMN public.reels.is_hidden IS
  'When true, reel should not appear in public feeds; admins may toggle via moderation.';

DROP POLICY IF EXISTS reels_update_admin ON public.reels;
CREATE POLICY reels_update_admin
  ON public.reels FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 2) Conversations: moderation queue (no fake rows — filters are empty until you set values)
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS admin_moderation_state text NOT NULL DEFAULT 'none';

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS admin_reviewed_at timestamptz NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'conversations_admin_moderation_state_check'
  ) THEN
    ALTER TABLE public.conversations
      ADD CONSTRAINT conversations_admin_moderation_state_check
      CHECK (admin_moderation_state IN ('none', 'reported', 'flagged'));
  END IF;
END $$;

COMMENT ON COLUMN public.conversations.admin_moderation_state IS
  'Admin queue: none | reported | flagged. Use admin_reviewed_at when triage is complete.';

CREATE INDEX IF NOT EXISTS idx_conversations_admin_mod_state
  ON public.conversations (admin_moderation_state)
  WHERE admin_moderation_state <> 'none';

DROP POLICY IF EXISTS conversations_update_admin ON public.conversations;
CREATE POLICY conversations_update_admin
  ON public.conversations FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 3) Faster audit lookups for cook drill-down (admin_logs already exists from admin setup)
CREATE INDEX IF NOT EXISTS idx_admin_logs_target_id_created
  ON public.admin_logs (target_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_logs_payload_chef_id
  ON public.admin_logs ((payload ->> 'chef_id'), created_at DESC);

-- 4) RPC: cook-scoped admin log lines for activity timeline
CREATE OR REPLACE FUNCTION public.get_admin_logs_for_cook(
  p_cook_id uuid,
  p_limit int DEFAULT 60
)
RETURNS TABLE (
  id uuid,
  admin_id uuid,
  action text,
  target_table text,
  target_id text,
  payload jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.ensure_admin();
  RETURN QUERY
  SELECT l.id, l.admin_id, l.action, l.target_table, l.target_id, l.payload, l.created_at
  FROM public.admin_logs l
  WHERE
    l.target_id = p_cook_id::text
    OR (l.payload ->> 'chef_id') = p_cook_id::text
    OR (l.payload ->> 'cook_id') = p_cook_id::text
  ORDER BY l.created_at DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 200);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_logs_for_cook(uuid, int) TO authenticated;

COMMENT ON FUNCTION public.get_admin_logs_for_cook IS
  'Admin-only: returns admin_logs rows for a cook (target_id or payload chef_id/cook_id).';
