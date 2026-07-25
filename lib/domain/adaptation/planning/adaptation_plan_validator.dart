import '../evaluation/adaptation_evaluation_result.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_constraint_scope.dart';
import '../vocabulary/block_priority.dart';
import 'adaptation_plan_result.dart';
import 'adaptation_plan_step.dart';
import 'session_adaptation_planner.dart';

/// Deterministic validation for generated adaptation plans.
class AdaptationPlanValidator {
  const AdaptationPlanValidator();

  static const unsupportedPlanActionTypes = {
    AdaptationActionType.swapExercise,
    AdaptationActionType.replaceBlock,
    AdaptationActionType.replaceSession,
    AdaptationActionType.removeExercise,
  };

  AdaptationPlanValidationResult validate({
    required PlannedSessionAdaptationInput session,
    required SessionAdaptationEvaluationResult evaluation,
    required AdaptationPlanResult plan,
  }) {
    final issues = <AdaptationPlanValidationIssue>[];

    if (plan.exactDurationFeasibilityConfirmed &&
        plan.unresolvedDurationDeficitMinutes != null &&
        plan.unresolvedDurationDeficitMinutes! > 0) {
      issues.add(
        const AdaptationPlanValidationIssue(
          code: AdaptationPlanValidationIssueCode
              .exactDurationClaimedWithUnresolvedDeficit,
        ),
      );
    }

    if (plan.adaptationConfidence.index < evaluation.adaptationConfidence.index) {
      issues.add(
        const AdaptationPlanValidationIssue(
          code: AdaptationPlanValidationIssueCode.confidenceExceedsEvaluation,
        ),
      );
    }

    final blockIds = session.blocks.map((b) => b.localId).toSet();
    final targetsByKey = <String, AdaptationPlanStep>{};
    var lastSequence = 0;

    for (final step in plan.steps) {
      if (step.sequence <= lastSequence) {
        issues.add(
          AdaptationPlanValidationIssue(
            code: AdaptationPlanValidationIssueCode.stepsNotOrdered,
            stepSequence: step.sequence,
          ),
        );
      }
      lastSequence = step.sequence;

      if (unsupportedPlanActionTypes.contains(step.actionType)) {
        issues.add(
          AdaptationPlanValidationIssue(
            code: AdaptationPlanValidationIssueCode.unsupportedActionType,
            stepSequence: step.sequence,
          ),
        );
      }

      if (step.blockLocalId != null && !blockIds.contains(step.blockLocalId)) {
        issues.add(
          AdaptationPlanValidationIssue(
            code: AdaptationPlanValidationIssueCode.unknownTarget,
            stepSequence: step.sequence,
          ),
        );
      }

      final targetKey = '${step.targetScope.dbValue}:${step.targetId}:${step.actionType.name}';
      if (targetsByKey.containsKey(targetKey)) {
        issues.add(
          AdaptationPlanValidationIssue(
            code: AdaptationPlanValidationIssueCode.contradictoryTargetActions,
            stepSequence: step.sequence,
          ),
        );
      }
      targetsByKey[targetKey] = step;

      if (step.actionType == AdaptationActionType.removeBlock) {
        final block = _block(session, step.blockLocalId);
        if (block != null) {
          final resolved = SessionAdaptationPlanner.resolveBlock(block);
          if (resolved.effectivePriority == BlockPriority.essential) {
            issues.add(
              AdaptationPlanValidationIssue(
                code: AdaptationPlanValidationIssueCode.essentialBlockRemoved,
                stepSequence: step.sequence,
              ),
            );
          }
          if (!resolved.effectivePolicy.canRemove) {
            issues.add(
              AdaptationPlanValidationIssue(
                code: AdaptationPlanValidationIssueCode.removalNotPermittedByPolicy,
                stepSequence: step.sequence,
              ),
            );
          }
        }
      }

      if (step.prescriptionReduction != null) {
        final reduction = step.prescriptionReduction!;
        if (!reduction.isValid) {
          issues.add(
            AdaptationPlanValidationIssue(
              code: AdaptationPlanValidationIssueCode.invalidPrescriptionValues,
              stepSequence: step.sequence,
            ),
          );
        }
        if (reduction.proposedValue >= reduction.originalValue) {
          issues.add(
            AdaptationPlanValidationIssue(
              code: AdaptationPlanValidationIssueCode.prescriptionVolumeIncreased,
              stepSequence: step.sequence,
            ),
          );
        }
      }
    }

    for (final protected in plan.protectedElements) {
      if (!blockIds.contains(protected.blockLocalId)) {
        issues.add(
          const AdaptationPlanValidationIssue(
            code: AdaptationPlanValidationIssueCode.unknownTarget,
          ),
        );
      }
    }

    return AdaptationPlanValidationResult(
      isValid: issues.isEmpty,
      issues: List.unmodifiable(issues),
    );
  }

  PlannedBlockAdaptationInput? _block(
    PlannedSessionAdaptationInput session,
    String? localId,
  ) {
    if (localId == null) return null;
    for (final block in session.blocks) {
      if (block.localId == localId) return block;
    }
    return null;
  }
}

enum AdaptationPlanValidationIssueCode {
  stepsNotOrdered,
  unknownTarget,
  contradictoryTargetActions,
  essentialBlockRemoved,
  removalNotPermittedByPolicy,
  invalidPrescriptionValues,
  prescriptionVolumeIncreased,
  unsupportedActionType,
  exactDurationClaimedWithUnresolvedDeficit,
  confidenceExceedsEvaluation,
}

class AdaptationPlanValidationIssue {
  const AdaptationPlanValidationIssue({
    required this.code,
    this.stepSequence,
  });

  final AdaptationPlanValidationIssueCode code;
  final int? stepSequence;
}

class AdaptationPlanValidationResult {
  const AdaptationPlanValidationResult({
    required this.isValid,
    required this.issues,
  });

  final bool isValid;
  final List<AdaptationPlanValidationIssue> issues;
}
