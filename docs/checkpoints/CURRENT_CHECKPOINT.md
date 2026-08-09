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
CONSOLIDATION_SAFETY_GATE_ESTABLISHED=true
CANONICAL_RUNTIME_AUTHORITY_ESTABLISHED=true
LEGACY_RUNTIME_DECISION=RETIRE
NEW_LEGACY_STARTS_CLOSED=true
ATHLETE_SHELL_CANONICAL_CATALOGUE_ENTRY=true
CANONICAL_COMPLETION_AUTHORITY=true
CANONICAL_PROGRESS_AUTHORITY=true
CANONICAL_HOME_BRIEFING_INDEPENDENCE=true
CANONICAL_LEGACY_SIDE_EFFECTS_REMOVED=true
EXISTING_LEGACY_STATE_SUPPORT=true
HOME_LEGACY_ENTRY_RETIRED=false
LEGACY_RUNTIME_DELETED=false
LEGACY_DATA_DELETED=false
CANONICAL_PROGRAMME_SEMANTICS_CHANGED=false
EXISTING_LEGACY_STATE_MUTATED=false
```

Phase 2.7 migrates completion, progress and Home briefing **callers** off
inappropriate legacy Plan Library / Coach Brain side effects for canonical
programme athletes, while retaining pure-legacy compatibility where still
required.

**Decision / authority:**
- [`../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
- [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)

## Pre-change caller graph (summary)

```text
WorkoutCompleteScreen
  → WorkoutCompletionService (+ programme progression when context set)
  → AdaptiveProgression when hasActivePlan  *** removed for programme-backed ***

ProgressScreen
  → ProgressSummaryService (Plan Library / SessionCompletionStore)
  *** programme athletes now → AthleteProgressSummaryBuilder
      → ProgrammeProgressSummaryService ***

Home programme branch (Phase 2.4)
  → AthleteProgrammeTodaySection only (already no DailyBriefing)
  *** confirmed / tripwired; pure-legacy still may use DailyBriefing ***
```

## Post-change authority

| Athlete state | Completion | Progress | Home briefing |
|---------------|------------|----------|---------------|
| Programme only / both-present | `WorkoutCompletionService` + programme progression; AdaptiveProgression **off** | Canonical programme slot outcomes only | Programme today; DailyBriefing **off** |
| Pure legacy `hasActivePlan` | AdaptiveProgression retained | `ProgressSummaryService` retained | DailyBriefing + HomeAdaptFlow retained |
| Unavailable programme evidence | N/A | Empty/neutral; **no** legacy fallback | Unavailable; **no** legacy fallback |

**Onboarding:** `ONBOARDING_LEGACY_START=false` (unchanged from Phase 2.6).

**Safety gate:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Next authorised task: **Phase 2.8 — Retire the Home Legacy Runtime Entry and
Isolate Remaining Legacy Code**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 2.6 — Stop New Legacy Starts | **COMPLETE** |
| Phase 2.7 — Migrate Completion, Progress and Briefing Dependencies | **COMPLETE** |
| Phase 2.8 — Retire Home Legacy Runtime Entry | Next |

## Remaining legacy surface after Phase 2.7

| Survivor | Classification | Planned retirement |
|----------|----------------|--------------------|
| HomeAdaptFlow / DailyBriefing (pure legacy Home) | PURE_LEGACY_COMPATIBILITY_RUNTIME | Phase 2.8 |
| AdaptiveProgression (pure legacy complete only) | PURE_LEGACY_COMPATIBILITY_RUNTIME | Phase 2.8/2.9 after Home+complete entries gone |
| ProgressSummaryService (pure legacy Progress) | PURE_LEGACY_COMPATIBILITY_RUNTIME | Phase 2.8/2.9 |
| PlanStartService / PlanLibraryScreen | ORPHANED_PRODUCTION_CODE (athlete shell); founder/staging may still open | Phase 2.9 |
| PlanAssignment local persistence | PURE_LEGACY_COMPATIBILITY_RUNTIME | Phase 2.9 data cleanup |
| Coach Brain generation services | PURE_LEGACY_COMPATIBILITY_RUNTIME + onboarding generate | Phase 2.8/2.9 |
| AthletePlanMaterialisationService | MATERIALISATION_BRIDGE | Retain |
| CoachBrainWorkoutPlan DTO / WorkoutPlayerLauncher | SHARED_NEUTRAL | Retain |
| HomeTodaySessionSection / AthleteGeneratedTodaySection | ORPHANED_PRODUCTION_CODE | Phase 2.9 |

## Preserved state

- Do not delete Coach Brain / Plan Library implementations yet.
- Do not retire Home legacy entry in this sprint (`HOME_LEGACY_ENTRY_RETIRED=false`).
- Do not clear `hasActivePlan` or delete local legacy data.
- Leave `supabase/.temp/*` untouched.
- Do not push without explicit authority.
- No staging/production contact unless authorised.

## Phase 2.8 prerequisites

1. Home `legacyPlanCompatibility` branch retirement decision + replacement empty/neutral UX.
2. Proof pure-legacy athletes no longer require DailyBriefing / HomeAdaptFlow product entry.
3. Completion/progress pure-legacy paths inventoried as delete-ready or still required.
4. Consolidation safety gate green after entry retirement.

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
./tool/testing/run_phase2_consolidation_safety_gate.sh
flutter test
```
