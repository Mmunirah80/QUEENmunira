-- Optional columns + helper for chef storefront status (Flutter is source of truth for UX;
-- use this for SQL reports, RPCs, or future Postgres filters).
-- Run in Supabase SQL editor after reviewing RLS.

alter table public.chef_profiles
  add column if not exists vacation_start date,
  add column if not exists vacation_end date;

comment on column public.chef_profiles.vacation_start is 'Optional first day of scheduled vacation (inclusive)';
comment on column public.chef_profiles.vacation_end is 'Optional last day of scheduled vacation (inclusive)';

-- App rule: available ⇔ NOT vacation AND within working hours AND is_online.
-- Note: uses server CURRENT_TIME (UTC in Supabase); align with app timezone if you rely on this.
create or replace function public.is_chef_available_now(
  p_is_open_now boolean,
  p_is_on_vacation boolean,
  p_working_start time,
  p_working_end time
)
returns boolean
language plpgsql
stable
as $$
begin
  if coalesce(p_is_on_vacation, false) then
    return false;
  end if;
  if p_working_start is null or p_working_end is null then
    return coalesce(p_is_open_now, false);
  end if;
  if p_working_end >= p_working_start then
    if not (current_time between p_working_start and p_working_end) then
      return false;
    end if;
  else
    -- Overnight window
    if not (current_time >= p_working_start or current_time <= p_working_end) then
      return false;
    end if;
  end if;
  return coalesce(p_is_open_now, false);
end;
$$;
