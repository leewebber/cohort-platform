# ADR-026: PlanningRecommendation is the canonical planning output (no exercises)

**Status:** Accepted (Phase 3.5 architecture)  
**Date:** 2026-07-29  
**Related:** ADR-023, ADR-024

## Context

Planning must answer “what should this athlete train next?” without collapsing into workout prescriptions. Multiple Phase 3 engines produce partial outputs that need one athlete/coach-facing artifact.

## Decision

Define **`PlanningRecommendation`** as the canonical planning output type with **required conceptual fields**:

| Field | Purpose |
|-------|---------|
| `capabilityPriorities` | Ordered capability focus + scores + rationale |
| `trainingIntents` | Ordered training intent ids + suitability + rationale |
| `programmePhaseId` | Active semantic phase |
| `trainingBlockId` | Optional mesocycle block |
| `weekTypeId` | Weekly emphasis |
| `sessionArchetypeId` | Session template id (knowledge) |
| `adaptationRationale` | Human-readable strings |
| `constraints` | Equipment, injury, time, environment tags |
| `confidence` | Aggregate 0–1 |
| `explainability` | Structured factor tree |

**Explicit exclusions:** exercise ids, sets/reps/loads, prescription text, Supabase movement row ids.

Version field **`contractVersion`** required for evolution.

Producer: **Planning Engine** (merge), delivered via **Coach Brain** orchestration in production paths.

Consumer: **Session Generator** (primary); UI explainability surfaces (read-only).

## Consequences

- JSON schema + Dart types in Phase 4; contract tests gate breaking changes.
- LLM assistants may **summarize** `explainability` but must not replace engine outputs as source of truth.

## Alternatives considered

- **Reuse `AdaptedSessionExecutionSnapshot` for planning** — rejected; wrong grain and implies exercises/adaptations already applied.

## Migration implications

- Internal tools may render recommendations before Session Generator exists.
