# M9.4 — Exercise Usage Relationships

**Status:** Implemented (read-only vertical slice)  
**Depends on:** M6 Session Blocks, M9.1 Session Revisions, M9.2 Session Usage Patterns, M8 Performance Capture

---

## Purpose

Given one **exact Exercise** (`exercise_id`), answer:

1. Which Session Revisions directly link to it?
2. Which Session Lineages contain revisions using it?
3. Which Programme Versions indirectly depend on it?
4. Which active Programme Assignments indirectly depend on it?
5. How many historical performances contain it?
6. Is usage authored, operational, historical, or unused?
7. Can callers receive a stable typed summary without understanding joins?

This milestone is **read-only**. Exercise action policies and Coach Studio UI are deferred.

> The relationship and policy architecture remains intentionally entity-specific. Generalisation should occur only after multiple entity types demonstrate genuinely identical semantics.

---

## Exact Exercise identity

All relationships use **`exercise_id`** only.

Never used for matching:

- display name
- label override
- movement name
- fuzzy text matching

Display labels may change; `exercise_id` is stable.

---

## Direct Session Revision path (authored)

**Preferred M6 path:**

```
session_block_exercises.exercise_id
    → session_blocks.session_id
    → performance_protocols.protocol_id
```

**Legacy structured path (when no block link exists for that revision):**

```
protocol_steps.exercise_id
    → performance_protocols.protocol_id
```

Legacy steps are included only when the same revision does not already have a block link for the exercise (avoids double-counting migrated content).

Each block link is returned as an `ExerciseRevisionReference` with block context and optional `displayLabelOverride`.

Counts:

- **`directSessionRevisionCount`** — distinct `protocol_id` values
- **`directBlockReferenceCount`** — total block/step links

---

## Session Lineage roll-up

Derived from direct Session Revision references:

- **`sessionLineageCount`** — distinct lineages
- **`ExerciseSessionLineageReference.revisionNumbers`** — only revisions that actually link the exercise

No automatic roll-up of revisions that do not link the exercise.

---

## Programme and Assignment transitive paths

```
Exercise
    → exact Session Revisions (block links)
        → programme_version_session_slots.protocol_id
            → Programme Version

Exercise
    → Programme Versions containing those exact revisions
        → programme_assignments where status = active
```

- Programme references include slot week/day context and pinned `protocolId`
- Assignments deduplicated by `assignmentId`
- Only `ProgrammeAssignmentStatus.active` counts as operational

Archived programme versions and session revisions remain visible.

---

## Historical identity path

**Authoritative structured path (implemented):**

```
training_exercise_results.source_exercise_id
    → training_block_results
        → training_session_records (terminal statuses only)
```

Terminal statuses follow M8: `completed`, `partially_completed`, `abandoned`.  
`in_progress` records are excluded.

Metrics:

| Field | Meaning |
|-------|---------|
| `recordCount` | Distinct terminal session records |
| `performanceOccurrenceCount` | Exercise result rows matched |
| `sessionRevisionCount` | Distinct `source_protocol_id` on matched records |

**Limitation:** Rows without `source_exercise_id` are not counted.  
`ExerciseHistoricalUsage.isAuthoritative = true` with explicit `limitationNote` — zero history means authoritative zero, not “unknown”.

Snapshot JSON (`exercise_snapshot.sourceExerciseId`) is not queried in M9.4. Records missing structured IDs are a known legacy gap documented here rather than inferred from display names.

---

## Classifications

Reuses M9.2 `ContentUsageClassification`:

| Classification | Exercise meaning |
|----------------|------------------|
| `directAuthored` | Linked in at least one Session Revision |
| `activeOperational` | Active assignment pins a programme version containing a linked revision |
| `historicalPerformance` | Authoritative terminal historical matches exist |

Historical classification requires `isAuthoritative && hasUsage`.

---

## Service API

```dart
ExerciseRelationshipService.getUsageForExercise(exerciseId)
ExerciseRelationshipService.tryGetUsageForExercise(exerciseId)
```

`tryGetUsageForExercise` distinguishes:

- `success` (including zero usage)
- `exerciseNotFound`
- `lookupFailed`

Optional granular methods mirror M9.2 shape.

---

## RLS and privacy

Coach/admin-facing read model following existing repository conventions.

- Does not expose athlete identity in user-facing strings
- `athleteId` retained internally on assignment references for routing only
- No athlete counts returned
- Does not loosen athlete RLS

---

## Indexes / migrations

**`20260721120000_add_exercise_usage_indexes.sql`**

- `idx_session_block_exercises_exercise_id`
- `idx_training_exercise_results_source_exercise_terminal`

Reuses existing programme slot and assignment indexes from Programme Engine and M9.2.

No graph table. No materialized view.

---

## Why no universal graph abstraction

Exercise usage paths differ from Session usage at the authored layer (block links + legacy steps vs programme slots). Forcing a generic graph now would either:

- duplicate authoritative data, or
- hide entity-specific semantics needed for correct deduplication

M9.2 patterns were replicated entity-specifically; generalisation deferred until semantics are proven identical.

---

## Known limitations

| Limitation | Notes |
|------------|-------|
| Historical rows without `source_exercise_id` | Not counted; not inferred from snapshot JSON in M9.4 |
| Legacy free-text protocol steps | Excluded when `exercise_id` absent |
| No Exercise action policies | M9.5+ |
| No Coach Studio UI | Service only |
| No athlete historical counts | Privacy by design |
| Block + legacy double-path | Deduped per revision |

---

## Future Exercise action policy consumption

A future `ExerciseActionPolicyService` should:

- Call `tryGetUsageForExercise()` before delete/archive/edit decisions
- Treat `lookupFailed` as fail-closed for destructive actions
- Interpret `directAuthored` / `activeOperational` / `historicalPerformance` like M9.3 Session policies
- Never use display names for blocking decisions

---

## Related documentation

- `56_M9_2_Session_Revision_Usage_Relationships.md`
- `57_M9_3_Session_Revision_Action_Policies.md`
- `52_M8_Performance_Capture_and_Training_History.md`
