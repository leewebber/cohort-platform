import '../../exercise_policy/models/exercise_policy_models.dart';
import '../../session_blueprint/models/session_blueprint.dart';

class PrescriptionRequest {
  const PrescriptionRequest({
    required this.executionPlan,
    required this.blueprint,
  });

  final SemanticSessionExecutionPlan executionPlan;
  final SessionBlueprint blueprint;
}

enum PrescriptionStatus {
  complete,
  partial,
  infeasible,
  invalidInput,
}

class PrescriptionWarning {
  const PrescriptionWarning({required this.code, required this.message});

  final String code;
  final String message;
}

enum PrescriptionExplainabilityLayer {
  blueprintSemantics,
  template,
  progression,
  role,
  constraint,
  outcome,
}

class PrescriptionExplainabilityFactor {
  const PrescriptionExplainabilityFactor({
    required this.layer,
    required this.code,
    required this.summary,
    required this.rationale,
    this.sourceEntityIds = const [],
    this.exerciseId,
  });

  final PrescriptionExplainabilityLayer layer;
  final String code;
  final String summary;
  final String rationale;
  final List<String> sourceEntityIds;
  final String? exerciseId;
}

class PrescriptionExplainability {
  const PrescriptionExplainability({
    required this.factors,
    required this.narrativeSummary,
  });

  final List<PrescriptionExplainabilityFactor> factors;
  final String narrativeSummary;
}

class PrescriptionIntervalStructure {
  const PrescriptionIntervalStructure({
    required this.rounds,
    required this.workDescription,
    required this.restDescription,
    this.workRestRatio,
  });

  final int rounds;
  final String workDescription;
  final String restDescription;
  final String? workRestRatio;
}

class ExercisePrescription {
  const ExercisePrescription({
    required this.exerciseId,
    required this.exerciseLabel,
    required this.sequence,
    required this.structuralComponentSequence,
    required this.movementRole,
    required this.sets,
    required this.repsDescription,
    this.durationMinutesMin,
    this.durationMinutesMax,
    this.distanceMetresMin,
    this.distanceMetresMax,
    this.restSeconds,
    this.rpeMin,
    this.rpeMax,
    this.effortGuidance,
    this.loadGuidance,
    this.intervals,
    required this.explainability,
  });

  final String exerciseId;
  final String exerciseLabel;
  final int sequence;
  final int structuralComponentSequence;
  final ExerciseMovementRole movementRole;
  final int sets;
  final String repsDescription;
  final int? durationMinutesMin;
  final int? durationMinutesMax;
  final int? distanceMetresMin;
  final int? distanceMetresMax;
  final int? restSeconds;
  final int? rpeMin;
  final int? rpeMax;
  final String? effortGuidance;
  final String? loadGuidance;
  final PrescriptionIntervalStructure? intervals;
  final List<PrescriptionExplainabilityFactor> explainability;
}

class PrescriptionResult {
  const PrescriptionResult({
    required this.status,
    required this.planId,
    required this.blueprintId,
    required this.sessionArchetypeId,
    required this.primaryTrainingIntentId,
    required this.prescriptions,
    required this.explainability,
    this.warnings = const [],
    required this.estimatedDurationMinutesMin,
    required this.estimatedDurationMinutesMax,
  });

  final PrescriptionStatus status;
  final String planId;
  final String blueprintId;
  final String sessionArchetypeId;
  final String primaryTrainingIntentId;
  final List<ExercisePrescription> prescriptions;
  final PrescriptionExplainability explainability;
  final List<PrescriptionWarning> warnings;
  final int estimatedDurationMinutesMin;
  final int estimatedDurationMinutesMax;
}
