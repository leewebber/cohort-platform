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
PHASE_2_7_COMPLETE=true
PHASE_2_8_COMPLETE=true
CONSOLIDATION_SAFETY_GATE_ESTABLISHED=true
CANONICAL_RUNTIME_AUTHORITY_ESTABLISHED=true
LEGACY_RUNTIME_DECISION=RETIRE
NEW_LEGACY_STARTS_CLOSED=true
ATHLETE_SHELL_CANONICAL_CATALOGUE_ENTRY=true
CANONICAL_COMPLETION_AUTHORITY=true
CANONICAL_PROGRESS_AUTHORITY=true
CANONICAL_HOME_BRIEFING_INDEPENDENCE=true
CANONICAL_LEGACY_SIDE_EFFECTS_REMOVED=true
HOME_LEGACY_ENTRY_RETIRED=true
NORMAL_ATHLETE_LEGACY_RUNTIME_REACHABLE=false
LEGACY_STATE_SELECTS_RUNTIME_AUTHORITY=false
LEGACY_HOME_COMPATIBILITY_SUPPORT=false
REMAINING_LEGACY_CODE_ISOLATED=true
LEGACY_RUNTIME_DELETED=false
LEGACY_DATA_DELETED=false
EXISTING_LEGACY_STATE_MUTATED=false
CANONICAL_PROGRAMME_SEMANTICS_CHANGED=false
```

Phase 2.8 retires the pure-legacy Home runtime entry. Home authority is
programme-evidence only. Legacy `hasActivePlan` / PlanAssignment no longer
select DailyBriefing or HomeAdaptFlow. Legacy-only athletes see the established
no-programme Home (`ChoosePlanEntryCard` → canonical catalogue). Persisted
legacy data is untouched. Deep service deletion is Phase 2.9.

**Decision / authority:**
- [`../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
- [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)

## Pre-change Home authority (Phase 2.4–2.7)

```text
materialised programme → AthleteProgrammeTodaySection
legacy only (hasActivePlan) → DailyBriefingSection + HomeAdaptFlow
neither → ChoosePlanEntryCard
loading / unavailable → fail-closed / catalogue (legacy gated)
```

## Post-change Home authority (Phase 2.8)

```text
materialised programme → AthleteProgrammeTodaySection
no materialised programme (with or without legacy) → ChoosePlanEntryCard
loading → Checking programme…
unavailable → Unable to confirm programme.
```

**Onboarding:** `ONBOARDING_LEGACY_START=false` — generate does not create
`hasActivePlan`; even if legacy state exists, Home ignores it for authority.

**Safety gate:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Next authorised task: **Phase 2.9 — Delete Unreachable Legacy Runtime and
Persistence Code**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 2.7 — Migrate Completion, Progress and Briefing | **COMPLETE** |
| Phase 2.8 — Retire Home Legacy Runtime Entry | **COMPLETE** |
| Phase 2.9 — Delete Unreachable Legacy Runtime and Persistence | Next |

## Remaining legacy surface after Phase 2.8

| Survivor | Classification | delete-ready | Planned |
|----------|----------------|--------------|---------|
| DailyBriefingSection / DailyBriefingService | ORPHANED_PRODUCTION_CODE | true | 2.9 |
| HomeAdaptFlow | ORPHANED_PRODUCTION_CODE | true | 2.9 |
| AdaptiveProgression (pure-legacy complete) | UNREACHABLE_LEGACY_RUNTIME for Home; still reachable from pure-legacy complete | false (complete path) | 2.9 after complete isolation |
| ProgressSummaryService | ORPHANED_PRODUCTION_CODE (Progress tab) / TEST_ONLY consumers | true for Progress tab | 2.9 |
| PlanStartService / PlanLibraryScreen | DIRECT_NON_SHELL_ENTRY (founder/staging) | false | 2.9 / tooling decision |
| PlanAssignment local persistence | UNREACHABLE for Home authority | false (data) | 2.9 data cleanup |
| AthleteProfileSession.hasActivePlan | SHARED session signal; ignored by Home | false | 2.9 |
| AthleteProgrammeGenerationService | ONBOARDING_DEPENDENCY + legacy complete | false | separate onboarding decision |
| AthletePlanMaterialisationService | MATERIALISATION_BRIDGE | false | retain |
| CoachBrainWorkoutPlan / WorkoutPlayerLauncher | SHARED_NEUTRAL | false | retain |

## Phase 2.9 prerequisites

1. Prove DailyBriefing / HomeAdaptFlow have zero production athlete callers.
2. Classify pure-legacy WorkoutComplete AdaptiveProgression as delete-ready or migrate.
3. Classify Plan Library founder/staging ownership before deleting PlanStartService.
4. Decide whether local PlanAssignment / hasActivePlan keys may be cleared.
5. No schema/Supabase deletion without separate authority.
6. Consolidation safety gate green after deletion.

## Preserved state

- Do not delete Coach Brain / Plan Library / DailyBriefing implementations yet.
- Do not clear `hasActivePlan` or delete local legacy data.
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
