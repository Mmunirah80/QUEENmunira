-- ============================================================
-- NAHAM — Patch notifications INSERT RLS (recipient spoofing fix)
-- Run once if an older supabase_rls_authorization_hardening.sql defined
-- notifications_insert_system without restricting customer_id.
--
-- Safe to re-run: drops old policy name + recreates split policies.
-- Full hardening re-run also applies the same (see current hardening file).
-- ============================================================

DROP POLICY IF EXISTS notifications_insert_system ON public.notifications;
DROP POLICY IF EXISTS notifications_insert_admin ON public.notifications;
DROP POLICY IF EXISTS notifications_insert_own_recipient ON public.notifications;

CREATE POLICY notifications_insert_admin
  ON public.notifications FOR INSERT
  WITH CHECK (public.is_admin ());

CREATE POLICY notifications_insert_own_recipient
  ON public.notifications FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND NOT public.is_admin ()
    AND customer_id = auth.uid ()
  );

COMMENT ON POLICY notifications_insert_admin ON public.notifications IS
  'Admins may insert notifications for any recipient.';

COMMENT ON POLICY notifications_insert_own_recipient ON public.notifications IS
  'Non-admins may only insert rows where customer_id (recipient) is auth.uid().';
