import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';

import 'plan_package_session_adaptation_adapter.dart';
import 'programme_adaptation_proposal_mapper.dart';

typedef ProgrammeProtocolDraftLoader =
    Future<ProtocolDraft> Function(String protocolId);

/// Compute-only programme adaptation proposal entry (Sprint 1.6B).
///
/// Does not accept, persist, mutate prepared packages, advance cursors, or
/// invoke Adaptive Progression / Plan Library generation / legacy decision
/// routing.
class ProgrammeAdaptationProposalService {
  ProgrammeAdaptationProposalService({
    PlanPackageSessionAdaptationAdapter? adapter,
    ProgrammeProtocolDraftLoader? loadProtocolDraft,
  }) : _adapter = adapter ?? const PlanPackageSessionAdaptationAdapter(),
       _loadProtocolDraft =
           loadProtocolDraft ??
           ((protocolId) => ProtocolBuilderService().loadProtocol(protocolId));

  final PlanPackageSessionAdaptationAdapter _adapter;
  final ProgrammeProtocolDraftLoader _loadProtocolDraft;

  /// Evaluates a proposal against a currently prepared programme package.
  ///
  /// Always returns a typed proposal/result. Never mutates [package].
  Future<ProgrammeAdaptationProposal> propose({
    required PreparedExecutionPackage package,
    required AdaptationRequest request,
    DateTime? proposedAt,
  }) async {
    if (!_isEligible(package)) {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: request,
        noSafeReason: package.isProgrammeBacked
            ? ProgrammeAdaptationNoSafeReason.staleOrMismatchedPreparedSession
            : ProgrammeAdaptationNoSafeReason.notProgrammeBacked,
        message:
            'Cohort could not safely adapt this session because the prepared '
            'session is missing or invalid. Your programme has not changed.',
        proposedAt: proposedAt,
      );
    }

    try {
      const AdaptationPolicyGate().assertAllowed(
        AdaptationPolicyGate.kindsForDayOf(request.reason),
      );
    } on AdaptationPolicyException {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: request,
        noSafeReason: ProgrammeAdaptationNoSafeReason.policyRejected,
        message:
            'Cohort could not safely adapt this session because the requested '
            'change is not permitted by coaching policy. Your prescribed '
            'programme and prepared session are unchanged.',
        proposedAt: proposedAt,
      );
    }

    try {
      final draft = await _loadProtocolDraft(package.protocolId!.trim());
      final run = _adapter.evaluate(
        package: package,
        request: request,
        authoredDraft: draft,
      );
      return ProgrammeAdaptationProposalMapper.fromPipelineRun(
        package: package,
        request: request,
        run: run,
        authoredDraft: draft,
        proposedAt: proposedAt,
      );
    } on PlanPackageAdaptationAdapterException catch (error) {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: request,
        noSafeReason: _mapAdapterCode(error.code),
        message:
            'Cohort could not safely adapt this session. ${error.message} '
            'Your prescribed programme has not changed, and your current '
            'prepared session remains available.',
        proposedAt: proposedAt,
      );
    } catch (_) {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: request,
        noSafeReason: ProgrammeAdaptationNoSafeReason.pipelineUnableToPlan,
        message:
            'Cohort could not safely adapt this session under your current '
            'constraint. Your prescribed programme has not changed, and your '
            'current prepared session remains available.',
        proposedAt: proposedAt,
      );
    }
  }

  bool _isEligible(PreparedExecutionPackage package) {
    return package.isProgrammeBacked &&
        package.protocolId != null &&
        package.protocolId!.trim().isNotEmpty &&
        package.assignmentId != null &&
        package.assignmentId!.trim().isNotEmpty &&
        package.plan.blocks.isNotEmpty;
  }

  ProgrammeAdaptationNoSafeReason _mapAdapterCode(String code) {
    return switch (code) {
      'not_programme_backed' =>
        ProgrammeAdaptationNoSafeReason.notProgrammeBacked,
      'draft_protocol_mismatch' ||
      'protocol_mismatch' ||
      'missing_protocol' ||
      'missing_assignment' ||
      'empty_prescription' ||
      'empty_prepared_plan' =>
        ProgrammeAdaptationNoSafeReason.staleOrMismatchedPreparedSession,
      _ => ProgrammeAdaptationNoSafeReason.pipelineUnableToPlan,
    };
  }
}
