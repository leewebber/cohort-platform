# Running Workout B1 — implementation handoff

**Recorded:** 2026-09-25
**Status:** Implemented locally. Awaiting founder approval.
**Branch:** `feat/structured-running-workout-v1`
**Base:** `origin/main` `02e20501c45bc31f1fd5722a3bafa46b1d82c26f`
**Contract:**
[`../architecture/Running_Workout_B1_Implementation_v1.md`](../architecture/Running_Workout_B1_Implementation_v1.md)
**Approval (historical):**
[`RUNNING_WORKOUT_B1_APPROVAL.md`](./RUNNING_WORKOUT_B1_APPROVAL.md)

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_PACE_FOUNDATION=B1_IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
RUNNING_WORKOUT_B1=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

## What shipped

Pure-Dart immutable `RunningWorkout` v1 under
`lib/domain/running_workout/`. No new package. No Flutter, provider,
or UI types in the core model.

- Schema version 1
- Atomic steps + one-level repeat groups
- Time (ms), distance (mm), manual-lap durations
- Typed targets without calculation
- Deterministic JSON encode/decode (fail-closed unknown authority keys)
- Validation with blocking errors vs warnings
- One-way projection from `WorkoutFormat` + `TimerConfiguration`
- In-memory only — not written to Plan Package, DB, or programme files

## Domain and JSON

See the implementation contract. Canonical distance is **millimetres**.
Pace is **milliseconds per kilometre**. Cadence is
`steps_per_minute`. RPE is `rpe_cr10` 1–10.

IDs for projections: `rw1:p:{sha256_16(format|timer tokens|source_ref)}`.
Not database or provider IDs.

## Validation codes (errors)

`unsupported_schema_version`, `missing_workout_id`, `empty_steps`,
`missing_id`, `duplicate_id`, `invalid_duration`,
`conflicting_duration`, `invalid_repeat_count`,
`empty_repeat_children`, `nested_repeat_group`, `invalid_target`,
`invalid_target_range`.

Codec failures: `unknown_field`, `unknown_step_kind`,
`unknown_duration_kind`, `unknown_target_kind`,
`unknown_role`, `unsupported_schema_version`.

Warnings: `untyped_guidance`, `projected_without_recovery`.

## Projection

| Input | Output |
|-------|--------|
| `steady_state` + positive `durationSeconds` | One `work` time step, target `none` |
| `intervals` + work + rounds + rest > 0 | One repeat of work + recovery (includes final recovery, matching `_tickIntervals`) |
| `intervals` + rest 0/null | Work-only repeat + warning; runtime default rest is not invented |
| Other formats | `unsupported_timer_shape` — existing timer still runs |

Labels such as Zone 2 / threshold stay notes. No numeric targets.

## Compatibility

Timer runtime, Plan Package hash
`810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83`,
Apollo sources, snapshots, and Studio isolation are unchanged.

Programme Studio was **not** redesigned. No technical preview pane
was added.

## Decisions still required before B2

- Exact percentage-of-benchmark-speed table
- Physiological label definitions (if any)
- Benchmark capture UX
- Freeze/override runtime (already architecturally decided; not
  implemented)

## Non-actions

No formulas, benchmarks, calculated targets, freeze, overrides, new
athlete timers, GPS, Garmin, metrics, content, SQL, hosted writes, or
push.
