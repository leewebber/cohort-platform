# 43 — Programme Engine Service Contracts

**Status:** Canonical service design (v0.1) — stores implemented  
**Related:** `41_Programme_Engine.md`, `42_Programme_Engine_Schema.md`  
**Stores:** Supabase implementations in `lib/data/repositories/*_supabase_store.dart`

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

Persistence boundaries for test doubles. **Supabase implementations** are live; business services remain future work.

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
  Future<ProgrammeVersion?> getVersionById(String versionId);
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

---

### 3.3 `ProgrammeAssignmentService`

Athlete enrolment and lifecycle.

```dart
abstract class ProgrammeAssignmentService {
  Future<ProgrammeAssignment> assignAthlete({
    required String athleteId,
    required String publishedVersionId,
    required DateTime startedAt,
    String? timezone,
  });

  Future<ProgrammeAssignment> pauseAssignment(String assignmentId);
  Future<ProgrammeAssignment> resumeAssignment(String assignmentId);
  Future<ProgrammeAssignment> completeAssignment(String assignmentId);

  /// Marks old assignment reassigned; creates new active assignment.
  Future<ProgrammeAssignment> reassignAthlete({
    required String athleteId,
    required String newPublishedVersionId,
    required DateTime startedAt,
    String? timezone,
  });
}
```

**Assign side effects:**
1. Supersede existing active assignment if present (`reassigned`)
2. Insert new `active` assignment at week 1 / `day_1` / session order 1
3. Seed `programme_slot_outcomes` as `scheduled` for visible horizon (current day minimum; full week optional v1)
4. Call `AthleteStateSyncService.syncFromAssignment`

---

### 3.4 `ProgrammeScheduleResolver`

Pure resolution over template + assignment cursor. No I/O beyond store reads.

```dart
abstract class ProgrammeScheduleResolver {
  Future<ProgrammeTemplate> loadTemplateForAssignment(
    ProgrammeAssignment assignment,
  );

  ProgrammeVersionDay? dayForCursor({
    required ProgrammeTemplate template,
    required int weekNumber,
    required String dayKey,
  });

  List<ProgrammeVersionSessionSlot> slotsForDay({
    required ProgrammeTemplate template,
    required int weekNumber,
    required String dayKey,
  });

  ProgrammeVersionSessionSlot? slotForCursor({
    required ProgrammeTemplate template,
    required ProgrammeAssignment assignment,
  });

  /// Display-only — not persisted.
  String? weekdayLabelForCursor({
    required ProgrammeAssignment assignment,
    required ProgrammeVersionDay day,
  });

  ProgrammeVersionDay? nextDay({
    required ProgrammeTemplate template,
    required int weekNumber,
    required String dayKey,
  });
}
```

---

### 3.5 `TodaySessionService`

Primary Home entry point. Combines assignment, template, slot outcomes, and execution state.

```dart
abstract class TodaySessionService {
  Future<ResolvedTodaySession> resolveForAthlete(String athleteId);
}
```

**Resolution steps:**
1. Load active assignment (not paused) — else `ResolvedTodaySession.noAssignment`
2. Load template for pinned version
3. Resolve day from cursor — if `rest` → `ResolvedTodaySession.restDay`
4. Load slot outcomes for day; select cursor slot
5. Load `training_sessions` for athlete + effective `protocol_id`
6. Map execution status to display state (Begin / Resume / Completed)
7. Return `ResolvedTodaySession` with programme context labels

Does **not** advance cursor. Does **not** write `athlete_state` (caller or sync service handles that).

---

### 3.6 `ProgrammeSlotOutcomeService`

Bridges Execution Engine events to programme slot state.

```dart
abstract class ProgrammeSlotOutcomeService {
  Future<ProgrammeSlotOutcome> markScheduled({
    required String assignmentId,
    required ProgrammeVersionSessionSlot slot,
    required int weekNumber,
    required String dayKey,
  });

  Future<ProgrammeSlotOutcome> markInProgress({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  Future<ProgrammeSlotOutcome> markCompleted({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  /// Session ended_early — does not advance day.
  Future<ProgrammeSlotOutcome> markCompletedPartial({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  Future<ProgrammeSlotOutcome> markSkipped({
    required String assignmentId,
    required String sessionSlotId,
  });

  Future<ProgrammeSlotOutcome> markReplaced({
    required String assignmentId,
    required String sessionSlotId,
    required String resolvedProtocolId,
    int? trainingSessionId,
  });
}
```

---

### 3.7 `ProgrammeProgressionService`

Advances assignment cursor after slot/day resolution.

```dart
abstract class ProgrammeProgressionService {
  /// Called after session review or explicit coach action.
  Future<ProgrammeAssignment> progressAfterSlotResolved({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  /// Returns true when all required slots have terminal outcomes.
  bool isDayComplete({
    required List<ProgrammeVersionSessionSlot> slots,
    required List<ProgrammeSlotOutcome> outcomes,
  });

  /// Manual cursor move — coach tooling (future).
  Future<ProgrammeAssignment> moveCursorTo({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
    int sessionOrder = 1,
  });
}
```

**`progressAfterSlotResolved` rules:**
1. Idempotency: skip if `trainingSessionId == assignment.lastProgressedTrainingSessionId`
2. Record outcome via `ProgrammeSlotOutcomeService` if not already terminal
3. If day incomplete → update `current_session_order` to next unresolved required slot only
4. If day complete → advance day/week per `ProgrammeScheduleResolver.nextDay`
5. If programme complete → `status = completed`
6. Update `lastProgressedTrainingSessionId`
7. Call `AthleteStateSyncService.syncFromAssignment`

**Ended early:** `completed_partial` counts as terminal for the slot but does not by itself complete the day unless all other required slots are also terminal.

---

### 3.8 `AthleteStateSyncService`

Denormalised projection — single writer for programme fields on `athlete_state`.

```dart
abstract class AthleteStateSyncService {
  Future<void> syncFromAssignment({
    required ProgrammeAssignment assignment,
    String? resolvedProtocolId,
    String? sessionStatus,
  });

  Future<void> clearProgrammeProjection(String athleteId);
}
```

**Writes:** `current_programme_id`, `current_week`, `current_day`, `current_protocol_id`, `session_status`.

**Never writes:** independent cursor values not derived from assignment.

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

| Variant | When |
|---------|------|
| `planned` | Required slot; no in-progress session today |
| `inProgress` | Matching `training_sessions.status = in_progress` |
| `completed` | Slot outcome terminal + session completed |
| `completedPartial` | Slot `completed_partial`; day may remain open |
| `restDay` | Day type rest |
| `paused` | Assignment paused |
| `noAssignment` | No active assignment |

**Shared fields:** `assignment`, `lineageCode`, `versionNumber`, `weekNumber`, `dayKey`, `weekdayLabel`, `slot`, `effectiveProtocolId`, `slotOutcome`, `trainingSessionId`.

---

## 5. Integration hooks (future, not implemented)

| Trigger | Service |
|---------|---------|
| Home load | `TodaySessionService.resolveForAthlete` |
| Session player open | `ProgrammeSlotOutcomeService.markInProgress` |
| Session finish (normal) | `ProgrammeSlotOutcomeService.markCompleted` → `ProgrammeProgressionService.progressAfterSlotResolved` |
| Session ended early | `ProgrammeSlotOutcomeService.markCompletedPartial` (no progression) |
| Session review dismiss / Home return | `ProgrammeProgressionService.progressAfterSlotResolved` (if completed) |
| Coach assigns programme | `ProgrammeAssignmentService.assignAthlete` |
| Decision Engine substitution | `ProgrammeSlotOutcomeService.markReplaced` |

Execution Engine files are **not** modified in this milestone. Hooks are documented for the wiring milestone.

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
  features/programme/
    models/
      programme_template.dart
      programme_catalog_entry.dart
      resolved_today_session.dart
    services/
      programme_catalog_service.dart
      programme_publishing_service.dart
      programme_assignment_service.dart
      programme_schedule_resolver.dart
      today_session_service.dart
      programme_slot_outcome_service.dart
      programme_progression_service.dart
      athlete_state_sync_service.dart
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
| 6. `ProgrammeScheduleResolver` | Pending |
| 7. `ProgrammeAssignmentService` + outcome seeding | Pending |
| 8. `TodaySessionService` | Pending |
| 9. `AthleteStateSyncService` | Pending |
| 10. Home refactor | Pending |
| 11. Progression hooks from session review | Pending |
| 12. Legacy data migration | Pending |
| 13. Coach Studio UI | Pending |

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
| No business services yet | Stores only — no `TodaySessionService`, progression, or publishing logic |
| Home unchanged | Still reads legacy `athlete_state` manual cursor |
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
