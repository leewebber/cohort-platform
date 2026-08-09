# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 2 — Architecture Consolidation **CLOSED**.

```text
PHASE_1_CLOSED=true
PHASE_1_REOPENED=false
PHASE_2_STARTED=true
PHASE_2_1_INVENTORY_COMPLETE=true
PHASE_2_2_COMPLETE=true
PHASE_2_3_COMPLETE=true
PHASE_2_4_COMPLETE=true
PHASE_2_5_COMPLETE=true
PHASE_2_6_COMPLETE=true
PHASE_2_7_COMPLETE=true
PHASE_2_8_COMPLETE=true
PHASE_2_9_COMPLETE=true
PHASE_2_10_COMPLETE=true
PHASE_2_CLOSED=true
CANONICAL_ARCHITECTURE_FROZEN=true
ONE_OPERATIONAL_AUTHORITY_PER_RESPONSIBILITY=true
LEGACY_RUNTIME_DECISION=RETIRE
NEW_LEGACY_STARTS_CLOSED=true
HOME_LEGACY_ENTRY_RETIRED=true
LEGACY_COMPLETION_PATH_RETIRED=true
NORMAL_ATHLETE_LEGACY_RUNTIME_REACHABLE=false
FOUNDER_STAGING_LEGACY_RUNTIME_REACHABLE=false
ONBOARDING_LEGACY_RUNTIME_REACHABLE=false
EXECUTABLE_LEGACY_RUNTIME_CODE_DELETED=true
LEGACY_PERSISTENCE_CODE_DELETED=partial
PASSIVE_LEGACY_DATA_COMPATIBILITY_RETAINED=true
PASSIVE_LEGACY_STATE_SELECTS_RUNTIME=false
LEGACY_DATA_DELETED=false
LEGACY_SCHEMA_CHANGED=false
EXISTING_LEGACY_STATE_MUTATED=false
CANONICAL_PROGRAMME_SEMANTICS_CHANGED=false
CANONICAL_HOME_SEMANTICS_CHANGED=false
CANONICAL_COMPLETION_SEMANTICS_CHANGED=false
CANONICAL_PROGRESS_SEMANTICS_CHANGED=false
CANONICAL_ADAPTATION_SEMANTICS_CHANGED=false
CANONICAL_AUTHORING_BEHAVIOUR_CHANGED=false
MATERIALISATION_BEHAVIOUR_CHANGED=false
ONBOARDING_BEHAVIOUR_CHANGED=false
PHASE_3_STARTED=false
```

Phase 2.10 verified consolidation closure and froze the canonical programme
architecture. Executable legacy runtime code remains deleted. Passive
PlanAssignment / `hasActivePlan` compatibility may decode stored values but
cannot select runtime authority.

**Binding authority:**
- [`../architecture/Canonical_Programme_Architecture_Freeze_v1.md`](../architecture/Canonical_Programme_Architecture_Freeze_v1.md)
- [`../architecture/Phase_2_Closure_v1.md`](../architecture/Phase_2_Closure_v1.md)
- [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)
- [`../architecture/Phase_2_Consolidation_Safety_Gate_v1.md`](../architecture/Phase_2_Consolidation_Safety_Gate_v1.md)

## Operational runtime

```text
Home → programme | none | loading | unavailable
Complete → canonical + shared SessionCompletion (no AdaptiveProgression)
Progress → AthleteProgressSummaryBuilder / programme evidence
Plans tab → AthleteProgrammeScreen catalogue
Founder → canonical Plan Package / programme tooling (no legacy Plan Library)
```

**Safety gate (still required before architecture-affecting work):**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Next authorised task (not started): **Phase 3.1 — Exercise Database Discovery
and Domain Design**.

## Delivery sequence

| Stage | Status |
|-------|--------|
| Phase 2.9 — Delete Unreachable Legacy Runtime | **COMPLETE** |
| Phase 2.10 — Verify Closure and Freeze Architecture | **COMPLETE** |
| Phase 2 closed | **YES** |
| Phase 3 | **NOT STARTED** |

## Retained survivors (not runtime authority)

| Survivor | Classification |
|----------|----------------|
| PlanAssignment + hydrator / local keys | RETAIN_PASSIVE_DATA_COMPATIBILITY |
| AthleteProfileSession.hasActivePlan | RETAIN_PASSIVE_DATA_COMPATIBILITY |
| SessionCompletion / CapabilityTimeline models | RETAIN_SHARED_NEUTRAL |
| AthleteProgrammeGenerationService | RETAIN_ONBOARDING_DEPENDENCY |
| AthletePlanMaterialisationService | RETAIN_MATERIALISATION_BRIDGE |
| CoachBrainWorkoutPlan / WorkoutPlayerLauncher | RETAIN_SHARED_NEUTRAL |
| ChoosePlanEntryCard (historical file path) | RETAIN_CANONICAL + HISTORICAL_NAME |
| HomeTodaySessionSection (unmounted) | Deferred orphan UI cleanup |

## Preserved state

- Do not clear `hasActivePlan` or delete local legacy data without separate authority.
- Leave `supabase/.temp/*` untouched.
- Do not push without explicit authority.
- No staging/production contact unless authorised.
- Do not begin Phase 3 without separate authorisation.

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
./tool/testing/run_phase2_consolidation_safety_gate.sh
flutter test
```
