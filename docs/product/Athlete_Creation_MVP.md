# Athlete Creation MVP — Phase 5 Sprint 2

**Date:** 2026-07-29  
**Status:** Athlete onboarding → Coach Brain programme → Home  
**Engine:** Unchanged Phase 4 Coach Brain pipeline

---

## Product intent

The athlete introduces themselves to their coach — not configuring software.  
A short linear flow produces a real `AthleteProfile`, builds `PlanningInput`, and runs Coach Brain. Home then shows **their** generated session.

---

## Flow

```
Welcome (name)
  → Goal
  → Equipment (multi-select)
  → Availability (days + duration)
  → Assessment (experience + optional activity)
  → Generating Your Programme
  → Home (personalised today card)
  → EXECUTE TODAY'S SESSION → Workout Player
```

Entry points:
- Login → **START TRAINING** (no account required)
- Home → **GET STARTED** when no engine profile yet

---

## AthleteProfile

Canonical immutable model: `lib/features/athlete_profile/models/athlete_profile.dart`

| Area | Fields |
|------|--------|
| Identity | `athleteId`, `displayName` |
| Goal | `primaryGoal` (+ optional secondary), maps to ontology `goalId` |
| Equipment | `availableEquipment[]`, `environmentId` |
| Availability | `trainingDaysPerWeek`, `preferredSessionDurationMinutes` |
| Assessment | `experienceLevel`, `assessmentComplete`, `baselineCapabilities`, `currentActivity` |
| Preferences | `preferredTrainingStyle`, `injuries`, `constraints` |
| Metadata | `createdAt`, `updatedAt`, `onboardingVersion` |

Reusable for coach-created athletes, imports, wearables — **no separate onboarding DTO**.

### Goal ontology mapping

Knowledge currently defines three goals. UI offers six curated choices; non-native goals map to the closest ontology goal + preference tag:

| UI goal | Ontology goal | Preference tag |
|---------|---------------|----------------|
| HYROX | `cohort.goal.hyrox_sub_60` | — |
| Fat Loss | `cohort.goal.general_fat_loss` | — |
| Military Preparation | `cohort.goal.military_selection` | — |
| General Fitness | `cohort.goal.general_fat_loss` | `general_fitness` |
| Strength | `cohort.goal.general_fat_loss` | `strength_emphasis` |
| Longevity | `cohort.goal.general_fat_loss` | `longevity` |

---

## Planning integration

```
AthleteProfile
  → AthletePlanningInputBuilder
  → PlanningInput
  → CoachBrainWorkoutPlanService.resolveFromProfile
  → CoachBrainService.run
  → PlanningContext + SessionExecutionPlan
  → AthleteProfileSession (in-memory)
  → Home AthleteGeneratedTodaySection
```

**No reference scenarios.** Evidence is self-report seeded from experience level + baseline capabilities.

---

## State

- `AthleteOnboardingDraft` — wizard only  
- `AthleteProfileSession` — bound profile + generated programme (`toPersistenceMap()` ready)  
- No auth required for guest path; optional bind of local `UserProfile` after onboarding

---

## Dependencies

- Coach Brain / Planning Engine / Exercise Policy / Prescription — **read-only consumers**
- Workout Player (Sprint 1) — executes generated plan
- Knowledge ontology 1.3.0 — goals, equipment, environments, capabilities

---

## Known limitations

1. General Fitness / Strength / Longevity lack dedicated ontology goals (mapped + tagged).
2. Assessment is self-report only — no physical testing.
3. No persistence — profile clears on process death.
4. No cloud sync / multi-device.
5. Programme name is derived (`{Goal} Programme`), not a stored catalogue template.
6. Existing programme-assignment Home path still available alongside onboarding entry.

---

## Future persistence

Persist `AthleteProfileSession.toPersistenceMap()` + generated plan ids; restore on launch before Home.

---

## Related

- [Workout_Player_MVP.md](./Workout_Player_MVP.md)
- [Architecture_Freeze_v1.md](../architecture/Architecture_Freeze_v1.md)
