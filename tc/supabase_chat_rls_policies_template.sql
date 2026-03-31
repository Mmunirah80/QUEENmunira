-- ============================================================
-- CHAT RLS — template policies (run ONLY after supabase_chat_rls_audit.sql)
-- Review with your team. Backup / staging first.
-- Assumes: public.conversations (id, customer_id, chef_id, type)
--          public.messages (conversation_id, sender_id, content, ...)
-- ============================================================

-- Optional: drop old chat policies by name if you are replacing them
-- DROP POLICY IF EXISTS "conversations_select_participant" ON public.conversations;
-- DROP POLICY IF EXISTS "conversations_insert_participant" ON public.conversations;
-- DROP POLICY IF EXISTS "messages_select_participant" ON public.messages;
-- DROP POLICY IF EXISTS "messages_insert_participant" ON public.messages;

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Participants read their threads
CREATE POLICY "conversations_select_participant"
  ON public.conversations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_id
    OR auth.uid() = chef_id
  );

-- Customer or chef can start a customer-chef row (tighten type if needed)
CREATE POLICY "conversations_insert_customer_chef"
  ON public.conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    type = 'customer-chef'
    AND (
      auth.uid() = customer_id
      OR auth.uid() = chef_id
    )
  );

-- Optional: allow updating own metadata rows (last_message, etc.) — adjust columns
-- CREATE POLICY "conversations_update_participant"
--   ON public.conversations
--   FOR UPDATE
--   TO authenticated
--   USING (auth.uid() = customer_id OR auth.uid() = chef_id)
--   WITH CHECK (auth.uid() = customer_id OR auth.uid() = chef_id);

-- Messages: read if you are in the parent conversation
CREATE POLICY "messages_select_participant"
  ON public.messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND (c.customer_id = auth.uid() OR c.chef_id = auth.uid())
    )
  );

-- Messages: insert only as yourself, and only into a conversation you belong to
CREATE POLICY "messages_insert_participant"
  ON public.messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND (c.customer_id = auth.uid() OR c.chef_id = auth.uid())
    )
  );

-- If policies already exist with these exact names, use DROP first or rename.
