# Daily Journey Accessibility and Interaction Integrity v1

**Status:** Binding Sprint 3 contract for production athlete-workout
accessibility, physical usability, and display/input resilience.

**Recorded:** 2026-09-21

```text
DAILY_JOURNEY_INTEGRITY_SPRINT=3
NEXT_IMPLEMENTATION_AUTHORISED=true
HOSTED_MIGRATION_REQUIRED=false
PHONE_BUILD_REQUIRED=false
FIELD_MANUAL_MUTATION=false
VISUAL_REDESIGN=false
BLUE_BRAND_PRODUCTION=false
WCAG_COMPLIANCE_CLAIMED=false
IOS_VOICEOVER_VALIDATED=false
ANDROID_TALKBACK_VALIDATED=false
APP_WIDE_ACCESSIBILITY_COMPLETE=false
ANDROID_RELEASE_IDENTITY=deferred
```

Binding:
[`Daily_Journey_Integrity_v1.md`](./Daily_Journey_Integrity_v1.md),
[`Daily_Journey_Execution_Reliability_v1.md`](./Daily_Journey_Execution_Reliability_v1.md),
[`../checkpoints/DAILY_JOURNEY_INTEGRITY_SPRINT_1_HANDOFF.md`](../checkpoints/DAILY_JOURNEY_INTEGRITY_SPRINT_1_HANDOFF.md),
[`../checkpoints/DAILY_JOURNEY_EXECUTION_RELIABILITY_SPRINT_2_HANDOFF.md`](../checkpoints/DAILY_JOURNEY_EXECUTION_RELIABILITY_SPRINT_2_HANDOFF.md),
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md).

Sprint 1 established one restore chain. Sprint 2 proved interruption,
serialized restart, and completion reconciliation. Sprint 3 makes that same
production journey usable with assistive technology, larger text, narrow
phones, and non-colour status — without replacing Sprint 1/2 authority.

This document does not start programme comparison, Android release work,
wearables, offline completion queue, the experimental electric-blue brand, or
an app-wide accessibility programme.

---

## 1. Evidence classes (must not be collapsed)

| Class | What it may prove | What it may not claim |
|-------|-------------------|------------------------|
| **1. Production accessibility implemented and automatically proven** | Widget/semantics tests against production-facing widgets on the Daily Journey path; tap targets; labels/roles/state; focus traversal in the test binding; reduced-motion flags; overflow checks at stated scales/widths; duplicate-action lock | WCAG conformance; iOS or Android platform certification |
| **2. Preview / browser evidence** | Founder visual inspection of representative projections at width/scale/reduced-motion in the Daily Journey preview (`PREVIEW ONLY`) | Production VoiceOver/TalkBack behaviour; physical-device layout |
| **3. Physical-device and VoiceOver/TalkBack evidence** | Reserved. Not performed in this sprint | Any VoiceOver, TalkBack, Switch Control, or hardware-keyboard claim |
| **4. App-wide accessibility work outside this path** | Out of scope | Coach surfaces, Backfill capture, onboarding, settings, Plan Library remnants |
| **5. Deferred Android release identity and signing** | Out of scope | Play package name, signing, TalkBack on a release APK |

Do not claim WCAG, iOS, Android, VoiceOver, or TalkBack compliance without the
matching evidence class. Class 1 passing is **not** Class 3.

---

## 2. Production path (only)

```text
authenticated athlete
  → Home / Calendar
  → ProgrammeSessionExecutionLauncher
  → SessionExecutionLauncher
  → ProductionRestoreResolver
  → ActiveSessionScreen
  → completion / pending / reconciled result
```

Include production-facing widgets used by that journey. Preview-only players
are not readiness evidence. Backfill remains a separate path and must not be
silently merged into live execution.

Covered surfaces:

* Today card Begin / Resume / Complete states
* blocked, stale, foreign, corrupt, unsupported, and partially recoverable drafts
* strength capture
* intervals
* endurance manual capture
* EMOM
* circuit
* for-time
* AMRAP
* structured recovery
* guidance-only rest
* completion confirmation
* completion pending and Retry
* reconciled hosted completion
* View results
* navigation back to Home
* destructive discard confirmation

---

## 3. Accessibility requirements

### Screen-reader meaning

Every actionable production control on this path must have:

* a concise accessible label
* the correct button / text-field / toggle role
* current value or state where relevant
* an accessible hint only when it adds necessary meaning
* no duplicate semantic announcement from nested text or icons

Workout state must be understandable without colour, card borders, icon
direction, or visual placement. Status words such as Begin, Resume, Complete,
Paused, Pending, and Cannot restore are authoritative — not phosphor/grey/red
alone.

### Focus and navigation

Predicted focus order for:

* entering a workout
* moving through blocks and exercises
* set capture fields
* timer controls
* completion
* errors and recovery actions
* pending / retry
* reconciled completion

When the UI changes materially, focus must move deliberately or remain stable.
It must not jump unpredictably to the top of the page. Dialogs trap focus
(platform `AlertDialog`) and return it to the invoking control after dismissal.

### State announcements

Announce meaningful events, not ticks:

* draft restored
* timer paused / resumed
* set recorded (completed checkbox)
* block completed
* save failed but local results retained
* completion pending
* completion reconciled / already saved
* destructive discard confirmed

Do not announce every timer second.

### Timer accessibility

Timer controls expose:

* timer type (interval, EMOM, for-time, AMRAP, circuit)
* running or paused
* meaningful elapsed or remaining value
* Resume / Pause / Reset / Record action names
* durable restored state

The clock face is visual-only. A single combined summary is the semantic
source. Pause/resume updates a live region once.

### Input accessibility

Strength and manual endurance fields use unambiguous labels and spoken units
(for example “Set 2 load, kilograms”). Prove:

* numeric keyboard
* stable values while focused
* validation that names the field
* completed-set controls as checked / unchecked
* previous-performance load failure does not block capture

### Touch and physical usability

Interactive targets on this route use a minimum 48 logical-pixel square.
Primary `CohortButton` keeps a 54 logical-pixel minimum height and wraps rather
than clipping at large text.

Begin, Resume, Finish, Retry, discard, and View results ignore duplicate taps
within a short lock window. Retry remains available after the lock expires.
Completion still uses the frozen Sprint 2 idempotency identity.

### Text scaling and layout

Required matrix (logical pixels × text scale):

| Width | 1.0× | 1.3× | 1.6× | 2.0× |
|-------|------|------|------|------|
| ~320  | required | required | required | required |
| ~390  | required | required | required | required |

Text may wrap. It must not clip critical copy, overlap controls, hide inputs,
move the only action off-screen without scrolling, produce unscrollable
overflow, or truncate safety/error meaning.

Portrait is primary. Landscape must not clip safety actions; this sprint does
not redesign the workout for landscape-first use.

### Contrast (measured, current black/green theme)

No new colour system. Measurements use relative luminance (sRGB) against
`CohortColors.background` `#030403` unless noted.

| Combination | Ratio | Notes |
|-------------|-------|--------|
| `textPrimary` `#ECEEEA` on background | 17.59:1 | Body and titles |
| `textSecondary` `#939C94` on background | 7.26:1 | Secondary copy; use for dates/meta on this path |
| `textMuted` `#5A635C` on background | 3.30:1 | **Fails** 4.5:1 normal text. Do not use for status, errors, or actions on this path |
| `phosphor` `#96A872` on background | 7.96:1 | Status text (with words, not colour alone) |
| `olive` `#738864` on background | 5.31:1 | Eyebrow / format labels |
| Button ink `#0C0E0B` on phosphor fill | 7.51:1 | Primary CTA label |
| `danger` `#A85646` on background | 3.99:1 | **Fails** 4.5:1. Errors on this path use `textPrimary` plus the word Error / Pending |
| `success` `#667A58` on background | 4.39:1 | **Below** 4.5:1. Completed state uses the word Completed, not green alone |
| Disabled primary at 0.45 opacity (pre-sprint) | 3.89:1 | **Fails**. Disabled CTAs must not fade the label; use enabled-false semantics plus `textSecondary` on `surfaceRaised` |

These ratios are calculated evidence for Class 1 documentation. They are not a
WCAG audit of the whole app.

### Motion

Honor `MediaQuery.disableAnimationsOf` for nonessential expand/collapse.
State must remain understandable with animations disabled.

---

## 4. Authority preserved from Sprint 1 and Sprint 2

Accessibility wrappers must not create alternate execution or completion paths.

Do not weaken or replace:

* authoritative hosted athlete identity
* `ProductionRestoreResolver`
* `ActivePerformanceDraft` as authoritative actuals
* `ProductionSessionDraft` identity / classification
* durable UI/timer cursor evidence
* fail-closed foreign / stale / corrupt / unsupported behaviour
* frozen completion idempotency identity
* completion pending + Retry
* hosted-complete reconciliation
* hosted-success-only cleanup
* guidance-only recovery prohibition
* single `View results` CTA
* truthful duration calculation (`completed_at − started_at`, omit ≤ 0)
* enrolment, assignments, M9/M10 authority, or content graph bindings

---

## 5. Preview

Extend `lib/main_daily_journey_integrity_preview.dart`. Do not import it from
`lib/main.dart`. Keep the PREVIEW ONLY banner.

Accessibility review mode inspects representative production projections at
narrow (320) and normal iPhone (390) widths, text scales 1.0 / 1.3 / 1.6 / 2.0,
reduced motion, and optional semantics debugger.

Required review states:

1. Begin session
2. Resumed strength with focused set input
3. Paused interval timer
4. Resumed for-time
5. Resumed AMRAP
6. Completion pending + Retry
7. Reconciled completion
8. Partially recoverable draft
9. Cannot safely restore
10. Destructive discard confirmation
11. Structured recovery
12. Guidance-only rest

Preview evidence is Class 2 only.

---

## 6. Verification

Focused widget/semantics tests against production-facing widgets. Do not alter
test expectations to hide overflow, semantic duplication, or inaccessible
interaction.

Gates: focused accessibility + production-journey tests; Sprint 1 restore/auth
tests; Sprint 2 serialized reliability, format, completion, and duration tests;
Home / Calendar / Train today / Backfill / sign-out / production-entry
regressions; changed-file `flutter analyze`; `git diff --check`; Phase 2
consolidation safety gate; full `flutter test`.

No local DB gate unless a migration or database file changes. None is required
for this sprint.

---

## 7. Stop boundary

Pause for founder architectural and visual approval. Local branch only. Nothing
pushed. No Field Manual write. No founder-phone install. `.env` unchanged. Do
not start Sprint 4 or later milestones.

Retained future work:

* physical iPhone VoiceOver validation
* physical Android TalkBack validation
* complete app-wide accessibility audit
* Android package identity and release signing
* GPS / wearable endurance evidence
* offline completion queue
* programme comparison
* blue-brand production implementation
