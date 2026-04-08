-- Fix: transition_order_status (or triggers) calls is_valid_order_transition which is missing (42883).
-- Run in Supabase SQL editor. Tighten rules later if you need real state-machine validation.
--
-- WARNING (production): The body below is `SELECT true` — a placeholder so migrations/triggers stop
-- failing. It does NOT enforce a real state machine. Before relying on DB for security, replace this
-- with rules aligned to `supabase_order_state_machine.sql` (or your canonical transition table).
-- Do not assume invalid transitions are blocked while this returns true for all pairs.

-- If this errors on type name, use: from_status public.order_status (with schema).
CREATE OR REPLACE FUNCTION public.is_valid_order_transition(
  from_status order_status,
  to_status order_status
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT true;
$$;
