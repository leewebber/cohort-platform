# 48 — Training Library

**Status:** M4 + M5 implemented  
**Related:** `47_Embedded_Session_Authoring.md`, `44_Programme_Builder.md`, `46_Programme_Editor.md`, `34_Protocol_Builder.md`, `45_Coach_Studio_Programme_Catalogue.md`

---

## Information architecture

```
Coach Studio
└── Training Library
    ├── Cohort Protocols      (M4 — read-only browse)
    ├── Session Library       (M4 — reusable coach Sessions)
    ├── Templates             (future)
    └── Exercises             (future)
```

Athlete-facing **Protocol Library** (Home → Knowledge) remains separate and unchanged.

---

## Tab responsibilities

| Tab | Query filters | Coach actions |
|-----|---------------|---------------|
| **Cohort Protocols** | `content_kind=cohort_protocol`, `authoring_scope=cohort_global`, `published=true` | Preview, **Copy to Session Library**, search |
| **Session Library** | `content_kind=session`, `authoring_scope=coach_private`, `owner_id=current coach`, `published=true` | Create, edit, preview, search |

Programme-only Sessions (`authoring_scope=programme_only`) **never** appear in Session Library.

---

## Reusable Session lifecycle

| Field | Value |
|-------|-------|
| `content_kind` | `session` |
| `authoring_scope` | `coach_private` |
| `endorsement_status` | `coach_authored` |
| `programme_version_id` | `null` |
| `published` | `true` (library-available — **not** Cohort endorsement) |
| `owner_id` | current coach identity |

Persistence: `SessionLibraryAuthoringCoordinator` → `ProtocolBuilderService.saveCoachLibrarySession`.

Internal IDs are opaque UUIDs — not coach-facing catalogue codes.

---

## Programme attachment semantics (M4)

**Policy A — Live reference**

When a coach selects a reusable Session from **Use Session Library**:

- The slot stores the existing Session `content_id` (no copy)
- No new `performance_protocols` row is created
- Programme document is marked dirty; normal programme Save persists the slot assignment
- Execution resolves content dynamically by `protocol_id` at runtime

**Consequence:** Editing a reusable Session in Session Library updates the underlying content for **all** programme slots referencing that ID — including published programmes. Content version pinning is deferred to a future milestone.

Programme-only Sessions (Build New Session / Edit Session in Programme Builder) remain independent rows scoped to one programme version.

---

## Copy to Session Library (M5)

From Cohort Protocol detail or card:

1. `CohortProtocolCustomisationCoordinator.prepareCopy` loads and validates official Protocol metadata (not ID prefix)
2. `SessionCloneService` deep-clones to coach Session draft
3. `LibrarySessionBuilderScreen` → `SessionLibraryAuthoringCoordinator.createSession`

Copied library Sessions:

- `coach_authored`, not Cohort-endorsed
- `source_content_id` records lineage — **not** approval
- Optional future list label: “Based on Cohort Protocol” (no raw ID in UI)
- No version pinning — edits are live for all referencing programmes when attached

When copied from Programme Builder with **Session Library** destination, attach uses live reference with the same warning as **Use Session Library**.

---

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `TrainingLibraryScreen` | Tab shell, navigation chrome |
| `TrainingLibraryService` | Catalogue loading (no Supabase in widgets) |
| `SessionLibraryAuthoringCoordinator` | Reusable Session create/edit/load |
| `ProgrammeSessionAuthoringCoordinator.attachExistingSession` | Attach reusable Session to draft slot |
| `SessionBuilderView` | Shared editing UI (persistence-free) |
| `LibrarySessionBuilderScreen` | Session Library create/edit host |
| `ProtocolBuilderService` | Shared persistence engine |

---

## Editing ownership rules

| Content | Editable from Session Library? |
|---------|-------------------------------|
| Reusable coach Session (`coach_private`) | Yes — owner only |
| Programme-only Session | No — edit from Programme Builder |
| Cohort Protocol | No — read-only for ordinary coaches |
| Another coach's Session | No |

Deletion/archive deferred — reusable Sessions may be referenced by programme slots.

---

## Future locations

- **Templates** — `content_kind=session_template` tab (not M4)
- **Exercises** — integration with Exercise Library (not M4)
- **Mine / Shared / Organisation** filters — architecture allows; not M4

---

## Diagnostics (debug mode)

```
[TrainingLibrary] opened tab=...
[TrainingLibrary] cohortLoaded count=...
[SessionLibrary] loaded count=...
[SessionLibrary] createStart
[SessionLibrary] createSucceeded
[SessionLibrary] updateSucceeded
[ProgrammeSessionAuthoring] attachExistingSession result=...
```

No Session titles, internal IDs, or private content logged in production.
