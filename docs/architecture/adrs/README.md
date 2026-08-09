# Architecture Decision Records

## Historical architecture-alignment ADRs (pre–Phase 1)

Records **ADR-017–ADR-022** formalize decisions from the earlier
architecture-alignment effort (then labeled Phase 2A, Sprints 6–10). See
[Architecture_Blueprint_v2.md §17](../Architecture_Blueprint_v2.md) and the
historical
[Phase_2_Architecture_Consolidation_Completion.md](../Phase_2_Architecture_Consolidation_Completion.md).

**Current Phase 2** (post–Phase 1 Architecture Consolidation) does **not** treat
ADR-020’s “Coach Brain sole day-of” claim as authoritative for materialised
programme athletes. Programme adaptation follows Sprint 1.6
(`Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`).

| ID | Title |
|----|--------|
| [ADR-017](./ADR-017-session-occurrence-canonical-identity.md) | SessionOccurrence is the canonical workout identity |
| [ADR-018](./ADR-018-workout-player-canonical-runtime.md) | WorkoutPlayer is the canonical runtime state machine |
| [ADR-019](./ADR-019-workout-execution-record-canonical-completion.md) | WorkoutExecutionRecord is the canonical completion aggregate |
| [ADR-020](./ADR-020-coach-brain-day-of-adaptation-authority.md) | Historical: Coach Brain day-of (Plan Library path; superseded for programme athletes by Sprint 1.6) |
| [ADR-021](./ADR-021-ui-m8-compatibility-adapters.md) | Existing UI and M8 persistence remain behind compatibility adapters |
| [ADR-022](./ADR-022-post-completion-adaptation-distinct.md) | Programme post-completion adaptation remains distinct from day-of workout adaptation |

**Superseded:** ADR-011 (dual pre-session adaptation paths) — superseded by ADR-020 as of Sprint 6B for the Plan Library day-of path; programme path further refined by Phase 1 Sprint 1.6.

## Phase 3.5 — Planning Engine architecture

| ID | Title |
|----|--------|
| [ADR-023](./ADR-023-planning-engine-ownership.md) | Planning Engine owns planning merge, not knowledge or exercises |
| [ADR-024](./ADR-024-coach-brain-planning-orchestrator.md) | Coach Brain orchestrates planning; day-of adaptation authority preserved |
| [ADR-025](./ADR-025-exercise-policy-semantic-boundary.md) | Exercise Policy owns movement selection; never changes intent |
| [ADR-026](./ADR-026-planning-recommendation-contract.md) | PlanningRecommendation canonical output (no exercises) |
| [ADR-027](./ADR-027-session-blueprint-contract.md) | SessionBlueprint between generator and exercise policy |

**Blueprint:** [Planning_Engine_v1.md](../Planning_Engine_v1.md)
