# Training Intent Ontology v1

Phase 3 Sprint 5 — semantic layer between **capability gaps** and future **session/programme** generation.

## Layered responsibilities

| Concept | Question it answers | Persistence in v1 | Example id |
|---------|---------------------|-------------------|------------|
| **Programme goal** | What outcome is the athlete pursuing? | `goal_requirements.yaml` | `cohort.goal.hyrox_sub_60` |
| **Capability** | What quality must be expressed or developed? | `capabilities.yaml` | `cohort.capability.threshold` |
| **Training intent** | What *type* of training addresses a capability gap? | `training_intents.yaml` | `cohort.training_intent.tempo_development` |
| **Session intent** | What is this *single session’s* primary emphasis? | Platform `SessionIntent` enum + builder | `SessionIntent.threshold` (runtime) |
| **Session archetype** | What high-level session *shape* fits an intent? | `session_archetypes.yaml` | `cohort.session_archetype.tempo_run` |
| **Exercise** | What movement implements load? | `exercises_reference.yaml` + platform `Exercise` | `cohort.exercise.back_squat` |

### Relationships (conceptual)

```mermaid
flowchart LR
  Goal[Programme goal] --> Req[Required capabilities]
  Req --> Gap[Capability gap]
  Gap --> TI[Training intent]
  TI --> SA[Session archetype]
  SA --> SI[Session intent at plan time]
  SI --> Ex[Exercise selection later]
```

- **Goals** declare required/optional **capabilities** (Sprint 3).
- **Gap analysis** ranks underdeveloped capabilities (Sprint 4).
- **Training intents** answer how to train toward a capability — via **capability → intent mappings** with suitability and progression stage.
- **Session archetypes** are templates (duration structure, fatigue class) — not prescriptions.
- **Session intent** (platform) is the coach-facing label on a planned session; it should align with ontology training intents but is not identical (legacy enum + richer YAML taxonomy).
- **Exercises** attach to intents secondarily (`supports_training_intents`) for substitution and curation — not for gap resolution.

## Training intent vs session intent

| | Training intent (knowledge) | Session intent (platform) |
|--|----------------------------|---------------------------|
| Scope | Mesocycle / priority theme | One session draft |
| Granularity | ~30 curated taxonomy nodes | Enum + builder metadata |
| Gap engine output | Yes | No (Sprint 6+) |
| Exercise binding | Indirect via archetypes | Direct in session builder |

Reconciliation: legacy YAML ids (e.g. `cohort.training_intent.aerobic_base`) map philosophically to `SessionIntent.aerobicConditioning` / similar — see `Vocabulary_Reconciliation_v1.md` for migration notes.

## Capability → intent mapping

File: `knowledge/reference/capability_intent_mappings.yaml`

Each mapping includes:

- `capability_id`, `training_intent_id`
- `suitability` (0–1)
- `progression_stage` (`foundation` … `recovery`)
- `prerequisite_intent_ids`, `prerequisite_capability_ids`
- `rationale`

Example: **Threshold** capability → tempo development, cruise intervals, threshold progression (multiple contextual options).

## Session archetypes

File: `knowledge/reference/session_archetypes.yaml`

Semantic templates only — e.g. Long easy run, Tempo run, Heavy lower, Carry session. Linked to training intents via `primary_training_intent_ids` and intent `common_session_archetype_ids`.

## Read-only API

`TrainingIntentGraphReader` on `KnowledgeGraphReader`:

- `intentsForCapability`
- `archetypesForIntent`
- `intentsForGoal`
- `progressionOptions`

Gap bridge: `TrainingIntentResolutionReader` / `TrainingIntentFromGapsService`.

## Version

Ontology **1.2.0** (Sprint 5). No Coach Brain wiring in this sprint.

## Sprint 6 handoff

- Map training intents + archetypes → session builder / `SessionIntent`
- Programme structure generation (still separate from exercise selection policy)
- Optional: rank archetypes by gap score + fatigue budget
