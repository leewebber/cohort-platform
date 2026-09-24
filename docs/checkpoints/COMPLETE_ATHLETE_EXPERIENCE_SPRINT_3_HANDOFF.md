# Complete Athlete Experience Sprint 3 — implementation handoff

**Status:** Implemented locally. Awaiting founder architectural and
visual approval. **Not complete.** **Not integrated.** **Not pushed.**

```text
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
NEXT_IMPLEMENTATION_AUTHORISED=false
HOSTED_APPLY=false
```

**Branch:** `feat/programme-completion-history-integrity-v1`  
**Base:** `origin/main` `8d7606d0c43b4b3b499dfbdc2f5ba9b0caa151ce`

## RPC design

**Choice A.** Execution independently requires an active assignment
(`prepareFixedOccurrence`, `IncompleteSessionTrainToday`, create/resume
and completion RPCs). The assignment-specific calendar resolver was
widened to accept `active` or `completed` when materialised.

Completed inspection skips `ensure` and `reconcile`. Success payload
includes `assignment_status`. `resolve_active_fixed_programme_calendar`
remains active-only.

Migration:
`supabase/migrations/20260924120000_completed_fixed_programme_calendar_inspection.sql`

## Preview

```text
flutter run -d chrome --web-port 4194 --web-hostname 127.0.0.1 \
  -t lib/main_completion_history_integrity_preview.dart
```

http://127.0.0.1:4194 — fixture-only. Not imported by `lib/main.dart`.

## Do not

Push, integrate, apply hosted migrations, mark Sprint 3 complete, or
begin the next milestone until founder approval.
