# Athlete Home Runtime Authority v1 — Phase 2.4

**Status:** Binding for Home runtime classification (Phase 2.4+)  
**First migrated caller:** `HomeScreen`  
**Decision owner:** `AthleteHomeRuntimeAuthorityResolver`  
(`lib/features/home/services/athlete_home_runtime_authority.dart`)

## Authority statement

| Runtime | Status |
|---------|--------|
| **Programme Athlete runtime** (`ProgrammeAdaptFlow` / materialised programme today) | **Canonical** |
| **Plan Library / Coach Brain runtime** (`HomeAdaptFlow` / daily briefing) | **Legacy compatibility only** |
| Founder programme authoring | Separate concern — not a founder-only athlete runtime |

Founders ultimately execute authored programmes through the same Programme
Athlete runtime as other athletes. Do not create a “founder-only” Coach Brain
runtime.

Legacy Plan Library implementation deletion is **not** authorised by Phase 2.4
(`LEGACY_RUNTIME_DELETED=false`). Phase 2.5 decided
`LEGACY_RUNTIME_DECISION=RETIRE` — see
[`Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](./Phase_2_Compatibility_Path_Retirement_Decision_v1.md).

## Decision table

| Materialised programme | Legacy active plan (`AthleteProfileSession.hasActivePlan`) | Programme evidence | Authority |
|------------------------|-----------------------------------------------------------|--------------------|-----------|
| Valid (`true`) | No | OK | `programme` |
| Valid (`true`) | Yes | OK | `programme` **exclusively** |
| No (`false`) | Yes | OK | `legacyPlanCompatibility` |
| No (`false`) | No | OK | `none` |
| Unknown (`null`) | Any | OK / loading | `loading` — no premature legacy activation |
| Any | Yes | Unavailable / error | `unavailable` — fail closed; no Coach Brain fallback |
| Any | No | Unavailable / error | `none` — catalogue empty-state; still no Coach Brain |

`hasActivePlan` is **not** equivalent to a materialised programme assignment.

## Home behaviour

| Authority | Home exposes |
|-----------|--------------|
| `programme` | `AthleteProgrammeTodaySection` → `ProgrammeAdaptFlow` only |
| `legacyPlanCompatibility` | `DailyBriefingSection` + Adapt → `HomeAdaptFlow` only |
| `none` | Choose-programme entry; neither adapt flow |
| `loading` | “Checking programme…”; neither adapt flow |
| `unavailable` | “Unable to confirm programme.”; neither adapt flow |

## Remaining independent callers (inventory for Phase 2.5)

These still make programme-versus-legacy decisions outside the Home resolver:

| Location | Notes |
|----------|-------|
| `lib/features/workout_player/screens/workout_complete_screen.dart` | Uses `AthleteProfileSession.hasActivePlan` for post-complete adapt |
| `lib/features/daily_briefing/services/daily_briefing_service.dart` | Legacy briefing resolution |
| `lib/features/programme/services/athlete_plan_materialisation_service.dart` | Blocks materialisation when legacy `hasActivePlan` preflight is true |
| `lib/features/progress/services/progress_summary_service.dart` | Progress summary `hasActivePlan` |
| Plan Library screens / `HomeAdaptFlow` itself | Compatibility implementation (retained) |

## Binding companions

- [`Phase_2_Consolidation_Safety_Gate_v1.md`](./Phase_2_Consolidation_Safety_Gate_v1.md)
- [`Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- [`Athlete_Plan_Materialisation_v1.md`](./Athlete_Plan_Materialisation_v1.md)
- Historical Coach Brain day-of ADR-020 — not canonical for materialised programme athletes
