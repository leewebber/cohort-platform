# Daily Journey Integrity Sprint 1 — handoff

**Recorded:** 2026-09-20

**Status:** Local Sprint 1 plus restore-authority completion. **Paused for
founder architectural and visual approval.**

```text
DAILY_JOURNEY_INTEGRITY_SPRINT_1=local
RESTORE_AUTHORITY_COMPLETE=local
NEXT_IMPLEMENTATION_AUTHORISED=false
PHONE_UNTOUCHED=true
HOSTED_WRITES=false
PUSHED=false
REPO_ENV_UNTOUCHED=true
OFFLINE_COMPLETION_QUEUE=deferred
```

Binding:
[`../architecture/Daily_Journey_Integrity_v1.md`](../architecture/Daily_Journey_Integrity_v1.md),
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md).

This sprint did **not** mutate Field Manual, change migrations, rebuild the
phone, or start programme comparison / Android identity / broader adaptation.

---

## Authentication

`ProductionAuthAuthority` is the shell gate. Local onboarding cannot authorize
entry. `LoginScreen` no longer offers START TRAINING. AuthGate hydration does
not use `WorkoutProgressSnapshot` as authentication. Coach Brain
`AthleteOnboardingFlow` / `AthleteProgrammeGenerationService` remain **legacy /
deferred**.

Offline: persisted Supabase session + last verified profile for **that** user
id → `authenticatedOffline`. Invalid refresh/JWT → `invalidIdentity`.
Network ≠ revocation.

Sign-out clears `AthleteSessionMemoryStore` and
`ProductionRestoreEnvelopeStore` for the signed-out athlete, plus existing
local persistence policy B. Hosted progress is not deleted.

---

## Production restore hierarchy

```text
authenticated athlete
  → ProgrammeSessionExecutionLauncher
    → SessionExecutionLauncher
      → ProductionRestoreResolver
        → ActiveSessionScreen
          → ActivePerformanceDraft (actuals)
          → ProductionSessionDraft + UI cursor (companion)
            → PerformanceRecordSaveCoordinator completion
```

| Store | Disposition |
|-------|-------------|
| `ActivePerformanceDraft` | Authoritative durable actuals |
| `ProductionSessionDraft` | Identity/classification on every restore |
| `ProductionSessionUiCursor` | Companion working position |
| `AthleteSessionMemoryStore` | In-process only; cannot authorize resume |
| `WorkoutProgressSnapshot` | Legacy discovery; boot prompt retired |

Production resume entries that must use the resolver:

- Home Begin/Resume
- Calendar Resume / Train today in-progress
- process-restart launch
- foreground reconcile on `ActiveSessionScreen`
- direct `launchActiveSessionWithPlan`

Backfill remains a separate path.

---

## Recovery

Passive rest/recovery = **guidance only**. Structured blocks execute on
`ActiveSessionScreen`. Dedicated recovery player is not production.

---

## Offline completion

**Deferred.** Local actuals remain durable. UI must stay pending/retry with
the same idempotency key. Never show hosted Complete from local state alone.

---

## Format restore matrix (production route, in-memory)

Proven via `test/session/production_format_restore_matrix_test.dart`
(capture → save → restart → resolver), not dedicated preview players:

| Format | Evidence |
|--------|----------|
| Strength | sets/load/reps/RPE + cursor |
| Intervals | interval actuals |
| Endurance | distance/duration/HR/note/partial |
| EMOM | score + timer cursor |
| Circuit | ended-early truth |
| For-time | elapsed + cap |
| AMRAP | rounds/reps |
| Structured recovery | executable-blocks policy |
| Guidance-only rest | no capture path |
| Unsupported | fail-closed |

Not claimed: device-run ActiveSessionScreen widget matrix for every format.

---

## Preview

```bash
flutter run -t lib/main_daily_journey_integrity_preview.dart
```

Optional Chrome: `flutter run -d chrome --web-port 4191 -t lib/main_daily_journey_integrity_preview.dart`

Not imported from `lib/main.dart`. No hosted data.

---

## Remaining launch gaps

Offline completion queue · phone draft migration · full a11y programme ·
comparison · Android identity · composing restore into a live device session
for every format.

---

## Next

Do not start the next milestone until founder approves this sprint.
