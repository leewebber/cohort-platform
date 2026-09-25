# Running Workout and Device Interop v1

**Status:** Binding vendor-neutral running architecture. **Not implemented.**
**Recorded:** 2026-09-25
**Parent:**
[`Launch_Programme_Library_v1.md`](./Launch_Programme_Library_v1.md)
**Related:**
[`Programme_Studio_v1.md`](./Programme_Studio_v1.md),
[`Programme_Performance_Metrics_Profile_v1.md`](./Programme_Performance_Metrics_Profile_v1.md)
**Current-capability audit:**
[`../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](../checkpoints/LAUNCH_PROGRAMME_LIBRARY_AUDIT.md)
§12.4

```text
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This document defines a structured-running workout model for high-quality
in-app execution, individual pace calculation, and later device export
and activity import. **Garmin is not the canonical authority.** Cohort
must work without any wearable. A wearable must never become execution
authority.

Do not invent Garmin API details. Provider discovery and implementation
are deferred.

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
| Live pace from duration+distance | Strong foundation | `EnduranceMetricsCalculator`; `IntervalResultMath` |
| RPE capture | Strong foundation | Session / optional phase RPE; not bound to prescription bands |
| Distance-based interval steps | Strong foundation / legacy-only | Endurance distance fields; block intervals are time-first |
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
| Device export / import | Missing | Not implemented |

**Implication:** HYROX Base must **not** be authored against prose zone
and pace strings. A structured workout model is required first.

---

## 2. Canonical model (vendor-neutral)

The workout is owned by the **pinned programme version** and the
**protocol / session revision** that the slot references. Device IDs are
external references only.

```text
RunningWorkout
  workoutId          stable, programme-version scoped
  protocolId         executable session identity
  programmeVersionId pin
  calculationPolicyId  versioned method (see §5)
  steps[]            ordered
  repeatGroups[]     optional nested repeats
```

### Step

| Field | Meaning |
|-------|---------|
| `stepId` | Stable within the workout |
| `order` | Strict sequence |
| `role` | warm_up / work / recovery / cooldown / open |
| `durationType` | time / distance / lap_button_open |
| `durationValue` | integer milliseconds or millimetres internally |
| `targetType` | none / pace / pace_range / heart_rate / power / cadence / rpe |
| `targetAuthored` | coach intent (e.g. “easy”, “threshold”, zone name) |
| `targetCalculated` | athlete-specific numbers, nullable until eligible |
| `repeatGroupId` | optional |

Repeat groups expand to concrete steps for execution and export. Nested
repeats are in-scope for the model even if v1 in-app UI only expands
them.

### Units

Store **SI-like integers** (ms, mm) in the canonical workout. Present
km or miles at the edge. Convert with a versioned converter. Do not
round-trip through display strings. Fail closed if a conversion would
change authored intent (document the allowed epsilon).

---

## 3. Intent versus calculated target versus actual

Keep four layers distinct:

1. **Authored intent** — what the programme version prescribed (easy,
   threshold, 5×3:00 / 2:00, etc.).
2. **Programme calculation policy** — which benchmark, which method
   version, staleness window. Owned by the programme version.
3. **Athlete benchmark input** — type, result, capture date, unit,
   eligibility.
4. **Calculated target** — numbers shown to the athlete for *this*
   occurrence.
5. **Actual completed result** — what was captured in-app or imported.

Missing or stale benchmarks **fail closed** to “intent only” or block
export — they must not invent a pace. Do not choose final physiological
formulas in this document.

---

## 4. In-app execution

Cohort remains the execution authority.

- Render structured steps in Daily Journey / Active Session.
- Timers implement time-based steps; distance-based steps may be
  treadmill/manual until GPS exists.
- Interval transitions follow authored work/recovery pairs.
- Partial completion, skipped steps, and extra intervals are first-class
  result states (block interval capture already has `completed` /
  `skipped` / `pace_unavailable`).
- Clock and timezone follow the athlete training timezone already used
  for enrolment / Calendar. Do not use device-local midnight as
  programme authority.

Athletes should **not** re-enter data a connected device already
captured **reliably** and that Cohort has matched to the exact
occurrence. Until import exists, manual capture remains required.

---

## 5. Pace-calculation contract

Required inputs to calculate a target safely:

| Input | Role |
|-------|------|
| Benchmark type | e.g. recent 5k, race result, test set — **programme-defined** |
| Benchmark result | Value + unit |
| Captured date | Athlete-local date |
| Validity / staleness policy | Programme-version rule |
| Calculation method / version | Named, testable, reproducible |
| Unit | Canonical store vs display |
| Confidence / eligibility | Fail closed if ineligible |

**Shared running infrastructure** owns: unit conversion, step identity,
timer semantics, result shapes, matching keys.

**Programme version** owns: which benchmarks, which method version,
zone names, and whether an override is allowed.

Override: only where the programme policy allows; record as athlete
override, not a rewrite of authored intent.

Do not ship a method without tests that replay the same inputs to the
same outputs.

---

## 6. Planned workout versus completed activity

| Object | Authority |
|--------|-----------|
| Planned workout | Pinned programme version + protocol revision + occurrence |
| Completed in-app record | Training session / block results already in Cohort |
| External activity | Provider activity id + timestamps + metrics |

Matching an imported activity requires **all** of:

- athlete identity
- `programme_version_id`
- assignment id
- occurrence / slot identity
- time window consistent with the athlete training date

Duplicates: idempotent upsert on `(athlete_id, provider, provider_activity_id)`.
Ambiguous matches fail closed; do not attach to the wrong occurrence.

Partial / skipped / extra intervals: store as completed-activity
variance against the planned step list. Do not silently rewrite the
plan.

Treadmill / manual activities: allowed when the programme step permits
or the athlete marks treadmill. They are not GPS proof.

---

## 7. Device interop (deferred providers)

### Export (later)

- Idempotent: same workout + policy + athlete targets → same export
  payload hash until inputs change.
- Provider workout id stored as **external reference**.
- Offline: queue export; retry; do not create a second planned workout
  identity.

### Import (later)

- Athletes should not re-type reliable device data.
- Revocation: stop import; retain already-stored Cohort evidence.
- Privacy: follow `connected_data_contracts.dart` — no location/travel
  categories. Provider tokens never enter programme authority.

### Garmin-specific

**Deferred.** No API paths, workout file formats, or OAuth details are
specified here. A later integration task must discover them. A minimal
vendor-neutral interface (export payload + import activity DTO) may be
designed in Infrastructure Sprint B without contacting Garmin.

**Export-readiness preview** (Studio): a workout is “structurally
exportable” only if every step has duration type + target type the
neutral model supports. It is **not** “Garmin-ready” until a provider
adapter exists.

---

## 8. Implementation boundary

Infrastructure may later add the neutral model, converters, and tests.
It must **not** author HYROX run sessions, contact Garmin, or make
wearables required for Daily Journey.

Hard stop: no launch-programme running prescriptions until content
authoring is separately approved.
