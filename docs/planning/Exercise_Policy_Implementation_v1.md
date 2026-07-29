# Exercise Policy implementation v1

Phase 4 Sprint 3 — implements [ADR-025](../architecture/adrs/ADR-025-exercise-policy-semantic-boundary.md): movement selection from [SessionBlueprint](./Session_Blueprint_Implementation_v1.md) without changing intent or archetype.

## Responsibilities

`DeterministicExercisePolicyEngine`:

- Selects **knowledge exercise ids** per blueprint structural component
- Enforces equipment, environment, injury, fatigue, and substitution-tag constraints
- Applies substitution rules from the knowledge graph when equipment blocks ideal candidates
- Preserves **primary training intent** and **session archetype** from the blueprint
- Emits **semantic** `SemanticSessionExecutionPlan` (no sets, reps, loads, or timers)

Does **not** own capability ranking, phase/block/week semantics, workout execution, or Coach Brain.

## Input / output

| Type | Role |
|------|------|
| `ExercisePolicyRequest` | `SessionBlueprint` + equipment, environment, injury, travel |
| `ExercisePolicyResult` | Status, selections, explainability, execution plan |
| `SemanticSessionExecutionPlan` | Policy-layer ordered plan (distinct from M7 `SessionExecutionPlan`) |

Port: `ExercisePolicyEngine.evaluate`.

## Selection algorithm

For each blueprint structural component (sequence order):

1. Build candidate pool from `exercisesDevelopingCapability` for targeted capabilities, then full exercise catalogue.
2. **Hard-filter** (constraint hierarchy below).
3. **Score** survivors:
   - Primary capability match +3, secondary +2, supporting +1
   - Primary intent match +2; other targeted intents +1
   - Movement pattern reuse −1 per duplicate pattern (diversity)
   - Equipment miss −5 (substitution path may recover)
4. Expand pool via `querySubstitutions` for top seeds that fail equipment (intent + constraint tags).
5. Take top N per component (equipment-satisfied or substitution-backed).
6. Tie-break: score desc, then `exercise.id` asc.

## Constraint hierarchy

1. Blueprint validity (`invalidRecommendation` / infeasible blueprint → policy abort)
2. Environment (`suitable_environments` must contain request environment when defined)
3. Injury (`noOverheadLoading`, `lowImpactRequired` — pattern/id heuristics)
4. Fatigue (`fatigueReduced` — exclude high local / very high systemic where applicable)
5. Assessment / technique (`assessmentIntegrityRequired`, `techniquePriority` — exclude advanced technical demand on assessment/skill components)
6. Equipment (required equipment ⊆ available, or substitution candidate)
7. Diversity (soft scoring)

## Substitution philosophy

Substitutions are **knowledge rules only** — never invented in policy code. Rules must preserve primary intent where tagged; policy adds suitability score bonus. Policy does **not** change blueprint intent when a substitution is used.

## Intent preservation

Validator asserts result `primaryTrainingIntentId` and `sessionArchetypeId` equal blueprint values. Scoring favours exercises whose `supportsTrainingIntentIds` include the blueprint primary intent.

## Explainability

Per selection: `ExerciseSelectionReason` (capability, intent, substitution, equipment).  
Run-level: `PolicyExplainabilityFactor` layers (blueprint, constraint, candidatePool, outcome).

## Validation

`ExercisePolicyValidator` checks request blueprint status, intent/archetype preservation, primary capability coverage on **complete** results, and exercise id shape.

## No-prescription invariant

`SemanticSessionExecutionPlan` contains only exercise ids, roles, and component mapping — no prescription types. `ExercisePolicyContract.assertSemanticPlanOnly` guards plan shape.

## Future prescription layer

A later sprint maps `SemanticSessionExecutionPlan` + blueprint semantic bands → M7 `SessionExecutionPlan` with sets/reps/loads, or a dedicated prescription engine. Policy output remains the semantic movement boundary.

## Known limitations

- Reference exercise catalogue is small; outdoor running requires matching environment in requests.
- Injury heuristics use id/pattern keywords, not full clinical modelling.
- Substitution query requires constraint tag overlap with rule tags (strict reader filter).
- Primary capability coverage validation only enforced for `complete` status.

## Coach Brain / player

No Coach Brain or Workout Player integration in this sprint. Future flow: Brain accepts/rejects **recommendation**; policy runs on accepted blueprint; player consumes prescription layer only after future adapter.
