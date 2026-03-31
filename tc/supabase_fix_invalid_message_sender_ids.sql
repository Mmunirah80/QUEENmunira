-- ============================================================
-- Repair invalid message.sender_id values
-- ============================================================
-- Replaces any messages.sender_id that does NOT exist in profiles.id
-- with the real support admin account id.
--
-- Admin account:
--   a3291c54-3ee6-4d61-8aea-62d3ff5c5657
-- ============================================================

begin;

-- Safety check: ensure the target admin user exists in profiles.
do $$
begin
  if not exists (
    select 1
    from public.profiles
    where id = 'a3291c54-3ee6-4d61-8aea-62d3ff5c5657'::uuid
  ) then
    raise exception 'Admin profile not found for id %', 'a3291c54-3ee6-4d61-8aea-62d3ff5c5657';
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

-- Apply fix.
update public.messages m
set sender_id = 'a3291c54-3ee6-4d61-8aea-62d3ff5c5657'::uuid
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

