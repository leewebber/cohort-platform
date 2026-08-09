# Athlete Home Runtime Authority v1 — Phase 2.4 / 2.8 / 2.9 / 2.10

**Status:** Binding for Home runtime classification (Phase 2.4+)  
**First migrated caller:** `HomeScreen`  
**Decision owner:** `AthleteHomeRuntimeAuthorityResolver`  
(`lib/features/home/services/athlete_home_runtime_authority.dart`)  
**Phase 2.8 amendment:** Legacy Plan Library Home entry retired —
`legacyPlanCompatibility` removed; `hasActivePlan` no longer selects Home
runtime.  
**Phase 2.9 amendment:** DailyBriefing / HomeAdaptFlow implementations deleted;
legacy Plan Library / PlanStartService deleted.  
**Phase 2.10 amendment:** Architecture frozen; `AthleteGeneratedTodaySection`
orphan deleted; `ChoosePlanEntryCard` remains the no-programme catalogue entry.
See [`Canonical_Programme_Architecture_Freeze_v1.md`](./Canonical_Programme_Architecture_Freeze_v1.md).

## Authority statement

| Runtime | Status |
|---------|--------|
| **Programme Athlete runtime** (`ProgrammeAdaptFlow` / materialised programme today) | **Canonical** |
| **Plan Library / Coach Brain runtime** (`HomeAdaptFlow` / daily briefing) | **Deleted (Phase 2.9)** after Home entry retirement in 2.8 |
| Founder programme authoring | Separate concern — not a founder-only athlete runtime |

Founders ultimately execute authored programmes through the same Programme
Athlete runtime as other athletes. Do not create a “founder-only” Coach Brain
runtime.

Phase 2.5 decided `LEGACY_RUNTIME_DECISION=RETIRE`. Phase 2.9 executes
`LEGACY_RUNTIME_CODE_DELETED=true` for unreachable implementations.
Persisted legacy data remains (`LEGACY_DATA_DELETED=false`).

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

## Remaining legacy surfaces (Phase 2.10)

| Location | Notes |
|----------|-------|
| DailyBriefing / HomeAdaptFlow / AdaptiveProgression coordinator / ProgressSummaryService / Plan Library screens / PlanStartService / AthleteGeneratedTodaySection | **Deleted** |
| `SessionCompletion` / capability timeline stores | Shared-neutral; path under `adaptive_progression/models` retained |
| `PlanAssignment` / `hasActivePlan` | Passive data compatibility only — ignored for Home/Progress/complete authority |
| `AthletePlanMaterialisationService` | MATERIALISATION_BRIDGE — `legacyHasActivePlan` preflight removed |
| `AthleteProgrammeGenerationService` | Onboarding dependency — retained |
| `ChoosePlanEntryCard` | Canonical no-programme entry (historical file path retained) |
| `HomeTodaySessionSection` | Unmounted; deferred orphan UI cleanup |

## Binding companions

- [`Phase_2_Consolidation_Safety_Gate_v1.md`](./Phase_2_Consolidation_Safety_Gate_v1.md)
- [`Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- [`Athlete_Plan_Materialisation_v1.md`](./Athlete_Plan_Materialisation_v1.md)
- [`Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](./Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
- Historical Coach Brain day-of ADR-020 — not canonical for materialised programme athletes
