# Phase 1 lifecycle inconsistencies

**Status:** Diagnosis complete. Local prevention trigger added. Hosted
historical repair is **proposed only** and is **not applied**.

Observed on the founder Field Manual athlete (read-only; IDs are shapes, not
a mutation list):

1. `training_sessions` leftover rows stayed `in_progress`.
2. A completed `training_session_records` row existed while the parent
   `training_sessions.status` stayed `in_progress`.
3. Assignment cursor stayed at week 1 / `day_4` while Calendar occurrences
   had completed other week-1 days via Backfill.

These are **generic** mechanisms, not founder-specific code.

## Authority split

| Layer | Role |
|-------|------|
| `programme_schedule_occurrences.disposition` | Calendar / schedule |
| `programme_slot_outcomes.outcome_status` | Programme slot |
| `training_session_records.status` | Performance evidence |
| `training_sessions.status` | M8 container |
| `programme_assignments` cursor | Compatibility history on fixed schedule; **not** Home Today |

`complete_programme_session_and_advance` writes records, outcomes, and
cursor. It does not update `training_sessions`. Dart
`completeSession()` is best-effort and historically swallowed errors.

Fixed Home uses calendar occurrence projection. Resume RPCs reject a
terminal outcome even if the parent row is still `in_progress`. Progress
counts records and slot outcomes, not parent status. Legacy
`TrainingSessionSetRepository` still filters
`training_sessions.status = 'completed'`, so M8 set history can under-count
when the parent is an orphan.

## Shape 1 — leftover `in_progress` parents

**Open outcome + in_progress parent:** expected resumable work. Calendar can
show Incomplete / in-progress overdue. Swap remains blocked while the
outcome is open.

**Terminal outcome + in_progress parent:** orphan container. Documented side
effect of the split. Swap no longer treats that orphan as an open session
(`20260906140000_*`).

**Unlinked pre-calendar attempts:** possible abandoned containers with no
terminal record. **Must not** be marked completed without evidence.

Home (fixed) does not resume via parent status. Ghost resume risk is low on
the fixed path and higher on any leftover cursor-based path.

## Shape 2 — completed record, parent still `in_progress`

Expected before the closeout trigger: RPC committed evidence; parent lagged.
Not a second completion. Future live completions **compounded** orphans
until `20260914120000_terminalize_training_session_from_completed_record.sql`.

That migration closes the parent when a record becomes `completed` or
`partially_completed`. It does **not** close parents for `abandoned` or
`in_progress`. It performs **no** migration-time row writes.

## Shape 3 — cursor behind Calendar

**Expected** for Backfill: the RPC must not advance the cursor. Fixed Home
still resolves Today from the calendar. Progress week labels that read
`assignment.currentWeek` can lag.

Compatibility cursor refresh exists on swap/recovery RPCs, not Backfill.

Normal future **live** completion of the cursor slot still advances that
cursor. It does not rewrite historical Backfill chronology.

## Local code fix

Implemented: terminal-record trigger (prevention for new completions once
the migration is on a database). Dart/SQL contract tests document calendar
vs cursor and evidence vs parent status.

Not implemented here: rewriting `TrainingSessionSetRepository` PostgREST
filters (legacy M8 path; needs a dedicated consumer audit).

## Hosted reconciliation proposal (paused)

Do **not** apply on Field Manual without founder approval. Do **not** write
Lee-specific SQL.

Generic, auditable steps:

1. **Read-only report** of counts:
   - terminal outcome ∧ parent `in_progress`
   - record completed ∧ outcome not terminal
   - cursor slot terminal ∧ remaining scheduled earlier occurrences
   - `in_progress` parents with no record and no in-progress outcome
2. **Close orphan parents** only where a terminal record **or** terminal
   slot outcome exists:

```sql
UPDATE public.training_sessions ts
SET status = 'completed',
    completed_at = COALESCE(ts.completed_at, NOW()),
    updated_at = NOW()
WHERE ts.status = 'in_progress'
  AND (
    EXISTS (
      SELECT 1 FROM public.training_session_records r
      WHERE r.training_session_id = ts.id
        AND r.status IN ('completed', 'partially_completed')
    )
    OR EXISTS (
      SELECT 1 FROM public.programme_slot_outcomes o
      WHERE o.training_session_id = ts.id
        AND o.outcome_status IN ('completed', 'completed_partial')
    )
  );
```

3. Apply `20260914120000_terminalize_training_session_from_completed_record.sql`
   so new completions stay consistent.
4. Optionally refresh compatibility cursors for active `fixed_schedule`
   assignments via the existing refresh function — **not** by inventing a
   next session.
5. Leave truly abandoned open rows `in_progress`. Never delete stale rows
   merely because they look old.

Rollback: restore from backup taken immediately before the UPDATE; the
trigger is additive `CREATE OR REPLACE` / `DROP TRIGGER IF EXISTS`.
