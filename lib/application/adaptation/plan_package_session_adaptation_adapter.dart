import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/coach_brain/session_adaptation/session_adaptation_pipeline.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';

import 'adaptation_request_constraint_mapper.dart';
import 'planned_session_adaptation_input_adapter.dart';
import 'planned_session_protocol_metadata_merge.dart';

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
  const PlanPackageSessionAdaptationAdapter({
    this.pipeline = const SessionAdaptationPipeline(),
  });

  final SessionAdaptationPipeline pipeline;

  /// Validates provenance, asserts day-of policy kinds, builds pipeline input
  /// from authored protocol content, and runs evaluate → plan → apply.
  ///
  /// Compute-only: never mutates [package] or any durable store.
  SessionAdaptationPipelineRun evaluate({
    required PreparedExecutionPackage package,
    required AdaptationRequest request,
    required ProtocolDraft authoredDraft,
    Map<String, ExerciseAdaptationMetadataForEvaluation>? exerciseMetadataById,
  }) {
    _assertEligiblePackage(package);
    _assertDraftMatchesPackage(package, authoredDraft);

    const AdaptationPolicyGate().assertAllowed(
      AdaptationPolicyGate.kindsForDayOf(request.reason),
    );

    final planned = package.plan.protocol != null
        ? PlannedSessionProtocolMetadataMerge.merge(
            draft: authoredDraft,
            protocol: package.plan.protocol!,
          )
        : PlannedSessionAdaptationInputAdapter.fromProtocolDraft(
            authoredDraft,
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

    return pipeline.run(
      plannedSession: planned,
      constraints: AdaptationRequestConstraintMapper.fromRequest(request),
    );
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
