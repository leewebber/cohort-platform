# Contextual Previous Performance (MVP)

**Phase:** 6 — Product Hardening  
**Sprint:** 2  
**Status:** Implemented (in-memory)

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

Store: `PreviousPerformanceStore` (memory only).

---

## Matching rules

`PreviousPerformanceResolver.resolveLatest(exerciseId:)`:

1. Require non-empty `exerciseId`
2. Filter store by exact `exerciseId` equality (not display name)
3. Require `hasDisplayableContent`
4. Sort by `performedAt` descending
5. Return latest, or `null` if none

Does not fabricate history. Does not match solely by display name when IDs exist.

---

## Supported session types (display)

| Type | Typical lines |
|------|----------------|
| Strength | Load · sets×reps · RPE |
| Running interval | Sets×distance · average pace |
| Timed conditioning | Duration / relevant prior values when present |

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

## Data limitations

- Snapshots are **in-memory** for this sprint (no cloud persistence).
- Resolver does not invent values from incomplete rows.
- Populating the store from completed set rows / completion pipeline is a future persistence requirement.

---

## Future persistence requirements

1. Persist per-exercise performance rows keyed by `exerciseId` + athlete  
2. Write snapshots on session completion from captured set results  
3. Optionally hydrate from `TrainingSessionSetRepository` when online  
4. Deep link from LAST TIME → Profile Training History (optional, later)
