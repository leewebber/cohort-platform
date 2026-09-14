# Backfill fixed-programme session results

**Status:** Applied schema and production athlete flow  
**Applied migration:** `supabase/migrations/20260913120000_backfill_fixed_programme_session_results.sql`  
**RPC:** `complete_backfilled_fixed_programme_occurrence`  
**Capability:** `backfill_results` via `cohort_athlete_runtime_capabilities`  
**Supersedes:** [Proposed_Backfill_Programme_Session_Schema_v1.md](./Proposed_Backfill_Programme_Session_Schema_v1.md)

Production capability checks fail closed until the hosted probe succeeds.

## Truthful chronology

| Concept | Live | Backfill |
|---------|------|----------|
| Scheduled | Occurrence `scheduled_date` / original scheduled date | Same |
| Performed | `started_at` timestamp | `performed_on` date (`performed_precision = date`) |
| Recorded | `completed_at` / `created_at` | Same clocks; **never** used as performed chronology |

`started_at` stays the live-session clock. Do not copy `performed_on` into
`started_at`. Progress and previous-performance comparisons use performed
chronology.

## What Backfill does not do

- Does not advance the assignment cursor.
- Does not fabricate completion without a result tree.
- Does not complete a different occurrence than the one selected.
- Does not skip remaining Incomplete sessions.
- Does not rewrite Plan Packages.

The athlete UI reuses the normal capture surfaces, including EMOM result
entry, then commits through the Backfill RPC.
