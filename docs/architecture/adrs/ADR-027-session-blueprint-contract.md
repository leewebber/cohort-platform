# ADR-027: SessionBlueprint bridges Session Generator and Exercise Policy

**Status:** Accepted (Phase 3.5 architecture)  
**Date:** 2026-07-29  
**Related:** ADR-025, ADR-026

## Context

`PlanningRecommendation` is macro/micro semantic (intents, phase, archetype). Execution requires a session-shaped artifact before movements are chosen. A gap existed between recommendation and `SessionExecutionPlan`.

## Decision

Introduce **`SessionBlueprint`** as the output of **Session Generator** and input to **Exercise Policy Engine**.

**Required conceptual fields:**

| Field | Purpose |
|-------|---------|
| `blueprintId` | Traceability |
| `sessionObjective` | Coaching objective for the session |
| `desiredAdaptations` | Capabilities/intents this session should stress |
| `sessionArchetypeId` | Knowledge archetype |
| `intensityTarget` | Semantic intensity band |
| `volumeTarget` | Semantic volume band |
| `requiredCapabilityIds` | Must be addressed by policy selection |
| `allowedSubstitutionPolicy` | Tags (preserve intent, preserve pattern, etc.) |
| `constraints` | Time, equipment, environment |
| `planningRecommendationRef` | Link to source recommendation |

**Explicit exclusions:** exercise list, block/step structure with movements, loads.

Session Generator **owns** translating `PlanningRecommendation` → `SessionBlueprint`.  
Exercise Policy **owns** `SessionBlueprint` → `SessionExecutionPlan` (or adapter).

## Consequences

- Session Generator may not call Supabase exercise stores directly; policy owns catalogue access.
- Unit tests: blueprint in → plan out, with intent preserved assertions.

## Alternatives considered

- **Skip blueprint; policy reads PlanningRecommendation directly** — rejected; mixes session structure targets with movement selection.

## Migration implications

- Phase 4b implements generator stub returning archetype + bands only.
