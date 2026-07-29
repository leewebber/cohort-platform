import '../evaluation/adaptation_evaluation_result.dart';
import '../planning/adaptation_plan_result.dart';
import '../planning/session_adaptation_planner.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/block_priority.dart';
import 'adapted_session_execution_snapshot.dart';

enum AdaptedSessionExecutionSnapshotIssueCode {
  missingSourceProtocolId,
  duplicateRetainedBlockId,
  duplicateOmittedBlockId,
  blockBothRetainedAndOmitted,
  essentialBlockMissing,
  unknownRetainedBlock,
  unknownOmittedBlock,
  auditStepCountMismatch,
  unplannedAdaptation,
  volumeIncrease,
  exactDurationClaimWithoutEvidence,
  confidenceExceedsPlan,
  fidelityExceedsPlan,
  unsupportedActionInAudit,
}

class AdaptedSessionExecutionSnapshotIssue {
  const AdaptedSessionExecutionSnapshotIssue({required this.code});

  final AdaptedSessionExecutionSnapshotIssueCode code;
}

class AdaptedSessionExecutionSnapshotValidationResult {
  const AdaptedSessionExecutionSnapshotValidationResult({
    required this.isValid,
    required this.issues,
  });

  final bool isValid;
  final List<AdaptedSessionExecutionSnapshotIssue> issues;
}

/// Validates adapted execution snapshots against source and plan.
class AdaptedSessionExecutionSnapshotValidator {
  const AdaptedSessionExecutionSnapshotValidator();

  AdaptedSessionExecutionSnapshotValidationResult validate({
    required PlannedSessionAdaptationInput source,
    required AdaptationPlanResult plan,
    required AdaptedSessionExecutionSnapshot snapshot,
  }) {
    final issues = <AdaptedSessionExecutionSnapshotIssue>[];

    if (snapshot.sourceProtocolId.trim().isEmpty) {
      issues.add(
        const AdaptedSessionExecutionSnapshotIssue(
          code:
              AdaptedSessionExecutionSnapshotIssueCode.missingSourceProtocolId,
        ),
      );
    }

    if (snapshot.sourceProtocolId != source.protocolId) {
      issues.add(
        const AdaptedSessionExecutionSnapshotIssue(
          code:
              AdaptedSessionExecutionSnapshotIssueCode.missingSourceProtocolId,
        ),
      );
    }

    final sourceBlockIds = source.blocks.map((b) => b.localId).toSet();
    final retainedIds = <String>{};
    for (final block in snapshot.retainedBlocks) {
      if (!retainedIds.add(block.sourceBlockLocalId)) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code: AdaptedSessionExecutionSnapshotIssueCode
                .duplicateRetainedBlockId,
          ),
        );
      }
      if (!sourceBlockIds.contains(block.sourceBlockLocalId)) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code: AdaptedSessionExecutionSnapshotIssueCode.unknownRetainedBlock,
          ),
        );
      }
    }

    final omittedIds = <String>{};
    for (final omitted in snapshot.omittedBlocks) {
      if (!omittedIds.add(omitted.sourceBlockLocalId)) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code: AdaptedSessionExecutionSnapshotIssueCode
                .duplicateOmittedBlockId,
          ),
        );
      }
      if (!sourceBlockIds.contains(omitted.sourceBlockLocalId)) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code: AdaptedSessionExecutionSnapshotIssueCode.unknownOmittedBlock,
          ),
        );
      }
      if (retainedIds.contains(omitted.sourceBlockLocalId)) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code: AdaptedSessionExecutionSnapshotIssueCode
                .blockBothRetainedAndOmitted,
          ),
        );
      }
    }

    for (final sourceBlock in source.blocks) {
      final resolved = SessionAdaptationPlanner.resolveBlock(sourceBlock);
      if (resolved.effectivePriority != BlockPriority.essential) continue;
      if (!retainedIds.contains(sourceBlock.localId)) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code:
                AdaptedSessionExecutionSnapshotIssueCode.essentialBlockMissing,
          ),
        );
      }
    }

    for (final block in snapshot.retainedBlocks) {
      if (block.adapted && block.appliedPlanStepSequences.isEmpty) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code: AdaptedSessionExecutionSnapshotIssueCode.unplannedAdaptation,
          ),
        );
      }
      for (final exercise in block.exercises) {
        if (exercise.executionPrescription.sets != null &&
            exercise.originalPrescription.sets != null &&
            exercise.executionPrescription.sets! >
                exercise.originalPrescription.sets!) {
          issues.add(
            const AdaptedSessionExecutionSnapshotIssue(
              code: AdaptedSessionExecutionSnapshotIssueCode.volumeIncrease,
            ),
          );
        }
        if (exercise.adapted &&
            exercise.executionPrescription.sets ==
                exercise.originalPrescription.sets) {
          issues.add(
            const AdaptedSessionExecutionSnapshotIssue(
              code:
                  AdaptedSessionExecutionSnapshotIssueCode.unplannedAdaptation,
            ),
          );
        }
      }
    }

    final plannedSteps = plan.steps.length;
    if (snapshot.appliedAdaptationAudit.length != plannedSteps &&
        plan.status != AdaptationPlanStatus.noPlanRequired) {
      issues.add(
        const AdaptedSessionExecutionSnapshotIssue(
          code: AdaptedSessionExecutionSnapshotIssueCode.auditStepCountMismatch,
        ),
      );
    }

    for (final entry in snapshot.appliedAdaptationAudit) {
      if (entry.actionType == AdaptationActionType.swapExercise ||
          entry.actionType == AdaptationActionType.replaceBlock ||
          entry.actionType == AdaptationActionType.replaceSession) {
        issues.add(
          const AdaptedSessionExecutionSnapshotIssue(
            code: AdaptedSessionExecutionSnapshotIssueCode
                .unsupportedActionInAudit,
          ),
        );
      }
    }

    if (snapshot.exactDurationFeasibilityConfirmed &&
        !snapshot.durationEstimateReliable) {
      issues.add(
        const AdaptedSessionExecutionSnapshotIssue(
          code: AdaptedSessionExecutionSnapshotIssueCode
              .exactDurationClaimWithoutEvidence,
        ),
      );
    }

    if (snapshot.adaptationConfidence.index < plan.adaptationConfidence.index) {
      issues.add(
        const AdaptedSessionExecutionSnapshotIssue(
          code: AdaptedSessionExecutionSnapshotIssueCode.confidenceExceedsPlan,
        ),
      );
    }

    if (snapshot.expectedFidelity.index < plan.expectedFidelity.index) {
      issues.add(
        const AdaptedSessionExecutionSnapshotIssue(
          code: AdaptedSessionExecutionSnapshotIssueCode.fidelityExceedsPlan,
        ),
      );
    }

    return AdaptedSessionExecutionSnapshotValidationResult(
      isValid: issues.isEmpty,
      issues: List.unmodifiable(issues),
    );
  }
}
