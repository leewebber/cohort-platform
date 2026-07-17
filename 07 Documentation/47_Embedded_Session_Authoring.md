# 47 — Embedded Session Authoring

**Status:** M1 + M2 + M3 implemented (metadata, Session Builder UI, programme-only persistence)  
**Related:** `34_Protocol_Builder.md`, `44_Programme_Builder.md`, `46_Programme_Editor.md`, `ProtocolDraft`, `ProtocolBuilderService`, `ProtocolRepository`

---

## Canonical terminology

| Term | Meaning |
|------|---------|
| **Protocol** | Cohort-endorsed official training content. |
| **Session** | Coach-authored or customised workout. |
| **Template** | Reusable starting structure copied on use. |
| **Programme Session** | Executable content occupying a programme slot. |

Coach-facing product language distinguishes Protocol (official) from Session (coach-authored). Technically both persist in `performance_protocols` + `protocol_steps` — **no second training-content stack**.

---

## Core architecture rule

Reuse existing persistence and execution:

- `performance_protocols`
- `protocol_steps`
- `ProtocolDraft` / `ProtocolStepDraft`
- `ProtocolBuilderService`
- `ProtocolRepository`
- `SessionExecutionRouter`

Future Session Builder UI wraps Protocol Builder internals; it does not fork schema or execution. **M2** extracts shared editing into `SessionBuilderView`.

---

## M2 — SessionBuilderView and navigation (implemented)

### SessionBuilderView boundary

| Layer | Responsibility |
|-------|----------------|
| `SessionBuilderView` | Visual editing of `ProtocolDraft`; emits `onDraftChanged`; no Supabase/Navigator/save |
| `ProtocolBuilderScreen` | Admin load/save/publish/preview; hosts `SessionBuilderView` in cohort admin mode |
| `EmbeddedSessionBuilderScreen` | Programme chrome, Save & Attach, preview, cancel, partial-failure recovery |
| `ProgrammeEditorController` | Programme document + slots — **unchanged** by M2 draft edits |

Location: `lib/features/session_builder/`

### Host modes

| Mode | UI terminology | Persistence |
|------|------------------|-------------|
| `cohortProtocolAdmin` | Protocol, protocol_id, Publish | `ProtocolBuilderService` (unchanged) |
| `embeddedProgrammeSession` | Session, Blocks, Exercises | `ProgrammeSessionAuthoringCoordinator` → `ProtocolBuilderService` + slot attach |

### Programme entry (M2)

Empty programme slot inspector:

- **Use Cohort Protocol** → existing `listCohortProtocols()` picker (`Cohort Protocols` sheet title)
- **Build New Session** → `EmbeddedSessionBuilderScreen` with `ProgrammeSessionAuthoringContext`

No slot mutation until Save & Attach (M3).

### M3 — Save & Attach and coordinator (implemented)

**Coordinator:** `lib/features/programme_builder/services/programme_session_authoring_coordinator.dart`

| Responsibility | Owner |
|----------------|-------|
| Programme-only metadata validation/normalization | Coordinator |
| Durable internal ID assignment (first save) | Coordinator via `TrainingContentIdGenerator` |
| Session row persistence | `ProtocolBuilderService.saveDraft` (wrapped — not called from UI) |
| In-memory slot attach | `ProgrammeSessionAssignmentPort` → `ProgrammeEditorController.assignProtocol` |
| Partial failure / retry attach | Coordinator |
| Navigation / widgets | `EmbeddedSessionBuilderScreen`, slot inspector |

Coach UI **never** calls `ProtocolBuilderService` or repositories directly. `SessionBuilderView` has no persistence imports.

### Persistence workflow (M3)

```
Save & Attach
  1. Validate preflight (editable programme, slot exists, version match)
  2. Reject cohort_protocol drafts
  3. Normalize metadata → session / programme_only / coach_authored / published=false
  4. Replace local-session-* with durable UUID (protocol_id TEXT)
  5. ProtocolBuilderService.saveDraft  ← Session row saved immediately
  6. assignProtocol(slot, contentId, displayTitle)  ← in-memory programme document only
  7. Programme document marked dirty — normal programme Save persists slot assignment
```

**Important:** Session save success does **not** guarantee programme document save success. If attach fails after save, coach sees **Retry adding to programme** (no second Session row).

### Internal Session ID rule (M3)

- First save assigns a **full RFC-4122 UUID** stored in `performance_protocols.protocol_id`
- No `RN-`, `BW-`, `FG-`, or `SES-*` coach-facing codes
- `local-session-*` ids exist only in-memory until persistence
- Internal IDs are **not** shown in coach UI; Session **name** is the visible identity
- Edit mode preserves the existing UUID

### Partial failure model

| Status | Meaning | Coach action |
|--------|---------|--------------|
| `attached` | Saved + attached in-memory | Return to Programme Editor |
| `sessionSaveFailed` | Save failed | Stay in builder; draft preserved |
| `sessionSavedAttachFailed` | Saved but attach failed | Retry adding to programme |
| `slotNotFound` | Programme/slot changed while editing | Reopen slot |
| `validationFailed` | Name/steps/classification | Fix draft inline |

### Create / edit flows (M3)

| Intent | Entry | ID behaviour |
|--------|-------|--------------|
| `createBlank` | Empty slot → Build New Session | New UUID on first save |
| `editCoachSession` | Programme session slot → Edit Session | Existing UUID preserved |

Edit is allowed only when loaded content is `session` + `programme_only` + matching `programme_version_id`. Cohort Protocol slots show Change/Remove — not Edit Session.

### State ownership

```
ProgrammeEditorController (document, slots)
  └─ slot inspector → navigates to EmbeddedSessionBuilderScreen
       └─ ProgrammeSessionAuthoringCoordinator (M3)
            ├─ ProtocolBuilderService.saveDraft
            └─ ProgrammeEditorController.assignProtocol
```

### Identity (M3)

- `CurrentCoachIdentity` port (`DevCoachIdentity` in development) sets `ownerId` on save
- No hardcoded `dev-coach` in widgets
- Full coach-owner RLS deferred to M4+

### M5 — Cohort Protocol copy-and-customise (implemented)

**Coordinator:** `CohortProtocolCustomisationCoordinator`  
**Clone service:** `SessionCloneService` (`lib/features/session_builder/services/session_clone_service.dart`)

| Flow | Entry | Save destination | Attach |
|------|-------|-------------------|--------|
| Programme picker | Add unchanged / **Copy and customise** / Preview | Programme-only (default) or Session Library | On Save & Attach |
| Assigned Cohort slot | Preview, **Copy and customise**, Change, Remove | Same | Replaces slot with copied Session |
| Training Library detail | **Copy to Session Library** | `coach_private`, `published=true` | None (library-only) |

**Clone semantics:**

- Deep copy of `ProtocolDraft`, step list, and step objects — mutating the clone never mutates the loaded source in memory
- New opaque UUID on first save; source step-row IDs cleared (`persistedId=null`)
- Copied Session is **not** Cohort-endorsed; original Protocol unchanged
- Provenance: `source_content_id` = original `protocol_id`, `source_content_kind=cohort_protocol`, `source_version_id=null` (no version pinning yet)
- Title default: `{source name} — Custom`

**Programme copy save destinations** (embedded builder):

- **This programme only** — `programme_only`, `published=false`, scoped to current programme version
- **Session Library** — one reusable row saved then attached by **live reference** (Policy A); shows warning: *Changes to this library Session may update other programmes using it.*

**Partial failure:** Library save + programme attach uses M3/M4 retry semantics — Session remains in library; retry attach does not save again.

**Intent:** `ProgrammeSessionAuthoringIntent.copyCohortProtocol` with optional `sourceProtocolId` for slot conflict detection.

Diagnostics prefix: `[CohortProtocolCustomisation]`.

### M6 handoff starting point

1. Promote programme-only Session → Session Library (general flow outside copy)
2. Duplicate Session in programme slots
3. Lineage display in list rows (optional “Based on RN-006 · …” without N+1)

### M4 — Training Library integration (implemented)

See `48_Training_Library.md`.

- **Training Library** shell in Coach Studio with Cohort Protocols + Session Library tabs
- Reusable Sessions: `session` / `coach_private` / `published=true` / `programme_version_id=null`
- Programme-only Sessions excluded from Session Library
- **Use Session Library** in Programme Editor attaches by live reference (Policy A)
- `SessionLibraryAuthoringCoordinator` for create/edit; `attachExistingSession` for picker attach
- Athlete Protocol Library unchanged

---

## Metadata schema (M1)

Additive columns on `performance_protocols`:

| Column | Type | Default (legacy backfill) |
|--------|------|---------------------------|
| `content_kind` | TEXT NOT NULL | `cohort_protocol` |
| `authoring_scope` | TEXT NOT NULL | `cohort_global` |
| `endorsement_status` | TEXT NOT NULL | `cohort_endorsed` |
| `owner_id` | TEXT NULL | NULL |
| `organisation_id` | TEXT NULL | NULL |
| `programme_version_id` | UUID NULL FK → `programme_versions.id` | NULL |
| `source_content_id` | TEXT NULL | NULL |
| `source_content_kind` | TEXT NULL | NULL |
| `source_version_id` | TEXT NULL | NULL |

### `content_kind` (simplified — no `programme_session`)

| Value | Meaning |
|-------|---------|
| `cohort_protocol` | Official Cohort Protocol |
| `session` | Coach Session (reusable or programme-only) |
| `session_template` | Reusable template (copy-on-use) |

**Programme-only workout:**

```
content_kind = session
authoring_scope = programme_only
programme_version_id = <uuid>
```

**Reusable coach workout:**

```
content_kind = session
authoring_scope = coach_private
programme_version_id = NULL
owner_id = <coach id>
```

### Explicitly excluded from M1

- `is_template` column
- `lifecycle_status` column
- `content_kind = programme_session`
- Title / ID prefix classification hacks

---

## Domain types (Dart)

`lib/models/training_content_vocabulary.dart`:

- `TrainingContentKind`
- `TrainingAuthoringScope`
- `TrainingEndorsementStatus`

Parsing rules:

- Unknown `endorsement_status` → `unreviewed` (never `cohortEndorsed`)
- Unknown `content_kind` → `session` (never silent Cohort Protocol)
- Unknown `authoring_scope` → `coachPrivate`

`ProtocolDraft` carries optional metadata fields; official Protocol Builder path defaults remain `cohortProtocol` / `cohortGlobal` / `cohortEndorsed`.

Invariants: `lib/models/training_content_classification.dart`

---

## Migration decision (M1)

**File:** `supabase/migrations/20260718130000_add_training_content_metadata.sql`

- All pre-existing rows backfilled as official Cohort Protocol metadata.
- `published`, `protocol_id`, names, and `protocol_steps` links preserved.
- `owner_id` / `organisation_id` use **TEXT** (not UUID) to align with `programme_versions.owner_id` and dev identity `dev-coach`.

---

## Repository classification (M1)

| Method | Filters |
|--------|---------|
| `listCohortProtocols` | `content_kind=cohort_protocol`, `authoring_scope=cohort_global`, `published=true` |
| `listCoachSessions(ownerId)` | `session`, `coach_private`, `owner_id` |
| `listProgrammeSessions(versionId)` | `session`, `programme_only`, `programme_version_id` |
| `listSessionTemplates` | `session_template` (+ optional owner) |

**Wired in M1:** athlete Protocol Library + Programme Builder Cohort picker → `listCohortProtocols`.

Admin Protocol Builder listing remains unfiltered via `getProtocols()` (draft/published admin surfaces).

---

## RLS (M1 — unchanged)

Current read behaviour for official published Cohort Protocols and development authoring access is preserved. Metadata columns prepare for future policies:

| Content | Future policy |
|---------|---------------|
| Cohort Protocol | Authenticated/public read as today; coaches cannot update/delete official rows |
| Coach private Session | Owner read/write |
| Programme-only Session | Programme owner read/write while draft; athlete read via assignment/execution |
| Template | Owner editable; Cohort global templates read-only for coaches |

Full coach-owner RLS deferred until Supabase Auth replaces dev identities.

---

## Implementation milestones

| Milestone | Scope | Status |
|-----------|-------|--------|
| **M1** | Metadata migration, domain model, backfill, repository classification | **Done** |
| **M2** | `SessionBuilderView` extraction, embedded navigation, programme slot actions | **Done** |
| **M3** | Save & Attach, coordinator, programme-only persistence, edit attached Session | **Done** |
| **M4** | Training Library, Session Library, reusable Sessions, programme attach | **Done** |
| **M5** | Cohort Protocol copy-and-customise, lineage, programme/library destinations | **Done** |
| M6 | Promote programme-only → reusable, duplicate Session, lineage UI | Pending |

---

## Diagnostics (debug mode)

```
[ProgrammeSessionAuthoring] saveStart version=... slot=... isEdit=...
[ProgrammeSessionAuthoring] sessionSaved
[ProgrammeSessionAuthoring] attachSucceeded
[ProgrammeSessionAuthoring] attachFailed stage=...
[ProgrammeSessionAuthoring] retryAttach result=...
```

No private user data or secrets logged.
