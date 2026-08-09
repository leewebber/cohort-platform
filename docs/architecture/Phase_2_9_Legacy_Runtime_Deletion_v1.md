# Phase 2.9 — Delete Unreachable Legacy Runtime and Persistence Code

**Status:** COMPLETE  
**Recorded:** 2026-08-09  
**Predecessor:** Phase 2.8 Home legacy entry retirement (`4c20cdf`)

```text
PHASE_2_9_COMPLETE=true
LEGACY_RUNTIME_CODE_DELETED=true
NORMAL_ATHLETE_LEGACY_RUNTIME_REACHABLE=false
FOUNDER_STAGING_LEGACY_RUNTIME_REACHABLE=false
LEGACY_COMPLETION_PATH_RETIRED=true
ADAPTIVE_PROGRESSION_DELETED=true
DAILY_BRIEFING_DELETED=true
HOME_ADAPT_FLOW_DELETED=true
LEGACY_PROGRESS_SUMMARY_DELETED=true
LEGACY_PLAN_LIBRARY_DELETED=true
PLAN_START_SERVICE_DELETED=true
LEGACY_PERSISTENCE_CODE_DELETED=partial
PASSIVE_LEGACY_DATA_COMPATIBILITY_RETAINED=true
LEGACY_DATA_DELETED=false
LEGACY_SCHEMA_CHANGED=false
EXISTING_LEGACY_STATE_MUTATED=false
```

## Pre-change residual caller graph (production)

| Symbol | Callers | Classification | Decision |
|--------|---------|----------------|----------|
| `DailyBriefingSection` / `DailyBriefingService` | none (orphaned after 2.8) | DELETE_LEGACY_RUNTIME | deleted |
| `HomeAdaptFlow` | none (orphaned after 2.8) | DELETE_LEGACY_RUNTIME | deleted |
| `AdaptiveProgressionCoordinator` | `WorkoutCompleteScreen` when `!programmeBacked && hasActivePlan` | DELETE_LEGACY_RUNTIME | entry closed then deleted |
| `PlanProgressionService` / `TrainingEvidenceUpdateService` | AdaptiveProgression only | DELETE_LEGACY_RUNTIME | deleted |
| `ProgressSummaryService` | none in athlete Progress (builder uses programme service) | DELETE_LEGACY_RUNTIME | deleted |
| `PlanLibraryScreen` / `PlanDetailScreen` / `plan_widgets` | founder shell + historical direct routes | DELETE_LEGACY_RUNTIME | deleted |
| `PlanStartService` | Plan detail Start only | DELETE_LEGACY_RUNTIME | deleted |
| `SessionCompletion` / stores | WorkoutComplete + Progress UI models | RETAIN_SHARED_NEUTRAL | retained under `adaptive_progression/models` |
| `PlanAssignment` + local repository + hydrator | hydrate / persistBoundSession / onboarding prepare | RETAIN_PASSIVE_DATA_COMPATIBILITY + RETAIN_ONBOARDING_DEPENDENCY | retained; no schema clear |
| `AthleteProfileSession.hasActivePlan` | session signal; Home/Progress/complete ignore for authority | RETAIN_PASSIVE_DATA_COMPATIBILITY | retained; no runtime authority |
| `AthleteProgrammeGenerationService` | onboarding + prepared_execution_reverter + hydrator | RETAIN_ONBOARDING_DEPENDENCY | retained |
| `AthletePlanMaterialisationService` | catalogue Start Programme | RETAIN_MATERIALISATION_BRIDGE | retained; `legacyHasActivePlan` preflight removed |
| `CoachBrainWorkoutPlan` / `WorkoutPlayerLauncher` | shared execution | RETAIN_SHARED_NEUTRAL | retained |
| Canonical catalogue / authoring / Plan Package | founder + athlete programme | RETAIN_CANONICAL | unchanged |

## Pure-legacy completion condition (pre-2.9)

```text
WorkoutCompleteScreen
→ !programmeContext (no ProgrammeExecutionContext)
→ AthleteProfileSession.hasActivePlan == true
→ AdaptiveProgressionCoordinator.runAfterCompletion
→ PlanAssignment / schedule mutation
```

## Completion path change

```text
all WorkoutCompleteScreen paths
→ WorkoutCompletionService (canonical when programmeContext present)
→ SessionCompletionStore + previous-performance capture
→ AthletePersistence.persistBoundSession (round-trip; no AdaptiveProgression)
→ Navigator pop

AdaptiveProgression calls = 0
PlanAssignment day/week mutation from completion = 0
hasActivePlan writes from completion = 0
```

Neutral completion behaviour preserved: shared workout-record / previous-performance
persistence and safe FINISH navigation remain for programme and non-programme
workouts.

## Plan Library ownership

```text
PlanLibraryScreen / PlanDetailScreen / PlanStartService
= legacy generated-plan Plan Library
≠ canonical programme catalogue / Plan Package authoring
→ retired from founder/staging and all named product mounts
```

Canonical `AthleteProgrammeScreen` catalogue, enrol, materialisation, and founder
authoring/import tooling remain reachable.

## Persistence boundary

Deleted: callerless PlanStart write path and progression writers.

Retained (passive):

* `PlanAssignment` model + `PlanAssignmentService` in-memory store
* `AthleteLocalRepository` plan-assignment keys (read/save/clear APIs unused for
  product start; hydrator may still round-trip)
* `AthleteProfileSession.hasActivePlan` decode/bind field
* `PlanCatalog` / `PlanDefinition` / `PlanLibraryFilters` (catalog data + filters;
  not a product Plan Library UI)
* `AthleteGeneratedTodaySection` widget (unmounted; not deleted — out of
  authorised cleanup scope / may still be useful for onboarding diagnostics)

Opening the app does **not** run a migration that clears legacy keys, sets
`hasActivePlan=false`, archives generated plans, or converts to canonical
assignment.

## Onboarding

```text
ONBOARDING_LEGACY_START=false
AthleteOnboardingFlow → AthleteProgrammeGenerationService.generate(profile)
→ profile-only Coach Brain prepare; does not call PlanStartService
→ does not create PlanAssignment for runtime authority
→ Home ignores hasActivePlan (Phase 2.8)
→ completion never invokes AdaptiveProgression (Phase 2.9)
```

## Post-change production reachability

```text
normal athlete
→ no DailyBriefing / HomeAdaptFlow / AdaptiveProgression / Plan Library start
→ Home = programme | none | loading | unavailable
→ Progress = AthleteProgressSummaryBuilder / programme evidence
→ Complete = canonical completion + shared records only

founder/staging
→ no PlanLibraryScreen mount
→ canonical programme tooling preserved
```

## Behavioural-change assessment

```text
architecture_changed=true
product_behaviour_changed=true
LEGACY_COMPLETION_BEHAVIOUR_CHANGED=true
LEGACY_FOUNDER_STAGING_PLAN_LIBRARY_CHANGED=true
CANONICAL_PROGRAMME_HOME_CHANGED=false
CANONICAL_PROGRAMME_SEMANTICS_CHANGED=false
CANONICAL_COMPLETION_SEMANTICS_CHANGED=false
CANONICAL_PROGRESS_SEMANTICS_CHANGED=false
CANONICAL_ADAPTATION_SEMANTICS_CHANGED=false
CANONICAL_AUTHORING_BEHAVIOUR_CHANGED=false
MATERIALISATION_BEHAVIOUR_CHANGED=false
ONBOARDING_BEHAVIOUR_CHANGED=false
EXISTING_LEGACY_STATE_MUTATED=false
LEGACY_DATA_DELETED=false
LEGACY_SCHEMA_CHANGED=false
```

Intentional product changes:

1. Non-programme-context completion no longer runs AdaptiveProgression.
2. Founder/staging legacy Plan Library route is retired.

## Separately authorised future work

* Physical retirement of stored PlanAssignment / `hasActivePlan` keys (data)
* Optional rename of shared `CoachBrainWorkoutPlan` / package paths (Phase 2.10+)
* Onboarding generative path product redesign (not authorised here)

## Next

**Phase 2.10 — Verify Consolidation Closure and Freeze the Canonical Architecture**
