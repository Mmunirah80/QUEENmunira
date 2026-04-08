-- ============================================================
-- Fair random inspection selection — SUPERSEDED
-- ============================================================
-- Fair selection + eligibility snapshot + selection_context column are merged into
-- `supabase_inspection_random_v2.sql` (chef_inspection_eligibility_snapshot,
-- chef_eligible_for_random_inspection, start_random_inspection_call).
--
-- For new databases: run only `supabase_inspection_random_v2.sql`.
--
-- If you previously ran this file alone, you already have selection_context and the
-- fair functions; re-running `supabase_inspection_random_v2.sql` is idempotent
-- (ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE functions).
-- ============================================================

SELECT 1 AS fair_selection_v1_superseded_by_inspection_random_v2;
