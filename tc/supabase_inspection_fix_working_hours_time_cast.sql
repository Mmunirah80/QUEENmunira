-- Hotfix: chef_is_within_working_hours_now called _inspection_parse_hhmm_to_minutes(time)
-- but only (text) exists → "function ... (time without time zone) does not exist"
-- Run in Supabase SQL Editor (idempotent). Safe to run multiple times.

BEGIN;

-- Belt + suspenders: overload for `time` columns (delegates to text parser).
CREATE OR REPLACE FUNCTION public._inspection_parse_hhmm_to_minutes (p_t time without time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT public._inspection_parse_hhmm_to_minutes (p_t::text);
$$;

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

COMMIT;
