import 'adapted_session_execution_snapshot.dart';

enum AdaptationPlanApplicationStatus {
  applied,
  noAdaptationRequired,
  rejectedInvalidPlan,
  rejectedSourceMismatch,
  applicationFailed,
  unsupportedPlanStep,
}

enum AdaptationPlanApplicationIssueCode {
  planNotApplicable,
  planValidationFailed,
  sourceSessionMismatch,
  unknownBlockTarget,
  unknownExerciseTarget,
  essentialBlockRemoval,
  removalNotPermitted,
  duplicateBlockRemoval,
  stalePrescriptionOriginalValue,
  prescriptionBelowMinimum,
  prescriptionVolumeIncrease,
  unsupportedActionType,
  policyMismatch,
  snapshotValidationFailed,
}

class AdaptationPlanApplicationIssue {
  const AdaptationPlanApplicationIssue({
    required this.code,
    this.planStepSequence,
    this.detail,
  });

  final AdaptationPlanApplicationIssueCode code;
  final int? planStepSequence;
  final String? detail;
}

class AdaptationPlanApplicationResult {
  const AdaptationPlanApplicationResult({
    required this.status,
    this.snapshot,
    this.issues = const [],
  });

  final AdaptationPlanApplicationStatus status;
  final AdaptedSessionExecutionSnapshot? snapshot;
  final List<AdaptationPlanApplicationIssue> issues;

  bool get isSuccess =>
      status == AdaptationPlanApplicationStatus.applied ||
      status == AdaptationPlanApplicationStatus.noAdaptationRequired;
}
