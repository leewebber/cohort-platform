# Athlete Home Runtime Authority v1 — Phase 2.4 / 2.8

**Status:** Binding for Home runtime classification (Phase 2.4+)  
**First migrated caller:** `HomeScreen`  
**Decision owner:** `AthleteHomeRuntimeAuthorityResolver`  
(`lib/features/home/services/athlete_home_runtime_authority.dart`)  
**Phase 2.8 amendment:** Legacy Plan Library Home entry retired —
`legacyPlanCompatibility` removed; `hasActivePlan` no longer selects Home
runtime.

## Authority statement

| Runtime | Status |
|---------|--------|
| **Programme Athlete runtime** (`ProgrammeAdaptFlow` / materialised programme today) | **Canonical** |
| **Plan Library / Coach Brain runtime** (`HomeAdaptFlow` / daily briefing) | **Retired from Home entry (Phase 2.8)** — implementations retained until Phase 2.9 |
| Founder programme authoring | Separate concern — not a founder-only athlete runtime |

Founders ultimately execute authored programmes through the same Programme
Athlete runtime as other athletes. Do not create a “founder-only” Coach Brain
runtime.

Legacy Plan Library implementation deletion is **not** authorised by Phase 2.8
(`LEGACY_RUNTIME_DELETED=false`). Phase 2.5 decided
`LEGACY_RUNTIME_DECISION=RETIRE` — see
[`Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](./Phase_2_Compatibility_Path_Retirement_Decision_v1.md).

## Decision table (Phase 2.8)

| Materialised programme | Programme evidence | Authority |
|------------------------|--------------------|-----------|
| Valid (`true`) | OK | `programme` |
| No (`false`) | OK | `none` (established no-programme / catalogue entry) |
| Unknown (`null`) | OK / loading | `loading` |
| Any | Unavailable / error | `unavailable` — fail closed; no Coach Brain fallback |

Legacy `hasActivePlan`, `PlanAssignment`, and generated plans are **ignored**
for Home authority selection. Observationally:

```text
no programme + no legacy  ≡  no programme + legacy-only
→ none (ChoosePlanEntryCard → canonical catalogue)
```

### Historical Phase 2.4 table (superseded for Home entry)

Phase 2.4 briefly selected `legacyPlanCompatibility` when
`materialisedProgramme=false` and `hasActivePlan=true`. That branch mounted
`DailyBriefingSection` + `HomeAdaptFlow`. Phase 2.8 retires that selection.

## Home behaviour

| Authority | Home exposes |
|-----------|--------------|
| `programme` | `AthleteProgrammeTodaySection` → `ProgrammeAdaptFlow` only |
| `none` | Choose-programme entry; neither adapt flow |
| `loading` | “Checking programme…”; neither adapt flow |
| `unavailable` | “Unable to confirm programme.”; neither adapt flow |

## Remaining legacy surfaces (not Home authority)

These may still exist in the repository but **do not** grant Home runtime:

| Location | Notes |
|----------|-------|
| `DailyBriefingSection` / `DailyBriefingService` | ORPHANED from athlete Home; Phase 2.9 delete-ready |
| `HomeAdaptFlow` | ORPHANED from athlete Home; Phase 2.9 delete-ready |
| `WorkoutCompleteScreen` | Pure-legacy AdaptiveProgression only when `!programmeBacked && hasActivePlan` |
| `AthletePlanMaterialisationService` | MATERIALISATION_BRIDGE — may still preflight on `hasActivePlan` |
| `ProgressSummaryService` | Unit/historical; Progress tab uses programme builder |
| Plan Library screens / `PlanStartService` | Founder/staging or direct routes; not athlete shell |

## Binding companions

- [`Phase_2_Consolidation_Safety_Gate_v1.md`](./Phase_2_Consolidation_Safety_Gate_v1.md)
- [`Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- [`Athlete_Plan_Materialisation_v1.md`](./Athlete_Plan_Materialisation_v1.md)
- [`Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](./Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
- Historical Coach Brain day-of ADR-020 — not canonical for materialised programme athletes
