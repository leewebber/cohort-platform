import 'package:cohort_platform/domain/adaptation/vocabulary/movement_pattern.dart';
import 'package:cohort_platform/domain/adaptation/vocabulary/training_environment.dart';
import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';

/// Contract-test fixtures only — not production seeds.
class ExerciseKnowledgeFixtures {
  ExerciseKnowledgeFixtures._();

  static final backSquat = ExerciseDefinition(
    id: ExerciseId.parse('EX-9001'),
    canonicalName: 'Barbell Back Squat',
    aliases: const ['back squat', 'bb back squat'],
    modality: ExerciseModality.strength,
    familyId: 'family.squat',
    movementPatterns: const [MovementPattern.squat],
    laterality: ExerciseLaterality.bilateral,
    technicalComplexity: ExerciseTechnicalComplexity.intermediate,
    impactLevel: ExerciseImpactLevel.high,
    validPrescriptionDimensions: const [
      PerformanceDimension.load,
      PerformanceDimension.repetitions,
      PerformanceDimension.rpe,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.load,
      PerformanceDimension.repetitions,
      PerformanceDimension.rpe,
    ],
    equipment: const EquipmentRequirement(
      requiredTokens: ['barbell', 'squat_rack'],
      supportsExternalLoad: true,
    ),
    environments: const EnvironmentSuitability(
      suitable: [TrainingEnvironment.fullGym, TrainingEnvironment.commercialGym],
      unsuitable: [TrainingEnvironment.hotelRoom],
    ),
    transitionalAliasIds: const ['cohort.exercise.back_squat'],
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final gobletSquat = ExerciseDefinition(
    id: ExerciseId.parse('EX-9002'),
    canonicalName: 'Goblet Squat',
    aliases: const ['goblet squat'],
    modality: ExerciseModality.strength,
    familyId: 'family.squat',
    movementPatterns: const [MovementPattern.squat],
    laterality: ExerciseLaterality.bilateral,
    technicalComplexity: ExerciseTechnicalComplexity.beginner,
    impactLevel: ExerciseImpactLevel.moderate,
    validPrescriptionDimensions: const [
      PerformanceDimension.load,
      PerformanceDimension.repetitions,
      PerformanceDimension.rpe,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.load,
      PerformanceDimension.repetitions,
      PerformanceDimension.rpe,
    ],
    equipment: const EquipmentRequirement(
      requiredTokens: ['dumbbell'],
      oneOfGroups: [
        ['dumbbell', 'kettlebell'],
      ],
      supportsExternalLoad: true,
    ),
    environments: const EnvironmentSuitability(
      suitable: [
        TrainingEnvironment.fullGym,
        TrainingEnvironment.hotelGym,
        TrainingEnvironment.home,
      ],
    ),
    transitionalAliasIds: const ['cohort.exercise.goblet_squat'],
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final dbRdl = ExerciseDefinition(
    id: ExerciseId.parse('EX-9003'),
    canonicalName: 'Dumbbell Romanian Deadlift',
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
      requiredTokens: ['dumbbell'],
      supportsExternalLoad: true,
    ),
    environments: const EnvironmentSuitability(
      suitable: [
        TrainingEnvironment.fullGym,
        TrainingEnvironment.hotelGym,
        TrainingEnvironment.home,
      ],
    ),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final outdoorRun = ExerciseDefinition(
    id: ExerciseId.parse('EX-9004'),
    canonicalName: 'Outdoor Running',
    modality: ExerciseModality.locomotion,
    movementPatterns: const [MovementPattern.locomotion],
    laterality: ExerciseLaterality.notApplicable,
    technicalComplexity: ExerciseTechnicalComplexity.beginner,
    impactLevel: ExerciseImpactLevel.moderate,
    validPrescriptionDimensions: const [
      PerformanceDimension.distance,
      PerformanceDimension.duration,
      PerformanceDimension.pace,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.distance,
      PerformanceDimension.duration,
      PerformanceDimension.pace,
    ],
    equipment: const EquipmentRequirement(),
    environments: const EnvironmentSuitability(
      suitable: [
        TrainingEnvironment.outdoors,
        TrainingEnvironment.track,
      ],
      unsuitable: [TrainingEnvironment.hotelRoom],
    ),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final treadmillRun = ExerciseDefinition(
    id: ExerciseId.parse('EX-9005'),
    canonicalName: 'Treadmill Running',
    modality: ExerciseModality.locomotion,
    movementPatterns: const [MovementPattern.locomotion],
    laterality: ExerciseLaterality.notApplicable,
    technicalComplexity: ExerciseTechnicalComplexity.beginner,
    impactLevel: ExerciseImpactLevel.moderate,
    validPrescriptionDimensions: const [
      PerformanceDimension.distance,
      PerformanceDimension.duration,
      PerformanceDimension.pace,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.distance,
      PerformanceDimension.duration,
      PerformanceDimension.pace,
    ],
    equipment: const EquipmentRequirement(requiredTokens: ['treadmill']),
    environments: const EnvironmentSuitability(
      suitable: [
        TrainingEnvironment.commercialGym,
        TrainingEnvironment.hotelGym,
        TrainingEnvironment.fullGym,
      ],
    ),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final skiErg = ExerciseDefinition(
    id: ExerciseId.parse('EX-9006'),
    canonicalName: 'SkiErg',
    modality: ExerciseModality.erg,
    movementPatterns: const [MovementPattern.cyclical],
    laterality: ExerciseLaterality.bilateral,
    technicalComplexity: ExerciseTechnicalComplexity.intermediate,
    impactLevel: ExerciseImpactLevel.high,
    validPrescriptionDimensions: const [
      PerformanceDimension.distance,
      PerformanceDimension.duration,
      PerformanceDimension.calories,
      PerformanceDimension.power,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.distance,
      PerformanceDimension.duration,
      PerformanceDimension.calories,
      PerformanceDimension.power,
    ],
    equipment: const EquipmentRequirement(requiredTokens: ['ski_erg']),
    environments: const EnvironmentSuitability(
      suitable: [TrainingEnvironment.fullGym, TrainingEnvironment.commercialGym],
      unsuitable: [TrainingEnvironment.hotelRoom],
    ),
    sportStandardRefs: [
      SportStandardRef(
        id: KnowledgeReferenceId.parse('sport.hyrox.ski_erg'),
        sportCode: 'hyrox',
        label: 'HYROX SkiErg station',
      ),
    ],
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final bandedSki = ExerciseDefinition(
    id: ExerciseId.parse('EX-9007'),
    canonicalName: 'Banded Ski Simulation',
    modality: ExerciseModality.bodyweight,
    movementPatterns: const [MovementPattern.cyclical],
    laterality: ExerciseLaterality.bilateral,
    technicalComplexity: ExerciseTechnicalComplexity.beginner,
    impactLevel: ExerciseImpactLevel.low,
    validPrescriptionDimensions: const [
      PerformanceDimension.repetitions,
      PerformanceDimension.duration,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.repetitions,
      PerformanceDimension.duration,
    ],
    equipment: const EquipmentRequirement(requiredTokens: ['resistance_band']),
    environments: const EnvironmentSuitability(
      suitable: [
        TrainingEnvironment.hotelRoom,
        TrainingEnvironment.home,
        TrainingEnvironment.hotelGym,
      ],
    ),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final hyroxWallBalls = ExerciseDefinition(
    id: ExerciseId.parse('EX-9008'),
    canonicalName: 'HYROX Wall Balls',
    modality: ExerciseModality.sportSpecific,
    movementPatterns: const [MovementPattern.squat, MovementPattern.ballThrow],
    laterality: ExerciseLaterality.bilateral,
    technicalComplexity: ExerciseTechnicalComplexity.intermediate,
    impactLevel: ExerciseImpactLevel.high,
    validPrescriptionDimensions: const [
      PerformanceDimension.repetitions,
      PerformanceDimension.load,
      PerformanceDimension.heightOrTarget,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.repetitions,
      PerformanceDimension.load,
      PerformanceDimension.heightOrTarget,
    ],
    equipment: const EquipmentRequirement(
      requiredTokens: ['wall_ball', 'target'],
      supportsExternalLoad: true,
    ),
    environments: const EnvironmentSuitability(
      suitable: [TrainingEnvironment.fullGym, TrainingEnvironment.commercialGym],
    ),
    sportStandardRefs: [
      SportStandardRef(
        id: KnowledgeReferenceId.parse('sport.hyrox.wall_balls'),
        sportCode: 'hyrox',
        label: 'Standard HYROX wall-ball protocol',
      ),
    ],
    movementStandardRefs: [
      MovementStandardRef(
        id: KnowledgeReferenceId.parse('standard.hyrox.wall_ball_target'),
        label: 'HYROX target height / ball mass',
      ),
    ],
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final hotelBodyweightSquat = ExerciseDefinition(
    id: ExerciseId.parse('EX-9009'),
    canonicalName: 'Bodyweight Squat',
    modality: ExerciseModality.bodyweight,
    familyId: 'family.squat',
    movementPatterns: const [MovementPattern.squat],
    laterality: ExerciseLaterality.bilateral,
    technicalComplexity: ExerciseTechnicalComplexity.beginner,
    impactLevel: ExerciseImpactLevel.low,
    validPrescriptionDimensions: const [
      PerformanceDimension.repetitions,
      PerformanceDimension.rpe,
    ],
    validCompletedPerformanceDimensions: const [
      PerformanceDimension.repetitions,
      PerformanceDimension.rpe,
    ],
    equipment: const EquipmentRequirement(),
    environments: const EnvironmentSuitability(
      suitable: [
        TrainingEnvironment.hotelRoom,
        TrainingEnvironment.home,
        TrainingEnvironment.anywhere,
      ],
    ),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final backSquatComparison = ComparisonProtocol(
    id: 'cmp.back_squat.standard',
    version: '1',
    exerciseId: backSquat.id,
    validDimensions: const [
      PerformanceDimension.load,
      PerformanceDimension.repetitions,
    ],
    setupKey: 'high_bar_standard',
    label: 'Barbell back squat standard setup',
  );

  static final hyroxWallBallComparison = ComparisonProtocol(
    id: 'cmp.hyrox.wall_balls',
    version: '1',
    exerciseId: hyroxWallBalls.id,
    validDimensions: const [
      PerformanceDimension.repetitions,
      PerformanceDimension.load,
      PerformanceDimension.heightOrTarget,
    ],
    setupKey: 'hyrox_standard',
    standardRefId: 'sport.hyrox.wall_balls',
    label: 'Standard HYROX wall-ball protocol',
  );

  static final outdoorRunComparison = ComparisonProtocol(
    id: 'cmp.outdoor_run',
    version: '1',
    exerciseId: outdoorRun.id,
    validDimensions: const [
      PerformanceDimension.distance,
      PerformanceDimension.pace,
    ],
    setupKey: 'outdoor',
  );

  static List<ExerciseDefinition> get allDefinitions => [
        backSquat,
        gobletSquat,
        dbRdl,
        outdoorRun,
        treadmillRun,
        skiErg,
        bandedSki,
        hyroxWallBalls,
        hotelBodyweightSquat,
      ];

  static List<ComparisonProtocol> get allProtocols => [
        backSquatComparison,
        hyroxWallBallComparison,
        outdoorRunComparison,
      ];

  /// Adaptation-related, not directly comparable.
  static final backSquatToGoblet = ExerciseRelationship(
    id: 'rel.ex9001.ex9002.equipment_alternative',
    sourceExerciseId: backSquat.id,
    targetExerciseId: gobletSquat.id,
    relationshipType: ExerciseRelationshipType.equipmentAlternative,
    substitutionConstraint: const SubstitutionConstraint(
      requiredEnvironments: [
        TrainingEnvironment.hotelGym,
        TrainingEnvironment.home,
      ],
      mustPreserveCharacteristics: ['squat_pattern'],
    ),
    preservesIntentNotes:
        'May preserve squat pattern under limited equipment; not like-for-like load history.',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final skiErgToBanded = ExerciseRelationship(
    id: 'rel.ex9006.ex9007.environment_alternative',
    sourceExerciseId: skiErg.id,
    targetExerciseId: bandedSki.id,
    relationshipType: ExerciseRelationshipType.environmentAlternative,
    substitutionConstraint: const SubstitutionConstraint(
      requiredEnvironments: [TrainingEnvironment.hotelRoom],
      emergencyOrRegressionOnly: true,
      sportStandardRestrictionIds: ['sport.hyrox.ski_erg'],
      mustPreserveCharacteristics: ['upper_pull_cyclical'],
    ),
    preservesIntentNotes:
        'May preserve part of skiing stimulus in a hotel room; cannot share SkiErg series.',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final outdoorToTreadmill = ExerciseRelationship(
    id: 'rel.ex9004.ex9005.environment_alternative',
    sourceExerciseId: outdoorRun.id,
    targetExerciseId: treadmillRun.id,
    relationshipType: ExerciseRelationshipType.environmentAlternative,
    substitutionConstraint: const SubstitutionConstraint(
      mustPreserveCharacteristics: ['locomotion'],
    ),
    preservesIntentNotes:
        'Related for continuity; outdoor and treadmill pace are not automatically equivalent.',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final backSquatToHotelBw = ExerciseRelationship(
    id: 'rel.ex9001.ex9009.environment_alternative',
    sourceExerciseId: backSquat.id,
    targetExerciseId: hotelBodyweightSquat.id,
    relationshipType: ExerciseRelationshipType.environmentAlternative,
    substitutionConstraint: const SubstitutionConstraint(
      requiredEnvironments: [TrainingEnvironment.hotelRoom],
      emergencyOrRegressionOnly: true,
      mustPreserveCharacteristics: ['squat_pattern'],
    ),
    preservesIntentNotes:
        'Valid for hotel-room continuity; invalid for direct barbell comparison.',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  /// Invalid until an explicit protocol proves equivalence — used in negative tests.
  static ExerciseRelationship directlyComparableWithoutProtocol() {
    return ExerciseRelationship(
      id: 'rel.ex9001.ex9002.directly_comparable_invalid',
      sourceExerciseId: backSquat.id,
      targetExerciseId: gobletSquat.id,
      relationshipType: ExerciseRelationshipType.directlyComparableVariant,
      lifecycleStatus: ExerciseLifecycleStatus.draft,
      version: '1',
    );
  }

  static List<ExerciseRelationship> get validRelationships => [
        backSquatToGoblet,
        skiErgToBanded,
        outdoorToTreadmill,
        backSquatToHotelBw,
      ];
}
