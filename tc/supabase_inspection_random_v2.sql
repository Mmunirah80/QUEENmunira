-- ============================================================
-- NAHAM — Random live inspection v2 (server-side eligibility, outcomes, escalation)
-- Run in Supabase SQL Editor after backup.
--
-- Fair random selection (built-in): min 7d after last completed visit, max 3 completed / 30d,
-- min 48h after last session start (any status — reduces repeat targeting / cancel spam),
-- then pick chef with longest time since last completed (ties → random). Each random start
-- stores selection_context JSON (chef_inspection_eligibility_snapshot + selection metadata).
--
-- Requires: public.ensure_admin(), public.is_admin(), chef_profiles, profiles, inspection_calls, chef_violations
--
-- Outcomes (admin submits only these — penalties are computed):
--   passed | no_answer | kitchen_not_clean | refused_inspection | admin_technical_issue
--
-- Violations (count toward escalation): no_answer, kitchen_not_clean, refused_inspection
-- Escalation: 1→warning, 2→freeze 3d, 3→freeze 7d, 4+→freeze 14d (repeat)
-- admin_technical_issue and passed do not count.
-- ============================================================

BEGIN;

-- Timezone for working-hours wall clock (chef local). Default UTC if unset.
ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS kitchen_timezone text NOT NULL DEFAULT 'UTC';

COMMENT ON COLUMN public.chef_profiles.kitchen_timezone IS
  'IANA timezone name for interpreting working_hours vs server UTC (e.g. Asia/Riyadh).';

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS inspection_violation_count integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.chef_profiles.inspection_violation_count IS
  'Count of countable random-inspection violations; drives automatic escalation.';

ALTER TABLE public.inspection_calls
  ADD COLUMN IF NOT EXISTS outcome text,
  ADD COLUMN IF NOT EXISTS counted_as_violation boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS ended_at timestamptz,
  ADD COLUMN IF NOT EXISTS selection_context jsonb NULL;

COMMENT ON COLUMN public.inspection_calls.selection_context IS
  'Snapshot at random-selection time: policy limits, checks passed, and why the chef was eligible.';

COMMENT ON COLUMN public.inspection_calls.outcome IS
  'Admin outcome: passed | no_answer | kitchen_not_clean | refused_inspection | admin_technical_issue';

-- Relax / extend status constraint
ALTER TABLE public.inspection_calls DROP CONSTRAINT IF EXISTS inspection_calls_status_allowed;
ALTER TABLE public.inspection_calls
  ADD CONSTRAINT inspection_calls_status_allowed
  CHECK (status IN ('pending', 'accepted', 'declined', 'missed', 'completed', 'cancelled'));

-- ----------------------------------------------------------------
-- Parse "HH:mm" or "H:mm" to minutes [0, 1439]
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._inspection_parse_hhmm_to_minutes (p_text text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  t text := trim(coalesce(p_text, ''));
  p int;
  h int;
  m int;
BEGIN
  IF t = '' THEN
    RETURN NULL;
  END IF;
  p := position(':' IN t);
  IF p < 1 THEN
    RETURN NULL;
  END IF;
  h := (substring(t FROM 1 FOR p - 1))::integer;
  m := (substring(t FROM p + 1 FOR 2))::integer;
  IF h IS NULL OR m IS NULL THEN
    RETURN NULL;
  END IF;
  IF h < 0 OR h > 23 OR m < 0 OR m > 59 THEN
    RETURN NULL;
  END IF;
  RETURN h * 60 + m;
END;
$$;

-- Same parser when columns are `time` / `time without time zone` (avoids missing overload errors).
CREATE OR REPLACE FUNCTION public._inspection_parse_hhmm_to_minutes (p_t time without time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT public._inspection_parse_hhmm_to_minutes (p_t::text);
$$;

-- ----------------------------------------------------------------
-- True if chef is within configured working hours (matches app rules approximately).
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chef_is_within_working_hours_now (p_chef_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  cp record;
  v_tz text;
  v_local timestamptz;
  v_now_min int;
  v_isodow int;
  v_key text;
  v_day jsonb;
  v_open text;
  v_close text;
  v_a int;
  v_b int;
  v_s int;
  v_e int;
BEGIN
  SELECT
    working_hours,
    working_hours_start,
    working_hours_end,
    kitchen_timezone
  INTO cp
  FROM public.chef_profiles
  WHERE id = p_chef_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  v_tz := nullif(trim(coalesce(cp.kitchen_timezone, '')), '');
  IF v_tz IS NULL THEN
    v_tz := 'UTC';
  END IF;

  v_local := timezone(v_tz, now());
  v_now_min :=
    extract(hour FROM v_local)::integer * 60 + extract(minute FROM v_local)::integer;
  v_isodow := extract(isodow FROM v_local)::integer;

  v_key := (ARRAY['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])[v_isodow];

  -- Empty json object {} => closed all week (matches Dart)
  IF cp.working_hours IS NOT NULL AND cp.working_hours = '{}'::jsonb THEN
    RETURN false;
  END IF;

  IF cp.working_hours IS NOT NULL AND jsonb_typeof(cp.working_hours) = 'object'
     AND cp.working_hours <> '{}'::jsonb THEN
    v_day := cp.working_hours -> v_key;
    IF v_day IS NOT NULL AND jsonb_typeof(v_day) = 'object' THEN
      IF (v_day ->> 'enabled') = 'false' THEN
        RETURN false;
      END IF;
      v_open := v_day ->> 'open';
      v_close := v_day ->> 'close';
      IF v_open IS NOT NULL AND v_close IS NOT NULL AND length(trim(v_open)) > 0 AND length(trim(v_close)) > 0 THEN
        v_a := public._inspection_parse_hhmm_to_minutes(v_open);
        v_b := public._inspection_parse_hhmm_to_minutes(v_close);
        IF v_a IS NULL OR v_b IS NULL THEN
          RETURN false;
        END IF;
        IF v_b >= v_a THEN
          RETURN v_now_min >= v_a AND v_now_min <= v_b;
        ELSE
          RETURN v_now_min >= v_a OR v_now_min <= v_b;
        END IF;
      END IF;
    END IF;
    -- JSON exists but today has no slot: fall back to legacy columns
    -- Cast to text: columns may be `time` type; only (text) overload exists.
    v_s := public._inspection_parse_hhmm_to_minutes(cp.working_hours_start::text);
    v_e := public._inspection_parse_hhmm_to_minutes(cp.working_hours_end::text);
    IF v_s IS NOT NULL AND v_e IS NOT NULL THEN
      IF v_e >= v_s THEN
        RETURN v_now_min >= v_s AND v_now_min <= v_e;
      ELSE
        RETURN v_now_min >= v_s OR v_now_min <= v_e;
      END IF;
    END IF;
    RETURN false;
  END IF;

  -- Legacy columns only
  v_s := public._inspection_parse_hhmm_to_minutes(cp.working_hours_start::text);
  v_e := public._inspection_parse_hhmm_to_minutes(cp.working_hours_end::text);
  IF v_s IS NULL OR v_e IS NULL THEN
    RETURN true;
  END IF;
  IF v_e >= v_s THEN
    RETURN v_now_min >= v_s AND v_now_min <= v_e;
  ELSE
    RETURN v_now_min >= v_s OR v_now_min <= v_e;
  END IF;
END;
$$;

-- ----------------------------------------------------------------
-- Eligibility snapshot (audit trail) + pool rules — single source of truth
-- Fair policy: min gap after last *completed* visit, cap per 30d, min gap after any
-- session start (stops cancel-spam retargeting), then pick chef with longest time
-- since last completed (ties → random()).
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chef_inspection_eligibility_snapshot (p_chef_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := clock_timestamp();
  cp record;
  v_blocked boolean;
  v_last_completed timestamptz;
  v_last_started timestamptz;
  v_hours_since_completed numeric;
  v_count_30d int;
  v_has_active boolean;
  v_cooldown_ok boolean;
  v_frequency_ok boolean;
  v_session_gap_ok boolean;
  v_min_interval interval := interval '7 days';
  v_min_session_gap interval := interval '48 hours';
  v_max_per_30 int := 3;
  v_eligible boolean := true;
  v_reasons text[] := ARRAY[]::text[];
  v_pass text[] := ARRAY[]::text[];
  v_approved boolean;
  v_hours_ok boolean;
BEGIN
  IF p_chef_id IS NULL THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'evaluated_at', v_now,
      'failure_reasons', jsonb_build_array('null_chef_id')
    );
  END IF;

  SELECT coalesce(is_blocked, false) INTO v_blocked FROM public.profiles WHERE id = p_chef_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('eligible', false, 'evaluated_at', v_now, 'failure_reasons', jsonb_build_array('no_profile'));
  END IF;
  IF v_blocked THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'profile_blocked');
  END IF;

  SELECT
    lower(trim(coalesce(approval_status, ''))) AS approval_status,
    initial_approval_at,
    coalesce(is_online, false) AS is_online,
    coalesce(suspended, false) AS suspended,
    coalesce(vacation_mode, false) AS vacation_mode,
    vacation_start,
    vacation_end,
    freeze_until,
    coalesce(kitchen_timezone, 'UTC') AS kitchen_tz
  INTO cp
  FROM public.chef_profiles
  WHERE id = p_chef_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('eligible', false, 'evaluated_at', v_now, 'failure_reasons', jsonb_build_array('no_chef_profile'));
  END IF;

  v_approved := (cp.approval_status = 'approved');
  IF NOT v_approved THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'not_approved');
  END IF;

  IF cp.initial_approval_at IS NULL THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'initial_approval_missing');
  END IF;

  IF NOT cp.is_online THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'not_online');
  END IF;

  IF cp.suspended THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'suspended');
  END IF;

  IF cp.vacation_mode THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'vacation_mode');
  END IF;

  IF cp.vacation_start IS NOT NULL AND cp.vacation_end IS NOT NULL THEN
    IF (v_now::date >= cp.vacation_start::date AND v_now::date <= cp.vacation_end::date) THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'scheduled_vacation');
    END IF;
  END IF;

  IF cp.freeze_until IS NOT NULL AND cp.freeze_until > v_now THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'frozen');
  END IF;

  v_hours_ok := public.chef_is_within_working_hours_now (p_chef_id);
  IF NOT v_hours_ok THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'outside_working_hours');
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.inspection_calls c
    WHERE c.chef_id = p_chef_id
      AND c.status IN ('pending', 'accepted')
  ) INTO v_has_active;
  IF v_has_active THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'active_inspection_call');
  END IF;

  SELECT MAX(c.finalized_at)
  INTO v_last_completed
  FROM public.inspection_calls c
  WHERE c.chef_id = p_chef_id
    AND c.status = 'completed'
    AND c.finalized_at IS NOT NULL;

  IF v_last_completed IS NULL THEN
    v_hours_since_completed := NULL;
    v_cooldown_ok := true;
  ELSE
    v_hours_since_completed := EXTRACT(EPOCH FROM (v_now - v_last_completed)) / 3600.0;
    v_cooldown_ok := (v_now - v_last_completed) >= v_min_interval;
    IF NOT v_cooldown_ok THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'cooldown_not_met_since_last_completed');
    END IF;
  END IF;

  SELECT COUNT(*)::int
  INTO v_count_30d
  FROM public.inspection_calls c
  WHERE c.chef_id = p_chef_id
    AND c.status = 'completed'
    AND c.finalized_at IS NOT NULL
    AND c.finalized_at > v_now - interval '30 days';

  v_frequency_ok := (v_count_30d < v_max_per_30);
  IF NOT v_frequency_ok THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'max_inspections_per_30_days');
  END IF;

  SELECT MAX(c.started_at)
  INTO v_last_started
  FROM public.inspection_calls c
  WHERE c.chef_id = p_chef_id
    AND c.started_at IS NOT NULL;

  IF v_last_started IS NULL THEN
    v_session_gap_ok := true;
  ELSE
    v_session_gap_ok := (v_now - v_last_started) >= v_min_session_gap;
    IF NOT v_session_gap_ok THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'min_session_gap_since_last_started_not_met');
    END IF;
  END IF;

  IF v_eligible THEN
    IF NOT coalesce(v_blocked, false) THEN
      v_pass := array_append(v_pass, 'profile_not_blocked');
    END IF;
    IF v_approved THEN
      v_pass := array_append(v_pass, 'chef_approved');
    END IF;
    IF cp.initial_approval_at IS NOT NULL THEN
      v_pass := array_append(v_pass, 'initial_approval_recorded');
    END IF;
    IF cp.is_online THEN
      v_pass := array_append(v_pass, 'chef_marked_online');
    END IF;
    IF NOT cp.suspended THEN
      v_pass := array_append(v_pass, 'not_suspended');
    END IF;
    IF NOT cp.vacation_mode THEN
      v_pass := array_append(v_pass, 'not_in_vacation_mode');
    END IF;
    IF v_hours_ok THEN
      v_pass := array_append(v_pass, 'within_working_hours');
    END IF;
    IF NOT v_has_active THEN
      v_pass := array_append(v_pass, 'no_active_inspection_session');
    END IF;
    IF v_cooldown_ok THEN
      v_pass := array_append(v_pass, 'min_gap_since_last_completed_ok');
    END IF;
    IF v_frequency_ok THEN
      v_pass := array_append(v_pass, 'under_rolling_30_day_frequency_cap');
    END IF;
    IF v_session_gap_ok THEN
      v_pass := array_append(v_pass, 'min_gap_since_last_session_start_ok');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'eligible', v_eligible,
    'evaluated_at', v_now,
    'why_eligible', to_jsonb(v_pass),
    'policy', jsonb_build_object(
      'min_interval_between_completed', v_min_interval::text,
      'min_interval_between_completed_hours', EXTRACT(EPOCH FROM v_min_interval) / 3600.0,
      'min_interval_between_session_starts', v_min_session_gap::text,
      'min_interval_between_session_starts_hours', EXTRACT(EPOCH FROM v_min_session_gap) / 3600.0,
      'max_completed_inspections_per_30_days', v_max_per_30,
      'rolling_window_days', 30
    ),
    'checks', jsonb_build_object(
      'profile_not_blocked', NOT coalesce(v_blocked, false),
      'approval_status_approved', v_approved,
      'initial_approval_at_set', cp.initial_approval_at IS NOT NULL,
      'is_online', cp.is_online,
      'not_suspended', NOT cp.suspended,
      'not_on_vacation_day', NOT (
        cp.vacation_start IS NOT NULL AND cp.vacation_end IS NOT NULL
        AND (v_now::date >= cp.vacation_start::date AND v_now::date <= cp.vacation_end::date)
      ),
      'not_frozen', NOT (cp.freeze_until IS NOT NULL AND cp.freeze_until > v_now),
      'within_working_hours', v_hours_ok,
      'no_active_pending_or_accepted_call', NOT v_has_active,
      'cooldown_since_last_completed_ok', v_cooldown_ok,
      'completed_inspections_last_30_days', v_count_30d,
      'under_30_day_frequency_cap', v_frequency_ok,
      'session_start_gap_ok', v_session_gap_ok
    ),
    'last_completed_inspection_at', v_last_completed,
    'hours_since_last_completed', v_hours_since_completed,
    'last_started_at', v_last_started,
    'hours_since_last_started', CASE
      WHEN v_last_started IS NULL THEN NULL
      ELSE EXTRACT(EPOCH FROM (v_now - v_last_started)) / 3600.0
    END,
    'failure_reasons', COALESCE(to_jsonb(v_reasons), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.chef_eligible_for_random_inspection (p_chef_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT coalesce(
    (public.chef_inspection_eligibility_snapshot (p_chef_id) ->> 'eligible')::boolean,
    false
  );
$$;

REVOKE ALL ON FUNCTION public.chef_inspection_eligibility_snapshot (uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chef_inspection_eligibility_snapshot (uuid) TO authenticated;

COMMENT ON FUNCTION public.chef_inspection_eligibility_snapshot (uuid) IS
  'Eligibility audit JSON: policy limits, booleans, why_eligible when true, failure_reasons when false.';

-- ----------------------------------------------------------------
-- Random eligible chef → new row (fair: longest since last completed, ties → random)
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_random_inspection_call ()
RETURNS public.inspection_calls
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_chef uuid;
  v_now timestamptz := clock_timestamp();
  v_channel text;
  v_row public.inspection_calls;
  v_snap jsonb;
  v_last_completed timestamptz;
  v_gap_seconds numeric;
  v_pool int;
BEGIN
  PERFORM public.ensure_admin();

  SELECT COUNT(*)::int
  INTO v_pool
  FROM public.chef_profiles cp
  WHERE public.chef_eligible_for_random_inspection (cp.id);

  IF v_pool IS NULL OR v_pool < 1 THEN
    RAISE EXCEPTION 'no eligible chefs';
  END IF;

  SELECT e.chef_id, e.last_completed
  INTO v_chef, v_last_completed
  FROM (
    SELECT
      cp.id AS chef_id,
      (
        SELECT MAX(c.finalized_at)
        FROM public.inspection_calls c
        WHERE c.chef_id = cp.id
          AND c.status = 'completed'
          AND c.finalized_at IS NOT NULL
      ) AS last_completed
    FROM public.chef_profiles cp
    WHERE public.chef_eligible_for_random_inspection (cp.id)
  ) e
  ORDER BY
    COALESCE(EXTRACT(EPOCH FROM (v_now - e.last_completed)), 1e20) DESC,
    random()
  LIMIT 1;

  IF v_chef IS NULL THEN
    RAISE EXCEPTION 'no eligible chefs';
  END IF;

  v_gap_seconds :=
    CASE
      WHEN v_last_completed IS NULL THEN NULL
      ELSE EXTRACT(EPOCH FROM (v_now - v_last_completed))
    END;

  v_snap := public.chef_inspection_eligibility_snapshot (v_chef);
  v_snap := v_snap || jsonb_build_object(
    'selection', jsonb_build_object(
      'method', 'fair_longest_time_since_last_completed',
      'method_detail', 'Among eligible chefs, prefer those with longest gap since last completed inspection; ties broken by random().',
      'eligible_pool_size', v_pool,
      'last_completed_at', v_last_completed,
      'seconds_since_last_completed', v_gap_seconds,
      'never_completed_inspection', v_last_completed IS NULL,
      'tie_break', 'random'
    )
  );

  v_channel :=
    'inspection_' || replace(v_chef::text, '-', '') || '_' || floor(extract(epoch FROM v_now))::bigint::text;

  INSERT INTO public.inspection_calls (
    chef_id,
    admin_id,
    channel_name,
    status,
    started_at,
    selection_context
  )
  VALUES (
    v_chef,
    auth.uid(),
    v_channel,
    'pending',
    v_now,
    v_snap
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.start_random_inspection_call () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_random_inspection_call () TO authenticated;

-- ----------------------------------------------------------------
-- Replace start_inspection_call: keep for backwards compat but enforce eligibility
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_inspection_call (p_chef_id uuid)
RETURNS public.inspection_calls
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_channel text;
  v_row public.inspection_calls;
BEGIN
  PERFORM public.ensure_admin();

  IF p_chef_id IS NULL THEN
    RAISE EXCEPTION 'chef_id is required';
  END IF;

  IF NOT public.chef_eligible_for_random_inspection (p_chef_id) THEN
    RAISE EXCEPTION 'Chef is not currently eligible for inspection';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.inspection_calls c
    WHERE c.chef_id = p_chef_id
      AND c.status IN ('pending', 'accepted')
  ) THEN
    RAISE EXCEPTION 'Chef already has an active inspection call';
  END IF;

  v_channel :=
    'inspection_' || replace(p_chef_id::text, '-', '') || '_' || floor(extract(epoch FROM v_now))::bigint::text;

  INSERT INTO public.inspection_calls (
    chef_id,
    admin_id,
    channel_name,
    status,
    started_at
  )
  VALUES (
    p_chef_id,
    auth.uid(),
    v_channel,
    'pending',
    v_now
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- ----------------------------------------------------------------
-- Finalize with outcome only — automatic escalation (no manual freeze level)
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.finalize_inspection_outcome (
  p_call_id uuid,
  p_outcome text,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_call public.inspection_calls;
  v_out text := lower(trim(coalesce(p_outcome, '')));
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_chef uuid;
  v_now timestamptz := clock_timestamp();
  v_count int;
  v_action text;
  v_freeze_until timestamptz;
  v_counted boolean := false;
  v_result_action text;
  v_violation_legacy text;
BEGIN
  PERFORM public.ensure_admin();
  -- Allows BEFORE UPDATE trigger to permit RPC-only writes to outcome / penalties.
  PERFORM set_config('app.inspection_finalize_ctx', '1', true);

  IF p_call_id IS NULL THEN
    RAISE EXCEPTION 'call_id is required';
  END IF;

  IF v_out NOT IN (
    'passed',
    'no_answer',
    'kitchen_not_clean',
    'refused_inspection',
    'admin_technical_issue'
  ) THEN
    RAISE EXCEPTION 'invalid outcome';
  END IF;

  SELECT *
  INTO v_call
  FROM public.inspection_calls
  WHERE id = p_call_id;

  IF v_call.id IS NULL THEN
    RAISE EXCEPTION 'inspection call not found';
  END IF;

  IF v_call.status = 'completed' THEN
    RETURN jsonb_build_object(
      'call_id', v_call.id,
      'already_completed', true,
      'outcome', v_call.outcome
    );
  END IF;

  IF v_call.status = 'cancelled' THEN
    RAISE EXCEPTION 'inspection call was cancelled';
  END IF;

  v_chef := v_call.chef_id;

  IF v_out IN ('no_answer', 'kitchen_not_clean', 'refused_inspection') THEN
    v_counted := true;
  END IF;

  v_violation_legacy := CASE v_out
    WHEN 'no_answer' THEN 'no_answer'
    WHEN 'kitchen_not_clean' THEN 'failed_hygiene_check'
    WHEN 'refused_inspection' THEN 'declined_call'
    ELSE NULL
  END;

  -- Non-violation outcomes
  IF NOT v_counted THEN
    v_result_action := CASE WHEN v_out = 'passed' THEN 'pass' ELSE 'admin_technical_issue' END;

    UPDATE public.inspection_calls
    SET
      status = 'completed',
      outcome = v_out,
      counted_as_violation = false,
      result_action = v_result_action,
      violation_reason = NULL,
      result_note = v_note,
      chef_result_seen = false,
      finalized_at = v_now,
      ended_at = v_now
    WHERE id = p_call_id;

    RETURN jsonb_build_object(
      'call_id', p_call_id,
      'outcome', v_out,
      'result_action', v_result_action,
      'counted_as_violation', false
    );
  END IF;

  -- Violation: increment inspection violation count and escalate
  UPDATE public.chef_profiles
  SET inspection_violation_count = coalesce(inspection_violation_count, 0) + 1
  WHERE id = v_chef
  RETURNING inspection_violation_count INTO v_count;

  IF v_count IS NULL THEN
    RAISE EXCEPTION 'chef profile not found';
  END IF;

  IF v_count = 1 THEN
    v_action := 'warning';
    UPDATE public.chef_profiles
    SET warning_count = coalesce(warning_count, 0) + 1
    WHERE id = v_chef;
  ELSIF v_count = 2 THEN
    v_action := 'freeze_3d';
    v_freeze_until := v_now + interval '3 days';
  ELSIF v_count = 3 THEN
    v_action := 'freeze_7d';
    v_freeze_until := v_now + interval '7 days';
  ELSE
    v_action := 'freeze_14d';
    v_freeze_until := v_now + interval '14 days';
  END IF;

  IF v_action LIKE 'freeze%' THEN
    UPDATE public.chef_profiles
    SET
      freeze_until = v_freeze_until,
      freeze_started_at = v_now,
      freeze_type = 'soft',
      freeze_reason = coalesce(
        v_note,
        'Automatic freeze from random kitchen inspection (violation #' || v_count::text || ')'
      ),
      is_online = false
    WHERE id = v_chef;
  END IF;

  INSERT INTO public.chef_violations (
    chef_id,
    inspection_call_id,
    admin_id,
    violation_index,
    reason,
    action_applied,
    note
  )
  VALUES (
    v_chef,
    p_call_id,
    auth.uid(),
    v_count,
    v_out,
    v_action,
    v_note
  );

  UPDATE public.inspection_calls
  SET
    status = 'completed',
    outcome = v_out,
    counted_as_violation = true,
    result_action = v_action,
    violation_reason = v_violation_legacy,
    result_note = v_note,
    chef_result_seen = false,
    finalized_at = v_now,
    ended_at = v_now
  WHERE id = p_call_id;

  RETURN jsonb_build_object(
    'call_id', p_call_id,
    'outcome', v_out,
    'result_action', v_action,
    'inspection_violation_count', v_count,
    'freeze_until', v_freeze_until,
    'counted_as_violation', true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_inspection_outcome (uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finalize_inspection_outcome (uuid, text, text) TO authenticated;

-- Optional: cancel without penalty (admin backs out before outcome)
CREATE OR REPLACE FUNCTION public.cancel_inspection_call (p_call_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_call public.inspection_calls;
BEGIN
  PERFORM public.ensure_admin();
  PERFORM set_config('app.inspection_finalize_ctx', '1', true);

  SELECT * INTO v_call FROM public.inspection_calls WHERE id = p_call_id;
  IF v_call.id IS NULL THEN
    RAISE EXCEPTION 'inspection call not found';
  END IF;

  IF v_call.status NOT IN ('pending', 'accepted') THEN
    RAISE EXCEPTION 'call cannot be cancelled';
  END IF;

  UPDATE public.inspection_calls
  SET
    status = 'cancelled',
    ended_at = clock_timestamp(),
    outcome = NULL,
    counted_as_violation = false,
    result_action = NULL,
    result_note = 'Cancelled by admin before completion'
  WHERE id = p_call_id;
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_inspection_call (uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_inspection_call (uuid) TO authenticated;

COMMENT ON FUNCTION public.start_random_inspection_call () IS
  'Admin: fair pick among eligible chefs (longest since last completed; ties random); stores selection_context audit JSON.';

COMMENT ON FUNCTION public.finalize_inspection_outcome (uuid, text, text) IS
  'Admin: outcome only (passed | no_answer | kitchen_not_clean | refused_inspection | admin_technical_issue). '
  'Penalties (warning / freeze_3d / freeze_7d / freeze_14d) are computed here from inspection_violation_count — never supplied by the client.';

ALTER TABLE public.inspection_calls DROP CONSTRAINT IF EXISTS inspection_calls_result_action_allowed;

ALTER TABLE public.inspection_calls
  ADD CONSTRAINT inspection_calls_result_action_allowed
  CHECK (
    result_action IS NULL
    OR result_action IN (
      'pass',
      'warning',
      'freeze_3d',
      'freeze_7d',
      'freeze_14d',
      'blocked',
      'admin_technical_issue'
    )
  );

DROP FUNCTION IF EXISTS public.finalize_inspection_call (uuid, text, text, text);

COMMIT;
