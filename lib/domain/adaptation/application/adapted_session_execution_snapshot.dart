import '../contracts/block_adaptation_policy.dart';
import '../evaluation/adaptation_evaluation_result.dart';
import '../planning/adaptation_plan_result.dart';
import '../planning/adaptation_plan_rationale.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_confidence.dart';
import '../vocabulary/adaptation_fidelity.dart';
import '../vocabulary/block_priority.dart';
import '../vocabulary/session_intent.dart';
import 'prescription_execution_snapshot.dart';

/// Lifecycle marker for in-memory execution snapshots (persistence in Task 3).
enum AdaptedSessionExecutionSnapshotStatus { ready }

class ExerciseExecutionSnapshot {
  const ExerciseExecutionSnapshot({
    required this.exerciseLinkLocalId,
    required this.exerciseId,
    required this.originalPrescription,
    required this.executionPrescription,
    required this.adapted,
    required this.appliedPlanStepSequences,
  });

  final String exerciseLinkLocalId;
  final String exerciseId;
  final PrescriptionExecutionSnapshot originalPrescription;
  final PrescriptionExecutionSnapshot executionPrescription;
  final bool adapted;
  final List<int> appliedPlanStepSequences;
}

class BlockExecutionSnapshot {
  const BlockExecutionSnapshot({
    required this.sourceBlockLocalId,
    required this.sourcePosition,
    required this.blockTypeDbValue,
    required this.effectivePriority,
    required this.effectivePolicy,
    required this.policySource,
    required this.exercises,
    required this.adapted,
    required this.appliedPlanStepSequences,
  });

  final String sourceBlockLocalId;
  final int sourcePosition;
  final String blockTypeDbValue;
  final BlockPriority effectivePriority;
  final BlockAdaptationPolicy effectivePolicy;
  final AdaptationPolicySource policySource;
  final List<ExerciseExecutionSnapshot> exercises;
  final bool adapted;
  final List<int> appliedPlanStepSequences;
}

class OmittedBlockExecutionRecord {
  const OmittedBlockExecutionRecord({
    required this.sourceBlockLocalId,
    required this.sourcePosition,
    required this.blockTypeDbValue,
    required this.omissionAction,
    required this.rationaleCode,
    required this.policySource,
    required this.planStepSequence,
    this.capturedExercises = const [],
  });

  final String sourceBlockLocalId;
  final int sourcePosition;
  final String blockTypeDbValue;
  final AdaptationActionType omissionAction;
  final AdaptationPlanRationaleCode rationaleCode;
  final AdaptationPolicySource policySource;
  final int planStepSequence;
  final List<ExerciseExecutionSnapshot> capturedExercises;
}

enum AdaptationStepApplicationStatus { applied }

class AdaptationStepAuditEntry {
  const AdaptationStepAuditEntry({
    required this.planStepSequence,
    required this.actionType,
    required this.targetScopeDbValue,
    required this.targetId,
    required this.rationaleCode,
    required this.applicationStatus,
    this.blockLocalId,
    this.exerciseLinkLocalId,
    this.originalValueReference,
    this.appliedValueReference,
    this.expectedTimeSavingMinutes,
    this.expectedTimeSavingUnknown = false,
    this.policySource,
    this.effectOnFidelity,
  });

  final int planStepSequence;
  final AdaptationActionType actionType;
  final String targetScopeDbValue;
  final String targetId;
  final String? blockLocalId;
  final String? exerciseLinkLocalId;
  final AdaptationPlanRationaleCode rationaleCode;
  final String? originalValueReference;
  final String? appliedValueReference;
  final int? expectedTimeSavingMinutes;
  final bool expectedTimeSavingUnknown;
  final AdaptationPolicySource? policySource;
  final AdaptationFidelity? effectOnFidelity;
  final AdaptationStepApplicationStatus applicationStatus;
}

/// Immutable execution snapshot for today's adapted (or unadapted) session.
///
/// Not persisted in Task 2B — attaches to Session Occurrence aggregate in Task 3.
class AdaptedSessionExecutionSnapshot {
  const AdaptedSessionExecutionSnapshot({
    required this.snapshotId,
    required this.sourceProtocolId,
    required this.status,
    required this.originalPlannedDurationMin,
    required this.resultingEstimatedDurationMin,
    required this.durationEstimateReliable,
    required this.primarySessionIntent,
    required this.secondarySessionIntents,
    required this.retainedBlocks,
    required this.omittedBlocks,
    required this.appliedAdaptationAudit,
    required this.expectedFidelity,
    required this.adaptationConfidence,
    required this.evaluationOutcome,
    required this.planStatus,
    required this.unresolvedConstraints,
    required this.exactDurationFeasibilityConfirmed,
    required this.unresolvedDurationDeficitMinutes,
    required this.planFindings,
  });

  final String snapshotId;
  final String sourceProtocolId;
  final AdaptedSessionExecutionSnapshotStatus status;
  final int? originalPlannedDurationMin;
  final int? resultingEstimatedDurationMin;
  final bool durationEstimateReliable;
  final SessionIntent? primarySessionIntent;
  final List<SessionIntent> secondarySessionIntents;
  final List<BlockExecutionSnapshot> retainedBlocks;
  final List<OmittedBlockExecutionRecord> omittedBlocks;
  final List<AdaptationStepAuditEntry> appliedAdaptationAudit;
  final AdaptationFidelity expectedFidelity;
  final AdaptationConfidence adaptationConfidence;
  final AdaptationEvaluationOutcome evaluationOutcome;
  final AdaptationPlanStatus planStatus;
  final List<AdaptationConstraintContextSummary> unresolvedConstraints;
  final bool exactDurationFeasibilityConfirmed;
  final int? unresolvedDurationDeficitMinutes;
  final List<AdaptationPlanRationaleCode> planFindings;
}
