# Running Workout and Device Interop v1

**Status:** Binding vendor-neutral running architecture.
**Approved.** Sprint B1 **approved, not started**. B2–B4 not
authorised. **Not implemented.**
**Recorded:** 2026-09-25
**Approval:**
[`../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md`](../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md)
**Audit (historical):**
[`../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md`](../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md)
**Parent:**
[`Launch_Programme_Library_v1.md`](./Launch_Programme_Library_v1.md)
**Related:**
[`Programme_Studio_v1.md`](./Programme_Studio_v1.md),
[`Programme_Performance_Metrics_Profile_v1.md`](./Programme_Performance_Metrics_Profile_v1.md),
[`Connected_Data_Privacy_v1.md`](./Connected_Data_Privacy_v1.md)
**Earlier capability note:**
[`../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md)
§12.4

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_PACE_FOUNDATION=APPROVED_B1_NOT_STARTED
RUNNING_WORKOUT_B1=APPROVED_NOT_STARTED
PACE_CALCULATION_B2=NOT_AUTHORISED
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This document defines a structured-running workout model for
high-quality in-app execution, individual pace calculation, and later
device export and activity import. **Garmin is not the canonical
authority.** Cohort must work without any wearable. A wearable must
never become execution authority.

Do not invent Garmin API details. Provider discovery and
implementation are deferred.

---

## 1. Current capability verdict

Production programme athletes use **block-native** execution:

`Plan Package` (session refs only) → `session_blocks` →
`SessionExecutionLoader` → `ActiveSessionScreen` → `BlockTimerController`
+ `PerformanceCaptureController`.

A **legacy** `IntervalSessionPlanBuilder` → `IntervalSessionView` →
`training_session_intervals` path exists for preview/debug and
`session_type: running` only. Production launchers do **not** use it
(`test/session/production_launcher_destination_scan_test.dart`).

| Concept | Class | Evidence |
|---------|-------|----------|
| Warm-up / cooldown blocks | Strong foundation | `SessionBlockType.warmUp` / `coolDown`; completion capture |
| Time-based continuous run | Production-complete | `WorkoutFormat.steadyState` + `durationSeconds` + `EnduranceResultData`; Apollo reclass `20260903120000` |
| Time-based work/recovery intervals | Production-complete | `WorkoutFormat.intervals` + rounds/work/rest; `IntervalResultData` |
| Manual completion | Production-complete | Block result editors |
| km / miles on endurance capture | Production-complete | `EnduranceResultData.distanceUnit`; `test/endurance/endurance_duration_capture_test.dart` |
| Live pace from duration+distance | Display only | `EnduranceMetricsCalculator`; `IntervalResultMath` — **not** prescription |
| RPE capture | Strong foundation | Session / optional phase RPE; not bound to prescription bands |
| Distance-based interval steps | Legacy-only / missing in prod run blocks | Endurance distance fields; block intervals are time-first |
| Pace **targets** (authored) | Unsafe / ambiguous | Prose / JSON `effort`; not enforced |
| Pace ranges | Missing | No structured type |
| Heart-rate zones | Unsafe / ambiguous | Text `zone_2` / intensity; optional `averageHeartRate` scalar |
| Power / cadence targets | Missing | Privacy enum only; `connected_data_contracts.dart` notes integrations not implemented |
| Nested repeats | Missing | Flat rounds only |
| Open / lap-button steps | Missing (prod) | Legacy instruction phases only |
| Lap / split capture | Missing | One pace row per authored round |
| Treadmill alternative at runtime | Missing | `runningReplaceable` is authoring metadata |
| Auto GPS completion | Missing | Timers finish phases; athlete enters results |
| Plan Package running prescription | Missing | Package cannot carry prescriptions |
| Versioned pace calculator | Missing | Studio `pace_calculation` is `notImplemented` |
| Device export / import | Missing | Not implemented |

**Implication:** HYROX Base must **not** be authored against prose
zone and pace strings. A structured workout model is required first.
Scoreboard detail:
[`../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md`](../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md).

---

## 2. Canonical model (vendor-neutral)

The workout is owned by the **pinned programme version** and the
**protocol / session revision** that the slot references. Device IDs
are external references only.

```text
RunningWorkout
  schema_version     integer (fail closed if unsupported)
  workoutId          stable, programme-version scoped
  protocolId         executable session identity
  programmeVersionId pin
  calculationPolicyId  versioned method (see §5)
  steps[]            ordered
  repeatGroups[]     optional; one level only in v1
```

### Step

| Field | Meaning |
|-------|---------|
| `stepId` | Stable within the workout |
| `order` | Strict sequence |
| `role` | warm_up / work / recovery / rest / cooldown / open |
| `durationType` | time / distance / lap_button_open |
| `durationMs` | integer milliseconds when `time` |
| `distanceMm` | integer millimetres when `distance` |
| `targetType` | none / pace / pace_range / heart_rate / power / cadence / rpe |
| `targetAuthored` | coach intent (structured value and/or label) |
| `targetCalculated` | athlete-specific numbers, nullable until eligible |
| `targetCalculatedUnit` | canonical unit of the calculated value |
| `presentationUnit` | display only |
| `repeatGroupId` | optional; v1 depth ≤ 1 |

Repeat groups expand to concrete steps for execution and export.
Unbounded or nested-nested repeats fail validation.

Progression/ramp steps are **out of v1** unless a later programme
genuinely authors them.

### Units

| Quantity | Canonical store | Display |
|----------|-----------------|---------|
| Distance | millimetres (int) | km or miles |
| Duration | milliseconds (int) | clock |
| Pace | milliseconds per kilometre (int) | min:ss /km or /mi |
| Power | watts (int) | watts |
| Heart rate | bpm (int) | bpm |
| Cadence | steps/min (int) | spm |

International mile = 1609.344 m exactly. Convert authored input
**once** to canonical integers. Display conversion is one-way.
Do not store formatted strings as numerical authority. Allowed
epsilon: 1 mm, 1 ms, 1 ms/km.

### Compatibility with today’s blocks

Store the typed document as a namespaced object beside existing
`timer_config` keys. Do **not** require a migration to start.

Deterministic projection:

- `steady_state` + `duration_seconds` → one time step, target `none`
- `intervals` + rounds/work/recovery seconds → one-level repeat of
  work + recovery time steps, target `none`
- Prose / `intensity` / `effort` → authored **label** only
- Founder `reps.text` and unknown shapes → fail closed

---

## 3. Intent versus calculated target versus actual

Keep five layers distinct:

1. **Authored intent** — what the programme version prescribed.
2. **Programme calculation policy** — method id/version, accepted
   benchmarks, staleness. Owned by the programme version.
3. **Athlete benchmark input** — type, result, capture date, unit,
   eligibility.
4. **Frozen calculated target** — numbers for *this* occurrence,
   frozen at the earliest execution commitment (successful device
   export or first in-app start; until export exists, first in-app
   start).
5. **Completed result** — in-app capture or later matched import.

Missing or stale benchmarks **fail closed** to “intent only”. They
must not invent a pace. Existing
`EnduranceMetricsCalculator` / `IntervalResultMath` are **actual
display** helpers, not calculation methods.

A later method version must not rewrite stored calculated targets or
completed results.

---

## 4. In-app execution

Cohort remains the execution authority.

- Render structured steps in Daily Journey / Active Session.
- Timers implement time-based steps. Distance steps without trusted
  automatic distance require deliberate **manual**
  advance/lap/evidence and must be labelled manual evidence.
  Treadmill/manual execution must work without GPS or a wearable.
- Interval transitions follow authored work/recovery pairs.
- Partial completion, skipped steps, and extra intervals are
  first-class (`completed` / `skipped` / `pace_unavailable` already
  exist on interval capture).
- Clock and timezone follow the athlete training timezone. Do not
  use device-local midnight as programme authority.
- Pause/resume and restart recovery reuse the current block-timer
  path. Audio/haptic cueing is later premium work.

Athletes should **not** re-enter data a connected device already
captured **reliably** and that Cohort has matched to the exact
occurrence. Until import exists, manual capture remains required.

---

## 5. Pace-calculation contract

Required inputs to calculate a target safely:

| Input | Role |
|-------|------|
| Benchmark type | Programme-defined evidence. Initial direction: Cohort 5 km time trial **or** recent trusted 5 km performance. A 5 km result is **not** automatically threshold pace. |
| Benchmark result | Value + canonical unit + source + athlete identity |
| Captured date | Athlete-local date |
| Validity / staleness policy | Programme-version rule (initial window **90 days**) |
| Calculation method / version | Named, testable, reproducible. Candidate family: **transparent, versioned percentage of benchmark speed**. Exact percentages and physiological labels are **unresolved until B2**. |
| Unit | Canonical store vs presentation (versioned conversion) |
| Confidence / eligibility | Fail closed if missing/stale; never invent a pace |

**Shared running infrastructure** owns: unit conversion, step
identity, timer semantics, result shapes, matching keys.

**Programme version** owns: which benchmarks, which method version,
and whether an override is allowed.

Do not copy Daniels VDOT or World Athletics scoring tables. Do not
use “threshold”, “easy”, “interval”, or other zone labels
**numerically** unless the selected B2 method explicitly defines
them. Authored session labels may stay descriptive; they are not
numeric calculation authority.

Override: only where the programme policy allows; record original
calculated target, override, reason/source, and time. Do not mutate
authored intent or the benchmark.

HR and RPE may be authored guidance or fallback. They are **not**
converted into pace unless a future approved method defines that
calculation. Missing HR/device data must not block an executable
workout.

B1 must **not** implement this calculation engine.

Do not ship a method without tests that replay the same inputs to
the same outputs.

---

## 6. Planned workout versus completed activity

| Object | Authority |
|--------|-----------|
| Planned workout | Pinned programme version + protocol revision + occurrence |
| Completed in-app record | Training session / block results already in Cohort |
| External activity | Provider activity id + timestamps + allowed metrics |

Matching an imported activity requires **all** of:

- athlete identity
- `programme_version_id`
- assignment id
- occurrence / slot identity
- time window consistent with the athlete training date

Duplicates: idempotent upsert on
`(athlete_id, provider, provider_activity_id)`.
Ambiguous matches fail closed; do not attach to the wrong
occurrence.

Partial / skipped / extra intervals: store as completed-activity
variance against the planned step list. Do not silently rewrite the
plan.

Treadmill / manual activities: allowed. They are not GPS proof.
Routes and live location remain prohibited.

---

## 7. Device interop (deferred providers)

### Export (later)

- Idempotent: same workout + policy + athlete targets → same export
  payload hash until inputs change.
- Provider workout id stored as **external reference**.
- Offline: queue export; retry; do not create a second planned
  workout identity.

### Import (later)

- Athletes should not re-type reliable device data.
- Revocation: stop import; retain already-stored Cohort evidence.
- Privacy: follow `connected_data_contracts.dart` — no
  location/travel categories. Provider tokens never enter programme
  authority.

### Garmin-specific

**Deferred.** No API paths, workout file formats, or OAuth details
are specified here. A later integration task must discover them.
Device provider implementation remains unauthorised.
`RUNNING_DEVICE_INTEGRATION_AUTHORISED` remains false. B1 must not
implement export/import.

**Export-readiness preview** (Studio B4): a workout is
“structurally exportable” only if every step has duration type +
target type the neutral model supports. It is **not**
“Garmin-ready” until a provider adapter exists.

---

## 8. Implementation boundary

**B1 is approved, not started.** Scope and gates:
[`../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md`](../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md).

B1 is the immutable RunningWorkout v1 domain, validation,
deterministic JSON, and backward-compatible projection from
supported steady-state and time-based interval timers. It must not
calculate athlete targets, change execution UI, migrate schema, or
author content.

B2 (calculation), B3 (execution changes), and B4 (full Studio
preview) remain **not authorised**.

Infrastructure must **not** author HYROX run sessions, contact
Garmin, select programme metrics, or make wearables required for
Daily Journey.

Hard stop: no launch-programme running prescriptions until content
authoring is separately approved. If B1 cannot preserve authority
in existing JSONB, stop for a new schema decision.
