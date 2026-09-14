# Progression Mechanics v1 — scalable retrieval proposal

**Status:** Design only. Do not apply hosted without founder approval.  
**Companion:** [`Progression_Mechanics_v1.md`](./Progression_Mechanics_v1.md)

## Current founder path

`PreviousStrengthPerformanceService` loads up to **40**
`training_session_records` for the athlete (completed / partially_completed),
then batches block / exercise / set rows for the session’s canonical exercise
IDs.

| Metric | Immediate behaviour |
|---|---|
| Query count | 4 bounded queries per Active Session open (records, blocks, exercises, sets) |
| Payload | One page of recent records, not full athlete history |
| Failure mode | Infrequently performed exercises whose last valid result sits **beyond** the 40 most recently *started* records are treated as first performance |
| UI | History loads independently; Begin/Resume is not blocked |

Ordering records by `started_at` then re-sorting with `PerformanceChronology`
means a very old Backfill with a recent `started_at` is included, but a live
result older than 40 newer sessions can drop out.

Raising the client limit indefinitely is rejected.

## Proposed server projection (not applied)

One authenticated RPC, for example
`latest_comparable_performances_for_exercises`:

**Inputs:** `athlete_id`, `exercise_ids[]`, optional `exclude_record_id`,
optional `current_chronology_at`.

**Output per exercise:** latest eligible record id, performed chronology,
completed sets with actuals, provenance (`live` / `backfill` / `corrected`).

**Eligibility:** same rules as Progression Mechanics v1 (terminal or partial
with completed sets; not abandoned; same athlete; chronology before current).

**Indexes (local proposal):**

- `training_session_records (athlete_id, status, started_at desc)` already
  useful for the 40-row page
- exercise results already index `source_exercise_id`
- a materialized latest-per-(athlete, exercise) row keyed by
  `PerformanceChronology` date + record_id would avoid scanning 40 parents

**Circuit/interval analog:** latest row per `(athlete_id, comparison_family)`
with format/scoring columns — separate RPC, same bounds.

Apply only after a local migration + full DB gate and founder approval.
Sprint 1 ships the comparison engine against the existing 40-record client
path.
