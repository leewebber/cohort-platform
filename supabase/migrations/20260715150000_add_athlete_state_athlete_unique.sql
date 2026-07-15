-- Fix athlete_state upsert ON CONFLICT target (PostgreSQL 42P10)
-- Related: lib/data/repositories/athlete_state_supabase_store.dart
--
-- PROBLEM:
--   AthleteStateSupabaseStore.upsertProjection uses:
--     onConflict: 'athlete_id'
--   PostgREST requires a UNIQUE or PRIMARY KEY constraint on the conflict
--   target. athlete_state had no unique constraint on athlete_id, causing
--   error 42P10: "there is no unique or exclusion constraint matching the
--   ON CONFLICT specification".
--
-- INTENDED MODEL:
--   athlete_state is a denormalised one-row-per-athlete projection cache.
--   ProgrammeAssignment remains source of truth. AthleteStateSyncService
--   upserts by athlete_id after assignment/progression changes.
--
-- STRATEGY:
--   1. Abort if duplicate athlete_id rows already exist (no silent deletes)
--   2. Add UNIQUE index on athlete_id
--   3. Keep AthleteStateSupabaseStore onConflict: 'athlete_id'
--
-- BEFORE APPLYING — inspect current data:
--
-- 1) Count rows per athlete_id (expect 0 duplicate groups)
-- SELECT athlete_id, COUNT(*) AS row_count
-- FROM athlete_state
-- GROUP BY athlete_id
-- HAVING COUNT(*) > 1
-- ORDER BY row_count DESC, athlete_id;
--
-- 2) Inspect lee specifically
-- SELECT *
-- FROM athlete_state
-- WHERE athlete_id = 'lee'
-- ORDER BY current_week NULLS LAST, current_day NULLS LAST;
--
-- 3) Total row count
-- SELECT COUNT(*) AS total_rows, COUNT(DISTINCT athlete_id) AS distinct_athletes
-- FROM athlete_state;
--
-- IF DUPLICATES EXIST:
--   Do not re-run this migration until duplicates are resolved manually.
--   Consolidate rows outside this migration, then re-apply.
--
-- AFTER APPLYING — verify constraint:
--
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND tablename = 'athlete_state'
--   AND indexname = 'athlete_state_athlete_id_unique';
--
-- SELECT conname, pg_get_constraintdef(oid) AS definition
-- FROM pg_constraint
-- WHERE conrelid = 'athlete_state'::regclass
--   AND conname = 'athlete_state_athlete_id_unique';

-- ---------------------------------------------------------------------------
-- Duplicate guard — fail loudly instead of deleting rows
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  duplicate_athlete_count INT;
BEGIN
  SELECT COUNT(*) INTO duplicate_athlete_count
  FROM (
    SELECT athlete_id
    FROM athlete_state
    GROUP BY athlete_id
    HAVING COUNT(*) > 1
  ) duplicates;

  IF duplicate_athlete_count > 0 THEN
    RAISE EXCEPTION
      'athlete_state migration aborted: % athlete_id value(s) have duplicate rows. '
      'Run duplicate diagnostic queries in 20260715150000_add_athlete_state_athlete_unique.sql '
      'and consolidate manually before retrying.',
      duplicate_athlete_count
      USING ERRCODE = '23505';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- One-row-per-athlete unique constraint
-- ---------------------------------------------------------------------------

ALTER TABLE athlete_state
  ADD CONSTRAINT athlete_state_athlete_id_unique UNIQUE (athlete_id);

COMMENT ON CONSTRAINT athlete_state_athlete_id_unique ON athlete_state IS
  'Enforces one-row-per-athlete projection model for AthleteStateSupabaseStore upsert on athlete_id.';
