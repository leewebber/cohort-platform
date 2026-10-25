# Capture and approved preparation

2026-10-25. [Exact approval](APPROVAL_2026_10_25.txt) · [Master](MASTER.md) ·
[Current content packet](FOUNDER_DECISION_PACKET.md).

All preparation sequences and exercise variants are approved, with barbell front rack for
main reverse lunges and split stance for cable Pallof. All 48 prescriptions and eight rest
entries are complete. Approved ramps remain separate from working sets; RDL/lunge loads
are chosen by feel, never from a squat benchmark. Gym preparation budgets are 12–15 min;
quality preparation is 15–17 min including the approved dynamic circuit and transitions.
Open-ended rep tempos and optional ramp choices do not require invented clocks or more
content decisions. Gym elapsed totals remain estimates, while main timed work is exact.

| Scope | Existing capture retained | Limit/consequence |
|---|---|---|
| Main strength/pairs — 24 gym | Actual sets/reps/load; existing completion rules. | No new mandatory RIR/rest/transition field. |
| Carries — eight Gym A | Completion plus optional load/scaling note. | No separately measured left/right carry rows; optional detail/comparison limit. |
| Plank/Pallof — eight Gym B/eight Gym C | Completion and optional note; authored holds/per-side targets retained. | No mandatory measured hold quality, per-side resistance or actual hold field. |
| Mixed finishers — eight Gym B/eight Gym C | Existing timers/targets/full rest and completion/optional notes. | Actual load can be noted; no newly required station output, race-height attestation or scoring. Existing structured circuit/strength logging elsewhere remains unchanged. |
| Quality/dedicated rowing | Existing interval actuals and explicit pace-unavailable path. | Targets are not performed measurements; no final recovery or invented fallback. |
| Easy/long runs | Existing endurance actuals; separate frozen main-duration choice and original range. | A chosen target is never copied to performed duration. |

C1 identifies optional evidence limitations on the 24 gym sessions, not a blocker to
faithful execution or completion. Initial actuals remain missing. Existing supported
actual-load fields and optional notes are available; this milestone adds no mandatory
result field or typed station form. Prescription metadata, advisory text and actuals
stay separate through save/reopen/export.

## Advisory circuit race weight

“Use your race weight” for Base wall balls is advice only. No exact kilograms, target
height, division lookup or verified race standard is implied. All eight current Gym C
sources therefore lose the obsolete B2/D4 dependency. Explicit load/height prescriptions,
formal assessments and their rule requirements remain untouched. An advisory station
cannot silently carry an explicit load/height/race mapping under the same advisory flag;
contradictory source shapes refuse. A completion tick is not race-valid measurement.

## Authenticated local proof

The established source-duration disposable gate now creates its own `app-local.json`
using `supabase status -o json`, restricts it to the task, and runs the existing Flutter
authenticated repository/start/save/completion/correction/History test. The task-owned
`COHORT_LOCAL_V3_EXPECT_DURATION=1` assertion requires a real authored window, exercising
the three-argument RPC and frozen original-range/selected-duration packet. Fresh/repeat
results and exact limits are recorded in the current handoff. No other project's config,
production secrets, Python HTTP probes or permission bypass is used. Ordinary broad test
runs still explicitly skip this test without `COHORT_LOCAL_V3_CONFIG`; dedicated configured
proof is separate. GoTrue login/native/device proof is not implied by local fixture JWTs.
