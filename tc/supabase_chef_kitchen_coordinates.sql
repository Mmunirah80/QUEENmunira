-- Pickup: store kitchen coordinates for distance sorting (run in Supabase SQL editor).
-- RLS: same as chef_profiles updates (cook updates own row via existing policies).

alter table public.chef_profiles
  add column if not exists kitchen_latitude double precision,
  add column if not exists kitchen_longitude double precision;

comment on column public.chef_profiles.kitchen_latitude is 'Pickup point latitude (WGS84)';
comment on column public.chef_profiles.kitchen_longitude is 'Pickup point longitude (WGS84)';
