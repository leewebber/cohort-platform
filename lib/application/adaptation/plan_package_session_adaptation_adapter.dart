import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/coach_brain/session_adaptation/session_adaptation_pipeline.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/recovery_state.dart';
import 'package:cohort_platform/models/session_block_type.dart';

import 'adaptation_request_constraint_mapper.dart';
import 'planned_session_adaptation_input_adapter.dart';
import 'planned_session_protocol_metadata_merge.dart';
import 'programme_adaptation_permission_gate.dart';
import 'approved_time_option.dart';
import 'approved_recovery_option.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';

/// Failure thrown when the prepared package cannot be adapted lawfully.
class PlanPackageAdaptationAdapterException implements Exception {
  PlanPackageAdaptationAdapterException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PlanPackageAdaptationAdapterException($code): $message';
}

/// Thin Plan-Package-native translation into [SessionAdaptationPipeline].
///
/// Translation and orchestration only — not a second adaptation engine, not a
/// programme author, and not a progression service. Does not call the legacy
/// decision router, Adaptive Progression, or Plan Library generation.
class PlanPackageSessionAdaptationAdapter {
  PlanPackageSessionAdaptationAdapter({
    SessionAdaptationPipeline? pipeline,
    KnowledgeGraphReader? knowledge,
  }) : pipeline = pipeline ?? SessionAdaptationPipeline(knowledge: knowledge);

  final SessionAdaptationPipeline pipeline;

  /// Validates provenance, asserts day-of policy kinds, builds pipeline input
  /// from authored protocol content, and runs evaluate → plan → apply.
  ///
  /// Compute-only: never mutates [package] or any durable store.
  SessionAdaptationPipelineRun evaluate({
    required PreparedExecutionPackage package,
    required AdaptationRequest request,
    required ProtocolDraft authoredDraft,
    List<PlanPackageAdaptationPermission> adaptationPermissions = const [],
    String? slotKey,
    ApprovedTimeOption? timeApproval,
    ApprovedRecoveryOption? recoveryApproval,
    ProgrammeExecutionContext? executionContext,
    Map<String, ExerciseAdaptationMetadataForEvaluation>? exerciseMetadataById,
  }) {
    _assertEligiblePackage(package);
    _assertDraftMatchesPackage(package, authoredDraft);

    const AdaptationPolicyGate().assertAllowed(
      AdaptationPolicyGate.kindsForDayOf(request.reason),
    );

    if (request.reason == AdaptationReason.equipment) {
      final permission = const ProgrammeAdaptationPermissionGate()
          .allowEquipmentSubstitution(
            permissions: adaptationPermissions,
            slotKey: slotKey,
          );
      if (!permission.allowed) {
        throw PlanPackageAdaptationAdapterException(
          'substitution_not_permitted',
          'Authored adaptation permissions do not permit equipment '
              'substitution (${permission.denial?.name}).',
        );
      }
    }

    if (recoveryApproval != null &&
        (timeApproval != null ||
            request.reason != AdaptationReason.recovery ||
            request.recoveryState != RecoveryState.poorSleep)) {
      throw PlanPackageAdaptationAdapterException(
        'recovery_option_unavailable',
        'No approved recovery adjustment for this workout.',
      );
    }
    final approvedOmission = recoveryApproval?.omission ?? timeApproval;
    final policyDraft =
        approvedOmission?.authorize(
          package: package,
          context: executionContext,
          draft: authoredDraft,
        ) ??
        authoredDraft;
    final planned = package.plan.protocol != null
        ? PlannedSessionProtocolMetadataMerge.merge(
            draft: policyDraft,
            protocol: package.plan.protocol!,
          )
        : PlannedSessionAdaptationInputAdapter.fromProtocolDraft(
            policyDraft,
            exerciseMetadataById: exerciseMetadataById,
          );

    if (planned.protocolId.trim() != package.protocolId?.trim()) {
      throw PlanPackageAdaptationAdapterException(
        'protocol_mismatch',
        'Authored protocol id does not match the prepared session protocol.',
      );
    }

    if (planned.blocks.isEmpty) {
      throw PlanPackageAdaptationAdapterException(
        'empty_prescription',
        'Prepared session has no authored blocks to adapt.',
      );
    }

    final constraints = AdaptationRequestConstraintMapper.fromRequest(request);
    final run = pipeline.run(
      plannedSession: planned,
      // The fixed endpoint bounds the existing omission planner. It is set
      // by the Recovery approval and is independent of athlete time budget.
      constraints: recoveryApproval == null
          ? constraints
          : constraints.copyWith(
              availableDurationMin: recoveryApproval.omission.shortMinutes,
            ),
    );
    if (recoveryApproval != null ||
        (request.reason == AdaptationReason.time &&
            run.plan.status != AdaptationPlanStatus.noPlanRequired)) {
      final approved = const ProgrammeAdaptationPermissionGate()
          .allowsOptionalAccessoryOmission(
            permissions: adaptationPermissions,
            slotKey: slotKey,
          );
      final removable = policyDraft.blocks.where(
        (block) =>
            block.blockType == SessionBlockType.accessory &&
            block.blockPriority == BlockPriority.optional &&
            block.adaptationPolicy?.canRemove == true,
      );
      final steps = run.plan.steps;
      final shortened = run.application.snapshot?.resultingEstimatedDurationMin;
      final budget =
          recoveryApproval?.omission.shortMinutes ?? request.availableMinutes;
      final originalDuration = policyDraft.durationMin;
      final preparedDuration = package.plan.durationMin;
      if (!approved ||
          removable.length != 1 ||
          !run.plan.exactDurationFeasibilityConfirmed ||
          steps.length != 1 ||
          steps.single.actionType != AdaptationActionType.removeBlock ||
          steps.single.blockLocalId != removable.single.localId ||
          shortened == null ||
          budget == null ||
          shortened > budget ||
          shortened != policyDraft.minimumViableDurationMin ||
          originalDuration == null ||
          (preparedDuration != originalDuration &&
              !(approvedOmission != null && preparedDuration == null)) ||
          steps.single.expectedTimeSavingMinutes !=
              originalDuration - shortened) {
        throw PlanPackageAdaptationAdapterException(
          'time_option_unavailable',
          recoveryApproval == null
              ? 'No coach-approved shorter option fits the time you selected.'
              : 'No approved recovery adjustment for this workout.',
        );
      }
    }
    return run;
  }

  void _assertEligiblePackage(PreparedExecutionPackage package) {
    if (!package.isProgrammeBacked) {
      throw PlanPackageAdaptationAdapterException(
        'not_programme_backed',
        'Adaptation requires a programme-backed prepared session.',
      );
    }
    if (package.protocolId == null || package.protocolId!.trim().isEmpty) {
      throw PlanPackageAdaptationAdapterException(
        'missing_protocol',
        'Prepared session is missing protocol identity.',
      );
    }
    if (package.assignmentId == null || package.assignmentId!.trim().isEmpty) {
      throw PlanPackageAdaptationAdapterException(
        'missing_assignment',
        'Prepared session is missing assignment identity.',
      );
    }
    if (package.plan.blocks.isEmpty) {
      throw PlanPackageAdaptationAdapterException(
        'empty_prepared_plan',
        'Prepared SessionExecutionPlan has no executable blocks.',
      );
    }
  }

  void _assertDraftMatchesPackage(
    PreparedExecutionPackage package,
    ProtocolDraft draft,
  ) {
    final packageProtocol = package.protocolId?.trim() ?? '';
    final draftProtocol = draft.protocolId.trim();
    if (packageProtocol.isEmpty || draftProtocol != packageProtocol) {
      throw PlanPackageAdaptationAdapterException(
        'draft_protocol_mismatch',
        'Loaded authored draft does not match prepared protocol identity.',
      );
    }
  }
}
