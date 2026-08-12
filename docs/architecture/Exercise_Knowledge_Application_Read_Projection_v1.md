# Exercise Knowledge Application Read Projection v1

**Status:** Complete and founder-accepted
**Scope:** Local, UI-neutral published text-guidance projection
**Accepted implementation:** `9bc5cd7cc78d0fe771aa7608ba717ec88787a0c2`

## Application boundary

`OperationalExerciseTextGuidanceQueryService.query(String)` accepts one
caller-supplied canonical `EX-*` identity. It resolves the operational
`ExerciseDefinition` and reads `ExerciseMovementKnowledge` through the
caller-supplied `ExerciseKnowledgeRepository`.

The immutable `OperationalExerciseTextGuidance` output contains:

- canonical exercise ID and canonical name;
- published `MovementStandard` text fields;
- published `CoachingContent` text fields.

Records are ordered by content ID and version. Authored sequence order is
preserved. Canonical JSON and equality are deterministic.

## Validation and outcomes

The service reuses `ExerciseId`, operational repository visibility,
`ExerciseMovementContentValidator`, and the existing publication contracts.
It validates the complete text input before returning a projection and never
mutates the supplied aggregate.

Typed outcomes are:

- `invalid_canonical_exercise_id`;
- `missing_published_exercise_definition`;
- `operational_text_guidance_unavailable`;
- `content_projection_invariant_violation`;
- resolved immutable guidance.

Transitional IDs, aliases, names, draft/retired definitions, unpublished text,
identity mismatches, and malformed published content fail closed. No partial
guidance is returned from invalid input.

## Authority boundaries

Canonical identity remains owned by canonical Exercise Definitions. The
projection cannot create, normalize, infer, repair, alias, or remap identity.
It does not consume the transitional-ID bridge or founder YAML importer.

The output contains no programme prescription, athlete actuals or evidence,
adaptation, comparison, substitution, movement relationship, Plan Package,
VideoReference, media, provider, or URL field. It creates no production
composition, feature/UI consumer, Workout Player hydration, persistence,
Supabase adapter, hosted publication, or content.

The Phase 3.2D pilot is reused unchanged as local integration evidence. All
eight approved identities project one published movement standard and one
published coaching record deterministically.

## Implementation map

- Read model:
  `lib/application/exercise_knowledge/operational_exercise_text_guidance.dart`
- Query service:
  `lib/application/exercise_knowledge/operational_exercise_text_guidance_query_service.dart`
- Unit tests:
  `test/application/exercise_knowledge/operational_exercise_text_guidance_query_service_test.dart`
- Pilot integration:
  `test/application/exercise_knowledge/phase_3_2d_text_guidance_projection_integration_test.dart`
- Authority guards:
  `test/architecture/exercise_knowledge_authority_boundaries_test.dart` and
  `test/domain/exercise_knowledge/exercise_movement_content_test.dart`

## Verification

- Focused projection and architecture tests: passed.
- Exercise Knowledge domain/application regressions: 158 tests passed.
- Full Flutter suite: 2,539 tests passed; 6 skipped by repository policy.
- Phase 2 architecture safety gate: 6/6 groups passed.
- Changed Dart files: zero diagnostics.
- Full analysis: 415 issues, zero errors; unchanged from the fresh pre-edit
  count of 415.

The task-scoped bounded baseline-tolerant exception is consumed by this
implementation checkpoint. It does not establish a reusable baseline or
authorise future exceptions.
