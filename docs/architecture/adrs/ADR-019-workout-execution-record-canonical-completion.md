# ADR-019: WorkoutExecutionRecord is the canonical completion aggregate

**Status:** Accepted (Phase 2 complete)  
**Date:** 2026-07-29  
**Related:** ADR-003 (M8 performance separate from authoring)

## Context

M8 `TrainingSessionRecord` is the Supabase-backed performance tree. Phase 2 introduced a domain completion aggregate tied to `WorkoutPlayer` and exercise outcomes without replacing M8 schema.

## Decision

- **`WorkoutExecutionRecord`** (`lib/domain/workout_execution_record/`) is the **canonical domain completion aggregate**, produced by `WorkoutExecutionRecord.finalizeFromWorkoutPlayer` inside `AthleteWorkoutOrchestrator.completeTodayWorkout`.
- **M8 persistence** remains via `PerformanceRecordSaveCoordinator.completeSession` from `ActivePerformanceDraft` (unchanged API and UX).
- **`WorkoutExecutionOutcomeMapper`** bridges M8 draft block status → domain `WorkoutExerciseExecutionEntry` list at finish (adapter, not a second source of truth during the session).

Programme finish order on Home path:

1. Domain completion (orchestrator + optional `WorkoutExecutionRecordStore.save`)
2. M8 save + progression + `AdaptationExecutionCoordinator`
3. UI projection only

## Consequences

- Two persisted “records” conceptually: domain (in-memory store today) and M8 (Supabase). They must stay consistent via ordered finish steps, not merged types.
- Name collision resolved: M8 = `TrainingSessionRecord`; domain = `WorkoutExecutionRecord`.

## Alternatives considered

- **Map domain record → M8 only** — deferred to Phase 4; would require mapper-owned field parity tests.
- **Drop domain record; M8 only** — rejected; breaks occurrence-centric history and future coach analytics.

## Migration implications

- Phase 4: Supabase port for domain records or explicit mapper from domain → M8 RPC inputs.
- Do not mutate completed domain or M8 aggregates (immutability principle unchanged).
