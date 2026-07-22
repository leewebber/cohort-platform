# 68 — V2.0 Personal Training Setup

Enables dual-role users (coach + athlete) to assign published programmes to themselves for personal training — without a coach–athlete relationship, debug actions, or duplicated assignment logic.

## User problem

The production assignment workflow assumes:

```
coach → active coach–athlete relationship → athlete assignment
```

Self-invitation is correctly prohibited (`coach_id <> athlete_id`), so dual-role users like Lee cannot use the roster assignment path for personal training. Debug assignment actions existed but are not a production personal-use path.

## Phase 0 findings

| Layer | Self-assignment state before Sprint 5 |
|-------|--------------------------------------|
| **Database** | Athlete-scoped INSERT allowed any authenticated user where `athlete_id = auth.uid()` via `cohort_programme_dev_athlete_ids()` |
| **Coach path** | Requires active relationship (`cohort_coach_has_active_athlete`) — blocks self (no self-relationship) |
| **Service** | `ProgrammeAssignmentServiceImpl` has no caller auth; `CoachAthleteService.assignProgrammeToAthlete` requires roster link |
| **UI** | Home empty state assumed coach assignment; no self-setup flow |

**Conclusion:** Assignment domain logic existed; production UI and explicit dual-role authorization were missing. DB allowed athlete-only self-insert (too broad).

## Self-assignment authorization

Allowed only when:

- Authenticated user has **both** `is_coach` and `is_athlete`
- `athlete_id` resolved from `CurrentUserSession.athleteId` (= `auth.uid()`)
- Selected programme version appears in coach-accessible published catalogue
- Normal assignment lifecycle rules pass (published version, replacement, one active assignment)

Not allowed:

- Athlete-only users assigning coach programmes
- Coach-only users without athlete role
- Arbitrary athlete IDs from UI input
- Coach–athlete relationship creation

## Distinction from coach–athlete assignment

| Path | Authorization | UI |
|------|---------------|-----|
| Coach → linked athlete | `CoachAthleteService` + relationship check | Athlete roster detail |
| Dual-role self-assign | `PersonalTrainingSetupService` + dual-role check | Home → CHOOSE PROGRAMME |

Both call `ProgrammeAssignmentServiceImpl.assignProgramme`.

## UI flow

1. Dual-role user with no programme sees **Set up your training** on Home
2. **CHOOSE PROGRAMME** → `PersonalTrainingSetupScreen`
3. Published programme list (coach catalogue)
4. Review card: name, version, duration, goal, start date
5. Replacement confirmation when active assignment exists
6. Confirm → assignment service → Home refresh → Today's Training

Athlete-only users retain **Join your coach**. Dual-role users see **Join a coach** as secondary card copy.

## Service reuse

| Component | Role |
|-----------|------|
| `PersonalTrainingSetupService` | Thin orchestration + authorization |
| `ProgrammeAssignmentServiceImpl` | Assignment lifecycle |
| `ProgrammeCatalogServiceImpl` | Published programme list |
| `CurrentUserSession` | Identity adapters (`athleteId`, `coachId`) |

## RLS changes

Migration `20260722120000_add_dual_role_self_assignment_policies.sql`:

- Adds `cohort_auth_is_dual_role_coach_athlete()`
- Replaces broad `dev_programme_assignments_insert` with `programme_assignments_dual_role_self_insert`
- Coach-linked insert policies unchanged

Allowed INSERT paths:

1. Coach with active relationship → existing coach policies
2. Dual-role user → self insert policy

## Mobile UX

- `SafeArea` on setup screen
- Scrollable programme list
- Empty state when no published programmes
- Native date picker for start date
- Duplicate-submit protection + replacement dialog
- Home auto-refresh after successful assignment

## Tests

- `test/personal_training/personal_training_setup_service_test.dart` — domain/security
- `test/personal_training/personal_training_home_empty_state_test.dart` — role-based Home empty states
- `test/personal_training/personal_training_migration_test.dart` — RLS contract

## Known limitations

- Programme list shows coach-accessible published content only; no marketplace or discovery
- Personal setup does not expose programme migration
- Coach-only users without athlete role cannot use athlete training flows (by design)
- Athlete-only users must join a coach for assignment (no self-programming)

## Next V2 blocker

**Multi-athlete coach operations at scale** — roster management, assignment visibility, and coach workflow polish for 5–10 private clients beyond Lee's personal path and single-athlete detail flows.
