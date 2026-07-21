# M9.5 — Coach Studio Governance UI

**Status:** Implemented  
**Depends on:** M9.2 Session Revision Usage, M9.3 Action Policies, M9.4 Exercise Usage

---

## Purpose

Expose M9 relationship and policy services in Coach Studio so coaches can see:

- **Session Revisions:** identity, lifecycle, allowed actions (with reasons), and where a revision is used
- **Exercises:** read-only downstream usage (no exercise action policies in this phase)

**Architectural principle:** widgets render decisions; they do not invent them.

| Service | Question |
|---------|----------|
| `SessionRevisionRelationshipService` | What uses this Session Revision? |
| `SessionRevisionActionPolicyService` | What may I do with this Session Revision? |
| `ExerciseRelationshipService` | What uses this Exercise? |

---

## Screens changed

| Screen | Change |
|--------|--------|
| `LibrarySessionBuilderScreen` | Governance section when editing an existing Session (`isEdit` + non-empty `protocolId`) |
| `ExerciseDetailScreen` | Read-only Exercise “Used by” panel |

No Coach Studio landing redesign. No embedded programme Session Builder governance in this phase (library edit path is the primary Session Revision surface).

---

## Service consumption boundaries

Production wiring lives in `CoachStudioGovernanceServices`:

- `createActionPolicyService()`
- `createRelationshipService()`
- `createRevisionService()`
- `createExerciseRelationshipService()`
- `createSessionGovernanceController()`

Widgets and controllers **call services only**. They do not:

- Re-evaluate lifecycle rules locally
- Query Supabase for usage edges directly
- Call delete/archive repositories from UI code (execution goes through `SessionRevisionService`)

Optional constructor injection on screens supports widget tests (`governanceController`, `revisionService`, `exerciseRelationshipService`).

---

## Components added

| Component | Role |
|-----------|------|
| `SessionGovernanceController` | Loads identity, `evaluateAll()`, and `tryGetUsageForRevision()` |
| `SessionGovernanceSection` | Composes identity + actions + usage; executes permitted actions |
| `SessionRevisionIdentityHeader` | Session name, “Session Revision”, revision number, lifecycle badge |
| `SessionRevisionActionPanel` | Renders all five policy decisions |
| `SessionRevisionUsagePanel` | “Used by” counts, classifications, programme links |
| `ExerciseUsagePanel` | Exercise usage summary and session revision links |
| `GovernanceStatusBadge` | Draft / Published / Archived badge |
| `GovernanceCountRow` | Bullet count row |
| `GovernanceCopy` | Coach-facing labels and formatters |

---

## Session Revision identity UX

Compact header example:

```
Strength Foundation
Session Revision · Revision 3 · Published   [Published]
```

Coach-facing terms only — no `protocol_id`, lineage UUID, or raw lifecycle enum strings.

---

## Action rendering rules

Driven by `SessionRevisionActionPolicyService.evaluateAll(protocolId)`:

| Policy outcome | UI treatment |
|----------------|--------------|
| Allowed | Enabled action button |
| Allowed + warning | Enabled button with warning styling; confirm using `userMessage` where needed |
| Blocked | Disabled button; `userMessage` inline; tooltip repeats message + alternative |
| Recommended alternative | Shown below blocked/warning copy (e.g. “Create draft revision 4 instead.”) |

Actions: Edit, Create new revision, Publish, Archive, Delete.

When Edit is blocked, the Session Builder body is read-only (`AbsorbPointer`) and Save is disabled.

---

## Action execution

| Action | Behaviour |
|--------|-----------|
| Edit | Draft: builder editable. Published/archived: blocked in place |
| Create new revision | `SessionRevisionService.createNewSessionRevision()` → reload draft → SnackBar with prior revision note |
| Publish | M6 validation → `SessionRevisionService.publishRevision()` → refresh policy |
| Archive | Confirm with policy message → `archiveRevision()` → refresh (usage preserved) |
| Delete | Confirm only when policy allows → `deleteRevision()` → pop to Session Library |

Never calls `SessionRevisionDeleteStore` from widgets.

---

## Session “Used by” panel

Driven by `SessionRevisionRelationshipService.tryGetUsageForRevision()`.

Shows aggregate counts:

- Programme Versions
- Programme slots (distinct from version count)
- Active Assignments
- Historical Performances

Classifications when present: Authored usage, Active operational usage, Historical usage.

Up to three programme reference links (`Programme Name · Programme Version N`) with optional navigation to `ProgrammeEditorScreen`. “View all” opens a bottom sheet.

---

## Exercise “Used by” panel

Driven by `ExerciseRelationshipService.tryGetUsageForExercise()`.

Shows session revision, lineage, programme, assignment, and historical counts plus block-link summary. Lists Session Revisions with optional navigation to `LibrarySessionBuilderScreen` (edit mode).

Existing Exercise edit/delete actions unchanged.

---

## Privacy constraints

Coach-facing UI shows **aggregate counts** and programme/session names only.

Never shown:

- Athlete names or IDs
- Assignment IDs
- Individual performance details

---

## Loading / error / empty states

| State | Session usage | Exercise usage |
|-------|---------------|----------------|
| Loading | `CircularProgressIndicator` in governance section | Spinner in panel |
| Unused | Fixed unused copy | Fixed unused copy |
| Historical-only | Archive-safe explanation | N/A (counts still shown) |
| Lookup failure | “Usage information could not be loaded. Destructive actions remain unavailable.” | Lookup failure message |
| Revision not found | Existing not-found copy | Exercise not found copy |

Archived revisions still display programme references.

---

## Navigation behaviour

- Programme Version link → `ProgrammeEditorScreen(versionId:)`
- Session Revision link (from Exercise panel) → `LibrarySessionBuilderScreen` with loaded draft

---

## Test coverage

`test/coach_studio/session_governance_widget_test.dart` — **43 tests** covering:

- Session identity (4)
- Session actions (14)
- Session execution (6)
- Session usage (9)
- Exercise usage (10)

Regression: M9.1–M9.4 service tests, Coach Studio, Programme Builder, M8, Founder Acceptance unchanged failure baseline.

**Targeted:** 43/43 passed  
**Full suite:** 649 passed, 20 failed (baseline unchanged)

---

## Known limitations

- No governance on embedded programme Session Builder
- No Exercise action policies
- No full revision history screen or diffing
- “View all” uses a simple bottom sheet, not a graph
- Programme navigation opens editor; no deep-link to specific slot

---

## Recommended next phase

**M9.6 — Exercise Action Policies** mirroring M9.3, plus optional embedded Session Builder governance and programme-slot deep links from usage panels.

---

## Key files

```
lib/features/coach_studio/governance/
  controllers/session_governance_controller.dart
  services/coach_studio_governance_services.dart
  widgets/session_governance_section.dart
  widgets/session_revision_identity_header.dart
  widgets/session_revision_action_panel.dart
  widgets/session_revision_usage_panel.dart
  widgets/exercise_usage_panel.dart
  governance_copy.dart

lib/features/training_library/screens/library_session_builder_screen.dart
lib/features/exercises/exercise_detail/exercise_detail_screen.dart

test/coach_studio/session_governance_widget_test.dart
```
