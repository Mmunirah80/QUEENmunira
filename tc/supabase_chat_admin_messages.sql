-- ============================================================
-- Allow admins to INSERT messages into any conversation (monitor / join).
-- SELECT is already covered in supabase_rls_authorization_hardening.sql
-- (conversations_select_participant, messages_select_participant with is_admin()).
--
-- Run after backup. If a policy named messages_insert_admin already exists
-- (e.g. from supabase_admin_chef_support_chat.sql), this replaces it with
-- the same broad check so customer–chef threads work too.
-- ============================================================

DROP POLICY IF EXISTS messages_insert_admin ON public.messages;

CREATE POLICY messages_insert_admin ON public.messages FOR INSERT TO authenticated
WITH CHECK (
  public.is_admin ()
  AND sender_id = auth.uid ()
  AND EXISTS (
    SELECT 1
    FROM public.conversations c
    WHERE c.id = messages.conversation_id
  )
);

COMMENT ON POLICY messages_insert_admin ON public.messages IS
  'Admins may post into any conversation row (customer–chef, support, etc.).';
