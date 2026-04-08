-- ============================================================
-- NAHAM — Block direct updates to inspection outcome / penalties
-- Run after supabase_inspection_random_v2.sql (needs set_config in finalize + cancel).
--
-- Admins must use finalize_inspection_outcome (outcome only) or cancel_inspection_call.
-- Chefs may still use chef_respond_inspection_call and may mark chef_result_seen.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.inspection_calls_prevent_manual_penalty ()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF nullif(current_setting('app.inspection_finalize_ctx', true), '') = '1' THEN
    RETURN NEW;
  END IF;

  -- Chef: answer the incoming call (pending → accepted / declined / missed)
  IF OLD.chef_id = auth.uid()
     AND coalesce(public.is_admin(auth.uid()), false) = false
     AND OLD.status = 'pending'
     AND NEW.status IN ('accepted', 'declined', 'missed')
     AND NEW.outcome IS NOT DISTINCT FROM OLD.outcome
     AND NEW.result_action IS NOT DISTINCT FROM OLD.result_action
     AND NEW.finalized_at IS NOT DISTINCT FROM OLD.finalized_at
     AND NEW.counted_as_violation IS NOT DISTINCT FROM OLD.counted_as_violation
     AND NEW.ended_at IS NOT DISTINCT FROM OLD.ended_at
  THEN
    RETURN NEW;
  END IF;

  -- Chef: dismiss outcome banner (chef_result_seen only)
  IF OLD.chef_id = auth.uid()
     AND coalesce(public.is_admin(auth.uid()), false) = false
     AND NEW.chef_result_seen IS DISTINCT FROM OLD.chef_result_seen
     AND NEW.outcome IS NOT DISTINCT FROM OLD.outcome
     AND NEW.result_action IS NOT DISTINCT FROM OLD.result_action
     AND NEW.finalized_at IS NOT DISTINCT FROM OLD.finalized_at
     AND NEW.counted_as_violation IS NOT DISTINCT FROM OLD.counted_as_violation
     AND NEW.status IS NOT DISTINCT FROM OLD.status
     AND NEW.violation_reason IS NOT DISTINCT FROM OLD.violation_reason
     AND NEW.result_note IS NOT DISTINCT FROM OLD.result_note
     AND NEW.ended_at IS NOT DISTINCT FROM OLD.ended_at
  THEN
    RETURN NEW;
  END IF;

  IF NEW.outcome IS DISTINCT FROM OLD.outcome
     OR NEW.result_action IS DISTINCT FROM OLD.result_action
     OR NEW.counted_as_violation IS DISTINCT FROM OLD.counted_as_violation
     OR NEW.finalized_at IS DISTINCT FROM OLD.finalized_at
     OR NEW.violation_reason IS DISTINCT FROM OLD.violation_reason
     OR NEW.result_note IS DISTINCT FROM OLD.result_note
     OR NEW.ended_at IS DISTINCT FROM OLD.ended_at
     OR (
       NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status IN ('completed', 'cancelled')
     )
  THEN
    RAISE EXCEPTION
      'inspection_calls: use finalize_inspection_outcome, cancel_inspection_call, chef_respond_inspection_call, or chef_result_seen only';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS inspection_calls_prevent_manual_penalty ON public.inspection_calls;

CREATE TRIGGER inspection_calls_prevent_manual_penalty
BEFORE UPDATE ON public.inspection_calls
FOR EACH ROW
EXECUTE PROCEDURE public.inspection_calls_prevent_manual_penalty ();

COMMENT ON FUNCTION public.inspection_calls_prevent_manual_penalty () IS
  'Rejects direct updates that set outcome/penalty/finalize fields; RPCs set app.inspection_finalize_ctx.';

COMMIT;
