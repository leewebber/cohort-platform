import '../vocabulary/adaptation_constraint_scope.dart';
import '../vocabulary/adaptation_constraint_severity.dart';
import '../vocabulary/block_priority.dart';
import '../vocabulary/canonical_technical_complexity.dart';
import '../vocabulary/exercise_category.dart';
import '../vocabulary/exercise_loading_potential.dart';
import '../vocabulary/exercise_placement_role.dart';
import '../vocabulary/exercise_training_effect.dart';
import '../vocabulary/impact_level.dart';
import '../vocabulary/movement_characteristic.dart';
import '../vocabulary/movement_pattern.dart';
import '../vocabulary/physiological_emphasis.dart';
import '../vocabulary/session_difficulty.dart';
import '../vocabulary/session_intent.dart';
import '../vocabulary/session_modality.dart';
import '../vocabulary/training_environment.dart';
import 'block_adaptation_policy.dart';
import 'minimum_viable_prescription.dart';

/// Minimum authored metadata for a session (protocol revision).
class SessionAdaptationMetadata {
  const SessionAdaptationMetadata({
    required this.primaryIntent,
    this.secondaryIntent,
    this.modality,
    this.physiologicalEmphasis,
    this.expectedDurationMinutes,
    this.minimumViableDurationMinutes,
    this.environments = const [],
    this.requiredEquipment = const [],
    this.difficulty,
    this.technicalComplexity,
    this.impact,
  });

  final SessionIntent primaryIntent;
  final SessionIntent? secondaryIntent;
  final SessionModality? modality;
  final PhysiologicalEmphasis? physiologicalEmphasis;
  final int? expectedDurationMinutes;
  final int? minimumViableDurationMinutes;
  final List<TrainingEnvironment> environments;
  final List<String> requiredEquipment;
  final SessionDifficulty? difficulty;
  final CanonicalTechnicalComplexity? technicalComplexity;
  final ImpactLevel? impact;
}

/// Minimum authored metadata for a block within a session.
class BlockAdaptationMetadata {
  const BlockAdaptationMetadata({
    required this.blockTypeDbValue,
    this.intent,
    this.priority,
    this.adaptationPolicy,
    this.minimumViablePrescription,
    this.dependsOnBlockIds = const [],
  });

  final String blockTypeDbValue;
  final SessionIntent? intent;
  final BlockPriority? priority;
  final BlockAdaptationPolicy? adaptationPolicy;
  final MinimumViablePrescription? minimumViablePrescription;
  final List<String> dependsOnBlockIds;
}

/// Minimum metadata for an exercise placement within a block.
class ExercisePlacementAdaptationMetadata {
  const ExercisePlacementAdaptationMetadata({
    required this.exerciseId,
    this.role,
    this.replaceable = true,
    this.removable = false,
    this.priority,
    this.prescriptionReference,
  });

  final String exerciseId;
  final ExercisePlacementRole? role;
  final bool replaceable;
  final bool removable;
  final BlockPriority? priority;
  final String? prescriptionReference;
}

/// Structured exercise library metadata for substitution (future persisted graph).
enum ExerciseSubstitutionRelationshipType {
  regression,
  progression,
  lateralAlternative,
  equivalent,
  samePattern,
}

extension ExerciseSubstitutionRelationshipTypeDb
    on ExerciseSubstitutionRelationshipType {
  String get dbValue {
    return switch (this) {
      ExerciseSubstitutionRelationshipType.regression => 'regression',
      ExerciseSubstitutionRelationshipType.progression => 'progression',
      ExerciseSubstitutionRelationshipType.lateralAlternative =>
        'lateral_alternative',
      ExerciseSubstitutionRelationshipType.equivalent => 'equivalent',
      ExerciseSubstitutionRelationshipType.samePattern => 'same_pattern',
    };
  }

  static ExerciseSubstitutionRelationshipType? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in ExerciseSubstitutionRelationshipType.values) {
      if (type.dbValue == normalized) return type;
    }
    return null;
  }
}

class ExerciseSubstitutionRelationship {
  const ExerciseSubstitutionRelationship({
    required this.fromExerciseId,
    required this.toExerciseId,
    required this.relationshipType,
    this.substitutionGroupId,
  });

  final String fromExerciseId;
  final String toExerciseId;
  final ExerciseSubstitutionRelationshipType relationshipType;
  final String? substitutionGroupId;
}

/// Minimum structured exercise catalogue metadata for adaptation.
class ExerciseAdaptationMetadata {
  const ExerciseAdaptationMetadata({
    required this.exerciseId,
    this.movementPatterns = const [],
    this.trainingEffects = const [],
    this.loadingPotential,
    this.equipment = const [],
    this.environments = const [],
    this.technicalComplexity,
    this.impact,
    this.movementCharacteristics = const [],
    this.category,
    this.substitutionRelationships = const [],
  });

  final String exerciseId;
  final List<MovementPattern> movementPatterns;
  final List<ExerciseTrainingEffect> trainingEffects;
  final ExerciseLoadingPotential? loadingPotential;
  final List<String> equipment;
  final List<TrainingEnvironment> environments;
  final CanonicalTechnicalComplexity? technicalComplexity;
  final ImpactLevel? impact;
  final List<MovementCharacteristic> movementCharacteristics;
  final ExerciseCategory? category;
  final List<ExerciseSubstitutionRelationship> substitutionRelationships;
}
