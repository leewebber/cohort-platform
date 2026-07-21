# M10.3 — Programme Assignment Migration Planner

**Status:** Implemented  
**Depends on:** M10.1 Programme Version Impact Analysis, M10.2 Programme Version Comparison, Programme Engine (M5–M7)

---

## Purpose

Given a **source Programme Version**, a **target Programme Version**, and **active assignments**, answer:

> If the coach wanted to migrate these assignments, what would be the safest plan?

This milestone produces **read-only planning facts**. It never performs migrations, mutates assignments, or changes athlete progress.

| Responsibility | Question |
|----------------|----------|
| **Impact (M10.1)** | What depends on this version? |
| **Comparison (M10.2)** | What changed between these versions? |
| **Planning (M10.3)** | What would happen? |
| **Migration (future)** | Apply the chosen changes. |

---

## Phase 0 — Progress model confirmed

Programme progress is **not** a stored percentage. Authoritative state:

| Layer | Source | Fields |
|-------|--------|--------|
| Cursor | `programme_assignments` | `current_week_number`, `current_day_key`, `current_slot_order` |
| Completion evidence | `programme_slot_outcomes` | terminal `outcome_status` per slot |
| Projection cache | `athlete_state` | **not** used for planning |

There is no `completionPercent` column. The planner computes:

```
completed required terminal outcomes / total required slots in source template
```

Initial position = first required slot in template order.  
`hasStarted` = any terminal required outcome **or** cursor moved from initial position.

Reassignment (`cancelOrReplaceActiveAssignment`) creates a fresh assignment — outcomes are **not** migrated.

---

## Architecture

```
ProgrammeMigrationPlannerService
  ├── ProgrammeVersionComparisonService   (M10.2 — what changed)
  ├── ProgrammeVersionImpactService       (M10.1 — source dependencies)
  ├── ProgrammeVersionComparisonStore     (source slot template)
  └── ProgrammeMigrationPlannerStore      (assignments + outcomes batch)
        └── ProgrammeMigrationPlannerEngine (pure classification)
              └── ProgrammeMigrationRecommendationBuilder
```

No new comparison/impact/assignment repository duplication.

---

## Models

| Model | Role |
|-------|------|
| `ProgrammeMigrationIdentity` | Source/target versions + embedded comparison & impact summaries |
| `AssignmentMigrationPlan` | Per-assignment classification, position, completion, reasoning |
| `MigrationSummary` | Aggregate counts by classification |
| `ProgrammeMigrationPlan` | Combined read model |
| `ProgrammeMigrationPlannerLookupResult` | Safe lookup wrapper |

### Classifications

| Value | Meaning |
|-------|---------|
| `alreadyCompleted` | Assignment status is completed |
| `safeImmediate` | Not started, or programmes identical |
| `safeAfterCurrentSession` | Current session unchanged; later content differs |
| `safeAfterCurrentWeek` | Only content after current week differs |
| `manualReview` | Current/past structure diverged; coach must decide |
| `cannotDetermine` | Progress or comparison not authoritative |
| `unsupported` | Reassigned or otherwise ineligible |

Classification is **separate** from recommendation text.

---

## Classification rules

Derived from comparison facts + authoritative progress — no invented heuristics.

| Condition | Classification |
|-----------|----------------|
| Programme identical | `safeImmediate` |
| Assignment completed | `alreadyCompleted` |
| No sessions completed (not started) | `safeImmediate` |
| Only future weeks changed | `safeAfterCurrentWeek` |
| Current session unchanged, future differs | `safeAfterCurrentSession` |
| Current session revision update (same lineage) | `safeAfterCurrentSession` |
| Current session removed | `manualReview` |
| Past/current structural divergence | `manualReview` |
| Progress unresolvable | `cannotDetermine` |
| Reassigned assignment | `unsupported` |
| Paused assignment | `manualReview` |

When certainty is impossible, the planner returns **Unknown** (`cannotDetermine`) — never **Safe**.

---

## Comparison integration

Consumes `ProgrammeVersionComparisonSummary` to determine:

- Whether programmes are identical
- Whether changes affect current session position
- Whether changes are future-only relative to assignment cursor
- Whether current session was removed or replaced

Does **not** reimplement comparison logic.

Change scope is evaluated using structural coordinates `(weekIndex, dayIndex, slotIndex)` from comparison slot snapshots.

---

## Impact integration

Consumes `ProgrammeVersionImpactSummary` for the **source** version to embed dependency context (active assignments, session references, historical facts).

Assignment loading uses `ProgrammeMigrationPlannerStore` — defaults to active assignments on the source version when `assignmentIds` is omitted.

---

## Recommendation generation

`ProgrammeMigrationRecommendationBuilder` produces concise coach-facing copy:

- No migration commands ("migrate now", "will upgrade")
- No automatic execution language
- Separate from classification enum

Examples:

- "Assignment has not begun or programme content is unchanged."
- "Current week should be completed before migration."
- "Current progress cannot be resolved authoritatively."

---

## Error handling

| Status | Meaning |
|--------|---------|
| `sourceNotFound` / `targetNotFound` | Version missing |
| `incompatibleLineage` | Versions not comparable |
| `comparisonUnavailable` | Comparison lookup failed |
| `impactUnavailable` | Impact lookup failed |
| `assignmentUnavailable` | Assignment batch load failed |
| `partial` | Comparison or progress enrichment incomplete |
| `lookupFailed` | Unexpected failure |

No fail-open "safe" recommendations when facts are missing.

---

## Performance

- One comparison call (reused for all assignments)
- One impact call for source version
- One source snapshot load for slot template
- Batch assignment + outcome load (no N+1 per slot)

Reuses existing M10.1 indexes on `programme_assignments` and `programme_slot_outcomes`.

---

## RLS and privacy

Coach/admin-facing planning only. Does not expose athlete PII beyond assignment IDs already available to coach tooling. Does not mutate data or loosen RLS.

---

## API

```dart
Future<ProgrammeMigrationPlan> planMigration({
  required String sourceProgrammeVersionId,
  required String targetProgrammeVersionId,
  List<String>? assignmentIds,
});

Future<ProgrammeMigrationPlannerLookupResult> tryPlanMigration({...});
```

---

## Known limitations

- Completion percentage is computed at planning time — not a persisted platform field
- Cross-version slot identity follows M10.2 structural matching; conservative removed+added semantics apply
- Paused assignments always require manual review
- No cursor mapping to target version (execution milestone)
- No athlete notification or background job orchestration

---

## Future migration execution (M10.4+)

- Coach Studio UI consuming `ProgrammeMigrationPlan`
- Explicit migration execution service (assignment replace + optional outcome policy)
- Action policy layer gating which classifications may proceed
- Athlete communication workflows

---

## Tests

`test/programme_migration/programme_migration_planner_service_test.dart` covers identical programmes, not started, week progress, completed, future-only changes, current session changes/removals, unknown progress, partial comparison, mixed summaries, ordering, and no auto-migration language.

Regression baseline: pre-existing suite failures unchanged (20).
