-- Optional: customer city on profiles (matches chef_profiles.kitchen_city for reels feed).
-- Run once if [profiles.city] does not exist yet.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS city text;

COMMENT ON COLUMN public.profiles.city IS
  'Customer home city; customer reels feed shows only reels where chef_profiles.kitchen_city matches (case-insensitive).';
