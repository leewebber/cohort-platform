# M10.1 — Programme Version Impact Analysis

**Status:** Implemented  
**Depends on:** M9 Content Governance, Programme Engine (M5–M7), M8 Performance Records

---

## Purpose

Given one **exact Programme Version**, answer:

> What currently depends on this version, what has already happened through it, and what would remain affected if a coach archives or replaces it?

This is **decision support**, not policy enforcement and not migration.

| Service | Question |
|---------|----------|
| `ProgrammeVersionImpactService` | What is affected? |

It does **not** answer what action is allowed (future policy/UI layers may consume this result).

---

## Phase 0 — Authoritative paths confirmed

### Programme identity

- `programme_versions.id` — exact immutable Programme Version
- `programme_lineages.id` — lineage roll-up context only
- Session slots: `programme_version_session_slots` → days → weeks → version

### Active assignments

- `programme_assignments.programme_version_id` pins exact version
- Operational impact uses **`status = active` only** (not paused/completed/reassigned)

### Historical attribution decision

`training_session_records` has **no `programme_version_id` column**.

Authoritative attribution order:

| Priority | Path | Rule |
|----------|------|------|
| 1 | `assignment_id` → `programme_assignments.programme_version_id` | Assignment pin wins when present |
| 2 | `programme_session_id` → slot tree → `programme_versions.id` | Used when no assignment_id |
| ✗ | `source_protocol_id` alone | **Not used** — Session Revisions are shared across programmes |
| ✗ | `programme_id` field alone | Lineage code / inconsistent runtime writes — not version-specific |

Terminal records only (`status <> in_progress`). In-progress records excluded.

Partial historical failure surfaces via `isAuthoritative`, `limitationNote`, and `warnings` without discarding authored/assignment facts.

---

## Models

| Model | Role |
|-------|------|
| `ProgrammeVersionSessionReference` | One slot with Session Revision metadata |
| `ProgrammeVersionExerciseReference` | Exercise aggregated across version's Session Revisions |
| `ProgrammeVersionAssignmentImpact` | Active assignment dependency |
| `ProgrammeVersionHistoricalImpact` | Terminal record aggregates + authority flags |
| `ProgrammeVersionLineageContext` | Newer versions, latest published |
| `ProgrammeVersionImpactSummary` | Combined read model |
| `ProgrammeVersionImpactLookupResult` | Safe lookup wrapper |

Classifications reuse M9 vocabulary:

- `directAuthored` — version has session slots
- `activeOperational` — active assignments pin this version
- `historicalPerformance` — terminal records attributable to this version

**Unused:** no active assignments and no history (may still have authored slots).

---

## Architecture

```
ProgrammeVersionImpactService
    → ProgrammeVersionImpactStore (abstract)
        → ProgrammeVersionImpactSupabaseStore (production)
        → InMemoryProgrammeVersionImpactStore (tests)
```

Shared builders in `programme_version_impact_store.dart`:

- `isRecordAttributableToProgrammeVersion`
- `buildHistoricalImpactFromRecords`
- `buildActiveAssignmentImpact`
- `buildProgrammeVersionLineageContext`
- `buildProgrammeVersionImpactClassifications`

No graph database, duplicate relationship table, or materialized dependency graph.

---

## Session and slot semantics

- `sessionReferences` — **every slot row** (stable week/day/slot order)
- `totalSessionSlotCount` — slot row count
- `distinctSessionRevisionCount` — deduplicated `protocol_id`
- `distinctSessionLineageCount` — deduplicated session lineages

Same Session Revision in multiple slots: all slots preserved; revision count deduplicated.

---

## Exercise aggregation

Programme Version → Session Revisions in slots → block links / legacy steps → `exercise_id`

Follows M9.4 rules:

- Block links preferred; legacy steps only when no block link on that revision
- No free-text inference
- Distinct exercise count vs block-link count kept separate

---

## Lineage context

Reports for queried version:

- Version number and lifecycle
- Whether newer versions exist in lineage
- Latest **published** version id/number
- Newer version ids (any lifecycle, including draft/archived)

Does not recommend or perform upgrades.

---

## Error and partial results

| Outcome | Behaviour |
|---------|-----------|
| Version not found | `ProgrammeVersionImpactLookupResult.versionNotFound` |
| Success, zero operational/history | Valid success — `isUnused` may be true with authored content |
| Total lookup failure | `lookupFailed` |
| Historical enrichment failure | Success with `warnings`, `isAuthoritative: false` |

---

## Privacy

Coach/admin-facing aggregates only in `summaryMessages`.

Not in user-facing copy:

- Athlete names, emails, IDs
- Assignment IDs
- Raw UUIDs

Internal typed models retain IDs for routing (consistent with M9).

---

## Indexes (additive)

Migration: `20260721130000_add_programme_version_impact_indexes.sql`

- `idx_training_session_records_assignment_terminal`
- `idx_training_session_records_programme_session_terminal`
- `idx_programme_assignments_version_active`
- `idx_programme_version_weeks_version`

---

## API

```dart
Future<ProgrammeVersionImpactSummary> getImpactForVersion(String programmeVersionId);
Future<ProgrammeVersionImpactLookupResult> tryGetImpactForVersion(String programmeVersionId);

// Optional decomposition for tests:
getSessionReferences(...)
getExerciseReferences(...)
getAssignmentImpact(...)
getHistoricalImpact(...)
getLineageContext(...)
```

Derived copy: `ProgrammeVersionImpactMessageBuilder.buildSummaryMessages()`

---

## Test coverage

- `test/programme_impact/programme_version_impact_service_test.dart` — 52 tests
- `test/programme_impact/programme_version_impact_migration_test.dart` — 1 test

**Targeted:** 53/53 passed  
**Full suite:** baseline failure count unchanged (20 pre-existing failures)

---

## Known limitations

- No `programme_version_id` on training records — history requires assignment or slot attribution
- `programme_id` on records not used for version-specific history
- Exercise aggregation queries all block links client-side in Supabase store (acceptable at M10.1 scale; may optimize later)
- No programme slot outcome history beyond skipped count
- No policy decisions or migration recommendations

---

## Intended future consumers

- M10.2 Programme Version action policies
- Coach Studio Programme Version impact panel
- Archive/replace confirmation copy

---

## Key files

```
lib/features/programme_impact/models/programme_version_impact_models.dart
lib/features/programme_impact/services/programme_version_impact_service.dart
lib/features/programme_impact/services/programme_version_impact_message_builder.dart
lib/data/repositories/programme_version_impact_store.dart
lib/data/repositories/programme_version_impact_supabase_store.dart
test/support/in_memory_programme_version_impact_store.dart
supabase/migrations/20260721130000_add_programme_version_impact_indexes.sql
```

---

## Recommended M10.2 scope

**Programme Version Action Policies** — mirror M9.3 using `ProgrammeVersionImpactService` as the fact layer; then Coach Studio impact UI consuming both impact and policy.
