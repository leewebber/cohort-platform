# Daily Journey Integrity — closeout

**Recorded:** 2026-09-22

**Status:** Daily Journey Integrity **complete**. Local documentation
closeout. **Paused for founder approval** before integration. The first
Complete Athlete Experience sprint is **not** authorised.

```text
DAILY_JOURNEY_INTEGRITY=COMPLETE
NEXT_MILESTONE=COMPLETE_ATHLETE_EXPERIENCE
NEXT_IMPLEMENTATION_AUTHORISED=false
PROGRAMME_COMPARISON_BOUND=false
PHONE_PRODUCTION_UNCHANGED=true
TEMPORARY_A11Y_PREVIEW_REMOVED=true
HOSTED_WRITES=false
FIELD_MANUAL_UNTOUCHED=true
PUSHED=false
REPO_ENV_UNTOUCHED=true
WCAG_COMPLIANCE_CLAIMED=false
IOS_VOICEOVER_CERTIFIED=false
ANDROID_TALKBACK_VALIDATED=false
APP_WIDE_ACCESSIBILITY_COMPLETE=false
```

Binding contracts remain historical evidence:

- [`../architecture/Daily_Journey_Integrity_v1.md`](../architecture/Daily_Journey_Integrity_v1.md)
- [`../architecture/Daily_Journey_Execution_Reliability_v1.md`](../architecture/Daily_Journey_Execution_Reliability_v1.md)
- [`../architecture/Daily_Journey_Accessibility_and_Interaction_Integrity_v1.md`](../architecture/Daily_Journey_Accessibility_and_Interaction_Integrity_v1.md)

This file does not rewrite
[`../architecture/Canonical_Programme_Architecture_Freeze_v1.md`](../architecture/Canonical_Programme_Architecture_Freeze_v1.md)
or Phase 1 architecture freeze documents.

---

## Production authority

```text
authoritative authenticated athlete
  → Home / Calendar
  → ProgrammeSessionExecutionLauncher
  → SessionExecutionLauncher
  → ProductionRestoreResolver
  → ActiveSessionScreen
  → ActivePerformanceDraft
  → idempotent hosted completion
  → truthful history/results
```

`ActivePerformanceDraft` remains durable actuals. `ProductionSessionDraft`
remains identity and classification. `ProductionSessionUiCursor` remains
position. Adaptation is still a proposal, not a second prescription
authority. Backfill remains separate from live session execution. Preview
entry `lib/main_daily_journey_integrity_preview.dart` is not imported by
`lib/main.dart`.

---

## Integrated range

Approved base / `origin/main` at closeout start:
`6796cb2f1199bfa0ef4cf803f5a0a19e142f6bbe`.

| Slice | HEAD | Note |
|-------|------|------|
| Sprint 1 | `e646f11` | Authority and safe restoration |
| Sprint 2 | `5b584a6` | Execution reliability |
| Sprint 3 | `5329343` | Accessibility and interaction integrity |
| Whitespace correction | `6796cb2` | Trailing EOF blank line on preview only |

The Sprint 1–3 plus whitespace range is linear. No merge rewrite.

Exact production HEAD `6796cb2` already passed focused Sprint 3 and prior
regressions, changed-file analysis, and full `flutter test`: **3183 passed,
6 skipped, 0 failed**.

---

## Sprint 1 — authority and safe restoration

- Authoritative hosted athlete identity
- Guest and legacy Coach Brain production entry fail-closed
- One production execution route
- Durable `ActivePerformanceDraft` actuals
- `ProductionSessionDraft` identity and classification
- Durable UI cursor
- Legacy snapshot no longer authorises resume
- Safe partial recovery
- Stale, foreign, corrupt, and unsupported drafts fail closed
- Guidance-only versus structured recovery policy

---

## Sprint 2 — execution reliability

- Serialized process-kill / cold-restart proof
- Strength, interval, endurance-manual, EMOM, circuit, for-time, and AMRAP
  persistence
- Paused timer restore without invented wall-clock training
- Frozen completion idempotency identity
- Uncertain completion remains pending and retryable
- Hosted-complete reconciliation
- Hosted success wins over stale local state
- Truthful duration calculation
- Single View results action
- No silent data loss

---

## Sprint 3 — accessibility and interaction integrity

- Production labels, roles, values, states, and hints
- Logical focus order
- Useful announcements without per-second timer spam
- Labelled fields and units
- Accessible checked / unchecked controls
- 48 / 54-point interaction targets
- 320 / 390 width coverage
- 1.0×, 1.3×, 1.6×, and 2.0× text-scale coverage
- Non-colour status meaning
- Reduced-motion support
- Contrast evidence (not a WCAG claim)
- Safe scrolling and reachable actions

---

## Physical iPhone evidence

Classification: **representative founder VoiceOver review**, not an
exhaustive matrix and not a certification.

- Fixture-only side-by-side validation app (`Cohort A11y Preview`,
  `uk.cohortperformance.cohort.a11ypreview`)
- Device: iPhone 17 Pro Max / iOS 26.4.2
- Initial validation build `0.0.0 (9007)` was a Flutter **debug / JIT**
  binary and could not launch independently. Device console:
  `Cannot create a FlutterEngine instance in debug mode without Flutter
  tooling or Xcode`; process terminated with signal 11
- Evidence-backed correction: standalone AOT **profile** build
  `0.0.0 (9008)` remained open without a Flutter debugger
- Production **Cohort Platform** `uk.cohortperformance.cohort` **1.0.0 (7)**
  was never replaced, launched, or mutated by the validation install
- Founder performed a representative physical VoiceOver review and accepted
  the current accessibility position
- Temporary validation app **removed after review** (bundle
  `uk.cohortperformance.cohort.a11ypreview` absent; production 1.0.0 (7)
  still installed)

### Not claimed

- Exhaustive VoiceOver matrix completion
- Formal accessibility certification
- WCAG conformance
- App Store accessibility-label eligibility across every common task
- Android TalkBack validation
- App-wide accessibility completion

---

## Deferred (does not reopen Daily Journey now)

- Offline completion queue
- GPS / wearable endurance evidence
- Android TalkBack validation
- Android package identity and release signing
- Broader app-wide accessibility review
- Physical beta testing across multiple devices
- Launch telemetry and crash monitoring

---

## Future capabilities recorded (not started)

These are approved **roadmap** capabilities only. No schema, UI, timer
product, radar maths, or metric mapping is authorised by this closeout.

### Standalone WOD Timer and Whiteboard

Pre-launch utility **candidate after the core athlete journey is complete**.
Do not promote it ahead of remaining Athlete Experience Completion
sequencing without a later founder decision.

Purpose: useful without programme enrolment; possible free-tier acquisition
hook; gym-floor utility; functional-fitness credibility; entry before
programme commitment.

Concept: timer-only and optional whiteboard; AMRAP, EMOM, for-time,
rounds-for-time, intervals, Tabata, configurable work-rest; large gym-floor
timer; pause / resume / reset with accidental-action protection; round/lap
tracking; finger or stylus ink; workout written beside the timer; mark
rounds, reps, or movements; typed accessible alternative to freehand ink;
local / offline; save and reuse a WOD; optional later history linkage.
Sharing, templates, and community remain later decisions.

Architecture direction only: reuse proven timer and persistence primitives
where appropriate; programme enrolment is not a prerequisite; do not create
a second conflicting workout-history authority; freehand ink is visual
annotation, not canonical structured workout data; accessible typed content
must exist if whiteboard content affects operation; free/paid packaging is a
commercial decision, not this closeout.

### Athlete-defined Performance Portfolio

Belongs to the later **Progression and Tracking** milestone. Do not
implement now.

Purpose: athletes track what matters to their sport and goals; complements
Cohort-authored HYROX, Hybrid, and Tactical metric sets; Progress beyond a
single programme; long-term identity and retention.

Concept: Cohort-authored metric packs and athlete-created portfolios;
custom name, test protocol, unit, direction (higher-is-better /
lower-is-better / target-range), baseline, current, personal best, target,
test date and history, optional category; configurable radar; trends;
programme/session coverage against selected metrics; later suggestions for
neglected capabilities.

Integrity rules:

1. Raw values with incompatible units must never be plotted directly on one
   radar axis system.
2. Radar values require an explicit normalisation model (baseline-to-target
   progress, validated benchmark bands, or athlete-relative percentile
   where evidence exists).
3. **Training coverage** and **measured performance change** are separate.
   Coverage shows what training addressed. Improvement requires recorded
   test evidence.
4. Cohort must not claim an athlete improved merely because sessions
   targeted that capability.
5. Programme-to-metric relationships must come from authored / canonical
   mappings, not display-name similarity or unconstrained AI inference.
6. Historical values remain truthful and are not rewritten when portfolios
   change.
7. User-created metrics must not alter canonical programme content.

---

## Next milestone

`NEXT_MILESTONE=COMPLETE_ATHLETE_EXPERIENCE`

Daily Journey Integrity is closed. Complete Athlete Experience is
**audited, awaiting founder approval**:
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md),
[`COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md`](./COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md).
Implementation is **not** started.

Do not start Android TalkBack, Android release identity, Daily Journey
reimplementation, offline completion, wearables/GPS, or the experimental
blue brand from this closeout.
