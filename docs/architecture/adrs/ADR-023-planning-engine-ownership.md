# ADR-023: Planning Engine owns planning merge, not knowledge or exercises

**Status:** Accepted (Phase 3.5 architecture)  
**Date:** 2026-07-29  
**Context:** Phase 3 delivered Knowledge Layer reasoning engines (gap, intent, programme semantics) without a single composition layer. Phase 2 delivered execution (Player, Record, adaptation). Phase 3.5 defines how they connect.

## Decision

Introduce a **Planning Engine** whose sole architectural responsibility is to **merge** deterministic engine outputs and validated context into a **`PlanningRecommendation`**.

The Planning Engine:

- **Owns** merge ordering, aggregate confidence, explainability aggregation, and contract validation for planning outputs.
- **Does not own** capability ontology, gap formulas, intent mappings, phase YAML, exercise catalogues, or session runtime state.

Reasoning remains in:

- Capability Gap Engine (Phase 3 Sprint 4)
- Training Intent Engine (Phase 3 Sprint 5)
- Programme Semantics Engine (Phase 3 Sprint 6)

Knowledge remains in **Knowledge Layer** read ports.

## Consequences

- Phase 4 implements `PlanningEngineService` (or equivalent) as a **pure** compositor where possible — testable without UI or Supabase.
- No planning logic in Flutter widgets or repositories.
- Session Generator and Exercise Policy are **downstream**; they must not re-rank capability gaps.

## Alternatives considered

- **Coach Brain as merge owner** — rejected as primary; Brain orchestrates I/O and policy (ADR-024), merge stays testable in Planning Engine.
- **Single “PlanningService” in application layer without named engine** — rejected; obscures ownership in §4 matrix.

## Migration implications

- New module under `lib/domain/planning/` or `lib/application/planning/` (TBD Phase 4) — no changes to Phase 2 execution aggregates in first slice.
