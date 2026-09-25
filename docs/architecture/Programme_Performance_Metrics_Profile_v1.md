# Programme Performance Metrics Profile v1

**Status:** Binding metrics-profile architecture. **Not implemented.**
No programme metrics are selected or authorised.
**Recorded:** 2026-09-25
**Parent:**
[`Launch_Programme_Library_v1.md`](./Launch_Programme_Library_v1.md)
**Related:**
[`Programme_Studio_v1.md`](./Programme_Studio_v1.md),
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md)

```text
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Each immutable programme version that claims performance outcomes must
own a **metrics profile**. The profile is not a universal fitness score.
Compilation alone does not populate it.

---

## 1. Authority

The profile is owned by `programme_versions.id` (the pin). Catalogue
default replacement must **not** change historical completed-programme
metrics. Progress for an athlete uses the **pinned** version’s profile
and that version’s evidence only.

Do not mix:

- athlete identities
- definitions across programme versions
- refresh failures with empty “no progress”
- missing evidence with zero

CAE Sprint 3 last-good / failure-versus-empty rules still apply.

---

## 2. What the profile must specify

| Field | Purpose |
|-------|---------|
| Programme intent | What this version is intended to improve (prose, honest) |
| Primary metrics | Outcome-focused, few |
| Secondary metrics | Diagnostic or supporting |
| Baseline tests | Slot refs + definitions |
| Checkpoint tests | Mid-block |
| Final tests | End-block |
| Metric id / name | Stable within the version |
| Unit | Canonical + display |
| Calculation method / version | Testable, reproducible |
| Evidence sources | In-app capture, allowed manual, later trusted device |
| Minimum data quality | Completeness, plausibility |
| Direction of improvement | Higher / lower / band |
| Display priority | Studio and later Progress |
| Comparison windows | Baseline↔checkpoint↔final; never silent cross-version |
| Missing-data behaviour | Honest unavailable — not zero |
| Stale-data behaviour | Per calculation policy |
| Role | descriptive / diagnostic / outcome |
| Manual entry permitted | Yes/no per metric |
| Trusted device populate | Yes/no; never required |
| Programme version bind | Exact version UUID + package hash |
| Historical reproducibility | Frozen method version on the profile |

---

## 3. Binding to today’s package / schema

Plan Package v1 already has **thin contracts**, not a metrics profile:

- `PlanPackageAssessment` — `id`, `slot_ref`, `evidence_requirement`,
  `comparison_identity_id`, `label`
- `PlanPackageEvidenceRequirement` — `id`, `comparison_identity_id`,
  `metric` (string), `required`
- `PlanPackageComparisonIdentity` — `id`, `session_lineage_id`, `label`

Apollo’s package leaves these arrays **empty**. They cannot express
method version, staleness, data quality, display priority, or
device-versus-manual policy.

**Verdict:** the existing schema is a **hook**, not a sufficient bind.

**Likely later change (describe only — do not implement):**

- Add a versioned `metrics_profile` object to Plan Package (new schema
  version **or** an additive optional field if a compatibility review
  allows it), **or**
- A sibling canonical artifact hashed and stored on
  `programme_versions` (new column / JSONB) with the same immutability
  triggers as the package.

Either way:

- The profile hash must be part of publication identity or an explicit
  companion hash recorded on the version row.
- Import/approve must **fail closed** once the rule is introduced if
  the programme type requires a profile and it is missing or invalid.
- Plan Package v1 must **not** gain exercise identities to do this.

Studio Stage 1 can preview today’s assessments as “insufficient
profile.” Studio must not invent HYROX metric selections.

---

## 4. Progress projection

A later programme-specific Progress view **projects** the pinned
profile. It does not compute a new definition at read time except by
the frozen method version.

Device evidence may populate a metric only when the profile allows it
and the activity has been matched per
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md)
§6. Cohort Progress must work with in-app evidence alone.

---

## 5. Illustrative metric categories

**Every row is illustrative.** No metric is selected. No programme
content is authorised.

### HYROX family (Base, First Race, Performance, Pro Performance)

- Running pace / durability
- Compromised running
- Station execution
- Transitions
- Strength retention
- Benchmark / race outcomes (never a sub-60 guarantee)

### Tactical Athlete 365

- Strength, power, aerobic capacity
- Loaded movement, repeat effort, durability

### Strength for Endurance

- Strength development, tissue capacity, interference-aware adherence
- Must not claim to manage the athlete’s full endurance plan

### Strength for Life 55+

- Strength, movement capacity, balance, consistency
- Requires later suitability / regression / safety treatment

---

## 6. Forbidden behaviours

- Universal opaque fitness score
- Causation the data cannot prove
- Cross-athlete or cross-version definition mix
- Silent change when a new default is published
- Missing evidence → 0
- Query failure → empty success
- Selecting final metrics in infrastructure sprints

---

## 7. Studio and publication

Programme Studio displays the profile, method versions, and missing
required fields. Founder review records whether the profile matches the
programme promise.

Once the fail-closed rule is introduced, `approve_*` /
`replace_approved_*` must reject a launch-family version that lacks a
valid profile. That RPC change is **described**, not implemented here.

---

## 8. Hard stop

No real launch-programme metrics selection may be created until a later
founder **content-authoring** approval for that family.
