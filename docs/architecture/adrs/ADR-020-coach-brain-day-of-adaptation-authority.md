# ADR-020: Coach Brain is the sole day-of adaptation authority

**Status:** Accepted (Phase 2 complete); **clarified for Plan Package programmes (Sprint 1.6B)**  
**Date:** 2026-07-29  
**Clarified:** 2026-08-03  
**Supersedes:** ADR-011 (dual pre-session adaptation paths)  
**Programme companion:** [Athlete_Programme_Acceptance_Gated_Adaptation_v1.md](../Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)

## Context

Home previously used `AdaptationDecisionService` (removed Sprint 6B) alongside domain pipeline code, creating duplicate evaluation gates and divergent snapshots.

## Decision (historical Plan Library / occurrence path)

Day-of session adaptation for the **legacy Plan Library / SessionOccurrence** Home flows runs through:

1. `AthleteWorkoutAdaptationApplicationService`
2. `CoachDecisionRouter` / session adaptation handler
3. `SessionAdaptationPipeline` (evaluate → plan → apply)
4. `SessionOccurrence.attachAdaptation` on athlete accept (`commitDayOfAdaptation`)

`HomeAdaptationDecisionPresenter` maps Coach Brain snapshot outcomes to sheet copy only — **no** independent `ConstraintEvaluator` gate in the presenter.

Declining the sheet does **not** attach an adapted snapshot; baseline snapshot on the occurrence remains unchanged.

## Clarification — Authored Plan Package programmes (binding)

For materialised Authored Plan Package programmes, the **authored programme is the sole prescription authority**. Coach Brain must **not** author, personalise, optimise, or progress that programme for different athletes.

Coach Brain’s only role in the programme adaptation workstream is to help the athlete execute the **current prescribed session** as faithfully as possible when real-world constraints make exact execution impractical. That role is fulfilled by the established deterministic `SessionAdaptationPipeline` (evaluate → plan → apply), not by generative daily planning or Adaptive Progression.

Programme-backed day-of adaptation therefore:

1. Uses a **Plan-Package-native adapter** (`PlanPackageSessionAdaptationAdapter`) that translates the current prepared prescription into pipeline input.
2. Invokes `SessionAdaptationPipeline` **directly** (translation/orchestration only).
3. Does **not** depend on the generative Plan Library product path, Adaptive Progression, or athlete-specific reauthoring.
4. Does **not** use `CoachDecisionRouter` merely to preserve an architectural label. The router may remain for legacy Plan Library / occurrence wiring; it is not the programme prescription authority.
5. Mutates prepared execution **only** after explicit athlete acceptance (Sprint 1.6C+). Sprint 1.6B is propose/review only.
6. Returns typed **no-safe-adaptation** when the constraint cannot be met while preserving authored intent closely enough.

This clarification supersedes any older reading of ADR-020 that would allow Coach Brain, `CoachDecisionRouter`, Adaptive Progression, or another service to reauthor programmes, generate athlete-specific intervals, rewrite progression, change future sessions, or alter scheduling under the name of day-of adaptation.

## Consequences

- Legacy Plan Library / occurrence Adapt may continue to use the historical application → router → pipeline → attach path.
- Programme Home Adapt uses Plan-Package-native adapter → pipeline → proposal/review (accept in 1.6C).
- Programme **post-completion** adaptation remains `AdaptationExecutionCoordinator` (ADR-022) and stays closed for Phase 1.

## Alternatives considered

- **Presenter-side second gate** — removed Sprint 6B (dual authority).
- **Direct Home → pipeline without Brain** — historically rejected for Plan Library extensibility; **adopted for Plan Package programmes** via a thin native adapter so generative Coach Brain cannot become a parallel prescription authority.
- **Reuse CoachDecisionRouter on the programme path solely for labeling** — rejected unless proven necessary; programme path calls the pipeline through the Plan-Package-native adapter.

## Migration implications

- New day-of **compute** rules belong in the domain evaluator/planner (`SessionAdaptationPipeline`).
- Programme product wiring belongs in the Plan-Package-native adapter and proposal service.
- Historical docs referencing `AdaptationDecisionService` remain superseded, not deleted.
