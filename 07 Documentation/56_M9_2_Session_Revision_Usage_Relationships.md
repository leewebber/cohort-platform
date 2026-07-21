# M9.2 — Session Revision Usage Relationships

**Status:** Implemented (read-only vertical slice)  
**Depends on:** M9.1 Session Lineages & Revisions, Programme Engine, M8 Performance Capture

---

## Purpose

Given one **exact Session Revision** (`protocol_id`), answer:

1. Which Programme Versions directly reference it?
2. Which **active** Programme Assignments transitively depend on it?
3. How many terminal `TrainingSessionRecord` rows reference it?
4. Is it used in authored content, operationally, historically, or not at all?
5. Can callers receive a stable typed summary without knowing database details?

This milestone is **read-only**. It does not delete, archive, upgrade, or mutate content.

---

## Architectural principle

Published content is immutable. Consumers pin exact revisions. Relationship information must be **derived from authoritative persisted data** — not duplicated into a graph table or cache.

```
Session Revision (protocol_id)
    ↑ direct authored
programme_version_session_slots.protocol_id

Session Revision
    ↑ transitive operational
programme_assignments (status = active)
    → programme_versions (pinned)
        → programme_version_session_slots.protocol_id

Session Revision
    ↑ historical
training_session_records.source_protocol_id (terminal statuses only)
```

---

## Exact-revision semantics

| Rule | Behaviour |
|------|-----------|
| Exact revision only | Querying Revision 2 does **not** include Revision 1 or 3 |
| Programme version pinning | Programme Version 1 → Rev 1; Version 2 → Rev 2 are reported separately |
| Assignment dependency | Assignment depends on a revision only when its pinned Programme Version contains that exact `protocol_id` |
| Historical independence | Records may exist even when no programme slot or active assignment references the revision |
| Archived visibility | Archived programme versions and session revisions remain visible in usage results |
| No duplicate assignments | One assignment appears once even if the revision appears in multiple slots |

---

## Classifications

| Classification | Meaning |
|----------------|---------|
| `directAuthored` | At least one programme slot references the revision |
| `activeOperational` | At least one **active** assignment is pinned to a programme version containing the revision |
| `historicalPerformance` | At least one **terminal** training record references `source_protocol_id` |

Terminal record statuses follow M8: `completed`, `partially_completed`, `abandoned`.  
`in_progress` records are excluded.

Assignment operational status follows Programme Engine: only `ProgrammeAssignmentStatus.active` counts.  
`paused`, `completed`, and `reassigned` are excluded.

---

## Programme-level vs slot-level counts

`SessionRevisionUsageSummary` exposes:

- **`programmeReferenceCount`** — distinct programme versions referencing the revision
- **`slotReferenceCount`** — total slot rows referencing the revision (may exceed programme count)

Both slot rows are preserved in `programmeReferences` with week/day/slot context.

---

## Service API

```dart
SessionRevisionRelationshipService.getUsageForRevision(protocolId)
```

Optional granular methods (same service):

- `getProgrammeReferences(protocolId)`
- `getActiveAssignmentReferences(protocolId)`
- `getHistoricalUsage(protocolId)`

Store boundary: `SessionRevisionRelationshipStore` (+ Supabase implementation).

Revision identity (`sessionLineageId`, `revisionNumber`) is loaded via `SessionLineageStore.getRevisionIdentity()`.

---

## Authoritative query paths

### Direct authored usage

`programme_version_session_slots` filtered by `protocol_id`, joined through:

`days → weeks → versions → lineages`

### Active operational usage

1. Resolve programme version IDs containing the revision (from slot query)
2. Load `programme_assignments` where:
   - `programme_version_id IN (...)` AND
   - `status = 'active'`

### Historical usage

`training_session_records` where:

- `source_protocol_id = protocolId`
- `status <> 'in_progress'`

Aggregate: count, earliest performed at, latest performed at.

---

## Indexes / migrations

**`20260721110000_add_session_revision_usage_indexes.sql`**

Adds partial index:

`idx_training_session_records_source_protocol_terminal` on `(source_protocol_id)` where terminal.

Existing indexes reused:

- `idx_programme_version_session_slots_protocol`
- `idx_programme_assignments_version`

No graph table. No relationship cache.

---

## RLS assumptions

The relationship service is **coach/admin-facing** in early phases.

Implementation follows existing repository conventions:

- Supabase reads use the same tables/policies as Programme Builder and Coach Studio dev policies
- No global RLS weakening
- Athlete-facing surfaces must not expose other athletes’ assignment or history metadata through this service without explicit scoped policies

In development, dev-coach programme authoring policies allow the required reads. Production coach policies should mirror Programme catalogue access patterns when UI is wired in M9.3+.

---

## Why no graph database

Relationships are deterministic joins over normalized authoritative tables. Duplicating edges would:

- Risk drift from source data
- Require invalidation on every slot/assignment/record change
- Add migration and sync complexity without improving correctness

M9.2 proves query shapes on Session Revisions first. Generalisation to exercises/programmes can follow once consumers exist.

---

## M8 compatibility

No changes to:

- `TrainingSessionRecord` schema
- Snapshot JSON
- Execution or history UI
- Founder Acceptance flows

Historical usage reads existing `source_protocol_id` values only.

---

## Known limitations (M9.2)

| Limitation | Notes |
|------------|-------|
| Session-revision-specific | No universal `ContentRelationshipService` yet |
| No lineage roll-up | Must query each revision separately |
| No slot substitution edges | `programme_slot_outcomes.replacement_protocol_id` not included |
| No Coach Studio UI | Service-only |
| No delete/archive policy | Consumed by M9.3 |
| No programme upgrade suggestions | M9.5+ |

---

## How M9.3 will consume this service

M9.3 **Safe Action Policies** can use `SessionRevisionUsageSummary` to decide:

- Whether a draft revision can be discarded safely
- Whether a published revision can be archived (warn vs block)
- Whether delete should be blocked when `hasActiveOperationalUsage` or `hasDirectAuthoredUsage`

Policy layer should interpret classifications — this service reports facts only.

---

## Tests

`test/session_revision/session_revision_relationship_service_test.dart` — direct, assignment, historical, and combined summary cases.

`test/session_revision/session_revision_usage_migration_test.dart` — index migration assertions.

Regression targets: M9.1 session revision tests, programme assignment pinning, M8 history, Founder Acceptance.

---

## Related documentation

- `55_M9_1_Session_Lineages_and_Revisions.md`
- `42_Programme_Engine_Schema.md`
- `52_M8_Performance_Capture_and_Training_History.md`
