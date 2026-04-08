-- ============================================================
-- NAHAM — Chat RLS: block cooks from sending/creating threads while frozen
-- Run after supabase_rls_authorization_hardening.sql (or merge policies manually).
-- ============================================================
-- Aligns with orders: chef_profiles.freeze_until > now() means the cook is in an
-- active freeze window (soft or hard). They should not insert new chat rows or messages.

CREATE OR REPLACE FUNCTION public.auth_uid_chef_may_use_chat ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT (cp.freeze_until IS NULL OR cp.freeze_until <= now())
      FROM public.chef_profiles cp
      WHERE cp.id = auth.uid ()
    ),
    true
  );
$$;

COMMENT ON FUNCTION public.auth_uid_chef_may_use_chat () IS
  'False when auth user is a cook with freeze_until in the future; true for customers (no chef_profiles row).';

-- messages: chefs may not insert while frozen
DROP POLICY IF EXISTS messages_insert_participant ON public.messages;

CREATE POLICY messages_insert_participant
  ON public.messages FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND sender_id = auth.uid ()
    AND public.auth_uid_chef_may_use_chat ()
    AND EXISTS (
      SELECT 1
      FROM public.conversations c
      WHERE
        c.id = messages.conversation_id
        AND (c.customer_id = auth.uid () OR c.chef_id = auth.uid ())
    )
  );

-- conversations: chefs may not create a row where they are chef_id while frozen;
-- customers creating a thread with a chef are not blocked by this function.
DROP POLICY IF EXISTS conversations_insert_participant ON public.conversations;

CREATE POLICY conversations_insert_participant
  ON public.conversations FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND (customer_id = auth.uid () OR chef_id = auth.uid ())
    AND (
      chef_id IS DISTINCT FROM auth.uid ()
      OR public.auth_uid_chef_may_use_chat ()
    )
  );
