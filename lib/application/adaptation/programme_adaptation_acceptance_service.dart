import 'package:cohort_platform/features/adaptation/models/accepted_adaptation_decision.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';

import 'plan_package_session_adaptation_adapter.dart';
import 'programme_adaptation_fingerprints.dart';
import 'programme_adaptation_proposal_mapper.dart';
import 'programme_adaptation_proposal_service.dart';

/// Result of an explicit programme adaptation acceptance attempt.
class ProgrammeAdaptationAcceptanceResult {
  const ProgrammeAdaptationAcceptanceResult._({
    required this.success,
    this.package,
    this.decision,
    this.errorCode,
    this.message,
  });

  factory ProgrammeAdaptationAcceptanceResult.ok({
    required PreparedExecutionPackage package,
    required AcceptedAdaptationDecision decision,
  }) {
    return ProgrammeAdaptationAcceptanceResult._(
      success: true,
      package: package,
      decision: decision,
    );
  }

  factory ProgrammeAdaptationAcceptanceResult.failed({
    required String errorCode,
    required String message,
  }) {
    return ProgrammeAdaptationAcceptanceResult._(
      success: false,
      errorCode: errorCode,
      message: message,
    );
  }

  final bool success;
  final PreparedExecutionPackage? package;
  final AcceptedAdaptationDecision? decision;
  final String? errorCode;
  final String? message;
}

/// Explicit acceptance owner for programme-backed adaptation (Sprint 1.6C).
///
/// Mutates only the current prepared package after athlete Accept. Does not
/// advance cursor, rewrite the Plan Package, or invoke Adaptive Progression.
class ProgrammeAdaptationAcceptanceService {
  ProgrammeAdaptationAcceptanceService({
    required AthleteProgrammeSessionPrepareService prepareService,
    PlanPackageSessionAdaptationAdapter? adapter,
    ProgrammeProtocolDraftLoader? loadProtocolDraft,
  }) : _prepareService = prepareService,
       _adapter = adapter ?? const PlanPackageSessionAdaptationAdapter(),
       _loadProtocolDraft =
           loadProtocolDraft ??
           ((protocolId) => ProtocolBuilderService().loadProtocol(protocolId));

  final AthleteProgrammeSessionPrepareService _prepareService;
  final PlanPackageSessionAdaptationAdapter _adapter;
  final ProgrammeProtocolDraftLoader _loadProtocolDraft;
  final Set<String> _consumedProposalIds = <String>{};
  bool _acceptInFlight = false;

  /// Accepts a reviewed proposal against the current prepared package.
  Future<ProgrammeAdaptationAcceptanceResult> accept({
    required String athleteId,
    required PreparedExecutionPackage currentPackage,
    required ProgrammeAdaptationProposal proposal,
    required ProgrammeExecutionContext executionContext,
    DateTime? acceptedAt,
  }) async {
    if (_acceptInFlight) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'accept_in_flight',
        message:
            'An adaptation acceptance is already in progress. Your prepared '
            'session was not changed.',
      );
    }
    _acceptInFlight = true;
    try {
      return await _acceptUnlocked(
        athleteId: athleteId,
        currentPackage: currentPackage,
        proposal: proposal,
        executionContext: executionContext,
        acceptedAt: acceptedAt,
      );
    } finally {
      _acceptInFlight = false;
    }
  }

  Future<ProgrammeAdaptationAcceptanceResult> _acceptUnlocked({
    required String athleteId,
    required PreparedExecutionPackage currentPackage,
    required ProgrammeAdaptationProposal proposal,
    required ProgrammeExecutionContext executionContext,
    DateTime? acceptedAt,
  }) async {
    final stamp = acceptedAt ?? DateTime.now().toUtc();

    if (!proposal.isAcceptable) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'not_acceptable',
        message:
            'Only a reviewed adaptation proposal can be accepted. Your '
            'prepared session was not changed.',
      );
    }
    if (_consumedProposalIds.contains(proposal.proposalId)) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'proposal_consumed',
        message:
            'This adaptation proposal was already used. Your prepared session '
            'was not changed.',
      );
    }
    if (currentPackage.acceptedAdaptation != null) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'already_adapted',
        message:
            'This prepared session already has an accepted adaptation. Your '
            'prepared session was not changed.',
      );
    }
    if (!_identityMatches(currentPackage, proposal)) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'stale_identity',
        message:
            'The prepared session changed since this proposal was created. '
            'Please review again. Your prepared session was not changed.',
      );
    }
    final currentFingerprint = ProgrammeAdaptationFingerprints.plan(
      currentPackage.plan,
    );
    if (currentFingerprint != proposal.originalPlanFingerprint) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'stale_plan',
        message:
            'The prepared session plan changed since this proposal was '
            'created. Please review again. Your prepared session was not '
            'changed.',
      );
    }

    try {
      const AdaptationPolicyGate().assertAllowed(
        AdaptationPolicyGate.kindsForDayOf(proposal.reason),
      );
    } on AdaptationPolicyException {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'policy_rejected',
        message:
            'This adaptation is no longer permitted by coaching policy. Your '
            'prepared session was not changed.',
      );
    }

    // Freshness revalidation: re-run pipeline and require identical reviewed plan.
    try {
      final draft = await _loadProtocolDraft(currentPackage.protocolId!.trim());
      final run = _adapter.evaluate(
        package: currentPackage,
        request: proposal.request!,
        authoredDraft: draft,
      );
      final fresh = ProgrammeAdaptationProposalMapper.fromPipelineRun(
        package: currentPackage,
        request: proposal.request!,
        run: run,
        authoredDraft: draft,
        proposedAt: proposal.proposedAt,
      );
      if (!fresh.isAcceptable) {
        return ProgrammeAdaptationAcceptanceResult.failed(
          errorCode: 'freshness_invalid',
          message:
              'This adaptation is no longer valid for the current prepared '
              'session. Please review again. Your prepared session was not '
              'changed.',
        );
      }
      final freshFingerprint = ProgrammeAdaptationFingerprints.plan(
        fresh.reviewedExecutablePlan!,
      );
      if (freshFingerprint != proposal.reviewedPlanFingerprint) {
        return ProgrammeAdaptationAcceptanceResult.failed(
          errorCode: 'proposal_mismatch',
          message:
              'The adaptation result no longer matches what you reviewed. '
              'Please review again. Your prepared session was not changed.',
        );
      }
      if (!_materialChangesEqual(proposal, fresh)) {
        return ProgrammeAdaptationAcceptanceResult.failed(
          errorCode: 'material_change_mismatch',
          message:
              'The adaptation changes no longer match what you reviewed. '
              'Please review again. Your prepared session was not changed.',
        );
      }
    } catch (_) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'revalidation_failed',
        message:
            'Cohort could not revalidate this adaptation safely. Your '
            'prepared session was not changed.',
      );
    }

    final reviewedPlan = proposal.reviewedExecutablePlan!;
    final decision = AcceptedAdaptationDecision(
      decisionId: 'accept.${proposal.proposalId}',
      programmedSessionKey: proposal.programmedSessionKey.value,
      reasonCode: proposal.reason.name,
      acceptedAt: stamp,
      changeSummary: proposal.allMaterialChanges
          .map((c) => c.summary)
          .toList(growable: false),
      preservedIntent: proposal.preservedIntent,
      requestCategory: proposal.reason.name,
      proposalId: proposal.proposalId,
      assignmentId: proposal.assignmentId,
      programmeVersionId: proposal.programmeVersionId,
      packageContentHash: proposal.packageContentHash,
      protocolId: proposal.protocolId,
      dayKey: proposal.dayKey,
      slotOrder: proposal.slotOrder,
      derivationExplanation: proposal.derivationExplanation,
      policyKinds: proposal.policyKinds,
      evaluationProvenance: proposal.evaluationProvenance,
      sessionChanges: proposal.sessionChanges
          .map((c) => c.toPersistenceMap())
          .toList(growable: false),
      exerciseChanges: proposal.exerciseChanges
          .map((c) => c.toPersistenceMap())
          .toList(growable: false),
      proposedAt: proposal.proposedAt,
      originalPlanFingerprint: proposal.originalPlanFingerprint,
      reviewedPlanFingerprint: proposal.reviewedPlanFingerprint,
      snapshotId: proposal.snapshotId,
    );

    final brief = WorkoutSessionBrief(
      sessionName: currentPackage.brief.sessionName,
      objective: currentPackage.brief.objective,
      estimatedDurationMinutes:
          reviewedPlan.durationMin ??
          currentPackage.brief.estimatedDurationMinutes,
      primaryFocus: currentPackage.brief.primaryFocus,
      trainingIntent: currentPackage.brief.trainingIntent,
      sessionDifficulty: currentPackage.brief.sessionDifficulty,
      sessionNotes: currentPackage.brief.sessionNotes,
      coachNotes: reviewedPlan.coachNotes ?? currentPackage.brief.coachNotes,
    );

    final updated = currentPackage.withAcceptedAdaptation(
      decision,
      executablePlan: reviewedPlan,
      executableBrief: brief,
    );

    try {
      await _prepareService.replacePreparedPackage(
        athleteId: athleteId,
        package: updated,
        executionContext: executionContext,
      );
    } catch (_) {
      return ProgrammeAdaptationAcceptanceResult.failed(
        errorCode: 'persist_failed',
        message:
            'Cohort could not save the accepted adaptation. Your prepared '
            'session was not changed.',
      );
    }

    _consumedProposalIds.add(proposal.proposalId);
    return ProgrammeAdaptationAcceptanceResult.ok(
      package: updated,
      decision: decision,
    );
  }

  bool _identityMatches(
    PreparedExecutionPackage package,
    ProgrammeAdaptationProposal proposal,
  ) {
    return package.isProgrammeBacked &&
        package.assignmentId == proposal.assignmentId &&
        package.programmeVersionId == proposal.programmeVersionId &&
        package.packageContentHash == proposal.packageContentHash &&
        package.programmedSessionKey.value ==
            proposal.programmedSessionKey.value &&
        package.protocolId == proposal.protocolId &&
        (package.dayKey ?? '') == (proposal.dayKey ?? '') &&
        (package.slotOrder ?? 0) == (proposal.slotOrder ?? 0);
  }

  bool _materialChangesEqual(
    ProgrammeAdaptationProposal a,
    ProgrammeAdaptationProposal b,
  ) {
    String encode(ProgrammeAdaptationMaterialChange c) =>
        '${c.scope.name}|${c.targetId}|${c.actionLabel}|${c.beforeValue}|'
        '${c.afterValue}|${c.summary}';
    final left = a.allMaterialChanges.map(encode).toList()..sort();
    final right = b.allMaterialChanges.map(encode).toList()..sort();
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  /// Test helper: clear consumed-proposal replay protection.
  void resetConsumedProposalsForTests() => _consumedProposalIds.clear();
}
