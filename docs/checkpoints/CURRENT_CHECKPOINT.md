# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 2 — Architecture Consolidation **in progress**.

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
CONSOLIDATION_SAFETY_GATE_ESTABLISHED=true
CANONICAL_RUNTIME_AUTHORITY_ESTABLISHED=true
LEGACY_RUNTIME_DECISION=RETIRE
NEW_LEGACY_STARTS_CLOSED=true
ATHLETE_SHELL_CANONICAL_CATALOGUE_ENTRY=true
EXISTING_LEGACY_STATE_SUPPORT=true
LEGACY_RUNTIME_DELETED=false
INTENDED_ENTRY_BEHAVIOUR_CHANGED=true
CANONICAL_PROGRAMME_SEMANTICS_CHANGED=false
EXISTING_LEGACY_STATE_MUTATED=false
```

Phase 2.6 closes new athlete-shell Plan Library starts. The Plans tab mounts
`AthleteProgrammeScreen` (canonical catalogue / Start Programme). Existing local
`hasActivePlan` compatibility remains temporarily supported. Legacy services are
not deeply deleted.

**Decision / authority:**
- [`../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
- [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)

**Onboarding:** `ONBOARDING_LEGACY_START=false` — onboarding generates a profile
session via Coach Brain without creating `PlanAssignment` / `hasActivePlan`
(requires plan + assignment + programme).

**Safety gate:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Next authorised task: **Phase 2.7 — Migrate Completion, Progress and Briefing
Dependencies to Canonical Programme State**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 2.5 — Compatibility-Path Retirement Decision | **COMPLETE** (`RETIRE`) |
| Phase 2.6 — Stop New Legacy Starts and Align Athlete Shell Catalogue Entry | **COMPLETE** |
| Phase 2.7 — Migrate Completion, Progress and Briefing Dependencies | Next |

## Remaining legacy surface after Phase 2.6

| Survivor | Classification after entry closure |
|----------|--------------------------------------|
| HomeAdaptFlow / DailyBriefing (existing `hasActivePlan`) | still runtime-reachable for existing state |
| AdaptiveProgression / WorkoutComplete `hasActivePlan` gate | still runtime-reachable for existing state |
| Progress Plan-Library summary | still runtime-reachable |
| PlanStartService / PlanLibraryScreen | orphaned from athlete shell; founder/staging/tests may still open Plan Library |
| PlanAssignment local persistence / models | still readable for existing state |
| Coach Brain services | still used by legacy compatibility + onboarding generate |
| AthletePlanMaterialisationService | MATERIALISATION_BRIDGE — preserved |
| HomeTodaySessionSection / AthleteGeneratedTodaySection | orphaned / product-unmounted |

## Preserved state

- Do not delete Plan Library / Coach Brain implementations yet.
- Do not migrate WorkoutComplete / Progress / DailyBriefing in this sprint.
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
