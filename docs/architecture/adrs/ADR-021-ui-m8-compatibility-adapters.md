# ADR-021: Existing UI and M8 persistence remain behind compatibility adapters

**Status:** Accepted (Phase 2 complete)  
**Date:** 2026-07-29

## Context

Phase 2 goal was architectural consolidation **without** athlete-visible or schema changes. M7 screens and M8 Supabase RPCs remain production contracts.

## Decision

Keep intentional **compatibility adapters** between domain execution and legacy surfaces:

| Adapter | Role |
|---------|------|
| `SessionExecutionLauncher` + `SessionExecutionLoader` | Load DB-backed `SessionExecutionPlan`; attach `WorkoutSessionLaunchContext` |
| `SessionExecutionController` (fallback) | Plan-owned state when no launch context |
| `WorkoutPlayerActiveSessionProjection` | Player → `ActiveSessionState` |
| `WorkoutSessionLaunchContext` | Bundle occurrence, snapshot, player, home execution bridge |
| `PerformanceRecordSaveCoordinator` | M8 complete + training session + progression + post-completion adaptation |
| `WorkoutExecutionOutcomeMapper` | Draft → domain exercise outcomes at finish |
| `HomeWorkoutLaunchService` / `HomeWorkoutExecutionContext` | Prepare/commit launch and adaptation on Home |

**One architecture, not zero adapters:** adapters are allowed until Phase 4 retires M7 plan coupling or adds occurrence persistence.

## Consequences

- `AthleteTodayWorkoutResolutionService` may import programme feature DTOs (`ResolvedTodaySession`) — application-layer bridge, not domain leakage.
- Widgets stay thin; they must not embed adaptation algorithms or completion invariants.

## Alternatives considered

- **Big-bang UI rewrite** — out of Phase 2 scope.
- **Remove adapters before persistence ports** — rejected; would break Supabase and UX parity.

## Migration implications

- Phase 4: shrink adapters as occurrence + plan projection unify; M8 coordinator likely remains even after domain record port.
