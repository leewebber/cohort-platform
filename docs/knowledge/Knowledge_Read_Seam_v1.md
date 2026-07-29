# Knowledge read seam v1 (design)

**Status:** Phase 3 Sprint 2 — interfaces + in-memory implementation; **not wired to production**

## Goals

- Persistence-independent access to curated ontology  
- Domain and Coach Brain consume **ports**, not YAML paths  
- No leakage of `YamlMap` or file layout into `lib/domain/`

## Ports (`lib/application/ports/knowledge_graph_reader.dart`)

| Port | Responsibility |
|------|------------------|
| `ExerciseKnowledgeReader` | Lookup exercise by id/alias; list exercises |
| `KnowledgeGraphReader` | Adds substitution queries |
| `CapabilityGraphReader` | Capability hierarchy, exercise mappings, goal requirements |
| `KnowledgeEntityResolver` | Map legacy strings → canonical exercise ids |

## Implementations

| Type | Path | Use |
|------|------|-----|
| `YamlKnowledgeOntologyLoader` | `lib/knowledge/io/` | Load `knowledge/` directory → bundle |
| `KnowledgeOntologyValidator` | `lib/knowledge/validation/` | Deterministic checks |
| `InMemoryKnowledgeGraphReader` | `lib/knowledge/read/` | Tests, future dev tools |
| `KnowledgeEntityResolverImpl` | same | Alias resolution |

### Capability queries (`CapabilityGraphReader`)

| Method | Behaviour |
|--------|-----------|
| `capabilityById` | Lookup node |
| `childrenOf` | Capabilities listing this id in `parent_ids` |
| `parentsOf` | Resolved parent nodes |
| `supportingCapabilities` | Nodes listed in `supporting_capability_ids` |
| `capabilitiesForExercise` | Primary / secondary / supporting lists |
| `exercisesDevelopingCapability` | Exercises referencing capability in any role |
| `goalRequirements` | Required / optional capability ids for a goal |
| `allGoals` | All goal metadata entries |

## Future production wiring (Sprint 3+)

1. Application composition root loads bundle at startup (or lazy singleton).  
2. Inject `KnowledgeGraphReader` into adaptation mappers **behind feature flags**.  
3. Optional Supabase projection of ontology — still maps to same Dart models.  
4. Coach Brain substitution handler uses `querySubstitutions` — not hard-coded lists.

## Dependency rule

```
features / application  →  ports  ←  lib/knowledge (models + readers)
domain/adaptation       →  may depend on ports only when integrated (later)
domain                  →  must not import lib/knowledge/io (YAML)
```

## Query example

```dart
reader.querySubstitutions(
  SubstitutionQuery(
    sourceExerciseId: 'cohort.exercise.back_squat',
    constraintTags: ['no_barbell', 'hotel_gym'],
    trainingIntentId: 'cohort.training_intent.lower_body_hypertrophy',
  ),
);
```

See `test/knowledge/ontology_validation_test.dart`.
