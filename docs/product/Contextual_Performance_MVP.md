# Contextual Previous Performance (MVP)

**Phase:** 6 — Product Hardening  
**Sprint:** 2 model · **Sprint 3 persistence**  
**Status:** Implemented (local persistence)

---

## Model

`PreviousPerformanceSnapshot` (typed fields, not generic blob strings as the domain):

| Field | Use |
|-------|-----|
| `exerciseId` | Stable match key |
| `sessionType` | strength / runningInterval / timedConditioning / other |
| `performedAt` | Recency |
| `setSummary` | e.g. `3 × 10` or `3 × 800 m` |
| `loadSummary` | e.g. `100 kg` |
| `repSummary` | Optional when not in setSummary |
| `paceSummary` | e.g. `Average pace 4:45/km` |
| `durationSummary` | Timed conditioning |
| `distanceSummary` | Distance work |
| `rpe` | Optional integer |
| `coachNote` | Optional calm note |

Backing store: `PreviousPerformanceStore` (memory) + `AthleteLocalRepository` (disk).

Typed capture: sealed `ExerciseExecutionResult` hierarchy  
(`StrengthExecutionResult` / `RunningIntervalExecutionResult` / `TimedConditioningExecutionResult`).

---

## Matching rules

`PreviousPerformanceResolver` + `PreviousPerformanceFromResults`:

1. Require non-empty stable `exerciseId`
2. Require comparable result kinds (do not compare strength vs interval merely because names match)
3. Exclude abandoned / invalid sets
4. Prefer the most recent valid completed performance (by completion session)
5. Require `hasDisplayableContent` for display
6. Return `null` when confidence is insufficient

Does not fabricate history. Does not match solely by display name when IDs exist.

---

## Supported session types (display)

| Type | Typical lines |
|------|----------------|
| Strength | Load · sets×reps · RPE |
| Running interval | Sets×distance · average pace |
| Timed conditioning | Duration / relevant prior values when present |

Current prescription remains visually dominant.

---

## Workout Player UI

Hierarchy on each relevant step:

1. Current prescription (dominant)  
2. Previous performance (`LAST TIME`) when snapshot exists  
3. Coaching cues  
4. Set controls  

No charts. No full session history during execution. Section omitted cleanly when no snapshot.

Media: `ExerciseMediaSlot` shows only when a real `videoUrl` / `imageUrl` exists.

---

## Persistence (Sprint 3)

1. On workout complete, `WorkoutExecutionCapture` records typed results already available from the player (extension points for later load/rep/RPE input UI)
2. `PreviousPerformanceFromResults.derive` writes contextual snapshots
3. Aggregates persist under `AthleteLocalRepository` and hydrate on bootstrap
4. Low-friction execution preserved — athletes are not required to enter every field

---

## Future

- Richer per-set input controls in Workout Player  
- Optional hydrate from cloud `TrainingSessionSetRepository` when online  
- Deep link from LAST TIME → Profile Training History (optional)
