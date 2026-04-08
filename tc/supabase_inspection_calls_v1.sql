-- ============================================================
-- NAHAM - Surprise inspection calls (minimal V1)
-- ============================================================
-- Adds:
-- - public.inspection_calls
-- - public.start_inspection_call(uuid)
-- - public.chef_respond_inspection_call(uuid, text)
-- - public.finalize_inspection_call(uuid, text, text, text)
--
-- Result actions:
--   pass | warning | freeze_3d | freeze_7d | freeze_14d | blocked
--
-- Violation reasons:
--   no_answer | declined_call | failed_hygiene_check | other
-- ============================================================

begin;

create table if not exists public.inspection_calls (
  id uuid primary key default gen_random_uuid(),
  chef_id uuid not null references public.profiles(id) on delete cascade,
  admin_id uuid not null references public.profiles(id) on delete restrict,
  channel_name text not null,
  status text not null default 'pending',
  response_reason text,
  result_action text,
  violation_reason text,
  result_note text,
  chef_result_seen boolean not null default false,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  finalized_at timestamptz
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'inspection_calls_status_allowed'
  ) then
    alter table public.inspection_calls
      add constraint inspection_calls_status_allowed
      check (status in ('pending', 'accepted', 'declined', 'missed', 'completed'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'inspection_calls_result_action_allowed'
  ) then
    alter table public.inspection_calls
      add constraint inspection_calls_result_action_allowed
      check (
        result_action is null
        or result_action in ('pass', 'warning', 'freeze_3d', 'freeze_7d', 'freeze_14d', 'blocked')
      );
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'inspection_calls_violation_reason_allowed'
  ) then
    alter table public.inspection_calls
      add constraint inspection_calls_violation_reason_allowed
      check (
        violation_reason is null
        or violation_reason in ('no_answer', 'declined_call', 'failed_hygiene_check', 'other')
      );
  end if;
end $$;

create index if not exists idx_inspection_calls_chef_created
  on public.inspection_calls(chef_id, created_at desc);

create index if not exists idx_inspection_calls_status_created
  on public.inspection_calls(status, created_at desc);

alter table public.chef_profiles
  add column if not exists freeze_until timestamptz,
  add column if not exists freeze_started_at timestamptz,
  add column if not exists freeze_type text,
  add column if not exists freeze_reason text,
  add column if not exists warning_count integer not null default 0;

create table if not exists public.chef_violations (
  id uuid primary key default gen_random_uuid(),
  chef_id uuid not null references public.profiles(id) on delete cascade,
  inspection_call_id uuid references public.inspection_calls(id) on delete set null,
  admin_id uuid not null references public.profiles(id) on delete restrict,
  violation_index integer not null,
  reason text not null,
  action_applied text not null,
  note text,
  created_at timestamptz not null default now()
);

alter table public.inspection_calls enable row level security;
alter table public.chef_violations enable row level security;

drop policy if exists "inspection_calls_admin_all" on public.inspection_calls;
create policy "inspection_calls_admin_all"
on public.inspection_calls
for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists "inspection_calls_chef_select_own" on public.inspection_calls;
create policy "inspection_calls_chef_select_own"
on public.inspection_calls
for select
using (chef_id = auth.uid());

drop policy if exists "inspection_calls_chef_update_own_pending" on public.inspection_calls;
create policy "inspection_calls_chef_update_own_pending"
on public.inspection_calls
for update
using (chef_id = auth.uid())
with check (chef_id = auth.uid());

drop policy if exists "chef_violations_admin_all" on public.chef_violations;
create policy "chef_violations_admin_all"
on public.chef_violations
for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists "chef_violations_chef_select_own" on public.chef_violations;
create policy "chef_violations_chef_select_own"
on public.chef_violations
for select
using (chef_id = auth.uid());

create or replace function public.start_inspection_call(p_chef_id uuid)
returns public.inspection_calls
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_channel text;
  v_row public.inspection_calls;
begin
  perform public.ensure_admin();

  if p_chef_id is null then
    raise exception 'chef_id is required';
  end if;

  if exists (
    select 1
    from public.inspection_calls c
    where c.chef_id = p_chef_id
      and c.status in ('pending', 'accepted')
  ) then
    raise exception 'Chef already has an active inspection call';
  end if;

  if not exists (
    select 1
    from public.chef_profiles cp
    where cp.id = p_chef_id
      and coalesce(cp.is_online, false) = true
      and coalesce(cp.suspended, false) = false
      and (cp.freeze_until is null or cp.freeze_until <= v_now)
  ) then
    raise exception 'Chef is not currently eligible for inspection';
  end if;

  v_channel := 'inspection_' || replace(p_chef_id::text, '-', '') || '_' || floor(extract(epoch from v_now))::bigint::text;

  insert into public.inspection_calls (
    chef_id, admin_id, channel_name, status
  )
  values (
    p_chef_id, auth.uid(), v_channel, 'pending'
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.chef_respond_inspection_call(
  p_call_id uuid,
  p_response text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if p_call_id is null then
    raise exception 'call_id is required';
  end if;
  if p_response not in ('accepted', 'declined', 'missed') then
    raise exception 'invalid response value';
  end if;

  update public.inspection_calls
  set
    status = p_response,
    responded_at = now(),
    response_reason = case
      when p_response = 'declined' then 'declined_call'
      when p_response = 'missed' then 'no_answer'
      else response_reason
    end
  where id = p_call_id
    and chef_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'inspection call not found or not pending';
  end if;
end;
$$;

create or replace function public.finalize_inspection_call(
  p_call_id uuid,
  p_result_action text,
  p_violation_reason text default null,
  p_result_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_call public.inspection_calls;
  v_new_warning_count integer;
  v_action_to_apply text;
  v_freeze_until timestamptz;
begin
  perform public.ensure_admin();

  if p_call_id is null then
    raise exception 'call_id is required';
  end if;

  if p_result_action not in ('pass', 'warning', 'freeze_3d', 'freeze_7d', 'freeze_14d', 'blocked') then
    raise exception 'invalid result action';
  end if;

  select *
    into v_call
  from public.inspection_calls
  where id = p_call_id;

  if v_call.id is null then
    raise exception 'inspection call not found';
  end if;

  if v_call.status = 'completed' then
    return jsonb_build_object(
      'call_id', v_call.id,
      'already_completed', true,
      'result_action', v_call.result_action
    );
  end if;

  v_action_to_apply := p_result_action;

  update public.inspection_calls
  set
    status = 'completed',
    result_action = p_result_action,
    violation_reason = p_violation_reason,
    result_note = p_result_note,
    chef_result_seen = false,
    finalized_at = now()
  where id = p_call_id;

  if p_result_action = 'pass' then
    return jsonb_build_object(
      'call_id', p_call_id,
      'result_action', 'pass'
    );
  end if;

  update public.chef_profiles
  set warning_count = coalesce(warning_count, 0) + 1
  where id = v_call.chef_id
  returning warning_count into v_new_warning_count;

  if v_new_warning_count is null then
    raise exception 'chef profile not found';
  end if;

  if v_new_warning_count = 1 then
    v_action_to_apply := 'warning';
  elsif v_new_warning_count = 2 then
    v_action_to_apply := 'freeze_3d';
    v_freeze_until := now() + interval '3 days';
  elsif v_new_warning_count = 3 then
    v_action_to_apply := 'freeze_7d';
    v_freeze_until := now() + interval '7 days';
  elsif v_new_warning_count = 4 then
    v_action_to_apply := 'freeze_14d';
    v_freeze_until := now() + interval '14 days';
  else
    v_action_to_apply := 'blocked';
  end if;

  if v_action_to_apply in ('freeze_3d', 'freeze_7d', 'freeze_14d') then
    update public.chef_profiles
    set
      freeze_until = v_freeze_until,
      freeze_started_at = now(),
      freeze_type = 'soft',
      freeze_reason = coalesce(nullif(trim(p_result_note), ''), 'Automatic freeze from inspection outcome'),
      is_online = false
    where id = v_call.chef_id;
  end if;

  if v_action_to_apply = 'blocked' then
    update public.profiles
    set is_blocked = true,
        blocked_reason = coalesce(p_result_note, 'Inspection violation escalation'),
        blocked_at = now()
    where id = v_call.chef_id;
  end if;

  insert into public.chef_violations (
    chef_id,
    inspection_call_id,
    admin_id,
    violation_index,
    reason,
    action_applied,
    note
  )
  values (
    v_call.chef_id,
    p_call_id,
    auth.uid(),
    v_new_warning_count,
    coalesce(p_violation_reason, 'other'),
    v_action_to_apply,
    p_result_note
  );

  update public.inspection_calls
  set result_action = v_action_to_apply
  where id = p_call_id;

  return jsonb_build_object(
    'call_id', p_call_id,
    'result_action', v_action_to_apply,
    'warning_count', v_new_warning_count,
    'freeze_until', v_freeze_until
  );
end;
$$;

grant execute on function public.start_inspection_call(uuid) to authenticated;
grant execute on function public.chef_respond_inspection_call(uuid, text) to authenticated;
grant execute on function public.finalize_inspection_call(uuid, text, text, text) to authenticated;

commit;

