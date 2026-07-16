# 43 — Programme Engine Service Contracts

**Status:** Canonical service design (v0.1) — stores + schedule services implemented  
**Related:** `41_Programme_Engine.md`, `42_Programme_Engine_Schema.md`, `44_Programme_Builder.md`, `45_Coach_Studio_Programme_Catalogue.md`  
**Stores:** Supabase implementations in `lib/data/repositories/*_supabase_store.dart`  
**Services (v0.1):** `ProgrammeScheduleResolver`, `TodaySessionService`, `AthleteStateSyncService`, `ProgrammeAssignmentService`  
**Builder (v0.1 scaffold):** Models + contracts in `lib/features/programme_builder/` — see `44_Programme_Builder.md`

---

## 1. Layering

```
Widgets (Home, Coach Studio — future)
    ↓
Services (business logic)
    ↓
Stores / Repositories (fetch and persist only)
    ↓
Supabase tables (§42)
```

| Rule | Detail |
|------|--------|
| Repositories fetch only | No schedule resolution, no progression rules |
| Services own logic | Publishing, assignment, resolution, progression, sync |
| Execution Engine untouched | Services link outcomes to `training_sessions`; never modify session player |
| `ProgrammeAssignment` is truth | `AthleteStateSyncService` projects assignment + resolution to `athlete_state` |

---

## 2. Store interfaces (repositories)

Persistence boundaries for test doubles. **Supabase implementations** are live. **Schedule services v0.1** are implemented; assignment, publishing, progression, and outcome services remain future work.

| Store interface | Supabase implementation |
|-----------------|-------------------------|
| `ProgrammeVersionStore` | `ProgrammeVersionSupabaseStore` |
| `ProgrammeAssignmentStore` | `ProgrammeAssignmentSupabaseStore` |
| `ProgrammeSlotOutcomeStore` | `ProgrammeSlotOutcomeSupabaseStore` |
| `AthleteStateStore` | `AthleteStateSupabaseStore` |

Shared helpers:
- `ProgrammeTemplateTreeAssembler` — deterministic tree assembly from flat rows
- `ProgrammeStoreException` — surfaces RLS/constraint failures (never swallowed)

**Auth note:** Flutter uses `SUPABASE_ANON_KEY` only. Service-role key is never used in the app.

### 2.1 `ProgrammeVersionStore`

Loads and persists versioned programme templates.

```dart
abstract class ProgrammeVersionStore {
  Future<ProgrammeLineage?> getLineageByCode(String code);
  Future<ProgrammeLineage?> getLineageById(String lineageId);
  Future<ProgrammeVersion?> getVersionById(String versionId);
  Future<ProgrammeVersion?> getVersionByLineageAndNumber({
    required String lineageCode,
    required int versionNumber,
  });
  Future<ProgrammeVersion?> getPublishedVersion({
    required String lineageCode,
    required int versionNumber,
  });
  Future<ProgrammeTemplate?> loadTemplate(String versionId);
  Future<ProgrammeVersion> saveDraftVersion(ProgrammeVersion version);
  Future<void> saveTemplateTree({
    required ProgrammeVersion version,
    required ProgrammeTemplate template,
  });
  Future<List<ProgrammeVersion>> listCatalogueVersions({
    required ProgrammeCatalogueQuery query,
  });
}
```

### 2.2 `ProgrammeAssignmentStore`

```dart
abstract class ProgrammeAssignmentStore {
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId);
  Future<ProgrammeAssignment?> getById(String assignmentId);
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment);
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment);
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId);
}
```

### 2.3 `ProgrammeSlotOutcomeStore`

```dart
abstract class ProgrammeSlotOutcomeStore {
  Future<ProgrammeSlotOutcome?> getForSlot({
    required String assignmentId,
    required String sessionSlotId,
  });
  Future<List<ProgrammeSlotOutcome>> listForAssignment(String assignmentId);
  Future<List<ProgrammeSlotOutcome>> listForDay({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
  });
  Future<ProgrammeSlotOutcome> upsert(ProgrammeSlotOutcome outcome);

  /// Deletes all outcomes for [assignmentId]. Returns deleted row count and ids.
  /// Reset workflows must verify count when outcomes were visible pre-delete.
  Future<ProgrammeSlotOutcomeDeleteResult> deleteOutcomesForAssignment({
    required String assignmentId,
  });
}
```

### 2.4 `AthleteStateStore`

```dart
abstract class AthleteStateStore {
  Future<AthleteState?> getByAthleteId(String athleteId);
  Future<void> upsertProjection(AthleteState projection);
}
```

---

## 3. Core services

### 3.1 `ProgrammeCatalogService`

Read-only catalogue for Coach Studio and enrolment pickers.

```dart
abstract class ProgrammeCatalogService {
  Future<List<ProgrammeCatalogEntry>> listPublished({
    required ProgrammeCatalogueQuery query,
  });

  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  });
}
```

**`ProgrammeCatalogueQuery`**

| Field | Purpose |
|-------|---------|
| `libraryScope` | Filter by scope |
| `ownerType` / `ownerId` | Coach or org library |
| `includeGlobalApproved` | Cohort Global curated only |
| `searchTerm` | Name/description search (future) |

**`ProgrammeCatalogEntry`** — summary row: lineage code, version, name, metadata, lifecycle.

---

### 3.2 `ProgrammePublishingService`

Draft → published lifecycle. No UI.

```dart
abstract class ProgrammePublishingService {
  /// Validates tree, freezes draft as immutable published version.
  Future<ProgrammeVersion> publishDraft({
    required String versionId,
    required String publishedByCoachId,
  });

  /// Retires version from new assignments.
  Future<ProgrammeVersion> archiveVersion(String versionId);

  /// Clones a published version into a new draft (version_number + 1).
  Future<ProgrammeVersion> cloneToNewDraft({
    required String publishedVersionId,
  });
}
```

**Publish rules:**
- Draft only; tree must have ≥1 week and valid protocol references
- Sets `lifecycle_status = published`, `published_at = now()`
- Child rows become immutable (enforced by store/RLS)
- Does not reassign active athletes

**Clone Version** (`cloneToNewDraft`): same lineage, version N → N+1 draft. Used when editing a published programme.

**Not duplicate programme** — that is `ProgrammeBuilderService.duplicateProgramme` (new lineage, v1). See `44_Programme_Builder.md` §8.

---

### 3.2.1 Programme Builder services — **contracts only (v0.1)**

**Canonical doc:** `44_Programme_Builder.md`  
**Location:** `lib/features/programme_builder/`

| Service | Role | Implementation |
|---------|------|----------------|
| `ProgrammeBuilderService` | Draft CRUD, structural edits, undo/redo, duplicate programme | Contract only |
| `ProgrammeBuilderValidationService` | Validate tree, publish checks, `buildPublishReadiness` | `ProgrammeBuilderValidationServiceImpl` |
| `ProgrammeBuilderCompiler` | `ProgrammeBuilderDocument` ↔ `ProgrammeTemplateTree` | Implemented |
| `ProgrammeBuilderPreviewService` | Structural + athlete-facing preview DTOs | Contract only |
| `ProgrammeBuilderProtocolPickerService` | Protocol catalogue for slot assignment | Contract only |
| `ProgrammeBuilderPublishCoordinator` | Validate → save if dirty → publish | Contract only |

**Boundary rules:**

| Concern | Owner |
|---------|-------|
| Author template versions | Programme Builder (`ProgrammeBuilderService` + `ProgrammePublishingService`) |
| Assign published versions to athletes | `ProgrammeAssignmentService` only |
| Resolve today's session | `TodaySessionService` |
| Home UI | Reads `TodaySessionService` — **never creates assignments** |

**Undo/redo:** client-only `ProgrammeBuilderHistory` — in-memory document snapshots, not persisted to Supabase.

**Dirty state:** `ProgrammeBuilderDocument.isDirty` / `lastSavedAt` — client session metadata separate from persisted `ProgrammeVersion` rows.

---

### 3.3 `ProgrammeAssignmentService` — **implemented (v0.1)**

**Sole production entry point** for athlete programme assignment lifecycle. Coach Studio and onboarding will call this same service.

**Implementation:** `ProgrammeAssignmentServiceImpl`  
**Wiring:** `ProgrammeAssignmentServices`  
**Result DTO:** `ProgrammeAssignmentOperationResult` / `ProgrammeAssignmentOperationStatus`

```dart
abstract class ProgrammeAssignmentService {
  Future<ProgrammeAssignment?> getCurrentAssignment({
    required String athleteId,
  });

  Future<ProgrammeAssignmentOperationResult> assignProgramme({
    required String athleteId,
    required String programmeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
    bool allowUnpublishedVersion = false,
  });

  Future<ProgrammeAssignmentOperationResult> assignByLineageVersion({...});

  Future<ProgrammeAssignmentOperationResult> pauseAssignment({
    required String assignmentId,
    String? reason,
  });

  Future<ProgrammeAssignmentOperationResult> resumeAssignment({
    required String assignmentId,
  });

  Future<ProgrammeAssignmentOperationResult> completeAssignment({
    required String assignmentId,
  });

  Future<ProgrammeAssignmentOperationResult> cancelOrReplaceActiveAssignment({
    required String athleteId,
    required String newProgrammeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool allowUnpublishedVersion = false,
  });
}
```

#### Boundary rules

| Layer | Responsibility |
|-------|----------------|
| `ProgrammeAssignmentService` | Create, replace, pause, resume, complete assignments |
| `TodaySessionService` | Resolve today's session from persisted assignment |
| `HomeTodaySessionLoader` | Display/resolve only — **never creates or repairs assignments** |
| `AthleteStateSyncService` | Projection writer only — runs after successful resolution |

Screens and coach features should call `getCurrentAssignment` on the service — not `ProgrammeAssignmentStore` directly.

#### Assign workflow (v0.1)

1. Validate programme version (reject missing, archived; reject unpublished unless `allowUnpublishedVersion`)
2. Resolve lineage code snapshot via `ProgrammeVersionStore.getLineageById`
3. Enforce one-active-assignment rule (`alreadyActiveConflict` when active exists and `replaceExistingActive = false`)
4. Resolve initial cursor via `ProgrammeScheduleResolver.resolveInitialCursor` — never hardcode week 1 / day_1 / slot 1
5. Insert `active` assignment with pinned `programmeVersionId`
6. Call `TodaySessionService.resolveForAthlete(athleteId)` — fresh post-insert resolution only
7. Call `AthleteStateSyncService.syncFromResolvedSession`
8. Return `assigned` or `partialSuccess` if projection sync fails (assignment remains valid)

**No outcome seeding on assign in v0.1.** `ProgrammeProgressionService` creates/upserts slot outcomes lazily when a session starts.

#### Replace workflow (v0.1)

- Old active assignment → `reassigned` (not `completed`)
- New assignment created through the same assign workflow
- After successful insert: `old.supersededByAssignmentId = new.id`
- Historical assignments and outcomes are preserved — never deleted

#### Pause / resume / complete

| Operation | Assignment | Outcomes | Projection |
|-----------|------------|----------|------------|
| Pause | `paused`, `pausedAt` set; cursor preserved | untouched | clear executable protocol; preserve programme context |
| Resume | `active`, `pausedAt` cleared | untouched | re-resolve + sync |
| Complete | `completed`, `completedAt` set | untouched | `clearProgrammeProjection` |

#### Diagnostics

```
[ProgrammeAssignment] operation=...
[ProgrammeAssignment] athlete=...
[ProgrammeAssignment] version=...
[ProgrammeAssignment] existingActive=...
[ProgrammeAssignment] cursor=...
[ProgrammeAssignment] result=...
[ProgrammeAssignment] projectionSynced=...
```

---

### 3.3.1 `ProgrammeAssignmentDevelopmentService` — **temporary dev tooling**

**Not part of the production interface.** Never used by Home, Coach Studio, onboarding, or athlete flows.

**Implementation:** `ProgrammeAssignmentDevelopmentServiceImpl`

```dart
abstract class ProgrammeAssignmentDevelopmentService {
  Future<ProgrammeAssignmentOperationResult> resetAssignment({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
    required int slotOrder,
    bool clearOutcomes = false,
  });
}
```

Resets cursor, optionally clears outcomes (with delete-count verification), re-resolves via `TodaySessionService`, and syncs `athlete_state`. DEBUG actions call this service — not direct store orchestration.

---

### 3.4 `ProgrammeScheduleResolver` — **implemented (v0.1)**

Pure, read-only resolution over assignment cursor + pinned template tree + slot outcomes. **No I/O, no mutation.**

**Implementation:** `ProgrammeScheduleResolverImpl`  
**Models:** `ProgrammeScheduleResolution`, `ProgrammeSuggestedCursor`  
**Errors:** `ProgrammeScheduleException` / `ProgrammeScheduleErrorCode`

```dart
abstract class ProgrammeScheduleResolver {
  ProgrammeScheduleResolution resolve({
    required ProgrammeAssignment assignment,
    required ProgrammeTemplateTree tree,
    required List<ProgrammeSlotOutcome> outcomes,
  });

  /// Initial cursor for new assignments — never assumes week 1 / day_1 / slot 1.
  ProgrammeSuggestedCursor resolveInitialCursor({
    required ProgrammeTemplateTree tree,
  });
}
```

#### Cursor-based v0.1 rules

| Input | Rule |
|-------|------|
| Week | `assignment.currentWeekNumber` must exist in loaded tree |
| Day | `assignment.currentDayKey` (`day_N` ordinal) must exist in that week |
| Slots | Ordered by `sessionOrder`; duplicate day keys or slot orders throw typed errors |
| Current slot | `in_progress` outcome takes priority; else first unresolved **required** slot |
| Optional slots | Surfaced in `optionalUnresolvedSlots` but never block day advancement |

#### Outcome status handling

| Category | Statuses |
|----------|----------|
| Resolved (advance past slot) | `completed`, `completed_partial`, `skipped`, `replaced` |
| Unresolved / current | `scheduled`, `in_progress`, `rescheduled` |
| Rescheduled | Remains current until replacement destination is explicitly complete |

#### Resolution kinds

| Kind | When |
|------|------|
| `executableSlot` | Required or optional slot with effective protocol |
| `restDay` | Day type `rest` or empty slot list — no protocol ID |
| `dayComplete` | All required slots on cursor day resolved; later day exists |
| `programmeComplete` | All required slots resolved and no later day/week exists |

#### Suggested next cursor

When a day is complete (or on rest day), resolver returns `ProgrammeSuggestedCursor` with the **next** week/day/slot — **without mutating** the assignment. Progression service (future) applies this after explicit advancement.

- Same week: next `day_key` by `day_order`
- Week rollover: first day of next week by `week_number`
- Programme end: `suggestedNextCursor = null`

#### Typed validation errors

Throws `ProgrammeScheduleException` for: empty programme structure, missing current week/day, duplicate day keys, duplicate slot order, slot/outcome outside loaded version tree, malformed assignment cursor.

---

### 3.5 `TodaySessionService` — **implemented (v0.1)**

**Implementation:** `TodaySessionServiceImpl`

```dart
abstract class TodaySessionService {
  Future<ResolvedTodaySession> resolveForAthlete(String athleteId);
}
```

**Resolution steps (v0.1):**
1. Load active assignment — if none → `ResolvedTodaySession.noActiveProgramme` (not an exception)
2. Load pinned `ProgrammeTemplateTree` for `programmeVersionId`
3. Load all `programme_slot_outcomes` for assignment
4. Delegate to `ProgrammeScheduleResolver.resolve`
5. Map to `ResolvedTodaySession` including effective protocol (`replacementProtocolId` when outcome is `replaced`, else planned `protocolId`)

Does **not** create `TrainingSession`. Does **not** advance assignment cursor. Does **not** write `athlete_state` directly (Home calls `AthleteStateSyncService` after resolve).

**Home (production v0.1):** `HomeTodaySessionLoader` resolves via `TodaySessionService.resolveForAthlete('lee')` on load. Programme-backed states take precedence over manual `athlete_state.current_protocol_id`. When resolution is `noActiveProgramme`, Home falls back to manual protocol selection. After resolve, Home syncs `athlete_state` as a projection only.

| Resolution kind | Home UI |
|-----------------|---------|
| `executable` | `TodaySessionCard` with programme week/day, slot title, required/optional label; Begin/Resume passes `ProgrammeExecutionContext` |
| `restDay` | Rest Day card — no Begin; optional **Continue to next programme day** (manual V0.1 progression) |
| `dayComplete` | Day Complete card — **Continue programme** applies `suggestedNextCursor` |
| `programmeComplete` | Programme Complete card — no session launch |
| `noActiveProgramme` | Manual `athlete_state.current_protocol_id` fallback (ad-hoc sessions preserved) |
| resolve error | Error card with Retry — never shows stale manual protocol |

Temporary DEBUG actions remain in a labelled **DEBUG** section and are not required for normal Home.

**Implementation:** `lib/features/home/services/home_today_session_loader.dart`, `lib/features/home/widgets/home_today_session_section.dart`

---

### 3.6 `ProgrammeSlotOutcomeService` — **implemented (v0.1)**

**Implementation:** `ProgrammeSlotOutcomeServiceImpl`

Bridges Execution Engine events to programme slot state. Slot outcomes remain separate from `training_sessions.status`.

```dart
abstract class ProgrammeSlotOutcomeService {
  Future<ProgrammeSlotOutcome> upsertFromResolution({
    required ResolvedTodaySession resolution,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    DateTime? resolvedAt,
  });
}
```

**Rules (v0.1):**
- Always persists `assignment_id`, `session_slot_id`, `week_number`, `day_key`, `session_order`
- Idempotent on `(assignment_id, session_slot_id)` via store upsert
- Preserves distinct statuses: `scheduled`, `in_progress`, `completed`, `completed_partial`, `skipped`, `replaced`, `rescheduled`
- Sets `resolved_at` on terminal outcomes unless explicitly provided

---

### 3.7 `ProgrammeProgressionService` — **implemented (v0.1)**

**Implementation:** `ProgrammeProgressionServiceImpl`  
**Result DTO:** `ProgrammeProgressionResult` / `ProgrammeProgressionStatus`  
**Execution bridge:** `ProgrammeSessionProgressionCoordinator`  
**Context DTO:** `ProgrammeExecutionContext`

```dart
abstract class ProgrammeProgressionService {
  Future<ProgrammeProgressionResult> markSessionStarted({...});
  Future<ProgrammeProgressionResult> completeSession({...});
  Future<ProgrammeProgressionResult> completeSessionPartial({...});
  Future<ProgrammeProgressionResult> skipSession({...});
  Future<ProgrammeProgressionResult> replaceSession({...});
  Future<ProgrammeProgressionResult> resolveAfterOutcome({...});
}
```

#### Progression order (v0.1)

```
1. Validate assignment + stale-resolution guard
2. Upsert programme_slot_outcome
3. Advance ProgrammeAssignment cursor (when terminal + rules allow)
4. Resolve next session via TodaySessionService
5. Sync athlete_state projection
```

**No single database transaction yet.** Steps run sequentially. Later-step failure returns `ProgrammeProgressionStatus.partialSuccess` with warnings — never silent partial success.

**Before beta:** wrap steps 2–4 in a Postgres RPC/transaction.

#### Cursor advancement rules

| Outcome | Advance cursor? |
|---------|-----------------|
| `in_progress` | No |
| `completed` / `completed_partial` / `skipped` | Yes — next required slot on same day, else next day/week via resolver `suggestedNextCursor` |
| `replaced` | Only when `trainingSessionId` provided (replacement session completed) |
| `rescheduled` | No — remains unresolved until destination completes |

Optional unresolved slots never block day advancement. Rest days update cursor but clear `current_protocol_id` from `athlete_state`. Programme complete sets assignment `status = completed` and `completed_at`.

#### Idempotency + stale protection

- Repeating the same terminal completion for the same `trainingSessionId` when `last_progressed_training_session_id` already matches → no double advance
- `ResolvedTodaySession` must match assignment cursor (`week`, `day_key`, `slot_order`) or returns `staleResolution`
- Outcome upsert failure prevents cursor update (throws `ProgrammeProgressionException`)

#### Partial failure statuses

| Status | Meaning |
|--------|---------|
| `completed` | Full workflow succeeded |
| `programmeComplete` | Assignment marked complete |
| `partialSuccess` | Outcome saved but assignment sync and/or `athlete_state` sync failed |
| `staleResolution` | Input resolution no longer matches assignment cursor |
| `noActiveProgramme` | No active assignment for athlete |

**Ended early:** `completed_partial` is terminal for the slot and follows the same required-slot advancement rules as `completed`.

---

### 3.8 `AthleteStateSyncService` — **implemented (v0.1)**

Denormalised projection — single writer for programme fields on `athlete_state`. **`ProgrammeAssignment` remains source of truth.**

**Implementation:** `AthleteStateSyncServiceImpl`

```dart
abstract class AthleteStateSyncService {
  Future<void> syncFromResolvedSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
  });

  Future<void> clearProgrammeProjection(String athleteId);
}
```

**v0.1 projection rules:**

| Resolution kind | `athlete_state` writes |
|-----------------|------------------------|
| `executable` | `current_programme_id` (lineage code), `current_week`, `current_day`, `current_protocol_id` (effective), `session_status` (outcome status) |
| `restDay`, `dayComplete`, `programmeComplete` | Preserve programme/week/day context; **clear** `current_protocol_id` and `session_status` |
| `paused` | Programme context + `session_status = paused`; clear protocol |
| `noActiveProgramme` | No automatic write (use `clearProgrammeProjection`) |

Sync is **idempotent** — skips upsert when projection unchanged.

**Never writes:** cursor values independent of assignment; assignment ID (not on `athlete_state` schema v1).

---

## 4. Resolved DTOs

### 4.1 `ProgrammeTemplate`

In-memory compiled tree for a `programme_version_id`:

```
ProgrammeVersion
  phases[] (optional)
  weeks[]
    days[]
      slots[]
```

Built by `ProgrammeVersionStore.loadTemplate`.

### 4.2 `ResolvedTodaySession`

| Kind | When |
|------|------|
| `noActiveProgramme` | No active assignment |
| `paused` | Assignment paused |
| `executable` | Current required/optional slot with effective protocol |
| `restDay` | Rest day at cursor |
| `dayComplete` | All required slots resolved; suggested next cursor returned |
| `programmeComplete` | No later day/week |

**Shared fields:** `assignmentId`, `programmeVersionId`, `lineageCode`, `programmeName`, `versionNumber`, `weekNumber`, `dayKey`, `dayTitle`, `dayType`, `dayIntent`, `slotId`, `slotOrder`, `slotTitle`, `plannedProtocolId`, `effectiveProtocolId`, `outcomeStatus`, `isOptional`, `isRestDay`, `programmeComplete`, `suggestedNextCursor`, `optionalUnresolvedSlotCount`.

---

## 5. Integration hooks

| Trigger | Service | Status |
|---------|---------|--------|
| Home load (production) | `TodaySessionService` → `AthleteStateSyncService` → `HomeTodaySessionSection` | **Live (v0.1)** |
| Home load (manual fallback) | `athlete_state.current_protocol_id` when no active assignment | **Live (v0.1)** |
| Home rest/day-complete continue | `HomeProgrammeContinuationService` (applies `suggestedNextCursor`) | **Live (v0.1)** |
| Session player open (programme-backed) | `ProgrammeProgressionService.markSessionStarted` + `ProgrammeExecutionContext` | **Live (v0.1)** |
| Session finish (normal) | `training_sessions.complete` → `ProgrammeProgressionService.completeSession` | **Live (v0.1)** |
| Session ended early | `training_sessions.complete` → `ProgrammeProgressionService.completeSessionPartial` | **Live (v0.1)** |
| Manual / preview session | No programme progression | Preserved |
| Coach assigns programme | `ProgrammeAssignmentService.assignProgramme` / `assignByLineageVersion` | **Live (v0.1)** — DEBUG only; Coach Studio pending |
| DEBUG assign test programme | `ProgrammeAssignmentService.assignByLineageVersion` (`allowUnpublishedVersion: true`) | **Live (v0.1)** |
| DEBUG reset assignment | `ProgrammeAssignmentDevelopmentService.resetAssignment` | **Live (v0.1)** — dev tooling only |
| Decision Engine substitution | `ProgrammeProgressionService.replaceSession` | Service live; DE hook pending |

**Coordinator:** `ProgrammeSessionProgressionCoordinator` in `lib/features/session/services/`. Called from `SessionPlayerScreen` after `training_sessions` completion. Requires optional `ProgrammeExecutionContext` — manual sessions omit it and preserve existing behaviour. Preview mode never passes programme context.

Execution Engine views (strength/interval/circuit) are **not** modified — integration is at the shared `SessionPlayerScreen` completion boundary only.

---

## 6. File organisation

```
lib/
  models/
    programme_lineage.dart
    programme_version.dart
    programme_version_phase.dart
    programme_version_week.dart
    programme_version_day.dart
    programme_version_session_slot.dart
    programme_slot_outcome.dart
    programme_assignment.dart          ← updated (UUID)
    programme_vocabulary.dart          ← + ProgrammeSlotOutcomeStatus
  data/repositories/
    programme_version_store.dart
    programme_version_supabase_store.dart
    programme_assignment_store.dart
    programme_assignment_supabase_store.dart
    programme_slot_outcome_store.dart
    programme_slot_outcome_supabase_store.dart
    athlete_state_store.dart
    athlete_state_supabase_store.dart
    programme_template_tree_assembler.dart
    programme_store_exception.dart
  core/constants/
    programme_dev_identity.dart
  features/home/
    models/home_today_session_state.dart
    services/home_today_session_loader.dart
    services/home_today_session_services.dart
    services/home_programme_continuation_service.dart
    widgets/home_today_session_section.dart
  features/programme/
    models/
      programme_template.dart
      programme_catalog_entry.dart
      programme_schedule_resolution.dart
      programme_suggested_cursor.dart
      programme_execution_context.dart
      programme_progression_result.dart
      resolved_today_session.dart
    errors/
      programme_schedule_exception.dart
      programme_progression_exception.dart
    debug/
      programme_debug_actions.dart
      programme_debug_resolution_cache.dart
      programme_dev_fixtures.dart
    services/
      programme_catalog_service.dart
      programme_publishing_service.dart
      programme_assignment_service.dart
      programme_assignment_service_impl.dart
      programme_assignment_services.dart
      programme_assignment_development_service.dart
      programme_assignment_development_service_impl.dart
      programme_assignment_operation_result.dart
      programme_schedule_resolver.dart
      programme_schedule_resolver_impl.dart
      today_session_service.dart
      today_session_service_impl.dart
      programme_slot_outcome_service.dart
      programme_slot_outcome_service_impl.dart
      programme_progression_service.dart
      programme_progression_service_impl.dart
      athlete_state_sync_service.dart
      athlete_state_sync_service_impl.dart
  features/session/services/
    programme_session_progression_coordinator.dart
```

---

## 7. V1 implementation order

| Step | Status |
|------|--------|
| 1. Schema migration | Done — `20260715120000_add_programme_engine_v1.sql` |
| 2. Dev RLS policies | Done — `20260715130000_add_programme_engine_dev_policies.sql` |
| 3. Supabase stores | Done — see §2 |
| 4. Seed fixture | Done — `supabase/seed/cohort_foundation_test_programme.sql` |
| 5. Store tests | Done — `test/programme_stores_test.dart` |
| 6. `ProgrammeScheduleResolver` | Done — `programme_schedule_resolver_impl.dart` |
| 7. `ProgrammeAssignmentService` | Done — v0.1; no outcome seeding on assign |
| 8. `TodaySessionService` | Done — `today_session_service_impl.dart` |
| 9. `AthleteStateSyncService` | Done — `athlete_state_sync_service_impl.dart` |
| 10. `ProgrammeSlotOutcomeService` + `ProgrammeProgressionService` | Done — v0.1 |
| 11. Session completion integration | Done — `ProgrammeSessionProgressionCoordinator` |
| 12. Home refactor | Done — `HomeTodaySessionSection` resolves from `TodaySessionService`; manual protocol is fallback only |
| 13. Legacy data migration | Pending |
| 14. Programme Builder scaffold | Done — models + contracts; see `44_Programme_Builder.md` |
| 15. Coach Studio UI | Done — Programme Catalogue v0.1; see `45_Coach_Studio_Programme_Catalogue.md` |
| 16. Programme Editor UI | Pending |

---

## 8. Development RLS strategy

**Migration:** `supabase/migrations/20260715130000_add_programme_engine_dev_policies.sql`

**Auth state at implementation:** Flutter has **no Supabase Auth session**. The app uses the anon key with hardcoded development athlete `lee` (`ProgrammeDevIdentity.athleteId`).

| Policy group | What it allows | Why it exists |
|--------------|----------------|---------------|
| `dev_programme_versions_select_catalogue` | Read published Cohort Global (`approved_for_global`) + unpublished global drafts | Catalogue preview and seed fixture reads |
| `dev_programme_versions_insert/update_draft_global` | Write draft global templates only | Coach Studio development authoring |
| Template structure read/write | Follow parent version visibility | Tree load/save for allowed versions |
| `dev_programme_assignments_*` | Read/write assignments for `lee` only | Single-user athlete development |
| `dev_programme_slot_outcomes_*` | Read/write outcomes via assignment scope | Slot resolution dev testing |

**Explicitly denied (no policy):** coach-private programmes, organisation programmes, published version mutation, assignments for athletes other than `lee`.

### Before external beta (required)

1. Drop all `dev_programme_*` policies and `cohort_programme_dev_*` helper functions
2. Add `auth.uid()` ownership policies for coach/org libraries
3. Remove anon write access entirely
4. Scope assignments to authenticated athlete identity or coach-athlete relationship
5. Remove hardcoded `ProgrammeDevIdentity` coupling from RLS helpers

---

## 9. Seed fixture

**File:** `supabase/seed/cohort_foundation_test_programme.sql`

| Field | Value |
|-------|-------|
| Lineage code | `COHORT-FOUNDATION-TEST` |
| Version | 1 (draft, Cohort Global) |
| Week 1 | `day_1` BW-001 strength, `day_2` RN-006 intervals, `day_3` rest, `day_4` FG-009 circuit |

Idempotent via fixed UUIDs and `ON CONFLICT DO NOTHING`. **Not wired to Home.**

Apply manually after migrations:

```bash
psql <connection> -f supabase/seed/cohort_foundation_test_programme.sql
```

---

## 10. Known limitations

| Limitation | Notes |
|------------|-------|
| Assignment/progression services pending | Resolver + Today + Sync only — no auto cursor advancement |
| Home production path | Resolves from `TodaySessionService`; manual `athlete_state` is fallback when no active assignment; DEBUG section retained temporarily |
| Dev RLS is temporary | Anon write access limited but still broader than production |
| `saveTemplateTree` replaces structure | Deletes and re-inserts weeks/days/slots for a draft version |
| No legacy data migration | `programmes` / `programme_sessions` tables still used by legacy repository |
| `athlete_state` RLS unchanged | Athlete state table uses existing project policies |
| Seed is unpublished draft | Must be published before athlete assignment in production flow |

---

## Related documents

| Document | Scope |
|----------|-------|
| `41_Programme_Engine.md` | Architecture |
| `42_Programme_Engine_Schema.md` | Tables and indexes |
| `44_Programme_Builder.md` | Coach Studio authoring, validation, preview, clone/duplicate |
