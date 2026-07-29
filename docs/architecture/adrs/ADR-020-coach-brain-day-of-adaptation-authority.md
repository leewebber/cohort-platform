# ADR-020: Coach Brain is the sole day-of adaptation authority

**Status:** Accepted (Phase 2 complete)  
**Date:** 2026-07-29  
**Supersedes:** ADR-011 (dual pre-session adaptation paths)

## Context

Home previously used `AdaptationDecisionService` (removed Sprint 6B) alongside domain pipeline code, creating duplicate evaluation gates and divergent snapshots.

## Decision

Day-of session adaptation for programme Home flows **must** run through:

1. `AthleteWorkoutAdaptationApplicationService`
2. `CoachDecisionRouter` / session adaptation handler
3. `SessionAdaptationPipeline` (evaluate → plan → apply)
4. `SessionOccurrence.attachAdaptation` on athlete accept (`commitDayOfAdaptation`)

`HomeAdaptationDecisionPresenter` maps Coach Brain snapshot outcomes to sheet copy only — **no** independent `ConstraintEvaluator` gate in the presenter.

Declining the sheet does **not** attach an adapted snapshot; baseline snapshot on the occurrence remains unchanged.

## Consequences

- Internal tools and Home share the same application service entry where wired.
- Programme **post-completion** adaptation remains `AdaptationExecutionCoordinator` (ADR-022) — not Coach Brain day-of pipeline.

## Alternatives considered

- **Presenter-side second gate** — removed Sprint 6B (dual authority).
- **Direct Home → pipeline without Brain** — rejected; breaks extensibility and handler registration model.

## Migration implications

- New day-of rules belong in domain evaluator/planner, invoked only via Brain handler.
- Historical docs referencing `AdaptationDecisionService` are marked superseded, not deleted.
