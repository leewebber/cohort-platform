# M10.2 — Programme Version Comparison Engine

**Status:** Implemented  
**Depends on:** M10.1 Programme Version Impact Analysis, M9 Exercise Relationships, Programme Engine (M5–M7)

---

## Purpose

Given two **exact Programme Version IDs in the same lineage**, answer:

> What changed between these versions?

This milestone produces **deterministic comparison facts only**. It does not migrate assignments, recommend upgrades, enforce policy, or render UI.

| Responsibility | Question |
|----------------|----------|
| **Impact (M10.1)** | What depends on this version? |
| **Comparison (M10.2)** | What changed between these versions? |
| **Policy (future)** | What is allowed? |
| **Migration (future)** | What should happen next? |

Keep these responsibilities separate.

---

## Phase 0 — Slot identity finding

Programme Version cloning (`cloneToNewDraft` → `saveTemplateTree`) **does not preserve slot UUIDs**. Cross-version comparison therefore cannot rely on stable slot IDs from cloning.

**Decision:** use conservative structural matching with explicit fallbacks.

| Priority | Slot matching basis | When used |
|----------|---------------------|-----------|
| 1 | `stableSlotId` | Same version self-compare; accidental UUID reuse across versions |
| 2 | `structuralPosition` | `(weekIndex, dayKey, slotIndex)` |
| 3 | — | Otherwise **removed + added** (never false “modified”) |

Weeks match by `weekIndex`. Days match by `(weekIndex, dayKey)`. Week/day “moved” is not claimed unless stable IDs survive (they generally do not across clones).

---

## Directional semantics

Comparison is **source → target**:

| Change | Meaning |
|--------|---------|
| Added | Present in target, absent from source |
| Removed | Present in source, absent from target |
| Modified | Matched entity, different content |
| Moved | Same matched slot ID, different position, same protocol |
| Replaced | Matched slot, different Session Lineage |
| Unchanged | Matched entity, no meaningful diff |

The result retains explicit source and target version identity. Comparison is **not symmetric**.

---

## Same-lineage requirement

Both versions must exist and share `programme_lineages.id`. Different lineages return `incompatibleLineage` — never silently compare unrelated programmes.

Do **not** compare using display name, version number alone, Session name, or Exercise name.

---

## Architecture

```
ProgrammeVersionComparisonService
  ├── ProgrammeVersionComparisonStore (abstract)
  │     └── ProgrammeVersionComparisonSupabaseStore
  ├── ProgrammeVersionComparisonEngine (pure deterministic diff)
  └── ProgrammeVersionComparisonMessageBuilder (derived copy)
```

Test support: `InMemoryProgrammeVersionComparisonStore`.

No new persistence table. No materialized comparison cache.

---

## Models

| Model | Role |
|-------|------|
| `ProgrammeVersionComparisonIdentity` | Lineage + source/target version facts |
| `ProgrammeMetadataChange` | Coach-authored metadata diff |
| `ProgrammeWeekChange` / `ProgrammeDayChange` | Calendar structure |
| `ProgrammeSlotSnapshot` / `ProgrammeSlotChange` | Session slot facts + classification |
| `SessionRevisionChange` | Revision transitions within matched slots |
| `ExerciseReferenceChange` / `ExerciseSetChange` | Programme-level Exercise set diff |
| `ProgrammeStructureMetrics` | Count deltas |
| `ProgrammeVersionComparisonSummary` | Combined read model |
| `ProgrammeVersionComparisonLookupResult` | Safe lookup wrapper |

### Status values

- `success` — full authoritative comparison
- `partial` — structural facts present; enrichment incomplete
- `sourceNotFound` / `targetNotFound`
- `incompatibleLineage`
- `lookupFailed`

### Classifications

`metadataChanged`, `structureChanged`, `sessionsAdded`, `sessionsRemoved`, `sessionsMoved`, `sessionRevisionsUpdated`, `exercisesAdded`, `exercisesRemoved`, `identical`, `partialComparison`.

---

## Metadata comparison

Compared fields (when persisted on `programme_versions`):

- name, description, durationWeeks, targetAthlete, difficulty, primaryGoal, equipmentRequirements, sessionsPerWeek

Excluded: lifecycle status, timestamps, generated IDs, audit fields.

Values are trimmed; empty strings normalise to null.

---

## Session slot comparison

Changed slot fields include:

- `protocolId` / Session Revision
- slot label, time of day, optionality, completion expectation, coach/athlete notes

Same Session Lineage with different revision → **modified** (revision transition recorded).  
Different Session Lineage → **replaced**.  
Same protocol, stable slot ID, different coordinates → **moved**.

---

## Exercise comparison

Exercises aggregate from exact Session Revisions referenced by each version using the same authoritative paths as M9.4 / M10.1:

- session block exercise links
- structured legacy steps (fallback when no block links for that revision)
- no workout-text parsing

Programme-level retained Exercises stay retained when Session location changes. Same-name different-ID Exercises remain distinct.

When exercise enrichment is not authoritative, `ExerciseSetChange` reports zero net delta and comparison is marked **partial**.

---

## Partial and ambiguity handling

| Condition | Behaviour |
|-----------|-----------|
| Exercise enrichment failure | Structural comparison retained; `partialComparison`; no authoritative zero-exercise claim |
| Session enrichment failure | `partialComparison`; limitation note added |
| Ambiguous slot pairing | Conservative removed + added |

Never force a false “modified” when identity is unreliable.

---

## Summary messages

`ProgrammeVersionComparisonMessageBuilder` produces concise UI-ready copy:

- No raw UUIDs
- No migration or upgrade recommendations
- Deterministic ordering

Examples:

- “No differences were found between Version 2 and Version 3.”
- “Version 3 updates 1 Session Revision.”
- “Strength Foundation changed from Revision 1 to Revision 2.”
- “Comparison is partial because enrichment could not be completed exactly.”

---

## Query performance

One aggregate load per version:

1. version row (via impact store helper)
2. weeks by `version_id`
3. days by week IDs (batched)
4. slots by day IDs (batched)
5. protocol metadata by referenced IDs (batched)
6. exercise links via `ProgrammeVersionImpactStore.listExerciseReferences`

Reuses M10.1 impact indexes. No speculative new indexes added in M10.2.

---

## RLS and privacy

Coach/admin-facing content comparison only. Does not expose athlete identity, assignments, or performance history (M10.1 responsibility). RLS unchanged.

---

## API

```dart
Future<ProgrammeVersionComparisonSummary> compareVersions({
  required String sourceProgrammeVersionId,
  required String targetProgrammeVersionId,
});

Future<ProgrammeVersionComparisonLookupResult> tryCompareVersions({...});

Future<List<ProgrammeMetadataChange>> compareMetadata({...});
Future<List<ProgrammeSlotChange>> compareSlots({...});
Future<List<ExerciseReferenceChange>> compareExercises({...});
```

---

## Known limitations

- No full Session Revision structural diff (block-level, prescription-level) — revision transitions and Exercise set changes only
- Slot UUIDs from cloning are not stable; structural matching may report removed+added where a human might infer “moved”
- No comparison persistence or caching
- Tags normalisation not implemented until tags are persisted on programme versions

---

## Future consumption (M10.3+)

- Coach Studio comparison UI consuming `ProgrammeVersionComparisonSummary`
- Action policy layer consuming comparison + impact separately
- Assignment migration planning (out of scope for M10.2)

---

## Tests

`test/programme_comparison/programme_version_comparison_service_test.dart` — 64 targeted cases covering identity, metadata, structure, slots, sessions, exercises, partial results, and summary rules.

Regression baseline: pre-existing suite failures unchanged (20).
