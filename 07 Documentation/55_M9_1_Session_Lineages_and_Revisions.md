# M9.1 — Session Lineages and Revisions

## Purpose

M9.1 establishes immutable **Session Revisions** grouped by **Session Lineages**, mirroring the Programme Engine versioning principle without changing M8 execution, snapshots, or athlete history.

## Core principle

**Published content is immutable.**  
New work creates a **new revision**. Consumers (programme versions, assignments) decide when to adopt newer revisions.

## Data model

```
Session Lineage (session_lineages)
    └── Session Revision (= performance_protocols row, protocol_id PK)
            └── session_blocks
                    └── session_block_exercises → exercise_id
```

| Concept | Storage | Notes |
|---------|---------|-------|
| Session Lineage | `session_lineages.id` | Stable identity (display name) |
| Session Revision | `performance_protocols.protocol_id` | **Immutable identifier** — unchanged from pre-M9 references |
| Revision number | `performance_protocols.revision_number` | Monotonic within lineage |
| Lifecycle | `performance_protocols.lifecycle_status` | `draft` \| `published` \| `archived` |

Existing `published` boolean remains for legacy catalogue queries and is kept in sync with lifecycle.

### Backfill

Migration `20260721100000_add_session_lineages_and_revisions.sql`:

- Creates one lineage per existing protocol
- Sets `revision_number = 1`
- Maps lifecycle from legacy `published` flag
- **Does not change any `protocol_id` values**

Programme slot `protocol_id` references, `training_sessions`, and M8 `source_protocol_id` values remain valid.

## Lifecycle

| Status | Editable | Assignable to published programme slots |
|--------|----------|----------------------------------------|
| `draft` | Yes (in place) | No (policy) |
| `published` | **No** — fork to new draft revision | Yes |
| `archived` | **No** — fork to new draft revision | No (historical resolve only) |

There is no `superseded` status in M9.1. A newer published revision in the same lineage implies supersession logically.

## Edit workflow

### Draft revision

Coach edits normally → `ProtocolBuilderService.saveDraft()` updates the same `protocol_id`.

### Published (or archived) revision

Coach clicks Edit → **`SessionRevisionService.createNewSessionRevision()`**:

1. Loads source revision
2. Allocates next `revision_number` in lineage
3. Deep-clones metadata, blocks, linked exercises, timers, capture modes
4. Persists new row with new `protocol_id` as **draft**
5. Source revision unchanged

`ProtocolBuilderService` rejects in-place saves when lifecycle is `published` or `archived`.

## Publishing workflow

1. Coach completes draft revision
2. `SessionRevisionService.publishRevision()` → `ProtocolBuilderService.publishDraft()`
3. Lifecycle → `published`, `published_at` set
4. Revision becomes immutable

Publishing does **not** update programme slots or assignments.

## Programme compatibility

Programme slots store **`protocol_id` only** (Session Revision instance id).

```
Programme Version 1 → slot → session-a (revision 1)
Programme Version 2 → slot → session-a-rev-2 (revision 2)  // manual coach choice
```

Programme Version 1 continues referencing revision 1 after revision 2 is published. This is intentional.

Programme assignment pins `programme_version_id` → transitively pins all session revision ids referenced by that version's slots.

## M8 compatibility — no changes required

M8 remains snapshot-authoritative:

```
Programme Version (pinned)
    → Session Revision (protocol_id)
    → TrainingSession (runtime)
    → TrainingSessionRecord + session_snapshot JSON
```

- `source_protocol_id` already identifies the revision instance performed
- Snapshots embed block/exercise capture-time labels
- Renaming or forking sessions does not rewrite completed records
- No M8 schema, restore path, or Founder Acceptance behaviour changed in M9.1

Optional future additive provenance (`source_session_lineage_id`) is out of scope for M9.1.

## Services (M9.1)

| Service | Role |
|---------|------|
| `SessionLineageStore` / `SessionLineageSupabaseStore` | Lineage CRUD + revision metadata queries |
| `SessionRevisionClone` | Pure deep-clone of revision draft |
| `SessionRevisionService` | `createLineage`, `createNewSessionRevision`, `publishRevision`, `archiveRevision` |

## Out of scope (later M9 phases)

- Content relationship graph / Used By UI
- Safe delete blockers
- Coach Studio version catalogue UI
- Programme slot upgrade suggestions
- Automatic propagation of new revisions into programmes

## Related files

| Path | Role |
|------|------|
| `supabase/migrations/20260721100000_add_session_lineages_and_revisions.sql` | Schema + backfill |
| `lib/models/session_lineage.dart` | Lineage model |
| `lib/models/session_revision_vocabulary.dart` | Lifecycle enum |
| `lib/features/session_revision/services/session_revision_service.dart` | Orchestration |
| `lib/features/session_revision/services/session_revision_clone.dart` | Clone helper |
| `lib/features/admin/services/protocol_builder_service.dart` | Immutability guard + lineage on create |
| `test/session_revision/session_revision_service_test.dart` | Targeted tests |
