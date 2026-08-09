# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 2 — Architecture Consolidation **in progress** (2.9 complete).

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
CONSOLIDATION_SAFETY_GATE_ESTABLISHED=true
CANONICAL_RUNTIME_AUTHORITY_ESTABLISHED=true
LEGACY_RUNTIME_DECISION=RETIRE
NEW_LEGACY_STARTS_CLOSED=true
HOME_LEGACY_ENTRY_RETIRED=true
LEGACY_COMPLETION_PATH_RETIRED=true
NORMAL_ATHLETE_LEGACY_RUNTIME_REACHABLE=false
FOUNDER_STAGING_LEGACY_RUNTIME_REACHABLE=false
LEGACY_RUNTIME_CODE_DELETED=true
DAILY_BRIEFING_DELETED=true
HOME_ADAPT_FLOW_DELETED=true
ADAPTIVE_PROGRESSION_DELETED=true
LEGACY_PROGRESS_SUMMARY_DELETED=true
LEGACY_PLAN_LIBRARY_DELETED=true
PLAN_START_SERVICE_DELETED=true
LEGACY_PERSISTENCE_CODE_DELETED=partial
PASSIVE_LEGACY_DATA_COMPATIBILITY_RETAINED=true
LEGACY_DATA_DELETED=false
LEGACY_SCHEMA_CHANGED=false
EXISTING_LEGACY_STATE_MUTATED=false
CANONICAL_PROGRAMME_SEMANTICS_CHANGED=false
CANONICAL_COMPLETION_SEMANTICS_CHANGED=false
CANONICAL_PROGRESS_SEMANTICS_CHANGED=false
CANONICAL_ADAPTATION_SEMANTICS_CHANGED=false
MATERIALISATION_BEHAVIOUR_CHANGED=false
ONBOARDING_BEHAVIOUR_CHANGED=false
```

Phase 2.9 deletes unreachable legacy runtime implementations after Phase 2.8
unmounted Home entry. AdaptiveProgression, DailyBriefing, HomeAdaptFlow, legacy
ProgressSummaryService, Plan Library screens, and PlanStartService are removed.
Persisted legacy PlanAssignment / `hasActivePlan` remain as passive compatibility
only — not runtime authority, not cleared, not migrated.

**Decision / authority:**
- [`../architecture/Phase_2_9_Legacy_Runtime_Deletion_v1.md`](../architecture/Phase_2_9_Legacy_Runtime_Deletion_v1.md)
- [`../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
- [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)

## Post-change runtime (Phase 2.9)

```text
Home → programme | none | loading | unavailable (no DailyBriefing)
Complete → canonical completion + shared SessionCompletion; AdaptiveProgression absent
Progress → AthleteProgressSummaryBuilder / programme evidence only
Plans tab → AthleteProgrammeScreen catalogue
Founder → no PlanLibraryScreen
```

**Safety gate:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Next authorised task: **Phase 2.10 — Verify Consolidation Closure and Freeze
the Canonical Architecture**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 2.8 — Retire Home Legacy Runtime Entry | **COMPLETE** |
| Phase 2.9 — Delete Unreachable Legacy Runtime and Persistence | **COMPLETE** |
| Phase 2.10 — Verify Consolidation Closure | Next |

## Retained survivors (not deleted)

| Survivor | Classification |
|----------|----------------|
| PlanAssignment + local repository + hydrator | RETAIN_PASSIVE_DATA_COMPATIBILITY |
| AthleteProfileSession.hasActivePlan | RETAIN_PASSIVE_DATA_COMPATIBILITY |
| SessionCompletion / CapabilityTimeline models+stores | RETAIN_SHARED_NEUTRAL |
| AthleteProgrammeGenerationService | RETAIN_ONBOARDING_DEPENDENCY |
| AthletePlanMaterialisationService | RETAIN_MATERIALISATION_BRIDGE |
| CoachBrainWorkoutPlan / WorkoutPlayerLauncher | RETAIN_SHARED_NEUTRAL |
| Canonical catalogue / authoring / Plan Package | RETAIN_CANONICAL |

## Preserved state

- Do not clear `hasActivePlan` or delete local legacy data without separate authority.
- Leave `supabase/.temp/*` untouched.
- Do not push without explicit authority.
- No staging/production contact unless authorised.

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
./tool/testing/run_phase2_consolidation_safety_gate.sh
flutter test
```
