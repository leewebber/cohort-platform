# Plan Library MVP — Phase 5 Sprint 3

**Date:** 2026-07-29  
**Status:** Plans as products · browse · assign · Home from PlanAssignment  
**Engine:** Unchanged Phase 4 Coach Brain pipeline

---

## Product intent

A **Plan** is a coaching product.  
A **PlanAssignment** is the athlete↔plan relationship.

The athlete chooses a plan. The coaching engine personalises sessions from that assignment. Programme construction is never exposed.

```
AthleteProfile
  → PlanAssignment (active plan)
  → PlanningInput (plan tags + profile)
  → Coach Brain
  → Today's Session
```

---

## Plan model

Canonical immutable model: `lib/features/plans/models/plan.dart`

| Area | Fields |
|------|--------|
| Identity | `planId`, `name`, `subtitle`, `description` |
| Classification | `primaryGoal`, `category`, `difficulty` |
| Training | `recommendedDaysPerWeek`, `typicalSessionDurationMinutes` |
| Requirements | `equipmentPresetIds`, `experience` |
| Presentation | `coverImageAsset` (placeholder), `colourTheme`, `tags` |
| Detail copy | `whoItsFor`, `whatYouImprove`, `typicalWeekSummary`, `faqs` |
| Metadata | `version`, `author`, `status` |

Catalog (in-memory, no persistence): `lib/features/plans/data/plan_catalog.dart`

---

## PlanAssignment

Immutable model: `lib/features/plans/models/plan_assignment.dart`

| Field | Role |
|-------|------|
| `assignmentId` | Unique assignment id |
| `athleteId` / `planId` | Relationship |
| `assignedAt` / `startedAt` | Lifecycle stamps |
| `currentPhase` / `currentWeek` / `currentDay` | Progress cursor |
| `status` | `active` · `paused` · `completed` · `cancelled` |
| `configuration` | Reserved map for future athlete-specific config |

MVP: **one active assignment**. The model allows future multi-assignment; UI does not.

---

## Navigation

| Entry | Destination |
|-------|-------------|
| Bottom nav **Plans** | `PlanLibraryScreen` |
| Home empty CTA **Choose a Plan** | `PlanLibraryScreen` |
| Plan card | `PlanDetailScreen` |
| **Start This Plan** | `PlanStartService` → bind session → pop to Home |

Screen hierarchy:

```
HomeScreen
  ├─ (empty) ChoosePlanEntryCard → PlanLibraryScreen
  │                              → PlanDetailScreen
  │                              → Start → Home (active plan)
  └─ (active) AthleteGeneratedTodaySection
       → Workout Player (existing Sprint 1 path)
```

---

## Dependencies

| Layer | Ownership |
|-------|-----------|
| `features/plans` | Plan product + assignment + library UI |
| `features/athlete_profile` | Profile session store; PlanningInput builder accepts Plan |
| `features/workout_player` | `CoachBrainWorkoutPlanService.resolveFromProfile` (+ plan) |
| Planning / Coach Brain / engines | **Unchanged** |

Plan identity is carried on `PlanningInput.athletePreferences.tags`:

- `plan_id:<planId>`
- `plan_assignment:<assignmentId>`

Days / duration / goal come from the Plan when present.  
`progressionPathId` is **not** set to `planId` (ontology path validation).

---

## Known limitations

- No persistence / cloud sync of assignments
- Cover images are colour placeholders
- Single active plan only (UI)
- Plan does not alter engine algorithms — tags + profile fields only
- FAQs are curated placeholders on catalog entries
- Sprint 2 onboarding can still generate a programme without a plan; Home requires an active plan for the today card

---

## Future recommendation engine (Sprint 4+)

Recommend plans from `AthleteProfile` (goal, equipment, days, experience) without exposing construction. Rank catalog, surface “Recommended for you”, keep assignment + Coach Brain path unchanged.

---

## Tests

`test/plans/plan_library_test.dart` covers catalog, filters, details, assignment, PlanningInput tags, Coach Brain invocation, Home empty + active plan.
