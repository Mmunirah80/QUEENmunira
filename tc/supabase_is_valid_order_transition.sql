-- Fix: transition_order_status (or triggers) calls is_valid_order_transition which is missing (42883).
-- Run in Supabase SQL editor. Tighten rules later if you need real state-machine validation.

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
