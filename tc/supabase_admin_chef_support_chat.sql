-- ============================================================
-- NAHAM — Admin ↔ chef support thread (document review messages)
-- Run in Supabase SQL Editor after backup.
--
-- Threads: type = 'chef-admin', chef_id = cook, customer_id = cook
-- (same uuid satisfies participant RLS for the cook; admin writes via policies below.)
-- ============================================================

DROP POLICY IF EXISTS conversations_insert_admin ON public.conversations;
CREATE POLICY conversations_insert_admin
  ON public.conversations FOR INSERT
  WITH CHECK (
    public.is_admin ()
    AND type = 'chef-admin'
    AND chef_id IS NOT NULL
    AND customer_id = chef_id
  );

DROP POLICY IF EXISTS messages_insert_admin ON public.messages;
CREATE POLICY messages_insert_admin
  ON public.messages FOR INSERT
  WITH CHECK (
    public.is_admin ()
    AND sender_id = auth.uid ()
    AND EXISTS (
      SELECT 1
      FROM public.conversations c
      WHERE c.id = messages.conversation_id
    )
  );

COMMENT ON POLICY conversations_insert_admin ON public.conversations IS
  'Allows admins to open chef-admin support threads.';
