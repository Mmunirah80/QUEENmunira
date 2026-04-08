-- ============================================================
-- Strict inspection: remove legacy RPC that accepted manual penalties
-- Run after `supabase_inspection_random_v2.sql` (or alongside deploys).
--
-- `finalize_inspection_outcome(p_call_id, p_outcome, p_note)` is the only supported
-- path: admin records outcome; server computes warning / freeze duration from
-- inspection_violation_count (see that function).
-- ============================================================

BEGIN;

DROP FUNCTION IF EXISTS public.finalize_inspection_call(uuid, text, text, text);

COMMENT ON FUNCTION public.finalize_inspection_outcome(uuid, text, text) IS
  'Admin records inspection outcome only. Penalties (warning, 3d/7d/14d freeze) are computed inside this function — not passed in.';

COMMIT;
