# Capture and preparation audit

2026-10-24. This audit was made before selecting capture modes or adding source
lowering. MASTER previously proposed no concrete new result fields: D5 was a broad
unresolved request to review capture/scoring, not a visible capture specification.
The founder's dose approval does not approve unseen capture requirements.

## Established capture reused

| Category / affected sessions | Existing contract and delivered use | Exact remaining limit |
|---|---|---|
| Main strength and upper pairs — 24 gym sessions | Existing strength result/set rows and actual reps/load. Superset identity/order survives prepare/save/reopen. Prescription RIR/rest ranges and percentage intent stay in prescription metadata. | No compulsory actual RIR, rest, pair-transition or benchmark-derived upper-body load. Existing strength completion requires a performed set with actual reps; this requirement is inherited, not newly inferred from a target. |
| Suitcase carries — 8 Gym A | Prescribed distance and per-side meaning stay typed. Established completion mode and optional block note are used. New canonical source metadata prevents legacy distance decoding from silently enabling load/distance capture requirements. | C1: no new mandatory carry-load/distance rows or separate left/right result identity. Existing generic carry capture elsewhere is unchanged; activating it for Base would require explicit capture scope. |
| Plank / Pallof — 8 Gym B and 8 Gym C | Typed hold duration, reps/side and two-second extended hold are retained; established completion mode plus optional note. | C1: no mandatory actual hold quality, per-side rows, actual lever/resistance/extended-hold measurement or RIR fields. |
| Mixed finishers — 8 Gym B and 8 Gym C | Existing minute timer shows timed work/recovery and full rest stations. Completion mode plus existing optional block note records scaling; prescribed station targets remain separate. | C1: no new station-output, every-minute completion, load, wall-ball height/standard attestation or scoring requirements. No prescribed target is marked performed automatically. |
| Quality / dedicated row — 8 quality and 8 Gym A | Existing interval capture and explicit pace-unavailable path remain unchanged. No final recovery is added. Preparation accelerations use completion capture, not benchmark pace capture. | A timed prescription is not an observed performance; no row fallback, new actual field or measurement verification is invented. |
| Easy / long runs — 16 sessions | Existing endurance capture remains; deliberate main-duration choice is separately frozen by the canonical v3 start. Existing performed distance/duration requirements are unchanged. | Chosen prescribed duration is never copied to performed duration or used as evidence that the run occurred. |

C1 is a capture capability limit, not a new required result or a blocker to rendering
and executing the prescription with existing completion/notes. All result values
initialise as missing. RPE display, per-side targets and rest/hold timings create no
new required results. Global dose approval does not grant new scoring or comparison
eligibility. Session snapshots retain the original source and chosen prescription;
actuals remain in their existing separate fields.

Binding source paths:
`lib/features/performance/models/block_capture_mode_resolver.dart`,
`lib/features/performance/services/performance_snapshot_builder.dart`,
`lib/features/performance/services/performance_validation_service.dart`,
`lib/features/session/models/session_execution_plan.dart` and
`lib/core/persistence/session_execution_plan_codec.dart`.

## Preparation and timing

- **P1 — all 24 gym sessions:** five-minute easy start, the supplied two-round
  movement doses, named ramp-up exercise and total 12–15 minute budget are retained.
  Easy starts have their existing timers; circuit prescriptions retain reps/side.
  Ramp-set counts, loads, reps and rest were not supplied and are never guessed.
  Warm-up sets remain separate from working sets. Repetition and transition durations
  and exact placement of optional core rest remain unquantified. Full gym timing
  is therefore partial, not a fabricated 60–90 minute sum.
- **P2 — eight quality runs:** 10 minutes easy plus 3×20-second relaxed accelerations
  with two 40-second easy recoveries are structured. Dynamic preparation is a retained
  instruction with no invented movements/duration. The post-work 15–20-minute easy
  range and five-minute walk remain authored instructions, not fixed or auto-selected
  durations. The main work/recovery timer is exact; full timing remains partial.
- **Easy runs:** retain the transferred 5–8 minute walk/jog preparation and five-minute
  walk afterward. No additional compulsory preparation choice or result field is created.
- **Long runs:** current explicit correction is exactly five minutes gentle walking/
  jogging plus five minutes walking afterward. Main windows are unchanged; every
  80-minute maximum totals 90 minutes. Prior 95-minute conflict is resolved.

P1/P2 distinguish incomplete quantitative preparation from complete main working
prescriptions. Open-ended preparation instructions remain visible and do not prevent
source compilation. Their future quantitative authoring is a content decision; the
implementation does not claim that such details were approved or supplied.

## Skipped authenticated test

`test/hyrox_base/athlete_authoritative_local_test.dart` checks
`COHORT_LOCAL_V3_CONFIG`; when absent, it explicitly skips with
“Requires task-owned disposable authenticated local gate.” That file is normally
created by `run_hyrox_authoritative_start_gate.sh`, which also runs Python HTTP probes.
No configuration from a different project is borrowed, no fake passing opt-in is set,
and no denied Python networking is retried or replaced. The existing authenticated
HTTP test remains skipped. The new separate SQL-only gate uses a uniquely named local
Docker project and `docker exec ... psql` over stdin; it proves actual SQL roles and
transactions, not GoTrue/HTTP/application transport. Ordinary compiler/runner/export
and existing trusted-server unit regressions are separate local tests.
