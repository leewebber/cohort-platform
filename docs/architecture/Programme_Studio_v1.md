# Programme Studio v1

**Status:** Infrastructure architecture **approved**. Stage 1 is
**complete, awaiting integration**.
**Recorded:** 2026-09-25
**Infrastructure approved:** 2026-09-25
**Parent:**
[`Launch_Programme_Library_v1.md`](./Launch_Programme_Library_v1.md)
**Related:**
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md),
[`Programme_Performance_Metrics_Profile_v1.md`](./Programme_Performance_Metrics_Profile_v1.md)
**Base:** `docs/launch-programme-library-audit` after
`2b72739602fbc887337c15b489a8919ac8c451b4`

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE_AWAITING_INTEGRATION
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This document governs Programme Studio. **Stage 1** is visually
approved and awaits integration
([`../checkpoints/PROGRAMME_STUDIO_STAGE_1_HANDOFF.md`](../checkpoints/PROGRAMME_STUDIO_STAGE_1_HANDOFF.md)).
Stages 2–3, running/pace, metrics, content, and publication remain
unauthorised.

---

## 1. Purpose

Studio exists so a human can inspect an authored programme the way an
athlete will live it — weeks, days, full prescriptions, metadata,
validation, identity, and quality-gate status — **without** becoming a
second source of truth or an unrestricted database editor.

It is an internal tool. It is not the athlete app, not a coach
marketplace, and not Build Your Own.

## 2. Non-goals

- Athlete-facing product UI
- Direct SQL or unrestricted hosted edits
- Silent mutation of a published version
- Garmin export or activity import
- Payments, beta, or catalogue publication
- Authoring HYROX Base or any other launch-family prescriptions
- Replacing Plan Package compile / import / approve RPCs

---

## 3. Source-authority model

**Current canonical sources remain authoritative:**

| Concern | Canonical source today |
|---------|------------------------|
| Catalogue schedule, metadata, contracts | Plan Package v1 YAML |
| Content identity | Canonical JSON SHA-256 from `PlanPackageCompiler` |
| Executable prescription | Published `performance_protocols` + `session_blocks` (Founder YAML import or protocol builder upstream) |
| Catalogue lifecycle | Import / publish / approve / replace RPCs |
| Athlete pin | `programme_assignments.programme_version_id` |

Studio **must not** create a parallel programme store.

| Stage | Write rule |
|-------|------------|
| Stage 1 (read-only) | Reads canonical files and compiled manifests only. No writes. |
| Stage 2 (structured authoring) | Writes or generates the **same** canonical representation (Plan Package YAML and/or protocol authoring YAML). Never a Studio-only blob. |
| Stage 3 (publish workflow) | Invokes existing compile → import → explicit publish/approve. No in-place published edit. |

**Publication remains a separate explicit approval action.** No Studio
control may silently modify a published version. Edits after publication
require a new immutable `version_number`.

Draft / published / approved / catalogue-default / archived-withdrawn
must map to states that **already exist** (`lifecycle_status`,
`approved_for_global`, archive). Studio must not invent a fifth
lifecycle that the RPCs cannot express.

---

## 4. Required capabilities (v1 product surface)

| Capability | Stage 1 | Later |
|------------|---------|-------|
| Programme and immutable version list | Yes | — |
| Draft / approved / published / default / withdrawn status | Yes (read existing) | — |
| Week-by-week overview | Yes | — |
| Day and session explorer | Yes | — |
| Complete protocol/session prescription rendering | Yes | — |
| Strength, run, erg, mixed-modal, recovery views | Yes (from current block model) | Richer after running-workout model |
| Programme metadata preview | Yes | — |
| Athlete-facing preview (discovery/detail facts) | Yes | — |
| Validation errors and warnings | Yes (compiler + import-preview issues) | — |
| Canonical package identity and SHA-256 | Yes | — |
| Version-to-version diff | Yes (canonical JSON / schedule / metadata) | Prescription-aware diff |
| Quality-gate checklist | Yes (human record + automated ticks) | — |
| Founder / head-coach review record | Yes (local/internal, not athlete data) | — |
| Running structured-step preview | Preview of **current** timer/block encoding | Full model after running sprint |
| Metrics-profile preview | Show package assessments/evidence if present | Full profile after metrics sprint |
| Garmin / export-readiness preview | Readiness flags only; **no export** | Provider work later |
| Unrestricted database editing | **Forbidden** | **Forbidden** |

---

## 5. Delivery stages

### Stage 1 — read-only review and validation (Sprint A)

**Complete, awaiting integration.** Internal, local, desktop-first on Lee’s Mac.
Dedicated **non-production** entry point only. Must not be imported by
`lib/main.dart` or appear in athlete navigation. No auth or hosted
deployment. No hosted SELECT or mutation. No SQL, migration, or
dependency change expected.

If Stage 1 unexpectedly requires a schema/database change or a second
authoring authority, **stop** for a new founder decision.

It may read and project existing **canonical local**
programme / package / protocol artifacts. It must **not** edit
canonical source, write to the database, publish versions, change
defaults, or create programme content.

Prefer a **deterministic generated review model** if the UI cannot
safely read repository sources directly. Any generated review artifact
must be reproducible, derived, and **excluded from publication
authority**. Do not duplicate or manually transcribe programme facts
into preview fixtures merely to look complete. If a genuine programme
cannot be projected, show the limitation and fail honestly. Fixtures
may test error/empty states only.

Command-line compile/hash remains the operator path for import.

### Stage 2 — structured authoring against one canonical source

Forms or structured editors that emit Plan Package YAML and protocol
authoring YAML. Still no publish. Still no hosted default change.

### Stage 3 — compile / diff / approve / publication workflow

Buttons that call the existing trusted import and service-role RPCs
through the same controlled operator path used today. Human must
confirm replace-default and pin preservation. Fail closed on hash
mismatch.

**Recommend leaving Stage 3 command-line until the first family is
ready to publish.** Studio Stage 1+2 do not require Cloud Run.

---

## 6. What can stay command-line initially

- `PlanPackageCompiler` / golden hash
- Trusted import HTTP or `service_role` RPC
- `publish_*` / `approve_*` / `replace_*`
- Local DB gates
- M9 graph artifact build

Studio Stage 1 should **display** those results, not replace them.

---

## 7. Metrics profile and running preview

Until
[`Programme_Performance_Metrics_Profile_v1.md`](./Programme_Performance_Metrics_Profile_v1.md)
is implemented, Studio shows existing package `assessments`,
`comparison_identities`, and `performance_evidence_requirements` (often
empty). It must label an empty profile as **not publication-ready**
once the fail-closed rule is introduced — it must not invent metrics.

Until
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md)
is implemented, running preview renders current `WorkoutFormat` +
`TimerConfiguration` + capture mode honestly (time-based intervals,
steady-state endurance). It must not display Garmin-ready steps that
do not exist.

---

## 8. Sprint A required capabilities

| Capability | Rule |
|------------|------|
| Inventory classification | Honest: production-published / internal-personal / legacy-withheld / fixture-test-example |
| Identity | Programme + immutable version |
| Metadata | Authored facts from the version / package |
| Structure | Week-by-week overview; day/session navigation |
| Prescriptions | Full protocol/session inspection |
| Modalities | Honest strength, run, erg, mixed-modal, recovery, assessment **already present** |
| Compiler | Validation status + canonical package hash |
| Comparison | Version-to-version where existing artifacts permit |
| Athlete preview | Discovery/detail metadata projection |
| Quality gate | Checklist projection (not a pass mark) |
| Readiness | Structured running, pace calculations, metrics profile, device/Garmin — **missing must show as missing/not implemented**, never simulated |
| Formulas / metrics | No final pace formulas; no real programme metrics selected |

## 9. Sprint A acceptance (implementation sprint, later)

The implementation sprint must prove:

- deterministic projection from authoritative artifacts
- stable package / version / hash identity
- complete navigation across available weeks / days / sessions
- no silent omission of unsupported prescriptions
- clear validation failures
- no source or hosted mutation
- no production entry-point import
- desktop layout and keyboard/mouse usability
- narrow viewport does not crash (desktop remains primary)
- large text remains readable
- accessible labels and status wording

**Visual founder review is required** before Sprint A is complete.

Complete and review Sprint A before beginning Sprint B. HYROX Base
authoring may not even be proposed until A, B, and C are accepted.
