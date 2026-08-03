# Adaptive Progression MVP — Phase 5 Sprint 4

**Date:** 2026-07-29  
**Status:** Complete workout → evidence → plan advance → Coach Brain → Home  
**Engine:** Unchanged Phase 4 Coach Brain pipeline

**Scope note (Sprint 1.6B):** This document describes the **legacy Plan Library /
generative Adaptive Progression** loop. It is **not** the prescription authority
for Authored Plan Package programmes. Programme-backed adaptation must not
invoke Adaptive Progression to reauthor, personalise, optimise, or progress an
authored programme. See
[`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
and the Sprint 1.6B clarification on ADR-020.

---

## Product intent

When an athlete finishes today's session, Cohort should feel continuous: evidence updates, the active plan advances, and tomorrow's personalised session is already waiting on Home.

Everything remains deterministic. No AI. No persistence in this sprint.

---

## Flow

```
Workout Complete (RPE + notes)
  → SessionCompletion (in-memory)
  → TrainingEvidenceUpdateService → AthleteProfile baselines
  → PlanProgressionService → day / week / phase
  → PlanningInput (existing builder)
  → Coach Brain
  → Tomorrow's SessionExecutionPlan
  → AthleteProfileSession.bind
  → Home refresh
```

UI transition (understated):

1. Analysing today's training…  
2. Updating your plan…  
3. Tomorrow is ready.

---

## Session completion

`lib/features/adaptive_progression/models/session_completion.dart`

| Field | Notes |
|-------|--------|
| `completedAt` | UTC stamp |
| `duration` | Elapsed from player |
| `exercisesCompleted` / `totalExercises` | From player state |
| `sessionRpe` | Optional 1–10 |
| `notes` | Optional |

Stored in `SessionCompletionStore` (memory only).

---

## Evidence flow

`TrainingEvidenceUpdateService` applies a **small, capped, deterministic** delta to `AthleteProfile.baselineCapabilities`, preferring the active plan's `capabilityPriorities`.

Existing `AthletePlanningInputBuilder` maps baselines → `AthleteCapabilityEvidenceProfile`. No Coach Brain / gap-engine changes.

---

## Plan progression

`PlanProgressionService` advances:

- **Day** +1; rolls to next **week** after `recommendedDaysPerWeek`
- **Phase** across plan duration thirds: Foundation → Build → Peak

---

## Regeneration

`AdaptiveProgressionCoordinator.runAfterCompletion`:

1. Build + store `SessionCompletion`  
2. Update evidence on profile  
3. Advance assignment  
4. `AthleteProgrammeGenerationService.generate` → Coach Brain  
5. Bind result to `AthleteProfileSession`

Home `setState` on return shows the new session and cursor — no manual refresh.

---

## Dependencies

| Module | Role |
|--------|------|
| `adaptive_progression` | Completion, evidence, progression, coordinator |
| `athlete_profile` | Session store + PlanningInput builder |
| `plans` | PlanDefinition / PlanAssignment |
| `workout_player` | Complete screen transition + result |
| Coach Brain / engines | **Unchanged** |

---

## Known limitations

- No persistence / cloud / wearables  
- Evidence deltas are intentionally small and formulaic  
- Phase labels are product-side (not ontology programme phases)  
- Adaptive loop runs only when an active plan is bound  
- Tomorrow's session is generated immediately (not deferred overnight)

---

## Sprint 5 recommendation

Persist `SessionCompletion` + assignment cursor; optionally schedule regeneration at local midnight; surface a calm “adaptation notes” strip on Home without exposing engine internals.
