# Running Workout B1 — implementation contract

**Status:** Local implementation contract for authorised Sprint B1.
**Parent:**
[`Running_Workout_and_Device_Interop_v1.md`](./Running_Workout_and_Device_Interop_v1.md)
**Approval:**
[`../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md`](../checkpoints/RUNNING_WORKOUT_B1_APPROVAL.md)
**Audit (historical):**
[`../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md`](../checkpoints/RUNNING_PACE_FOUNDATION_AUDIT.md)
**Base:** `origin/main` `02e20501c45bc31f1fd5722a3bafa46b1d82c26f`

```text
RUNNING_WORKOUT_B1=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This contract does not reopen founder decisions. It does not authorise
B2–B4, pace formulas, content, migrations, or Garmin work.

---

## Existing runtime authorities (unchanged)

| Concern | Authority |
|---------|-----------|
| Catalogue pin | Plan Package v1 + immutable `programme_version` |
| Executable session | `performance_protocols` + `session_blocks` |
| Timer / execution | `WorkoutFormat` + `TimerConfiguration` → `BlockTimerController` |
| Capture | `EnduranceResultData` / `IntervalResultData` |
| History | `block_snapshot` + result JSON |

B1 does **not** replace any of these. Projection is one-way and
in-memory only.

## New domain boundary

Place: `lib/domain/running_workout/` (app domain, no Flutter, no new
package, no new pub dependency).

Later consumers (Studio, Daily Journey, calculation, adapters) may
import this module. Plan Package v1 schema is **not** changed. The
compiler package is not given a new dependency in B1.

No provider or UI types belong in the core model.

## JSON contract (schema version 1)

Documented object:

- `schema_version` (int, must be `1`)
- `workout_id` (non-empty string; portable; not a DB or provider id)
- optional `title`, `intent`, `notes` (authored display only)
- `provenance` (non-athlete): `kind` (`authored` / `projected` /
  `unsupported`), `source_kind`, `source_format`, `id_derivation`
- `steps[]` discriminated by `kind`: `atomic` | `repeat`

Atomic: `step_id`, `role`, `duration`, `target`, optional `notes`.

Repeat: `group_id`, `count` (≥ 1), `steps[]` of **atomic only**.

Duration: `time` + `milliseconds` (> 0) | `distance` + `millimetres`
(> 0) | `manual_lap` (no value).

**Canonical distance unit: millimetres** (int). Pace: milliseconds
per kilometre (int). Cadence: `steps_per_minute`. RPE: `rpe_cr10`
integer 1–10.

Target `kind`: `none` | `pace` | `pace_range` | `heart_rate` |
`heart_rate_range` | `heart_rate_zone_ref` | `power` | `power_range`
| `cadence_range` | `rpe` | `rpe_range`.

Unknown schema, discriminators, or unknown **authority** keys fail
closed. Encode → decode → encode is equivalent. No timestamps,
paths, random IDs, or locale-formatted numerics. This JSON is **not**
a Plan Package field or hosted row contract.

## Projection boundary

`WorkoutFormat` + `TimerConfiguration` → `RunningWorkout` or an
explicit finding.

Supported:

- `steady_state` + positive `durationSeconds` → one `work` time step
- `intervals` + positive `workSeconds` + positive `rounds` → one
  repeat group of `work` + optional `recovery` when
  `restSeconds` > 0

Current interval timer plays rest after **every** work interval,
including the last (`BlockTimerController._tickIntervals`). Projection
preserves that by keeping recovery inside the repeat group.

`restSeconds == 0` or null: no recovery child (0 ms is not a valid
time step). Warning recorded. Runtime default rest (15 s when
`restSeconds` is null) is **not** invented as authored duration.

Unsupported formats (`amrap`, `emom`, `for_time`, `tabata`,
`rounds`, `other`, `none`) fail projection. Prose / `intensity` /
`effort` become notes or warnings, never numeric targets.

IDs are derived from format + canonical timer tokens + optional
non-path `source_ref` via SHA-256 prefix. No runtime-random UUIDs.

Do not persist projected JSON.

## Validation rules

Blocking errors vs non-blocking warnings. Codes are stable (see
implementation). No launch/coaching approval. Ambiguous prose is a
warning, never a target.

## Backward compatibility

- Plan Package compile/hash unchanged
- Apollo source and package hash unchanged
- Timer runtime unchanged
- Snapshots / completion / Progress / History unchanged
- No programme file or DB row rewrite

## Non-goals

Formulas, benchmarks, calculated targets, freeze, overrides, new
athlete timers, GPS, Garmin, metrics, content, SQL/migrations,
hosted writes, Plan Package schema change, Studio Coach Review
redesign.

## Acceptance gates

Immutable equality; schema 1; deterministic IDs and JSON;
round-trip; all roles/durations/targets; range order; unknown
discriminators fail; nested repeat rejected; prose not numericised;
steady-state and interval projection; unsupported shapes fail;
existing timer/hash/isolation regressions green; analyze + safety
gate + full `flutter test`.

## Stop conditions

Stop if B1 would require Plan Package schema change, migration, row
rewrite, timer replacement, programme source edits, formulas,
benchmark UI, metrics, Garmin, a new external dependency, or a
second programme authority.
