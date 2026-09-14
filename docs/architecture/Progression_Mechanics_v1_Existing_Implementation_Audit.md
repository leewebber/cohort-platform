# Progression Mechanics v1 — existing implementation audit

**Status:** Binding companion to [`Progression_Mechanics_v1.md`](./Progression_Mechanics_v1.md)  
**Audited at:** `4725c8ced4e13757c7ac206415ee5115c9199acd`

Classifications: complete and contract-compliant · partially implemented ·
fixture/preview only · disconnected from production · missing · conflicting.

This sprint does **not** rewrite working programme previous-strength retrieval
(`PreviousStrengthPerformanceService`, hotfix `be4d421`).

| Area | Classification | Notes |
|---|---|---|
| `PreviousStrengthPerformanceService` | complete and contract-compliant for **recall** | Athlete + canonical exercise ID + terminal records + `PerformanceChronology`. Unchanged. |
| `PreviousPerformanceResolver` / `PreviousPerformanceStore` | disconnected from production programme strength | Legacy KV/in-memory; accordion uses it only as fallback when hosted history is not ready. |
| `StrengthResultComparison` | conflicting | Primary verdict is Epley estimated 1RM. 90 kg × 3 vs 80 kg × 5 is labeled Improved. Contract requires Mixed. Labels `Baseline` / `Maintained` vs required First performance / Matched. Ignores partially completed records. |
| `StrengthProgressService` + `ExerciseProgressType` | conflicting / disconnected | Third vocabulary (`loadProgress`, `volumeProgress`). Used by legacy `StrengthSessionView` / `SessionPlayerScreen`, not programme `ActiveSessionScreen`. |
| Circuit / EMOM comparison | partially implemented | Format-aware `comparisonFamily`; EMOM intervals completed; fixed-work average round. Reuses strength enum. Chronology uses `completedAt`, not `PerformanceChronology`. No Mixed. Adjusted vs prescribed targets not distinguished in verdict copy. |
| Interval comparison | partially implemented | Family + work duration + pace. Faster = Improved. Chronology uses `completedAt`. Consistency (pace spread) does not force Mixed. |
| Endurance / Zone 2 | missing | No restrained “facts without verdict” service. Conditioning blocks counted as endurance sessions for radar participation. |
| `PerformanceChronology` | complete for records that use it | Shared implementation exists. Interval/circuit previous-pick and some Progress sorts still copy `completedAt`. |
| PB detection | partially implemented / conflicting | Interval fastest-in-family and circuit fastest-round flags. No typed strength PBs (heaviest load / reps-at-load). Interval PR can use non-chronology order. |
| Progress projections | partially implemented | History + “exercise bests” from latest strength set via 1RM comparison. `recentImprovements` unused. List history limit 40. |
| Capability radar | conflicting | `_participation` fills Strength/Endurance from **session count** (`0.18 + 0.08n`, cap 0.55). Violates “session count must not raise capability score.” Discipline from compliance is allowed. No founder-approved performance-axis formula. |
| Completed-session summary | partially implemented | Uses `StrengthResultComparison` / interval / circuit. Widget badges follow that enum. |
| Correction invalidation | complete for persistence | `correctCompleted` invalidates previous-strength cache; completed-session tests recompute after correction. Must keep working with new verdicts. |
| Backfill chronology | complete when using `PerformanceChronology` | `performed_on` on the record. Interval/circuit previous pick does not honor it. |
| First-performance states | partially implemented | `baseline` / “First recorded performance” on accordion. Completed view says Baseline. |
| Comparable-protocol identity | partially implemented | Intervals/circuits: `comparisonFamily`. Strength: `source_exercise_id`. Titles not used as sole key in those services. |
| Evidence confidence | missing | No High/Moderate/Low/None model. |
| Shared vocabulary | conflicting | At least three: `StrengthExerciseComparisonStatus`, `ExerciseProgressType`, Home/Progress string labels. |

## Duplicate comparison models

Canonical v1 vocabulary lives in
`lib/features/performance/progression/`. Existing format comparators must
**delegate** verdicts there. Widgets display projections only.

`StrengthProgressService` remains for the legacy session player this sprint and
must not be used by programme Progress, Home completed-today, or completed
session results.

## Radar violation

Yes: current participation fill **violates** Progression Mechanics v1.
Sprint 1 removes Strength/Endurance session-count fill. Axes stay unavailable
until a separate founder-reviewed capability-scoring contract exists.
Discipline may continue to use adherence.
