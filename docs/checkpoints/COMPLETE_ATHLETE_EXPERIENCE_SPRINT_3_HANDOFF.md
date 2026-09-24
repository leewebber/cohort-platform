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
**HEAD:** local only — see the founder stop report.

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
SHA-256: `3df3970c7951c2b3b1bdfec81959a58dfb690f5c7711f2954d7c9b466f6a9f26`  
Not applied to hosted systems.

Assignment status domain remains
`active | paused | completed | reassigned`. There is no `cancelled` or
`draft` assignment status. Gate BA rejects paused, reassigned,
unmaterialised, and missing IDs.

## Preview

```text
flutter run -d chrome --web-port 4194 --web-hostname 127.0.0.1 \
  -t lib/main_completion_history_integrity_preview.dart
```

http://127.0.0.1:4194 — fixture-only. Not imported by `lib/main.dart`.

Review states: `activeProgramme`, `todayCompleteProgrammeContinues`,
`programmeJustCompleted`, `completedHome`, `completedCalendar`,
`completedProgrammes`, `progressData`, `progressEmpty`,
`progressRefreshFailed`, `progressBlocked`, `historyData`,
`historyEmpty`, `historyRefreshFailed`, `historyBlocked`,
`missingAthlete`, `coachOnlyDenied`, `noActiveWithHistory`,
`completedPlusNewActive`, `unavailableCompletedPin`,
`narrow320CompletedHome`, `largeTextCompletedHome`.

## Local database gate

`./supabase/tests/run_local_db_gate.sh` passed after Gate BA fixture
hardening, including Gate BA in both reset loops. Hosted apply was
not run.

## Do not

Push, integrate, apply hosted migrations, mark Sprint 3 complete, or
begin the next milestone until founder approval.

Founder visual design for completed Home is approved. A later local
copy-only correction replaced remaining architectural athlete-facing
strings; authority and RPCs are unchanged.
