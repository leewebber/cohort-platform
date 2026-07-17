# 34 — Protocol Builder

**Status:** Canonical architecture  
**Related:** `47_Embedded_Session_Authoring.md`, `ProtocolDraft`, `ProtocolBuilderService`, `performance_protocols`, `protocol_steps`

---

## Purpose

Protocol Builder is the coach/admin authoring surface for single-session training content stored in `performance_protocols` with ordered steps in `protocol_steps`.

---

## Canonical terminology

- **Protocol** — Cohort-endorsed official training content.
- **Session** — Coach-authored or customised workout.
- **Template** — Reusable starting structure copied on use.
- **Programme Session** — Executable content occupying a programme slot.

Protocol Builder today authors **Cohort Protocols** (`content_kind=cohort_protocol`). Future Session Builder reuses the same draft model and service with different default metadata (M2+).

### Shared SessionBuilderView (M2)

`ProtocolBuilderScreen` hosts `SessionBuilderView` for admin authoring. Shared widgets live under `lib/features/session_builder/`:

- `SessionBuilderView` — metadata + blocks/steps editing
- `SessionBuilderStepEditorCard` — exercise/step editor
- `SessionBuilderEditingState` — draft snapshot builder

Standalone admin responsibilities remain in `ProtocolBuilderScreen`: load, save draft, publish, unpublish, success dialogs.

---

## Domain model

| Dart | Table |
|------|-------|
| `ProtocolDraft` | `performance_protocols` |
| `ProtocolStepDraft` | `protocol_steps` |

M1 metadata on `ProtocolDraft`:

- `contentKind`, `authoringScope`, `endorsementStatus`
- `ownerId`, `organisationId`, `programmeVersionId`
- `sourceContentId`, `sourceContentKind`, `sourceVersionId`

Official authoring path defaults: `cohortProtocol` / `cohortGlobal` / `cohortEndorsed`.

---

## Persistence

`ProtocolBuilderService`:

1. Upsert `performance_protocols` (including M1 metadata via `ProtocolDraft.toProtocolMap()`)
2. Replace `protocol_steps` for the protocol id

Load maps metadata via `ProtocolDraft.applyTrainingContentMetadata`. Saves must not discard classification when editing ordinary fields.

### Coach Session access (M3)

Admin Protocol Builder continues to use `ProtocolBuilderService` directly for Cohort Protocols.

Embedded programme Session authoring accesses persistence **only** through `ProgrammeSessionAuthoringCoordinator` — the coordinator wraps `saveDraft` / `loadProtocol` and enforces programme-only metadata. Coach UI must not call the service directly.

Reusable Session Library authoring uses `SessionLibraryAuthoringCoordinator` → `ProtocolBuilderService.saveCoachLibrarySession` (`published=true`, library-available semantics).

### Cohort Protocol cloning (M5)

Official Cohort Protocols are **immutable to ordinary coaches**. Copy-and-customise uses the same draft model and `ProtocolBuilderService` persistence — not in-place mutation of the source row.

| Concern | Owner |
|---------|-------|
| Deep clone | `SessionCloneService` |
| Source eligibility | `ProtocolBuilderService.loadCohortProtocolForCopy` (metadata validation) |
| Orchestration | `CohortProtocolCustomisationCoordinator` |
| Programme save | `ProgrammeSessionAuthoringCoordinator` |
| Library save | `SessionLibraryAuthoringCoordinator` |

Cloned Sessions receive new UUIDs, `coach_authored` endorsement, and provenance fields. Source Protocol rows and steps are never updated by coach copy flows.

---

## Boundaries

- Protocol Builder does not embed programmes or slots.
- Programme Builder references `protocol_id` only.
- Execution uses `SessionExecutionRouter` — unchanged by M1.
