# Daily Journey Execution Reliability v1

**Status:** Binding Sprint 2 contract for production workout interruption,
serialized restart, completion reconciliation, and build-7 compatibility.

**Recorded:** 2026-09-21

```text
DAILY_JOURNEY_INTEGRITY_SPRINT=2
NEXT_IMPLEMENTATION_AUTHORISED=true
HOSTED_MIGRATION_REQUIRED=false
PHONE_BUILD_REQUIRED=false
FIELD_MANUAL_MUTATION=false
OFFLINE_COMPLETION_QUEUE=deferred
```

Binding:
[`Daily_Journey_Integrity_v1.md`](./Daily_Journey_Integrity_v1.md),
[`../checkpoints/DAILY_JOURNEY_INTEGRITY_SPRINT_1_HANDOFF.md`](../checkpoints/DAILY_JOURNEY_INTEGRITY_SPRINT_1_HANDOFF.md),
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md).

Sprint 1 established one restore chain. Sprint 2 must prove that chain through
the real production workout under interruption, restart, and failure.

This document does not start programme comparison, Android release work,
wearables, offline completion queue, or the experimental electric-blue brand.

---

## 1. Authority hierarchy

Production entry only:

```text
authenticated athlete
  → ProgrammeSessionExecutionLauncher
    → createOrResumeTrainingSession (hosted; same occurrence)
    → SessionExecutionLauncher
      → ProductionRestoreResolver
        → ActiveSessionScreen
          → ActivePerformanceDraft          (actuals)
          → ProductionSessionDraft          (identity)
          → ProductionSessionUiCursor       (working position)
            → SessionFinishReviewScreen
              → PerformanceRecordSaveCoordinator.completeSession
                → AthleteProgrammeCompletionService (hosted)
```

| Store | Role | May authorize resume? |
|-------|------|------------------------|
| `ActivePerformanceDraft` | Durable actuals | Yes, via resolver |
| `ProductionSessionDraft` | Identity / classification | Companion only |
| `ProductionSessionUiCursor` | Block/exercise/interval position | Companion only; never changes result meaning |
| `AthleteSessionMemoryStore` | In-process | No |
| `WorkoutProgressSnapshot` | Legacy discovery | No |
| Preview mains / dedicated players | Founder review only | No |

Backfill remains a separate path. Train today remains the same launcher.

---

## 2. Interruption contract

| Event | Required behaviour |
|-------|-------------------|
| App backgrounded / inactive / hidden / screen locked | Flush confirmed inputs to durable local actuals + envelope where the platform allows |
| Incoming interruption | Same flush; timer paused snapshot unless format wall-clock policy applies |
| Navigation away from ActiveSession | Flush; do not complete |
| Process killed after last confirmed input | Restart reads serialized actuals + envelope; same training session |
| Cold restart | Resolver decides; no duplicate `createOrResume` session |
| Token expired, draft local | Invalid identity → Sign in; drafts stay scoped by athlete id |
| Transient network / completion timeout | Retain local actuals and cursor; pending/retry; same idempotency identity |
| Lost response after server commit | Reconcile to hosted truth; then clear local draft |
| Double completion tap | One frozen idempotency identity |
| Reopen after hosted completion | Hosted wins; stale local draft cannot show Complete until reconciliation |
| Sign-out with active draft | Clear in-process memory and that athlete’s envelope; hosted records retained |
| Other athlete on same device | Foreign draft inaccessible; no leak |

Rules:

- Confirmed inputs flush before lifecycle suspension where allowed.
- Local actuals remain durable until authoritative hosted success.
- UI cursor never changes result meaning.
- Timers restore from persisted clock/cursor evidence, not fabricated elapsed time.
- App downtime does **not** silently count as training unless the authored timer
  semantics explicitly require wall-clock continuation. Sprint 2 default:
  restore **paused** at the last persisted remaining/elapsed cursor.
- No local-only state may render a session Complete.
- Offline queue remains deferred; pending/retry must stay honest.

---

## 3. Timer policy

| Format | Persist | Restore |
|--------|---------|---------|
| Strength | No workout timer | Exact set/exercise cursor when present; else first incomplete valid set |
| Intervals | Phase, interval number, remaining/work seconds | Paused at persisted position |
| Endurance | Duration field, not GPS | Manual fields only |
| EMOM | `CircuitTimerCursor` | Paused at persisted minute/interval |
| Circuit | Station/round cursor when representable | Next incomplete station/round; no fabricated complete |
| For time | `elapsedSeconds` + remaining work | Resume (not Start timer) at persisted elapsed |
| AMRAP | Remaining or elapsed seconds + rounds/reps | Paused; do not convert to circuit/for-time |
| Fixed-work rounds | Existing fixed-work cursor | Existing controller |

Wall-clock continuation is **not** implied by backgrounding. Do not invent
elapsed time from `DateTime.now()` minus start.

---

## 4. Completion reconciliation

1. Flush latest draft before submitting.
2. Freeze one idempotency identity for the training session attempt.
3. Hosted success → clear envelope, memory, and in-progress draft; then show
   confirmed complete.
4. Failure / timeout → retain actuals and cursor; athlete-facing
   **Completion pending** + Retry; never Complete.
5. Lost response → replay same payload, then reconcile hosted record /
   assignment cursor. If already committed, treat as success and clean up.
6. Hosted complete vs stale local → hosted wins.

---

## 5. Build-7 compatibility

Phone build 7 may have created mixed local data: performance drafts without
`ProductionSessionDraft`, missing UI cursor, `WorkoutProgressSnapshot`,
generated-session envelopes, or timer metadata.

| Classification | Policy |
|----------------|--------|
| Safely resumable | Compatible identity + actuals → resume same session |
| Partially recoverable | Actuals present, cursor/identity incomplete → retain actuals; resume first incomplete valid position; tell the athlete only when they would otherwise be lost |
| Cannot safely restore | Unmappable snapshot / unsafe mix → fail closed; Return to Home; discard only with confirmation |
| Already completed hosted | Hosted wins; clear stale local |
| Foreign athlete | Inaccessible |
| Stale occurrence / programme version | Blocked; calendar/home recovery |
| Corrupt | Fail closed |
| Unsupported version | Fail closed if safety cannot be established; do not invent fields |

Never invent missing actuals, timer time, session identity, or completion.

---

## 6. Production execution matrix (Sprint 1 baseline)

Classifications are from the **production** `ActiveSessionScreen` path, not
preview players. Sprint 1 in-memory restore tests exist; they did not
serialize through a fresh dependency graph.

| Format | Inputs | Evidence | Draft | Cursor | Timer | Restart (Sprint 1) | Class |
|--------|--------|----------|-------|--------|-------|--------------------|-------|
| Strength | Sets, reps, load, RPE, notes | Completed sets | `StrengthResultData` + set drafts | Block/exercise when saved | None | Actuals + cursor | Functional but incomplete |
| Intervals | Interval rows, pace, note | Completed intervals | `IntervalResultData` | Block | Restored from result if present; checkpoint not written from timer | Actuals | Functional but incomplete |
| Endurance | Duration / distance / HR / note | Manual fields | `EnduranceResultData` | Block | Stopwatch optional | Actuals | Functional but incomplete |
| EMOM | Timer + score | Rounds, targets, cursor | `CircuitResultData` + `timerCursor` | Block | Cursor persisted | Score + cursor | Functional but incomplete |
| Circuit | Station actuals, ended-early | Stations / rounds | `CircuitResultData` | Block | Cursor if circuit timer | Ended-early truth | Functional but incomplete |
| For time | Elapsed, remaining work, completed | Time + remaining | `ForTimeResultData` | Block | Elapsed on timer pop; production resume did not auto-open timer | Elapsed + cap | Functional but incomplete |
| AMRAP | Rounds, extra reps | Score | `AmrapResultData` | Block | Restore used a duration heuristic, not persisted remaining | Rounds/reps | Functional but incomplete |
| Structured recovery | Acknowledgement | Completion flags | `CompletionResultData` | Block | None | Executable-blocks policy | Production-complete for acknowledgement blocks |
| Guidance-only rest | None | None | None | None | None | No training session | Unsupported / fail-closed (correct) |
| Unsupported / malformed | None | None | None | None | None | Fail closed before invalid session | Unsupported / fail-closed |

History / correction: existing completed-result correction path remains; Sprint 2
must not regress it. Previous-performance load must not block capture.

Sprint 2 target: every functional-but-incomplete row becomes **production-complete**
for interruption, serialized restart, timer restore (where applicable), save
feedback, and fail-closed behaviour. Accessibility is **workout-path usable**,
not the full app-wide programme.

---

## 7. Save-state feedback

Athlete-facing copy (no RPC / resolver / payload / cursor / Supabase /
idempotency):

| State | Copy |
|-------|------|
| Saving local write | Saving |
| Durable local write succeeded | Saved |
| Local write failed | Couldn’t save — Retry |
| Hosted completion in flight or uncertain | Completion pending |
| Hosted success or reconciled commit | Completion confirmed |

Do not show Saved until the durable local write succeeds. Do not show Complete
until hosted authority confirms or reconciliation finds the already-committed
completion. Pending must say confirmed local inputs remain retained.

---

## 8. Offline-queue boundary

**Deferred.** No background completion queue. Local actuals stay; UI stays
pending/retry with the same identity. Never fabricate hosted Complete.

---

## 9. Known limitations (honest, remaining after Sprint 2 unless closed)

- No Field Manual writes; no new phone build in this sprint.
- No GPS/wearable invention for endurance.
- Wall-clock timer continuation is not default.
- Full-app accessibility programme remains later.
- Debounced keystroke network (Sprint 1 §8) remains a performance nicety;
  coalesced revision saves are acceptable if they do not drop the last
  confirmed input.
- Preview harness is PREVIEW ONLY and must not be imported by `lib/main.dart`.

---

## 10. Preview

Internal: `lib/main_daily_journey_integrity_preview.dart`

```bash
flutter run -d chrome --web-port 4191 \
  -t lib/main_daily_journey_integrity_preview.dart
```

Not imported from `lib/main.dart`.
