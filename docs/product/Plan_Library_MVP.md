# Plan Library MVP — Phase 5 Sprint 3

**Date:** 2026-07-29  
**Status:** PlanDefinition · PlanAssignment · active coaching context  
**Engine:** Unchanged Phase 4 Coach Brain pipeline

> **Legacy quarantine (Sprint 1.1):** `PlanDefinition` and its Coach Brain
> workout-generation pathway are **non-authoritative**. Production programme
> development uses `ProgrammeLineage` / immutable `ProgrammeVersion` and the
> Authored Plan Package (`docs/architecture/Authored_Plan_Package_v1.md`).
> New Plan Package code must not depend on this pathway. Existing behaviour
> remains temporarily supported pending a separately approved migration/removal
> sprint — do not delete or redirect users from this document alone.

---

## Architecture

Three distinct concepts — never blur them:

| Concept | Role |
|---------|------|
| **PlanDefinition** | Immutable coaching product in the Plan Library |
| **PlanAssignment** | Athlete↔Plan relationship; progress only |
| **Active coaching context** | Built at planning time → consumed by Coach Brain |

```
AthleteProfile
  + PlanAssignment (active)
  + PlanDefinition
  → PlanningInput
  → Coach Brain
  → SessionExecutionPlan
```

Plans describe coaching philosophy.  
The coaching engine generates daily execution.

---

## PlanDefinition

`lib/features/plans/models/plan_definition.dart`

Immutable. **Contains no workouts.**

| Area | Fields |
|------|--------|
| Identity | `planId`, `slug`, `version` |
| Presentation | `name`, `subtitle`, `shortDescription`, `longDescription`, `coverImagePlaceholder`, `colourTheme`, `tags` |
| Classification | `category`, `primaryGoal`, `supportedGoals` |
| Training shape | `recommendedDaysPerWeek`, `typicalSessionDurationMinutes`, `durationWeeks` |
| Requirements | `equipmentProfile`, `experienceLevel` |
| Philosophy | `progressionModel`, `coachingFocus`, `capabilityPriorities` |
| Detail copy | `whoItsFor`, `whatYouImprove`, `typicalWeekSummary`, `faqs` |
| Metadata | `author`, `published`, `createdAt` |

Catalog: `lib/features/plans/data/plan_catalog.dart` (in-memory).

---

## PlanAssignment

`lib/features/plans/models/plan_assignment.dart`

Progress only:

`assignmentId`, `athleteId`, `planId`, `status`, `assignedAt`, `startedAt`, `completedAt`, `currentPhase`, `currentWeek`, `currentDay`, `configuration`

Statuses: `active` · `paused` · `completed` · `cancelled`

MVP: one active assignment (model allows future multi-assignment).

---

## PlanAssignmentService

`lib/features/plans/services/plan_assignment_service.dart` (in-memory):

- Assign Plan  
- Replace Active Plan  
- Read Active Plan / Assignment  
- Clear Active Plan  

---

## Navigation & UI

| Entry | Destination |
|-------|-------------|
| Bottom nav **Plans** | `PlanLibraryScreen` |
| Home empty **Browse Plans** | `PlanLibraryScreen` |
| Plan card | `PlanDetailScreen` |
| **START PLAN** | `PlanStartService` → Home |

Hierarchy:

```
HomeScreen
  ├─ (empty) Choose Your First Plan → Browse Plans
  │         → Plan Library → Plan Detail → START PLAN → Home
  └─ (active) Active Plan · Phase · Week · Day · Today's Session
              → Workout Player
```

---

## Planning integration

`AthletePlanningInputBuilder` accepts `PlanDefinition` + `PlanAssignment`.

Preference tags (engines unchanged):

- `plan_id:<planId>`
- `plan_assignment:<assignmentId>`
- `progression_model:<…>`
- `coaching_focus:<…>`
- `priority_<capabilityId>`
- week / day cursors

`progressionPathId` is **not** set to plan ids (ontology validation).

---

## Future marketplace

Plans become catalogue SKUs: discovery, recommendations, entitlements, coach publishing — without changing Coach Brain. Assignment remains the athlete↔product link.

---

## Known limitations

- No persistence / cloud sync  
- Cover images are colour placeholders  
- Single active plan (UI)  
- Philosophy tags influence preferences only — not engine algorithms  
- No subscriptions, payments, or coach editing  
- Sprint 2 onboarding can still generate without a plan; Home today requires an active plan  

---

## Tests

`test/plans/plan_library_test.dart` — models, assignment service, filters, details, PlanningInput, Coach Brain, Home empty/active.
