# Daily Journey Integrity v1

**Status:** Binding Sprint 1 contract for production authentication, session
entry, and resumable workout state.

**Recorded:** 2026-09-20

```text
DAILY_JOURNEY_INTEGRITY_SPRINT=1
NEXT_IMPLEMENTATION_AUTHORISED=true
HOSTED_MIGRATION_REQUIRED=false
PHONE_BUILD_REQUIRED=false
FIELD_MANUAL_MUTATION=false
```

Binding:
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md),
[`../checkpoints/ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md`](../checkpoints/ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md),
[`Canonical_Programme_Architecture_Freeze_v1.md`](./Canonical_Programme_Architecture_Freeze_v1.md),
[`Phase_1_Implemented_Architecture_v1.md`](./Phase_1_Implemented_Architecture_v1.md).

This document does not start programme comparison, Android identity, broader
adaptation triggers, or a phone release.

---

## 1. Preflight (production route, before Sprint 1 edits)

| Item | Evidence |
|------|----------|
| Entry | `lib/main.dart` → `CohortPlatformApp` → `AuthGate` |
| AuthGate | `unauthenticated`/`error` + `AthleteProfileSession.hasCompletedOnboarding` → **AthleteAppShell without hosted session** |
| START TRAINING | `LoginScreen` runs `AthleteOnboardingFlow` → `AthleteProgrammeGenerationService` (Coach Brain) → local `CurrentUserSession.bind` → shell |
| Hydration | `AuthGate` calls `AthletePersistence.hydrate(allowRegenerate: true)` |
| Supabase session | `AuthService` uses `supabase_flutter` persisted `currentSession` / `currentUser` |
| Home today | `AthleteProgrammeTodaySection` → `ProgrammeSessionExecutionLauncher` → `ActiveSessionScreen` |
| Train today | `incomplete_session_train_today.dart` / calendar preview → same launcher |
| Preview players | `SessionPlayerScreen` / dedicated views — **not** AthleteAppShell destinations |
| Recovery | `SessionExecutionRouter.recoveryFlow`; `SessionPlayerScreen` TODO `RecoverySessionView` — not production launcher |
| Draft | In-progress performance record + `AthleteSessionMemoryStore` + `WorkoutProgressSnapshot` |
| Completion | `PerformanceRecordSaveCoordinator` from `ActiveSessionScreen` |

### 1.1 Route table (as found)

| State | Current screen | Current authority | Intended | Risk | Fix |
|-------|----------------|-------------------|----------|------|-----|
| Cold launch signed out | Login, or shell if local onboarding | Onboarding flag can replace auth | Login | Guest / foreign draft | Fail-closed AuthGate |
| Cold launch signed in | Shell | Supabase session + profile | Shell | OK | Keep |
| Expired session online | Error or unauthenticated | Often treated as guest if onboarded | Login | Wrong identity | Invalid → sign-in |
| Expired session offline | Same guest hole | Onboarding flag | Login **or** offline-authenticated if cached Supabase identity | Data leak | Distinguish network vs revoke |
| Previously authenticated, temporarily offline | Guest shell possible | Local profile | Shell only with persisted Supabase user + last profile | Guest plan | Offline phase |
| Profile incomplete | `ProfileSetupScreen` | Auth user, no profile | Same | OK | Keep |
| Today planned | Home Begin | Programme launcher | `ActiveSessionScreen` | OK | Identity envelope |
| Today in progress | Home Resume | Same | Same session | Duplicate start if identity weak | Resume RPC |
| Past incomplete Train today | Calendar | Same launcher | Original occurrence | Cursor-wrong-day | Keep occurrence id |
| Resumed draft | Partial memory + hosted draft | Mixed | Versioned draft | Loss / wrong session | Draft contract |
| Completed session | Home done | Hosted records | Hosted wins | Stale local draft | Completed-hosted-wins |
| Rest day | Home rest | Occurrences | Guidance, no Begin workout | False complete | No executable start |
| Executable recovery | TODO player if routed via preview | None in production | Guidance or structured blocks | Begin→TODO | Fail-closed / guidance |
| Unsupported format | Launcher throws unsupported block | Fail-closed-ish | Honest unavailable | Crashy copy | Athlete-safe error |

---

## 2. Authentication state model

`ProductionAuthPhase`:

| Phase | Meaning | Shell? |
|-------|---------|--------|
| `unauthenticated` | No valid/cached authenticated identity | No — Sign in |
| `authenticating` | Finite restore/sign-in | Loading + retry |
| `authenticatedOnline` | Verified hosted identity | Yes |
| `authenticatedOffline` | Supabase persisted session + last known profile; network failed | Yes, local drafts only for **that** user id |
| `invalidIdentity` | Definitive revoke/invalid token | Sign in; quarantine drafts by athlete id |
| `profileRequired` | Session exists, profile missing | Profile setup |
| `awaitingEmailConfirmation` | Signup pending | Verification |

### Offline identity policy

- Reuse `supabase_flutter` persisted `Session`/`User`. Do not invent a second auth store.
- `AthleteProfileSession.hasCompletedOnboarding` is **never** shell authority.
- Display name / local athlete id is **never** shell authority.
- Network failure while a persisted session exists is **not** revocation.
- Invalid refresh token / user-not-found / explicit sign-out **is** fail-closed.
- Offline phase never generates a plan or guest athlete.
- Sign-out keeps existing `AthletePersistence.clearForSignOut` (policy B).
- Drafts are keyed by authenticated `user.id`; another account cannot restore them.

---

## 3. Production session route

```text
authenticated athlete
  → active assignment + calendar occurrence
    → today’s (or Train-today) prepared package
      → ProgrammeSessionExecutionLauncher
        → ActiveSessionScreen
          → durable draft
            → idempotent completion
              → refresh Home / Calendar / Progress
```

Canonical launch identity (required for programme-backed starts):

- athlete id (= `auth.users.id`)
- assignment id
- occurrence id when present
- programme version / pin
- programmed session key
- training session id when created/resumed
- prepared package content hash
- scheduled date / day key / slot
- execution mode
- draft owner = athlete id

Preview `SessionPlayerScreen` is not a production destination.

### Restore hierarchy

| Store | Role |
|-------|------|
| `ActivePerformanceDraft` | Durable actuals. Authoritative for result restoration. |
| `ProductionSessionDraft` | Identity / integrity / classification. Not a second actuals store. |
| `ProductionSessionUiCursor` | Versioned companion navigation state, scoped to athlete + session. |
| `AthleteSessionMemoryStore` | Same-process cache only. Cannot authorize resume. Discarded when durable authority disagrees. |
| `WorkoutProgressSnapshot` | Legacy WorkoutPlayer discovery only. Never proof. Never creates a training session. Never routes to preview players. |

`ProductionRestoreResolver` is the only production resume authority. Home Resume, Calendar Train today / in-progress, boot affordance, foreground reconcile, and process-restart launch all call it before `ActiveSessionScreen` is entered with restored data.

Boot no longer shows an independent “Resume training?” prompt. Empty legacy snapshots are cleared. Unmappable `enteredResults` show **Draft cannot be safely restored**. Home’s occurrence Resume remains the athlete action when a valid durable draft exists.

UI cursor: schema v1, athlete/assignment/occurrence/training-session scoped. Missing or unsupported cursor falls back to the first incomplete block. Cursor never changes result semantics. Successful hosted completion clears envelope + cursor. Failed completion retains both.

---

## 4. Draft schema

`ProductionSessionDraft` version **1**.

Persisted fields (when present and truthful): schema version, athlete id,
assignment id, occurrence id, programme version, programmed session key,
training session id, package hash, scheduled date, started-at, active block,
completed block ids, strength/interval/endurance/EMOM/circuit actuals already
in the performance draft, notes, RPE, timer snapshot, ended-early, accepted
adaptation identity, last durable save, finalisation/idempotency key,
`entryMode` (live vs backfill).

Cosmetic UI-only state is not persisted.

### Classification on restore

| Class | Behaviour |
|-------|-----------|
| Compatible | Restore |
| Legacy/partial | Restore derivable fields; tell athlete recovery is partial |
| Stale occurrence | Do not resume; keep input quarantined |
| Stale programme version | Do not execute; re-prepare required |
| Completed hosted | Hosted wins; do not resume in-progress UI |
| Foreign athlete | Ignore/quarantine; no exposure |
| Corrupt | Ignore/quarantine; no fabricate |
| Unsupported future version | Reject explicitly |

Never fabricate timestamps, timer usage, or actuals.

---

## 5. Persistence triggers

Save after meaningful edits (debounced): set/result, block complete, note/RPE,
timer start/pause/resume/advance, adaptation accept, app background, route pop,
before hosted finalise.

---

## 6. Recovery decision

**Decision:** authored **passive rest/recovery** is a **guidance-only** Home /
Calendar state (no Begin-as-workout). Structured recovery **blocks** on the
prepared plan execute through `ActiveSessionScreen` like any other block.
Unsupported `recoveryFlow` dedicated player (`RecoverySessionView` TODO) is
**not** a production destination — fail closed with unavailable copy.

Do not mark passive guidance complete as a workout.

---

## 7. Completion

One finalisation path from `ActiveSessionScreen` via
`PerformanceRecordSaveCoordinator`. Hosted success is required before draft
clear. Failure retains draft. Double-tap / retry must be idempotent. Offline
without a queue stays **Completion pending** + draft retained — never false
hosted complete. Backfill ≠ live. Correction uses completed-results path.

---

## 8. Performance budgets (targets)

| Step | Target |
|------|--------|
| Auth resolution | < 1.5s cached session |
| Shell display | First frame after phase known |
| Today display | Occurrence projection only — not full programme tree |
| Begin/Resume | Immediate local feedback; prepare already done |
| Draft write | Debounced; not per keystroke network |
| Draft restore | Before first editable frame when local |
| Completion | Immediate pending UI; hosted then refresh |

---

## 9. Deferred

Programme comparison · Android identity/signing · full a11y programme ·
wearables · broader adaptation triggers · **offline completion queue** (honest
pending/retry + retained draft only) · phone build 7 draft mutation · hosted
writes · composing every format through a device-run ActiveSessionScreen
widget matrix beyond the in-memory production-route restore tests.

---

## 10. Preview

Internal: `lib/main_daily_journey_integrity_preview.dart`

Command: `flutter run -t lib/main_daily_journey_integrity_preview.dart`

Not imported from `lib/main.dart`.
