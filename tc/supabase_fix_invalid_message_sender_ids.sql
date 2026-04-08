-- ============================================================
-- Repair invalid message.sender_id values
-- ============================================================
-- Replaces any messages.sender_id that does NOT exist in profiles.id
-- with **an active admin** from public.profiles (role = admin, not blocked).
-- No hardcoded UUID — works across environments.
-- ============================================================

begin;

do $$
begin
  if not exists (
    select 1
    from public.profiles p
    where lower(trim(p.role::text)) = 'admin'
      and (p.is_blocked is null or p.is_blocked = false)
  ) then
    raise exception 'No active admin profile (role=admin, not blocked) in public.profiles; cannot repair senders.';
  end if;
end $$;

-- Preview rows that will be updated.
select
  count(*) as invalid_sender_messages
from public.messages m
left join public.profiles p
  on p.id = m.sender_id
where m.sender_id is null
   or p.id is null;

-- Apply fix: attribute orphaned senders to the chosen admin row above.
update public.messages m
set sender_id = s.admin_id
from (
  select p.id as admin_id
  from public.profiles p
  where lower(trim(p.role::text)) = 'admin'
    and (p.is_blocked is null or p.is_blocked = false)
  order by p.created_at asc nulls last, p.id asc
  limit 1
) s
where m.sender_id is null
   or not exists (
     select 1
     from public.profiles p
     where p.id = m.sender_id
   );

-- Post-check (must be 0).
select
  count(*) as remaining_invalid_sender_messages
from public.messages m
left join public.profiles p
  on p.id = m.sender_id
where m.sender_id is null
   or p.id is null;

commit;
