import 'package:cohort_platform/domain/adaptation/vocabulary/movement_pattern.dart';
import 'package:cohort_platform/domain/adaptation/vocabulary/training_environment.dart';
import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';

import 'exercise_knowledge_fixtures.dart';
import 'exercise_movement_content_fixtures.dart';

/// Graph contract fixtures — hotel / limited-equipment examples (not production).
class ExerciseRelationshipGraphFixtures {
  ExerciseRelationshipGraphFixtures._();

  static final barbellRdl = ExerciseDefinition(
    id: ExerciseId.parse('EX-9011'),
    canonicalName: 'Barbell Romanian Deadlift',
    modality: ExerciseModality.strength,
    familyId: 'family.hinge',
    movementPatterns: const [MovementPattern.hinge],
    laterality: ExerciseLaterality.bilateral,
    technicalComplexity: ExerciseTechnicalComplexity.intermediate,
    impactLevel: ExerciseImpactLevel.moderate,
    validPrescriptionDimensions: const [
      PerformanceDimension.load,
      PerformanceDimension.repetitions,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.load,
      PerformanceDimension.repetitions,
    ],
    equipment: const EquipmentRequirement(
      requiredTokens: ['barbell'],
      supportsExternalLoad: true,
    ),
    environments: const EnvironmentSuitability(
      suitable: [TrainingEnvironment.fullGym, TrainingEnvironment.commercialGym],
      unsuitable: [TrainingEnvironment.hotelRoom],
    ),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  /// Barbell RDL → dumbbell RDL with equipment constraints.
  static final barbellRdlToDbRdl = ExerciseRelationship(
    id: 'rel.ex9011.ex9003.equipment_alternative',
    sourceExerciseId: barbellRdl.id,
    targetExerciseId: ExerciseKnowledgeFixtures.dbRdl.id,
    relationshipType: ExerciseRelationshipType.equipmentAlternative,
    substitutionConstraint: const SubstitutionConstraint(
      requiredEquipmentTokens: ['dumbbell'],
      forbiddenEquipmentTokens: [],
      mustPreserveCharacteristics: ['hinge_pattern'],
    ),
    preservesIntentNotes:
        'May preserve hinge pattern with dumbbells; not the same load history.',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  /// Structurally valid but requires kettlebell equipment the context may lack.
  static final gobletRequiresKettlebell = ExerciseRelationship(
    id: 'rel.ex9001.ex9002.equipment_alt_kb_required',
    sourceExerciseId: ExerciseKnowledgeFixtures.backSquat.id,
    targetExerciseId: ExerciseKnowledgeFixtures.gobletSquat.id,
    relationshipType: ExerciseRelationshipType.equipmentAlternative,
    substitutionConstraint: const SubstitutionConstraint(
      requiredEquipmentTokens: ['kettlebell'],
      requiredEnvironments: [TrainingEnvironment.hotelGym],
      mustPreserveCharacteristics: ['squat_pattern'],
    ),
    preservesIntentNotes:
        'Eligible only when kettlebell is available — still not auto-selected.',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  /// Retired edge — historically resolvable, excluded from operational graph.
  static final retiredBackSquatToGoblet = ExerciseRelationship(
    id: 'rel.ex9001.ex9002.equipment_alternative.retired',
    sourceExerciseId: ExerciseKnowledgeFixtures.backSquat.id,
    targetExerciseId: ExerciseKnowledgeFixtures.gobletSquat.id,
    relationshipType: ExerciseRelationshipType.relatedNonComparable,
    substitutionConstraint: const SubstitutionConstraint(
      mustPreserveCharacteristics: ['squat_pattern'],
    ),
    preservesIntentNotes: 'Prior related edge, retired; historical only.',
    lifecycleStatus: ExerciseLifecycleStatus.retired,
    version: '1',
    publishedAt: DateTime.utc(2026, 1, 1),
    retiredAt: DateTime.utc(2026, 8, 1),
  );

  /// Published edge to missing/unpublished target — fail closed.
  static final edgeToMissingTarget = ExerciseRelationship(
    id: 'rel.ex9001.ex9997.environment_alternative',
    sourceExerciseId: ExerciseKnowledgeFixtures.backSquat.id,
    targetExerciseId: ExerciseId.parse('EX-9997'),
    relationshipType: ExerciseRelationshipType.environmentAlternative,
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static ExerciseCatalogueSnapshot operationalSnapshot() {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: 'graph-fixtures-1',
      definitions: [
        ...ExerciseKnowledgeFixtures.allDefinitions,
        barbellRdl,
      ],
      relationships: [
        ExerciseKnowledgeFixtures.backSquatToGoblet,
        ExerciseKnowledgeFixtures.skiErgToBanded,
        ExerciseKnowledgeFixtures.outdoorToTreadmill,
        ExerciseKnowledgeFixtures.backSquatToHotelBw,
        barbellRdlToDbRdl,
      ],
      comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
      movementStandards: [
        ExerciseMovementContentFixtures.movementStandard,
      ],
    );
  }

  static ExerciseCatalogueSnapshot historicalSnapshot() {
    return operationalSnapshot().copyWith(
      relationships: [
        ...operationalSnapshot().relationships,
        retiredBackSquatToGoblet,
      ],
    );
  }
}
