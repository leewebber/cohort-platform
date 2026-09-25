# Programme Studio v1

**Status:** Binding internal-tool architecture. **Not implemented.**
**Recorded:** 2026-09-25
**Parent:**
[`Launch_Programme_Library_v1.md`](./Launch_Programme_Library_v1.md)
**Related:**
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md),
[`Programme_Performance_Metrics_Profile_v1.md`](./Programme_Performance_Metrics_Profile_v1.md)
**Base:** `docs/launch-programme-library-audit` after
`28432212b4cba125cead523754850b3be844aac5`

```text
PROGRAMME_STUDIO_IMPLEMENTATION_AUTHORISED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This document defines an internal desktop/web-friendly Programme Studio
for founder and head-coach review. It is **not** a licence to implement
Studio, author programmes, or publish catalogue content.

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

### Stage 1 — read-only review and validation

Local or internal desktop/web. Load a Plan Package path and resolve
referenced protocols from local fixtures or a **read-only** projection.
Show compile result, hash, week map, session bodies, metadata, and gate
checklist. No hosted mutation.

**This is the minimum Studio stage before any new launch-family
authoring is reviewed.** Command-line compile/hash may remain the
operator path for import.

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

## 8. Acceptance (when later implemented)

Stage 1 is accepted when a founder can review Apollo v2 week structure
and protocol bodies without writing hosted data, and can see compile
hash plus validation issues. No launch-family content is created by
that acceptance.
