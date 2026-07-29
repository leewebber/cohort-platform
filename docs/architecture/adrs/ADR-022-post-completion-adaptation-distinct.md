# ADR-022: Programme post-completion adaptation remains distinct from day-of workout adaptation

**Status:** Accepted (unchanged; reaffirmed Phase 2)  
**Date:** 2026-07-29  
**Related:** ADR-012, `66_V2_0_End_To_End_Execution_And_Adaptation.md`

## Context

Two adaptation concerns exist: (1) changing **today’s** executable snapshot before/during session start, and (2) mutating **future programme slots** after an M8 save based on completed performance.

## Decision

- **Day-of:** `SessionAdaptationPipeline` + Coach Brain (ADR-020); evaluate/plan/apply on `PlannedSessionAdaptationInput`; attaches snapshot to **current** occurrence.
- **Post-completion:** `AdaptationExecutionCoordinator` after `PerformanceRecordSaveCoordinator.completeSession`; deterministic rules on M8 record; mutates future slot outcomes; idempotent audit events.

These paths **must not** be merged or invoked interchangeably.

## Consequences

- Completing a workout triggers coordinator **after** M8 persistence, regardless of domain `WorkoutExecutionRecord` save.
- Day-of decline leaves future slots unchanged; day-of accept does not replace post-completion load progression rules.

## Alternatives considered

- **Single adaptation service for both** — rejected; different inputs, mutability, and audit requirements (`79` ontology vs programme engine).

## Migration implications

- Domain completion may eventually **feed** post-completion evaluator inputs, but coordinator remains the programme mutation entry point until explicitly redesigned in a later phase.
