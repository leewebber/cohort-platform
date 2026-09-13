# Proposed backfill programme-session schema (not applied)

Founder review required before any hosted or local-chain application.
This file is **not** a `supabase/migrations/` entry.

## Why existing columns are insufficient

`training_session_records.started_at` is `NOT NULL` and is the live-session clock.
`completed_at` is when the result tree became terminal.
Neither can truthfully hold a date-only historical performance without overloading
or fabricating an exact start time.

## Proposed columns

```sql
ALTER TABLE public.training_session_records
  ADD COLUMN entry_mode TEXT NOT NULL DEFAULT 'live'
    CHECK (entry_mode IN ('live', 'backfill')),
  ADD COLUMN performed_on DATE,
  ADD COLUMN performed_precision TEXT NOT NULL DEFAULT 'timestamp'
    CHECK (performed_precision IN ('timestamp', 'date')),
  ADD COLUMN recorded_at TIMESTAMPTZ;

ALTER TABLE public.training_session_records
  ADD CONSTRAINT training_session_records_backfill_truth_check
  CHECK (
    (entry_mode = 'live' AND started_at IS NOT NULL)
    OR
    (
      entry_mode = 'backfill'
      AND performed_on IS NOT NULL
      AND performed_precision = 'date'
      AND recorded_at IS NOT NULL
    )
  );
```

`started_at` should become nullable only for `entry_mode = 'backfill'`.
Live rows are unchanged. Comparison/Progress use `performed_on` for backfill
and `started_at` for live. Never compare using `recorded_at`.

## RPC (to be specified with the migration)

Transactional `complete_backfilled_fixed_programme_occurrence`:
- athlete owns the active assignment
- occurrence is date-derived unfinished, not skipped, not completed
- no in-progress training session
- idempotency key = athlete + assignment + occurrence + `backfill`
- one completed result tree attached to the original occurrence/slot
- does not mutate today’s occurrence
- does not create a schedule operation unless one genuinely occurred
