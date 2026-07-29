# Architecture Decision Records

## Phase 2 closure

Records **ADR-017–ADR-022** formalize decisions implemented during Phase 2A (Sprints 6–10). See [Architecture_Blueprint_v2.md §17](../Architecture_Blueprint_v2.md).

| ID | Title |
|----|--------|
| [ADR-017](./ADR-017-session-occurrence-canonical-identity.md) | SessionOccurrence is the canonical workout identity |
| [ADR-018](./ADR-018-workout-player-canonical-runtime.md) | WorkoutPlayer is the canonical runtime state machine |
| [ADR-019](./ADR-019-workout-execution-record-canonical-completion.md) | WorkoutExecutionRecord is the canonical completion aggregate |
| [ADR-020](./ADR-020-coach-brain-day-of-adaptation-authority.md) | Coach Brain is the sole day-of adaptation authority |
| [ADR-021](./ADR-021-ui-m8-compatibility-adapters.md) | Existing UI and M8 persistence remain behind compatibility adapters |
| [ADR-022](./ADR-022-post-completion-adaptation-distinct.md) | Programme post-completion adaptation remains distinct from day-of workout adaptation |

**Superseded:** ADR-011 (dual pre-session adaptation paths) — superseded by ADR-020 as of Sprint 6B.

## Phase 3.5 — Planning Engine architecture

| ID | Title |
|----|--------|
| [ADR-023](./ADR-023-planning-engine-ownership.md) | Planning Engine owns planning merge, not knowledge or exercises |
| [ADR-024](./ADR-024-coach-brain-planning-orchestrator.md) | Coach Brain orchestrates planning; day-of adaptation authority preserved |
| [ADR-025](./ADR-025-exercise-policy-semantic-boundary.md) | Exercise Policy owns movement selection; never changes intent |
| [ADR-026](./ADR-026-planning-recommendation-contract.md) | PlanningRecommendation canonical output (no exercises) |
| [ADR-027](./ADR-027-session-blueprint-contract.md) | SessionBlueprint between generator and exercise policy |

**Blueprint:** [Planning_Engine_v1.md](../Planning_Engine_v1.md)
