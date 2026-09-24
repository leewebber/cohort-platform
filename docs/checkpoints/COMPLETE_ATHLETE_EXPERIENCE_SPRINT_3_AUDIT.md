# Complete Athlete Experience Sprint 3 — audit

**Recorded:** 2026-09-24
**Live pointer:** Founder decisions bound 2026-09-24.
Sprint 3 is **approved, not started, not implemented.**
**Base / start SHA:** `origin/main` `840542170137c4e75ffe663bbc08d7b98be3faac`
**Branch:** `docs/complete-athlete-experience-sprint-3-audit` (local only)

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=APPROVED_NOT_STARTED
NEXT_IMPLEMENTATION_AUTHORISED=false
HOSTED_WRITES=false
PUSHED=false
IMPLEMENTATION_STARTED=false
```

Binding:
[`../architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_3_v1.md).
Parent:
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md).

Sprint 1 remains complete at `a3cd351`. Sprint 2 remains complete at
`8405421`. This audit does not reopen either.

Preview routes and test fixtures are **not** production evidence.
Citations below are `lib/`, `supabase/migrations/`, and production
entry `lib/main.dart` → `AuthGate` → `AthleteAppShell`.

---

## 1. Purpose

Determine the exact architecture and bounded implementation slice that
closes:

A. Programme-complete Home
B. Progress errors appearing as empty data
C. History identity fallback `athlete.local`
D. Home / Progress / History agreement after programme completion

Production tracing shows A–D share one read model: **active-only
assignment + fallback athlete id**. They are not four separate fixes.

---

## 2. Preflight (this task)

| Check | Result |
|-------|--------|
| `origin/main` | `840542170137c4e75ffe663bbc08d7b98be3faac` |
| Local HEAD before branch | same |
| Worktree | clean |
| Sprint 1 ancestor `a3cd351` | yes |
| Sprint 2 handoff ancestor `24159f1` | yes |
| Divergence vs `origin/main` | 0 / 0 |
| `.env` SHA-256 | `869a01b1e4ee6b0559face678843f0df9ce57cbaf30febadb90f796c2a161816` |

---

## 3. Production route (files)

### 3.1 Authenticated identity

| Step | File | Fact |
|------|------|------|
| Entry | `lib/main.dart` | `CohortPlatformApp` → `AuthGate` |
| Phase | `lib/features/auth/services/production_auth_authority.dart` | Session + verified profile → athlete or founder shell |
| Shell pick | `lib/core/access/app_experience_resolver.dart` | Founder email → `FounderWorkspaceShell`; **else athlete**. No coach role. |
| Session | `lib/features/auth/services/current_user_session.dart` | `athleteId => userId` |
| Strict helper (unused by shell tabs) | `lib/core/services/authenticated_identity.dart` | `requireAthleteId()` requires session **and** `isAthlete` |
| Profile cache | `lib/features/athlete_profile/services/athlete_profile_session.dart` | In-memory; not Home/Progress assignment authority |
| Sign-out | `lib/features/auth/controllers/auth_controller.dart` | Clears session, caches, restore envelope, local persistence |

### 3.2 Shell identity fallback (production-reachable code)

| File | Line behaviour |
|------|----------------|
| `lib/features/app_shell/athlete_app_shell.dart` | `_athleteId` → profile ?? session ?? `'athlete.local'` |
| `lib/features/home/home_screen.dart` | same |
| `lib/features/progress/screens/progress_screen.dart` | same |
| `lib/features/app_shell/screens/athlete_profile_screen.dart` | same; **displays** that id; pushes History with it |
| `lib/features/app_shell/founder_workspace_shell.dart` | same (not athlete production) |
| `lib/features/workout_player/controllers/workout_player_controller.dart` | profile ?? `'athlete.local'` — **not** Daily Journey production (`ProgrammeSessionExecutionLauncher` → `ActiveSessionScreen`) |
| `lib/features/athlete_profile/onboarding/athlete_onboarding_flow.dart` | mints `athlete.local.{epoch}` — onboarding draft id, not History authority |

Tests seed `'athlete.local'` as a **fixture athlete id** (Calendar,
Home authority, Progress builder). That is not a production user.

### 3.3 Home / current programme

| Step | File | Fact |
|------|------|------|
| Active row | `lib/data/repositories/programme_assignment_supabase_store.dart` | `status = 'active'` only |
| Runtime | `lib/features/home/services/athlete_home_runtime_authority.dart` | `programme \| none \| loading \| unavailable` — **no completed** |
| Home UI | `lib/features/home/home_screen.dart` | `none` → `ChoosePlanEntryCard`; completed today only while assignment still active and occurrence `completed` |
| Calendar RPC | `resolve_active_fixed_programme_calendar` in `20260824120000_apollo_calendar_driven_schedule_slice_1.sql` | `status = 'active'` else `no_active_assignment` |
| Calendar UI | `lib/features/programme/screens/athlete_calendar_screen.dart` | null → “No programme scheduled” / Choose Programmes |
| Programmes | `lib/features/programme/controllers/athlete_programme_controllers.dart` | `getActiveAssignment`; `canEnrol = !hasActiveAssignment` |
| Continuity | `lib/features/programme/domain/athlete_programme_continuity.dart` | `completed` if assignment.status is completed — **unfed** after complete |
| Completed UI (dead after complete) | `lib/features/programme/widgets/athlete_programme_status_state.dart` | “This programme is complete.” |

`listForAthlete` already returns completed rows. Home/Calendar do not
use it.

### 3.4 Completion write

| Step | File | Fact |
|------|------|------|
| Client | `lib/features/programme/services/athlete_programme_completion_service.dart` | Existing RPC; `terminalProgramme` if RPC flag or assignment status completed |
| RPC | `supabase/migrations/20260801160000_complete_programme_session_and_advance.sql` | No next week → `status = 'completed'`, `completed_at`, `terminal_programme` true |
| Outcomes | `programme_slot_outcomes` | Occurrence-level complete; not programme-complete alone |
| Local draft | completion service `clearGeneratedSession` | Best-effort; must not affect server commit |
| Boot draft | `lib/features/session/services/workout_progress_snapshot_policy.dart` | `completedHosted` / foreign athlete → clear |

Programme completion is **assignment-level persisted**. Occurrence
completion is separate. Client derivation is allowed only from that
row.

### 3.5 Progress

| Step | File | Fact |
|------|------|------|
| Tab | `ProgressScreen` in shell | Rebuilds on tab select (`_progressEpoch`) |
| Build | `lib/features/progress/services/athlete_progress_summary_builder.dart` | Active assignment only; miss → `emptySummary()`; tree fail → placeholder 0 sessions; history fail → `[]` |
| UI catch | `progress_screen.dart` `_bootstrap` | `catch (_) { emptySummary(); }` |
| Name | `fromProgrammeSummary` | `planName: assignment.lineageCode` |
| Merge | `_mergeEvidence` | `hasActivePlan` becomes true if any completed records exist |
| Radar | `CapabilityRadarProjectionService` | Empty scaffold while loading |

### 3.6 History

| Step | File | Fact |
|------|------|------|
| Entry | Profile → `TrainingHistoryScreen` | Identity from Profile fallback |
| Load | `PerformanceRecordSaveCoordinator.listHistory` → `SupabasePerformanceRecordStore.listHistory` | `training_session_records` where `athlete_id` and not in_progress |
| UI | `lib/features/performance/screens/training_history_screen.dart` | Loading / error / empty / list. Pull-to-refresh. Uses `AthleteSafeErrorPresenter`. |

History is **athlete-scoped**, not current-assignment-scoped. After a
later enrol, prior records remain if the athlete id is unchanged.

---

## 4. How the four blockers interact

```text
Final session RPC
  → assignment.status = completed
  → getActiveAssignment() = null
  → Home none (Choose Plan)
  → Calendar no_active_assignment
  → Programmes canEnrol true (correct for mutation, wrong for “current”)
  → Progress emptySummary + maybe history
  → History OK only if athleteId is the real user
```

If Progress or History then fail, the athlete sees **first-run empty**
on those tabs while Home also looks unenrolled. That is the launch
lie.

If identity falls back to `athlete.local`, History/Progress query a
key that is not `auth.uid()`. Hosted RLS returns no rows for that
string. The UI looks empty even when the signed-in athlete has
results.

---

## 5. Readiness scoreboard (production)

Score vocabulary matches the parent plan.

| Area | Score | Why |
|------|-------|-----|
| Programme completion write | Strong foundation | Existing RPC + tests; product journey missing |
| Programme-complete Home | Missing | Active-only runtime → Choose Plan |
| Calendar after complete | Functional but incomplete | Honest empty only when never assigned; after complete it is the wrong empty |
| Programmes after complete | Functional but incomplete | Continuity completed exists; loader drops the row |
| Progress destination | Functional but incomplete | Evidence builder exists; **error-as-empty is unsafe if believed** |
| History list UI | Strong foundation | Typed error + empty + refresh |
| History identity | Functional but incomplete | Production fallback `'athlete.local'` |
| Cross-surface agreement after complete | Missing | Surfaces disagree by construction |
| Coach-only athlete-shell entry | Functional but incomplete | Launch-integrity already bound; resolver sends non-founder to athlete shell |

---

## 6. State-agreement matrix (summary)

Full matrix:
[`../architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_3_v1.md)
§7.

**Today (wrong):** completed → Home/Calendar/Programmes behave as
no-programme; Progress may show empty or orphan evidence; History
depends on fallback.

**Required:** completed → Home complete + Calendar inspect +
Programmes completed + Progress/History keep evidence; enrol still
allowed because completed is not active; failures stay typed.

---

## 7. Proposed Sprint 3 boundary

**Name:** Programme Completion and History Integrity

Required: current-assignment projection; programme-complete Home;
completed Calendar inspect via existing
`resolve_fixed_programme_calendar(assignment_id)`; Progress
error-versus-empty + last-good-data; remove production
`athlete.local`; History fail-closed identity; coach-only fail-closed
on athlete History/Progress; agreement tests.

**Sprint 3 can close Complete Athlete Experience.** Sprint 4 is not
required for this milestone.

The live approved boundary is architecture §8–§9.2. This section
remains the audit proposal.

---

## 8. Historical founder questions (audit)

See architecture §9.1. Only three product choices needed founder
input at audit time:

1. Home complete primary CTA ranking (recommend View results).
2. Whether Home invites immediate enrol (recommend allow, do not force).
3. Celebration tone (recommend factual title, no claims).

### 8.1 Resolved founder decisions (2026-09-24)

Live answers are in
[`../architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_3_v1.md)
§9.2. Summary:

| Decision | Binding |
|----------|---------|
| Architecture | **Approved** (`APPROVED_NOT_STARTED`) |
| Name | Programme Completion and History Integrity |
| Implementation | Approved, **not started** |
| Home | “You finished {authored title}.” Primary View results. Secondary Browse programmes. No unsupported claims |
| Next programme | Completed is not active. Existing no-active enrol allowed. No force, auto-enrol, recommend, repin, urgency, or hiding results |
| Continuity | Completed assignment is historical context until a later active assignment. Surfaces agree. Later enrol creates a new row |
| Identity / errors | Architectural requirements as listed in architecture §9.2 |

---

## 9. Explicit non-actions (this task)

Did not implement Sprint 3. Did not change Dart, SQL, fixtures,
preview, native, hosted, or phone. Did not push. Did not contact Field
Manual. Did not mutate `.env`.
