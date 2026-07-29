# Workout Player MVP — Phase 5 Sprint 1

**Date:** 2026-07-29  
**Status:** Athlete vertical slice — execute today’s session from Home  
**Engine:** Phase 4 Coach Brain → `SessionExecutionPlan` (unchanged)

---

## Product intent

Home answers only: **What do I need to do today?**  
The Workout Player is a calm athlete execution surface — Apple Workout + mission briefing. No analytics, coach tools, editing, or planning changes.

---

## Navigation flow

```
Home (TODAY'S TRAINING)
  → EXECUTE TODAY'S SESSION / RESUME SESSION
  → Workout Overview
  → START SESSION
  → Workout Player (exercise pages)
  → Workout Complete
  → FINISH
  → Home (Training Complete success state)
```

Rest-day CTA **Continue to next programme day** also opens the Workout Player (Coach Brain plan), per Sprint 1 brief.

Navigation uses existing `Navigator` + `MaterialPageRoute` conventions (no go_router).

---

## Screen hierarchy

| Screen | File | Role |
|--------|------|------|
| Workout Overview | `screens/workout_overview_screen.dart` | Mission briefing + Start |
| Workout Player | `screens/workout_player_screen.dart` | One exercise at a time |
| Workout Complete | `screens/workout_complete_screen.dart` | Summary + Finish → Home |

Supporting: `widgets/workout_player_widgets.dart` (progress, meta rows, video placeholder).

---

## State model

`WorkoutPlayerController` → `WorkoutPlayerState`

| Field | Purpose |
|-------|---------|
| `plan` | `SessionExecutionPlan` from Coach Brain |
| `brief` | Overview metadata (objective, intent, difficulty, notes) |
| `steps` | Flattened exercise list |
| `phase` | overview / active / complete |
| `currentExerciseIndex` / `currentSet` | Position |
| `completedExerciseIndexes` | Progress |
| `startedAt` / `completedAt` | Duration |
| `sessionRpe` / `notes` | Optional complete fields |
| `toPersistenceMap()` | Snapshot hook for future persistence |

Lifecycle: `WidgetsBindingObserver` logs pause snapshots; **no persistence** in Sprint 1.

---

## Dependencies

```
HomeTodaySessionSection
  → WorkoutPlayerLauncher
      → creates TrainingSession (existing repo)
      → WorkoutOverviewScreen
          → CoachBrainWorkoutPlanService
              → CoachBrainService (ports only; no engine edits)
              → WorkoutPlanFromPlanningContext (projection)
          → WorkoutPlayerController + WorkoutPlayerScreen
          → WorkoutCompleteScreen
              → WorkoutCompletionService
                  → TrainingSessionRepository.completeSession
                  → ProgrammeSessionProgressionCoordinator
```

**Does not modify:** planning engines, prescription logic, knowledge formulas, gap analysis.

**Knowledge loading:** on-disk `knowledge/` when present; otherwise extracts bundled assets (`pubspec.yaml` assets under `knowledge/`).

**Evidence source:** [AthleteProfile](./Athlete_Creation_MVP.md) → PlanningInput (Sprint 2). Reference scenarios are no longer used for athlete execution.

---

## Widget tree (player, simplified)

```
Scaffold
  AppBar (exercise N of M)
  Column
    ScrollView
      Session progress
      Exercise progress
      Remaining duration
      Video placeholder
      Exercise name / category
      Description / cues / prescription / rest / RPE / set
    Previous | Next
    COMPLETE SET (primary)
```

---

## Future extensions

- Persist `WorkoutPlayerState.toPersistenceMap()` across process death
- Athlete-specific `PlanningInput` (real evidence, goal, equipment)
- Wire programme protocol title to match engine session title on Home
- Exercise video player in placeholder slot
- Optional return to legacy `ActiveSessionScreen` for timer-heavy formats
- Day-of adaptation (ADR-020) remains separate

---

## Known limitations

1. Coach Brain uses a **reference gap scenario** for evidence — not the athlete’s live profile yet.
2. Home programme card title may still reflect assigned **protocol** while the player runs the **engine** plan.
3. No offline persistence of in-progress set index.
4. Rest-day “Continue…” launches the player rather than advancing the programme cursor (Sprint 1 literal requirement).
5. Legacy `ActiveSessionScreen` remains for other entry points; athlete Home path uses Workout Player.
6. Screenshots in CI are widget-level only; device captures are manual.

---

## Related

- [Architecture_Freeze_v1.md](../architecture/Architecture_Freeze_v1.md)
- [Coach_Brain_Orchestration_v1.md](../planning/Coach_Brain_Orchestration_v1.md)
