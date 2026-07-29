# ADR-024: Coach Brain orchestrates planning; day-of adaptation authority preserved

**Status:** Accepted (Phase 3.5 architecture)  
**Date:** 2026-07-29  
**Related:** ADR-020 (day-of adaptation), ADR-023 (Planning Engine)

## Context

ADR-020 establishes Coach Brain as the **sole day-of session adaptation authority** via `SessionAdaptationPipeline`. Phase 4 adds **macro/micro planning** (“what should the athlete train next?”) requiring orchestration across multiple engines.

Risk: Coach Brain accumulates coaching knowledge and duplicate ranking logic.

## Decision

Coach Brain **expands** to orchestrate **planning runs**:

1. Accept `PlanningInput`
2. Invoke Gap Engine, Training Intent Engine, Programme Semantics readers, Planning Engine
3. Apply **policies** (recovery downgrade, coach override, travel simplification)
4. Return `PlanningRecommendation` + explainability envelope

Coach Brain **must not**:

- Embed YAML taxonomy or gap scoring formulas
- Select exercises or change training intent emphasis (Exercise Policy / engine owners)

**ADR-020 remains in force:** day-of **session adaptation** (evaluate → plan → apply on an existing planned session) stays on the existing handler + `SessionAdaptationPipeline`. Planning orchestration is a **separate handler** (e.g. `PlanningCoachDecisionHandler`).

## Consequences

- Two Brain paths: **planning** (pre-session structure) vs **adaptation** (day-of change to attached plan).
- Home/application services call Brain for both; ownership table in `Planning_Engine_v1.md` §4 prevents duplicate decisions.
- Stub handlers in `stub_coach_decision_handlers.dart` gain real planning handler in Phase 4 — not a second adaptation pipeline.

## Alternatives considered

- **Planning Engine invoked directly from UI** — rejected; loses policy centralization and audit.
- **Merge ADR-020 into Planning Engine** — rejected; adaptation ontology is session-scoped, not macro planning.

## Migration implications

- Document handler registration order and feature flags in Phase 4 sprint plans.
- Presenters remain mapping-only (ADR-020 pattern).
