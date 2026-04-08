-- ============================================================
-- CHAT RLS — template policies (run ONLY after supabase_chat_rls_audit.sql)
-- Review with your team. Backup / staging first.
--
-- Assumes: public.conversations (id, customer_id, chef_id, type, …)
--          public.messages (conversation_id, sender_id, content, …)
--
-- NAHAM PRODUCTION: Prefer the full bundle instead of this file alone:
--   • supabase_rls_authorization_hardening.sql — auth_is_active_user(), is_admin(),
--     conversations_update_participant, messages_update_own / messages_delete_own
--   • supabase_chat_rls_chef_freeze_v1.sql — optional freeze rules on messages/conversations
--   • supabase_admin_chef_support_chat.sql — admin ↔ chef threads (chef-admin)
--
-- If you already applied supabase_rls_authorization_hardening.sql, do NOT run this file:
-- it DROPs the same policy names and would replace stronger policies with this minimal set.
--
-- This template is a minimal baseline for empty projects or quick staging.
-- It does NOT include admin policies, blocked-user checks, or message update/delete.
-- ============================================================

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Idempotent: drop policies this file owns (names must match CREATE below)
DROP POLICY IF EXISTS conversations_select_participant ON public.conversations;
DROP POLICY IF EXISTS conversations_insert_participant ON public.conversations;
DROP POLICY IF EXISTS messages_select_participant ON public.messages;
DROP POLICY IF EXISTS messages_insert_participant ON public.messages;

-- Legacy names (older template iterations) — safe no-ops if absent
DROP POLICY IF EXISTS conversations_insert_customer_chef ON public.conversations;

-- Participants read their threads (customer-chef, customer-support with chef_id null,
-- chef-admin with customer_id = chef_id = cook, etc.)
CREATE POLICY conversations_select_participant
  ON public.conversations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_id
    OR auth.uid() = chef_id
  );

-- Start a thread: user must be the customer or the chef row they insert.
-- Do NOT restrict type to customer-chef only — the app also inserts customer-support
-- (chef_id NULL → only customer_id = auth.uid() matches) and chef-admin (same id in both).
CREATE POLICY conversations_insert_participant
  ON public.conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = customer_id
    OR auth.uid() = chef_id
  );

-- Optional: last_message / last_message_at updates from the app
-- CREATE POLICY conversations_update_participant
--   ON public.conversations
--   FOR UPDATE
--   TO authenticated
--   USING (auth.uid() = customer_id OR auth.uid() = chef_id)
--   WITH CHECK (auth.uid() = customer_id OR auth.uid() = chef_id);

-- Messages: read if you belong to the parent conversation
CREATE POLICY messages_select_participant
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

-- Messages: insert as yourself only, into a conversation you belong to
CREATE POLICY messages_insert_participant
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
