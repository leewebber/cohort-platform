# Daily Journey Integrity Sprint 1 — handoff

**Recorded:** 2026-09-20

**Status:** Local Sprint 1 implementation of production authentication,
canonical `ActiveSessionScreen` entry, draft classification, and recovery
guidance. **Paused for founder architectural and visual approval.**

```text
DAILY_JOURNEY_INTEGRITY_SPRINT_1=local
NEXT_IMPLEMENTATION_AUTHORISED=false
PHONE_UNTOUCHED=true
HOSTED_WRITES=false
PUSHED=false
REPO_ENV_UNTOUCHED=true
```

Binding:
[`../architecture/Daily_Journey_Integrity_v1.md`](../architecture/Daily_Journey_Integrity_v1.md),
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md).

This sprint did **not** mutate Field Manual, change migrations, rebuild the
phone, or start programme comparison / Android identity / broader adaptation.

---

## Authentication

`ProductionAuthAuthority` is the shell gate. Local onboarding cannot authorize
entry. `LoginScreen` no longer offers START TRAINING. Coach Brain
`AthleteOnboardingFlow` / `AthleteProgrammeGenerationService` remain in-repo
as **legacy / deferred** (hydrator reconstruct tests, prepared-execution
reverter) and are not a production launch path.

Offline: persisted Supabase session + last verified profile for **that** user
id → `authenticatedOffline`. Invalid refresh/JWT → `invalidIdentity` → sign
in. Network ≠ revocation.

## Production route

Home Begin/Resume and Calendar Train today already used
`ProgrammeSessionExecutionLauncher` → `ActiveSessionScreen`. Sprint 1 adds
recovery-guidance fail-closed (no Begin-as-workout), draft identity
classification, background persist on `ActiveSessionScreen`, and a production
destination scan (no `SessionPlayerScreen`).

## Draft

`ProductionSessionDraft` schema version **1**. Classifier handles compatible,
legacy/partial, stale occurrence/version, completed-hosted-wins, foreign,
corrupt, unsupported future. Actuals remain in the existing performance draft /
in-progress record path.

## Recovery decision

Passive rest/recovery = **guidance only**. Structured blocks still execute on
`ActiveSessionScreen`. `RecoverySessionView` TODO is not a production
destination.

## Preview

```bash
flutter run -t lib/main_daily_journey_integrity_preview.dart
```

Optional Chrome: `flutter run -d chrome --web-port 4191 -t lib/main_daily_journey_integrity_preview.dart`

Not imported from `lib/main.dart`. No hosted data. No production athlete ids.

## Deferred

Full format-by-format restore harness on device · offline completion queue ·
complete a11y programme · phone draft migration of Lee’s build 7 · comparison ·
Android identity.

## Next

Do not start the next milestone until founder approves this sprint.
