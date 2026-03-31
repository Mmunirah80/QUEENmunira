-- ============================================================
-- NAHAM — Final chef access rules (new account vs renewal)
-- Safe to run multiple times.
--
-- Access mode definition:
-- - new_pending      => approval_status not approved/rejected (lock main tabs)
-- - active           => approval_status = approved and not suspended
-- - renewal_blocked  => approval_status = approved and suspended
-- - rejected_account => approval_status = rejected
-- ============================================================

CREATE OR REPLACE FUNCTION public.chef_access_mode(
  p_approval_status text,
  p_suspended boolean
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN lower(coalesce(p_approval_status, 'pending')) = 'rejected' THEN 'rejected_account'
    WHEN lower(coalesce(p_approval_status, 'pending')) = 'approved'
         AND coalesce(p_suspended, false) = true THEN 'renewal_blocked'
    WHEN lower(coalesce(p_approval_status, 'pending')) = 'approved' THEN 'active'
    ELSE 'new_pending'
  END
$$;

CREATE OR REPLACE VIEW public.chef_access_modes AS
SELECT
  cp.id AS chef_id,
  cp.approval_status,
  cp.suspended,
  cp.rejection_reason,
  cp.suspension_reason,
  public.chef_access_mode(cp.approval_status, cp.suspended) AS access_mode
FROM public.chef_profiles cp;

COMMENT ON FUNCTION public.chef_access_mode(text, boolean)
IS 'Maps chef_profiles status to one of: new_pending, active, renewal_blocked, rejected_account.';

COMMENT ON VIEW public.chef_access_modes
IS 'Operational view for final account access logic and admin QA checks.';

