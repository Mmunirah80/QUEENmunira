-- ============================================================
-- NAHAM — Authorization hardening (RLS + helpers + admin_logs)
-- Run in Supabase SQL Editor after backup.
-- Prerequisites: tables profiles, chef_profiles, menu_items, orders,
-- order_items, notifications exist. conversations/messages created below if missing.
-- ============================================================
-- Realtime (blocked user UX): Database → Replication → enable `profiles`
--   ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
-- ============================================================

-- ─── 1) Schema: is_blocked + admin_logs + chat (if missing) ─────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_blocked boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.is_blocked IS 'Suspended accounts: RLS denies app data; own profile row still readable.';

CREATE TABLE IF NOT EXISTS public.admin_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  action text NOT NULL,
  target_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_logs_created_at_idx ON public.admin_logs (created_at DESC);

CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  customer_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  chef_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  type text,
  created_at timestamptz NOT NULL DEFAULT now ()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  conversation_id uuid NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  content text,
  created_at timestamptz NOT NULL DEFAULT now ()
);

CREATE INDEX IF NOT EXISTS messages_conversation_id_idx ON public.messages (conversation_id);

-- Columns some DBs lack; safe to re-run before the VIEW.
ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS warning_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS approval_status text DEFAULT 'pending';

-- Safe columns for customer browse (Flutter should query this VIEW, not chef_profiles for listings).
CREATE OR REPLACE VIEW public.chef_profiles_public AS
SELECT
  id,
  kitchen_name,
  is_online,
  vacation_mode,
  working_hours_start,
  working_hours_end,
  bio,
  kitchen_city,
  approval_status,
  warning_count,
  created_at,
  updated_at
FROM public.chef_profiles;

-- ─── 2) SECURITY DEFINER helpers (avoid RLS recursion on profiles) ──

CREATE OR REPLACE FUNCTION public.auth_role ()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Two overloads on purpose: NO default on the uuid form — avoids clash with is_admin()
-- if supabase_admin_role_setup ever used is_admin(uuid DEFAULT auth.uid()) (ambiguous in PG).
CREATE OR REPLACE FUNCTION public.is_admin (p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_uid
      AND p.role = 'admin'
      AND COALESCE(p.is_blocked, false) = false
  );
$$;

CREATE OR REPLACE FUNCTION public.is_admin ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.is_admin (auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.auth_is_blocked ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT is_blocked FROM public.profiles WHERE id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.auth_is_active_user ()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid () IS NOT NULL AND NOT public.auth_is_blocked ();
$$;

-- ─── 3) Trigger: no self-unblock / no self-promotion to admin ─────────

CREATE OR REPLACE FUNCTION public.enforce_profiles_integrity ()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NOT public.is_admin () THEN
      IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
        RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
      END IF;
      IF NEW.role IS DISTINCT FROM OLD.role AND NEW.role = 'admin' THEN
        RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_integrity ON public.profiles;
CREATE TRIGGER trg_profiles_integrity
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profiles_integrity ();

-- ─── 4) Drop existing policies on target tables ─────────────────────────

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'profiles', 'chef_profiles', 'menu_items', 'orders', 'order_items',
        'conversations', 'messages', 'notifications', 'admin_logs'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chef_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;

-- profiles — own row always readable (incl. is_blocked); admin reads all
CREATE POLICY profiles_select_own
  ON public.profiles FOR SELECT
  USING (auth.uid () = id OR public.is_admin ());

CREATE POLICY profiles_insert_own
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid () = id OR public.is_admin ());

CREATE POLICY profiles_update_own_or_admin
  ON public.profiles FOR UPDATE
  USING (auth.uid () = id OR public.is_admin ())
  WITH CHECK (auth.uid () = id OR public.is_admin ());

CREATE POLICY profiles_delete_admin
  ON public.profiles FOR DELETE
  USING (public.is_admin ());

-- chef_profiles — chefs see own full row; customers may read approved rows (prefer chef_profiles_public in app to omit bank_*).
CREATE POLICY chef_profiles_select
  ON public.chef_profiles FOR SELECT
  USING (
    public.is_admin ()
    OR auth.uid () = id
    OR (
      public.auth_role () = 'customer'
      AND approval_status = 'approved'
    )
  );

CREATE POLICY chef_profiles_insert_own_chef
  ON public.chef_profiles FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'chef'
    AND auth.uid () = id
  );

CREATE POLICY chef_profiles_update_owner_admin
  ON public.chef_profiles FOR UPDATE
  USING (public.is_admin () OR (public.auth_is_active_user () AND auth.uid () = id))
  WITH CHECK (public.is_admin () OR (public.auth_is_active_user () AND auth.uid () = id));

CREATE POLICY chef_profiles_delete_admin
  ON public.chef_profiles FOR DELETE
  USING (public.is_admin ());

-- menu_items
CREATE POLICY menu_items_select
  ON public.menu_items FOR SELECT
  USING (
    public.is_admin ()
    OR public.auth_role () = 'customer'
    OR (public.auth_role () = 'chef' AND chef_id = auth.uid ())
  );

CREATE POLICY menu_items_insert_chef
  ON public.menu_items FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'chef'
    AND chef_id = auth.uid ()
  );

CREATE POLICY menu_items_update_chef
  ON public.menu_items FOR UPDATE
  USING (
    public.auth_is_active_user ()
    AND public.auth_role () = 'chef'
    AND chef_id = auth.uid ()
  )
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'chef'
    AND chef_id = auth.uid ()
  );

CREATE POLICY menu_items_delete_chef
  ON public.menu_items FOR DELETE
  USING (
    public.auth_is_active_user ()
    AND public.auth_role () = 'chef'
    AND chef_id = auth.uid ()
  );

-- orders
CREATE POLICY orders_select_parties
  ON public.orders FOR SELECT
  USING (
    public.is_admin ()
    OR (
      public.auth_is_active_user ()
      AND (customer_id = auth.uid () OR chef_id = auth.uid ())
    )
  );

CREATE POLICY orders_insert_customer
  ON public.orders FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'customer'
    AND customer_id = auth.uid ()
  );

CREATE POLICY orders_update_parties
  ON public.orders FOR UPDATE
  USING (
    public.auth_is_active_user ()
    AND (
      public.is_admin ()
      OR (public.auth_role () = 'customer' AND customer_id = auth.uid ())
      OR (public.auth_role () = 'chef' AND chef_id = auth.uid ())
    )
  )
  WITH CHECK (
    public.auth_is_active_user ()
    AND (
      public.is_admin ()
      OR (public.auth_role () = 'customer' AND customer_id = auth.uid ())
      OR (public.auth_role () = 'chef' AND chef_id = auth.uid ())
    )
  );

CREATE POLICY orders_delete_admin
  ON public.orders FOR DELETE
  USING (public.is_admin ());

-- order_items
CREATE POLICY order_items_select_via_order
  ON public.order_items FOR SELECT
  USING (
    public.is_admin ()
    OR EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE
        o.id = order_items.order_id
        AND public.auth_is_active_user ()
        AND (o.customer_id = auth.uid () OR o.chef_id = auth.uid ())
    )
  );

CREATE POLICY order_items_insert_customer
  ON public.order_items FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'customer'
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE
        o.id = order_items.order_id
        AND o.customer_id = auth.uid ()
    )
  );

CREATE POLICY order_items_update_parties
  ON public.order_items FOR UPDATE
  USING (
    public.auth_is_active_user ()
    AND (
      EXISTS (
        SELECT 1
        FROM public.orders o
        WHERE
          o.id = order_items.order_id
          AND (o.customer_id = auth.uid () OR o.chef_id = auth.uid ())
      )
      OR public.is_admin ()
    )
  );

CREATE POLICY order_items_delete_parties
  ON public.order_items FOR DELETE
  USING (
    public.auth_is_active_user ()
    AND (
      EXISTS (
        SELECT 1
        FROM public.orders o
        WHERE
          o.id = order_items.order_id
          AND o.customer_id = auth.uid ()
      )
      OR public.is_admin ()
    )
  );

-- conversations (chat threads)
CREATE POLICY conversations_select_participant
  ON public.conversations FOR SELECT
  USING (
    public.is_admin ()
    OR (
      public.auth_is_active_user ()
      AND (customer_id = auth.uid () OR chef_id = auth.uid ())
    )
  );

CREATE POLICY conversations_insert_participant
  ON public.conversations FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND (customer_id = auth.uid () OR chef_id = auth.uid ())
  );

CREATE POLICY conversations_update_participant
  ON public.conversations FOR UPDATE
  USING (
    public.auth_is_active_user ()
    AND (customer_id = auth.uid () OR chef_id = auth.uid ())
  );

CREATE POLICY conversations_delete_admin
  ON public.conversations FOR DELETE
  USING (public.is_admin ());

-- messages
CREATE POLICY messages_select_participant
  ON public.messages FOR SELECT
  USING (
    public.is_admin ()
    OR (
      public.auth_is_active_user ()
      AND EXISTS (
        SELECT 1
        FROM public.conversations c
        WHERE
          c.id = messages.conversation_id
          AND (c.customer_id = auth.uid () OR c.chef_id = auth.uid ())
      )
    )
  );

CREATE POLICY messages_insert_participant
  ON public.messages FOR INSERT
  WITH CHECK (
    public.auth_is_active_user ()
    AND sender_id = auth.uid ()
    AND EXISTS (
      SELECT 1
      FROM public.conversations c
      WHERE
        c.id = messages.conversation_id
        AND (c.customer_id = auth.uid () OR c.chef_id = auth.uid ())
    )
  );

CREATE POLICY messages_update_own
  ON public.messages FOR UPDATE
  USING (public.auth_is_active_user () AND sender_id = auth.uid ())
  WITH CHECK (public.auth_is_active_user () AND sender_id = auth.uid ());

CREATE POLICY messages_delete_own
  ON public.messages FOR DELETE
  USING (public.auth_is_active_user () AND sender_id = auth.uid ());

-- notifications (recipient id stored in customer_id in current app)
CREATE POLICY notifications_select_recipient
  ON public.notifications FOR SELECT
  USING (
    public.is_admin ()
    OR (public.auth_is_active_user () AND customer_id = auth.uid ())
  );

-- Inserts: admins may target any recipient (system / support). Everyone else must only
-- insert rows where recipient_id (customer_id) is themselves — prevents spoofing.
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

CREATE POLICY notifications_update_recipient
  ON public.notifications FOR UPDATE
  USING (
    public.auth_is_active_user ()
    AND (customer_id = auth.uid () OR public.is_admin ())
  );

CREATE POLICY notifications_delete_recipient_or_admin
  ON public.notifications FOR DELETE
  USING (public.is_admin () OR customer_id = auth.uid ());

-- admin_logs
CREATE POLICY admin_logs_select_admin
  ON public.admin_logs FOR SELECT
  USING (public.is_admin ());

CREATE POLICY admin_logs_insert_admin
  ON public.admin_logs FOR INSERT
  WITH CHECK (public.is_admin () AND admin_id = auth.uid ());

CREATE POLICY admin_logs_no_update
  ON public.admin_logs FOR UPDATE
  USING (false);

CREATE POLICY admin_logs_no_delete
  ON public.admin_logs FOR DELETE
  USING (false);

-- ─── 5) RPC hardening (quantity) ───────────────────────────────────────
-- Old installs may have a different return type; OR REPLACE cannot change it.
-- CASCADE may drop restore_order_stock_once (it calls increase_*); re-run supabase_order_state_machine.sql after.
DROP FUNCTION IF EXISTS public.decrease_remaining_quantity (uuid, integer) CASCADE;
DROP FUNCTION IF EXISTS public.increase_remaining_quantity (uuid, integer) CASCADE;

CREATE OR REPLACE FUNCTION public.decrease_remaining_quantity (p_dish_id uuid, p_quantity integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_remaining integer;
  v_ok boolean := false;
BEGIN
  IF auth.uid () IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;
  IF public.auth_is_blocked () THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF public.auth_role () IS DISTINCT FROM 'customer' THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'remaining_quantity', 0);
  END IF;

  UPDATE public.menu_items
  SET remaining_quantity = remaining_quantity - p_quantity
  WHERE
    id = p_dish_id
    AND remaining_quantity >= p_quantity
  RETURNING
    remaining_quantity INTO v_remaining;

  IF FOUND THEN
    v_ok := true;
  ELSE
    SELECT
      remaining_quantity INTO v_remaining
    FROM
      public.menu_items
    WHERE
      id = p_dish_id;

    v_remaining := COALESCE(v_remaining, 0);
    v_ok := false;
  END IF;

  RETURN jsonb_build_object('ok', v_ok, 'remaining_quantity', COALESCE(v_remaining, 0));
END;
$$;

CREATE OR REPLACE FUNCTION public.increase_remaining_quantity (p_dish_id uuid, p_quantity integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_remaining integer;
  v_cap integer;
  v_found boolean := false;
BEGIN
  IF auth.uid () IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;
  IF public.auth_is_blocked () THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF public.auth_role () NOT IN ('customer', 'chef') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'remaining_quantity', 0);
  END IF;

  SELECT
    daily_quantity INTO v_cap
  FROM
    public.menu_items
  WHERE
    id = p_dish_id;

  UPDATE public.menu_items
  SET
    remaining_quantity = CASE
      WHEN v_cap IS NULL THEN remaining_quantity + p_quantity
      ELSE LEAST(remaining_quantity + p_quantity, v_cap)
    END
  WHERE
    id = p_dish_id
  RETURNING
    remaining_quantity INTO v_remaining;

  IF FOUND THEN
    v_found := true;
  END IF;

  RETURN jsonb_build_object('ok', v_found, 'remaining_quantity', COALESCE(v_remaining, 0));
END;
$$;

REVOKE ALL ON FUNCTION public.decrease_remaining_quantity (uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.increase_remaining_quantity (uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.decrease_remaining_quantity (uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increase_remaining_quantity (uuid, integer) TO authenticated;
