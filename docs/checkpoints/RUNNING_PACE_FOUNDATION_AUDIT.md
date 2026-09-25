# Running / Pace Foundation — pre-implementation audit

**Recorded:** 2026-09-25
**Status:** Architecture and decision record only. **Not implemented.**
**Branch:** `docs/running-pace-foundation-audit`
**Base / `origin/main`:** `82ddb176d4df9f493d577001091ee9c1d6c404ad`
**Binding architecture:**
[`../architecture/Running_Workout_and_Device_Interop_v1.md`](../architecture/Running_Workout_and_Device_Interop_v1.md)
**Parents:**
[`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md),
[`../architecture/Programme_Studio_v1.md`](../architecture/Programme_Studio_v1.md),
[`PROGRAMME_STUDIO_STAGE_1_HANDOFF.md`](./PROGRAMME_STUDIO_STAGE_1_HANDOFF.md)

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_PACE_FOUNDATION=AUDITED_AWAITING_APPROVAL
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This document is the focused Sprint B audit. It does **not** authorise
implementation, HYROX content, Garmin contact, metrics-profile
selection, or schema change.

---

## 1. Current-state authority trace

### 1.1 Layers that exist today

| Layer | Authority | What it can express | What it cannot |
|-------|-----------|---------------------|----------------|
| Plan Package v1 YAML | Catalogue schedule + **exact protocol pin** | `sessions[].protocol_id`, `session_lineage_id`, `revision_number`; slot `prescription_summary` prose | Block timers, pace targets, structured steps. Apollo summaries say “refer to committed executable protocol …” |
| `performance_protocols` | Session revision identity | `protocol_id`, lineage, revision, `running_required`, `running_replaceable`, `coaching_notes`, `duration_min` | Structured workout graph |
| `session_blocks` | **Executable** prescription for programme athletes | `workout_format`, `timer_config` JSONB, `content`, `performance_capture_mode` | Typed pace/HR/power targets; extra JSON keys (`intensity`, `effort`) are **dropped** by `TimerConfiguration.fromJson` |
| `session_block_exercises.prescription` | Exercise-linked JSON | Strength-shaped fields (`sets`, `reps`, `load`, `distance_m`); Apollo also stores run keys in SQL | Dart `StrengthExercisePrescription` ignores run keys (`work_seconds`, `record`) |
| Founder YAML (Spartan import) | Richer block/exercise prose | `reps.type: duration`, `reps.text`, `load.unit: rpe` | Not a vendor-neutral workout graph |
| Legacy `protocol_steps` + `IntervalSessionPlan` | Preview/debug interval player | Distance **or** time targets on `training_session_intervals` | **Not** the production Programme Athlete launcher |
| M8 capture JSON | Athlete **actuals** | `EnduranceResultData`, `IntervalResultData` in `training_block_results.result_data` | Authored targets; GPS; power; cadence; device id |
| Progress / History | Projection of snapshots + actuals | `CompletedSessionResultProjection`; derived pace **strings** | Recalculated athlete targets |

**Pin authority remains intact.** Enrolment binds
`programme_assignments.programme_version_id`. Slot resolution requires
published immutable version and exact
`materialisedPackageContentHash == version.packageContentHash`
(`lib/features/programme/services/athlete_programme_authored_slot_resolver.dart`).
Atomic session start validates version, hash, and
`effective_protocol_id`
(`supabase/migrations/20260813140000_atomic_programme_training_session_start.sql`).
Edits that change a published version require a **new** version number;
they must not rewrite pinned historical assignments.

### 1.2 Materialisation and execution path (production)

```text
Plan Package session pin
  → published programme_version (immutable hash)
  → assignment.programme_version_id + materialised hash
  → occurrence / Daily Journey slot
  → protocol_id → session_blocks
  → SessionExecutionLoader → ActiveSessionScreen
  → BlockTimerController + PerformanceCaptureController
  → training_session_records + training_block_results
  → completion cursor
  → Progress / History projection
```

Legacy path (`IntervalSessionPlanBuilder` → `IntervalSessionView` →
`training_session_intervals`) exists for `session_type: running`
preview/debug. Production launchers do **not** use it
(`test/session/production_launcher_destination_scan_test.dart`).

### 1.3 Representative authored examples (repository facts)

| Example | Repository authority | Structured meaning |
|---------|----------------------|--------------------|
| Steady-state Zone 2 | Plan pin `SES-APOLLO-W05-TUE` → `APOLLO-W5-TUE-R1` (`tool/programmes/apollo_build_12_week_v1.plan-package.yaml`). Seed block `Zone 2 run` originally `workout_format=intervals` + `work_seconds:3600` + `intensity:zone_2` (`supabase/migrations/20260821124000_apollo_build_week5_executable_protocols.sql`). Correction `20260903120000_classify_continuous_conditioning_as_steady_state.sql` rewrites 23 such blocks to `steady_state` + `duration_seconds` + capture `endurance`. | Time duration is structured. “Zone 2” / RPE 3–4 remain **prose / untyped JSON**. |
| Work / recovery intervals | `APOLLO-W5-THU-R1` Hard intervals: `rounds`, `work_seconds`, `recovery_seconds`, `tracking: ["interval_pace"]` | Time-first intervals. Effort/RPE strings in JSON are not Dart timer fields. |
| Distance-based run intervals | **None** in Apollo executable protocols. Station `distance_m` exists on mixed circuits. Legacy interval table has `target_distance_meters`. | Production run intervals are **time**, not distance. |
| Threshold session | `APOLLO-W9-THU-R1` Threshold intervals: 3×480s / 120s, `effort: threshold`, `rpe: 7-8` | Time structure yes; “threshold” is a label, not a calculated pace. |
| Mixed run / station | `APOLLO-W5-SAT-R1` `workout_format: rounds` + `round_sequence` + station `distance_m` | Circuit, not a running-step graph. |
| Treadmill / manual substitution | `Protocol.runningReplaceable` authored. **No** athlete-session consumer under `lib/features/session`. | Metadata only. |

Spartan founder YAML (`tool/programmes/spartan_physique_block1_week1.yaml`)
uses `easy-run` / `threshold-run` with `reps.text` such as
`50 minutes` and `4 min work / 2 min easy jog recovery`. That is
importable prose, not the structured contract.

### 1.4 Where structure is flattened

- Plan Package `prescription_summary` (often a protocol referral).
- `session_blocks.content` duplicates the session in sentences.
- `performance_protocols.coaching_notes` (“Track distance, average pace…”).
- `timer_config` extras (`intensity`, `effort`, `rpe`,
  `comparison_protocol_id`) survive in JSONB but are **not** in
  `TimerConfiguration`.
- History `prescriptionContext` uses `blockSnapshot.content`.
- Summaries format **calculated** pace as display strings
  (`EnduranceMetricsCalculator`, `PerformanceResultSummaryFormatter`).

### 1.5 Version-mix risk

Capture writes `block_snapshot` with the authored block at completion
time. History reads the snapshot, not a live recompile. A later
protocol edit on a **new** revision does not rewrite completed rows.
Risk is **new occurrences** if an unpublished/local editor mutates the
same `protocol_id` without a new revision. Production pin + published
immutability is the safeguard. Sprint B must keep snapshot + pin
rules; it must not recalculate historical **completed** targets when a
formula version changes.

---

## 2. Capability scoreboard

| Capability | Class | Evidence |
|------------|-------|----------|
| Time-based continuous run | Production-complete | `WorkoutFormat.steadyState` + `durationSeconds` + `EnduranceResultData` |
| Time-based work/recovery | Production-complete | `WorkoutFormat.intervals` + rounds/work/rest + `IntervalResultData` |
| Manual completion + km/mi display | Production-complete | `EnduranceResultData.distanceUnit`; `test/endurance/endurance_duration_capture_test.dart` |
| Live/derived pace from duration+distance | Display only | `EnduranceMetricsCalculator` — **not** a prescription |
| Per-interval pace actual | Production-complete | `IntervalWorkResult.paceSecondsPerKm`; states completed / skipped / `pace_unavailable` |
| Per-interval distance actual | Missing (M8) | Implied km only (`workSeconds / paceSecondsPerKm`) |
| Per-repetition splits beyond authored rounds | Missing | One row per authored work interval |
| Authored pace / pace-range targets | Unsafe / ambiguous | Prose and untyped `effort` |
| HR zone as target | Unsafe / ambiguous | `zone_2` text; optional `averageHeartRate` actual |
| Power / cadence targets | Missing | Privacy enum only (`connected_data_contracts.dart`) |
| Nested repeats | Missing | Flat `rounds` |
| Open / lap-button step | Missing (prod) | Legacy instruction phases only |
| Treadmill alternative at runtime | Missing | `runningReplaceable` unused in session |
| GPS / route / device identity | Prohibited / missing | `ProhibitedLocationData`; no capture fields |
| Plan Package running prescription | Missing | Pins only |
| Versioned pace calculator | Missing | Studio checks `pace_calculation` / `running_structure` are `notImplemented` |
| Device export / import | Missing | Not implemented |
| VDOT / critical-speed / Daniels tables | Absent | No repository calculator of that kind |

### What athletes can record now

| Datum | Authored target | Calculated | Actual persisted |
|-------|-----------------|------------|------------------|
| Total duration | `duration_seconds` / sum of work | — | Session + endurance `durationSeconds` |
| Total distance | Rare (`distance_m` stations; long-run exercise JSON) | Implied from interval pace | Endurance `distance` + unit |
| Interval duration | `workSeconds` | — | Copied onto result row; not re-entered |
| Interval distance | No prod run field | Implied km | No dedicated field |
| Split / lap list | No | — | No |
| Pace | No numeric target | Display from duration+distance; interval avg/fast/slow | Interval `paceSecondsPerKm` |
| Heart rate | No zone object | — | Optional endurance average HR |
| Power / cadence / GPS / device id | No | — | No (location prohibited) |
| RPE | Prose / untyped JSON | — | Session `overall_rpe`; not bound to prescription bands |

**Evidence that would be lost** if a new model naively replaced
execution: existing `training_block_results.result_data` and
`block_snapshot` rows; interval work states
(`completed` / `skipped` / `pace_unavailable`); endurance
distance-unit preference; derived history strings. Sprint B must
**project** onto current capture, not replace it in place.

---

## 3. Storage / schema verdict

**No migration is required to begin Sprint B.**

Existing JSONB is sufficient for a versioned structured-workout
document:

- `session_blocks.timer_config` already stores the executable timer.
- `training_block_results.result_data` already stores endurance and
  interval actuals.
- Extra keys can be added under a namespaced object
  (`running_workout_v1`) without dropping current keys.

**Do not** treat untyped extras (`intensity`, `effort`) as the new
contract. B1 must introduce a **typed** document and a deterministic
projection **from** today’s supported timer shapes.

If a later slice (outside B, or late B3) needs first-class query of
export/import refs, an **additive** table would be:

| Change | Authority gained | Compatibility |
|--------|------------------|---------------|
| `running_workout_exports` (`athlete_id`, `occurrence_id`, `provider`, `idempotency_key`, `provider_workout_ref`, `payload_hash`, `state`) | Device adapter bookkeeping | Existing rows unchanged; optional |
| `running_activity_imports` (`athlete_id`, `provider`, `provider_activity_id` unique, `matched_occurrence_id` nullable) | Idempotent import | Fail-closed unmatched; no rewrite of in-app actuals |

Those tables are **not** authorised in this audit and must not be
written now. Device implementation remains
`RUNNING_DEVICE_INTEGRATION_AUTHORISED=false`.

Rollback of a JSON contract is a code-version problem: readers must
ignore unknown `schema_version` or fail closed; they must not mutate
old snapshots.

---

## 4. Proposed structured workout contract

Vendor-neutral, immutable, owned by the **pinned programme version**
and the **protocol / session revision**. Device IDs are external
references only. Full field list:
[`../architecture/Running_Workout_and_Device_Interop_v1.md`](../architecture/Running_Workout_and_Device_Interop_v1.md)
§2.

Minimum v1 capabilities:

- Stable `workoutId` (programme-version scoped) and `stepId`
- Ordered steps: warm-up, work, recovery, rest, cooldown, open/lap
- Duration: time (integer milliseconds) or distance (integer
  millimetres) or lap-button-open
- Repeat groups: **one level** of repeat is enough for Apollo-like
  `N × work / recovery`. Nested repeats are **not** required for v1;
  reject unbounded nesting
- Continuous steady-state as a single time (or later distance) step
- Progression/ramp: **out of v1** unless a later programme genuinely
  authors it

Target types: `none`, `pace`, `pace_range`, `heart_rate_zone` /
range, `power_zone` / range, `cadence_range`, `rpe`.

Every numeric field stores four aspects:

| Aspect | Meaning |
|--------|---------|
| Authored | Coach intent (label and/or structured value on the version) |
| Athlete-calculated | Nullable until a valid method+benchmark exists |
| Canonical stored unit | Integers; never formatted strings |
| Presentation unit | km/mi, clock pace, etc. at the edge |

### Canonical units and rounding

| Quantity | Store | Present |
|----------|-------|---------|
| Distance | millimetres (int) | km or miles |
| Duration | milliseconds (int) | clock |
| Pace | milliseconds per kilometre (int) | min:ss /km or /mi |
| Power | watts (int) | watts |
| Heart rate | bpm (int) | bpm |
| Cadence | steps/min (int) | spm |
| RPE | integer 1–10 (or Borg 6–20 if a method declares it) | same |

Conversion: international mile = **1609.344 m** exactly. Convert
once from authored input to canonical integers. Display conversion
is one-way from canonical. Do not round-trip through display
strings. Allowed epsilon for “same authored intent”: 1 mm, 1 ms,
1 ms/km.

Schema version: `running_workout.schema_version` integer on the
document. Readers fail closed on unsupported versions.

### Authoring compatibility

Express the contract **beside** existing `timer_config`, not instead
of Plan Package v1 (Plan Package still has no exercise/workout
bodies).

Deterministic projection for **currently supported** shapes:

| Current shape | Projection |
|---------------|------------|
| `steady_state` + `duration_seconds` | One work (or continuous) time step; target `none` unless a typed target exists |
| `intervals` + `rounds` + `work_seconds` + `recovery_seconds` | Repeat group of work + recovery time steps; target `none` |
| Untyped `intensity` / `effort` / prose Zone 2 | **Authored intent label only** — do not invent pace numbers |
| `reps.text` founder YAML | Fail closed unless a later importer mapping is explicit |
| Distance-based run intervals | Unsupported until authored as typed distance steps |
| Circuit `rounds` / stations | Not a running workout; leave on existing circuit path |

Fail-closed validation:

- Missing duration **and** distance on a non-open step
- Pace range low ≥ high, or non-positive
- Repeat count < 1 or > declared max (recommend 32)
- Conflicting authored targets (pace **and** power both required)
- Nested repeat depth > 1
- Unknown `schema_version`

Programme Studio later preview (Stage 1 remains read-only): Quality
Gate item `running_structure` becomes Passed only when every run
block either projects cleanly or is labelled “could not be
interpreted safely”. Technical Integrity shows the typed document.
Do **not** author HYROX workouts in Studio.

---

## 5. Pace-calculation authority

Keep five objects distinct:

1. Authored workout intent
2. Programme-version **calculation policy** (method id + staleness +
   allowed benchmarks)
3. Athlete **benchmark evidence** (type, result, date, unit)
4. **Calculated** athlete target for an occurrence
5. **Completed** result

Existing calculators (`EnduranceMetricsCalculator`,
`IntervalResultMath`, `IntervalPaceFormat`) compute **actual**
display metrics. They are **not** eligible as a prescription method
merely because they exist.

### Versioned method interface

Each method declares:

- `method_id` + `method_version`
- Accepted benchmark types
- Required fields
- Valid input range
- Staleness policy (programme-owned)
- Output zone/target set
- Rounding (integer ms/km)
- Failure codes (`missing_benchmark`, `stale_benchmark`,
  `out_of_range`, `unsupported_combination`)

Reproducibility inputs: benchmark identity + result + capture date +
method/version + programme-version policy. A later formula **must
not** rewrite stored calculated targets or completed results.

### When to persist calculated targets

**Recommend: freeze at occurrence preparation / first start of that
occurrence.**

| Moment | Verdict |
|--------|---------|
| Enrolment | Too early; fitness changes; would stale-lock a whole programme |
| Assignment materialisation | Programme-version pin, not athlete physiology |
| Occurrence preparation / first start | **Recommended.** One frozen calculated-target document on the occurrence, with method + benchmark refs |
| Every timer tick | Forbidden |

Trade-off: start-time freeze can differ from “what the coach assumed
at enrol,” but it matches travel/timezone rules already used for the
training date and keeps historical completions immutable.

### Research boundary (no implementation)

| Approach | Fit | Caveat |
|----------|-----|--------|
| Recent race / time-trial equivalence | Transparent if the mapping is a **declared, tested table or function owned by Cohort** | Do **not** copy Daniels VDOT or World Athletics scoring tables (copyright / licence) |
| Critical speed (two+ TTs; Jones / Vanhatalo literature) | Scientifically published; testable | Needs multiple efforts; later method, not v1 default |
| Threshold / lactate-style field test | Common coaching practice | Lab lactate is out of scope; field test must be defined by the programme version |
| Time-trial-derived % of threshold pace | **Recommended v1 method family** | Method version must list exact percentages; no hidden tables |
| Heart-rate %HRmax / Karvonen | Weak pace authority; useful **guidance** | Drift, meds, heat; not a substitute for pace targets |
| RPE | Guidance / fail-open display | Not a calculated pace |

External sports-science **and** legal review is required before any
method that embeds a third-party scoring table. Prefer methods
Cohort can publish in tests.

---

## 6. Ranked founder recommendations

Infrastructure decisions (needed before B implementation):

| # | Decision | Recommendation | Why |
|---|----------|----------------|-----|
| 1 | Primary benchmark hierarchy | 1) programme-defined recent race or TT 2) programme-defined threshold test 3) no valid benchmark → intent-only | Matches hybrid-athlete reality; fails closed |
| 2 | Initial supported tests | 5 km TT or race; optional 1.5 km / 3 km later; no 42 km as v1 input | Short TTs are repeatable; marathon equivalence is a later method |
| 3 | Pace-zone method | Versioned **% of threshold pace** derived from the selected TT by a Cohort-owned, tested mapping — not VDOT tables | Transparent and licensable |
| 4 | Staleness window | Programme-version policy; **recommended default 90 athlete-local days** | Long enough for a block; short enough to stay honest |
| 5 | No valid benchmark | Show authored intent only; **do not invent pace**; export remains not-ready | Safer than fake precision |
| 6 | HR / RPE | **Guidance only** in v1, not pace authority | Existing capture already has optional HR and session RPE |
| 7 | Freeze calculated targets | Occurrence first-start | See §5 |
| 8 | Athlete override | Allowed only if programme policy says so; stored as override, never as authored rewrite | Preserves prescription authority |
| 9 | km / mile display | Athlete preference; canonical store stays SI integers | Avoids conversion drift |
| 10 | Treadmill / manual | Always allowed for in-app completion; mark `surface=treadmill\|outdoor_manual\|unknown`; not GPS proof | `runningReplaceable` is not runtime yet |

Decisions that **can wait** until HYROX Base authoring (not Sprint B
blockers): exact zone names and percentages for that programme;
whether HYROX includes a mandatory 5 km test slot; Garmin as first
provider; third-session semantics; final physiological constants
beyond the method interface.

Do not ask the founder to choose JSON key names, millisecond vs
second storage, or adapter class names — those have an objectively
safer answer above.

---

## 7. Execution architecture (not implemented)

Cohort remains execution authority. Wearables never become it.

| Concern | Sprint B3 (initial) | Later / premium |
|---------|---------------------|-----------------|
| Countdown / start | Reuse block timer start | — |
| Automatic time-step transitions | Yes, from structured steps | — |
| Distance steps without GPS | Treadmill / manual advance; do not fake GPS | Device distance later |
| Manual lap / advance | Yes | — |
| Pause / resume | Yes (existing timer) | — |
| Skip / repeat step | Skip as first-class result; repeat only if authored | Extra intervals as variance |
| Early finish / partial | Existing interval states | — |
| Background / interruption / restart | Existing format-restore matrix | Stronger audio recovery |
| Audio / haptic | Optional later | Premium cueing |

---

## 8. Garmin / device adapter boundary (design only)

Cohort = programme and assignment authority. Provider = execution
and evidence. App works with **zero** wearables.

Neutral objects (no Garmin API paths):

- Outbound workout DTO + `payload_hash`
- `provider` + `provider_workout_ref`
- `idempotency_key` = hash(athlete, occurrence, workout, policy,
  calculated-target document)
- Export state: `not_exported` / `queued` / `exported` / `revoked`
- Inbound activity: `provider_activity_id`, timestamps, allowed
  metrics (no route coordinates)
- Match requires athlete + `programme_version_id` + assignment +
  occurrence + training-date window
- Duplicates: unique `(athlete_id, provider, provider_activity_id)`
- Revocation: stop import; **retain** already-stored Cohort evidence
- Athletes must not re-enter **reliably matched** interval results

Provider-specific discovery remains unauthorised.

Privacy: future HR, device account ids, activity timestamps are
sensitive. Routes/GPS remain **prohibited**
([`../architecture/Connected_Data_Privacy_v1.md`](../architecture/Connected_Data_Privacy_v1.md)).
Minimum retention: keep occurrence-matched summaries for the
programme-history lifetime; do not store prohibited location; device
account ids stay in a connection table, not in programme authority.
No privacy-policy or storage change in this task.

---

## 9. Proposed slices

| Slice | Scope | Out |
|-------|-------|-----|
| **B1** | Structured workout domain, validation, backward-compatible projection from current timer shapes | Content, Garmin, formulas |
| **B2** | Versioned benchmark + calculation-method engine; persist targets at occurrence start | Selecting HYROX metrics; proprietary tables |
| **B3** | In-app structured execution + result evidence projected onto current capture | Premium audio; GPS required mode |
| **B4** | Programme Studio preview / readiness for structured running | Stage 2 authoring; publication |

Garmin provider implementation is **outside** Sprint B.
Programme content is **outside** every B slice.

---

## 10. Acceptance gates (when implementation is later authorised)

- Existing Apollo/Spartan blocks still execute and capture
- Projection never silently numeric-ises Zone 2 / threshold prose
- Pin + package hash + protocol revision unchanged
- Calculated-target replay tests: same inputs → same outputs
- Formula version change does not mutate historical rows
- Studio `running_structure` / `pace_calculation` become honest
  statuses, not “Ready to launch”
- `lib/main.dart` still cannot reach Studio preview
- No hosted Garmin calls
- Phase 2 safety gate remains green

---

## 11. Stop conditions

Stop and return to the founder if implementation would:

- require a hosted migration before the JSON contract is proven
- copy a proprietary pace table
- make wearables required for Daily Journey
- author HYROX or any launch-family sessions
- rewrite completed actuals or snapshots
- weaken exact-version pin
- treat compiler success as launch approval

---

## 12. Stage 1 integration note

Programme Studio Stage 1 is **operationally complete** on
`origin/main` `82ddb17`. The closeout commit still recorded
`PROGRAMME_STUDIO_STAGE_1=COMPLETE_AWAITING_INTEGRATION` as
historical evidence
([`PROGRAMME_STUDIO_STAGE_1_HANDOFF.md`](./PROGRAMME_STUDIO_STAGE_1_HANDOFF.md)).
Live pointers now read `PROGRAMME_STUDIO_STAGE_1=COMPLETE`. Stage 1
implementation is not reopened.
