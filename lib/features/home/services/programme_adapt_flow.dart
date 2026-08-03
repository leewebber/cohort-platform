import 'package:flutter/material.dart';

import '../../../application/adaptation/programme_adaptation_acceptance_service.dart';
import '../../../application/adaptation/programme_adaptation_fingerprints.dart';
import '../../../application/adaptation/programme_adaptation_proposal_service.dart';
import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adaptation_bottom_sheet.dart';
import '../../../core/widgets/programme_adaptation_proposal_sheet.dart';
import '../../adaptation/models/programme_adaptation_proposal.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/models/prepared_execution_package.dart';
import '../../session/models/session_execution_plan.dart';

/// Outcome of the programme Adapt Session flow after Sprint 1.6C.
class ProgrammeAdaptFlowResult {
  const ProgrammeAdaptFlowResult({
    this.proposal,
    this.acceptedPackage,
    this.accepted = false,
  });

  final ProgrammeAdaptationProposal? proposal;
  final PreparedExecutionPackage? acceptedPackage;
  final bool accepted;
}

/// Athlete-initiated programme Adapt Session flow.
///
/// Propose → review → optional explicit Accept (1.6C). Non-accept exits remain
/// no-ops. Never advances cursor or invokes Adaptive Progression.
class ProgrammeAdaptFlow {
  ProgrammeAdaptFlow({
    ProgrammeAdaptationProposalService? proposalService,
    ProgrammeAdaptationAcceptanceService? acceptanceService,
  }) : _proposalService =
           proposalService ?? ProgrammeAdaptationProposalService(),
       _acceptanceService = acceptanceService;

  final ProgrammeAdaptationProposalService _proposalService;
  final ProgrammeAdaptationAcceptanceService? _acceptanceService;

  /// Opens reason selection → evaluation → review → optional accept.
  Future<ProgrammeAdaptFlowResult> open(
    BuildContext context, {
    required String athleteId,
    required PreparedExecutionPackage package,
    ProgrammeExecutionContext? executionContext,
  }) async {
    if (!_isEligible(package)) {
      await _showSafeMessage(
        context,
        'Adaptation is only available for a prepared programme session.',
      );
      return const ProgrammeAdaptFlowResult();
    }

    final beforeFingerprint = ProgrammeAdaptationFingerprints.package(package);
    final beforePlanFingerprint = ProgrammeAdaptationFingerprints.plan(
      package.plan,
    );

    final request = await showAdaptationBottomSheet(context);
    if (request == null || !context.mounted) {
      _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
      return const ProgrammeAdaptFlowResult();
    }

    ProgrammeAdaptationProposal proposal;
    try {
      proposal = await _proposalService.propose(
        package: package,
        request: request,
      );
    } catch (error) {
      if (!context.mounted) return const ProgrammeAdaptFlowResult();
      await _showSafeMessage(
        context,
        AthleteSafeErrorPresenter.message(
          error,
          fallback:
              'Cohort could not safely adapt this session. Your prepared '
              'session is unchanged.',
          logTag: 'ProgrammeAdaptFlow.propose',
        ),
      );
      _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
      return const ProgrammeAdaptFlowResult();
    }

    if (!context.mounted) {
      _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
      return ProgrammeAdaptFlowResult(proposal: proposal);
    }

    final accepted = await showProgrammeAdaptationProposalSheet(
      context,
      proposal,
    );

    final acceptanceService = _acceptanceService;
    final activeContext = executionContext;
    if (accepted != true ||
        !proposal.isAcceptable ||
        acceptanceService == null ||
        activeContext == null) {
      _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
      return ProgrammeAdaptFlowResult(proposal: proposal);
    }

    if (!context.mounted) {
      return ProgrammeAdaptFlowResult(proposal: proposal);
    }

    final result = await acceptanceService.accept(
      athleteId: athleteId,
      currentPackage: package,
      proposal: proposal,
      executionContext: activeContext,
    );

    if (!result.success) {
      if (context.mounted) {
        await _showSafeMessage(
          context,
          result.message ??
              'Cohort could not apply that adaptation. Your prepared session '
                  'is unchanged.',
        );
      }
      _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
      return ProgrammeAdaptFlowResult(proposal: proposal);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Today's prepared session has been adapted."),
        ),
      );
    }
    return ProgrammeAdaptFlowResult(
      proposal: proposal,
      acceptedPackage: result.package,
      accepted: true,
    );
  }

  bool _isEligible(PreparedExecutionPackage package) {
    return package.isProgrammeBacked &&
        package.protocolId != null &&
        package.protocolId!.trim().isNotEmpty &&
        package.assignmentId != null &&
        package.plan.blocks.isNotEmpty &&
        package.acceptedAdaptation == null;
  }

  static String packageFingerprint(PreparedExecutionPackage package) =>
      ProgrammeAdaptationFingerprints.package(package);

  static String planFingerprint(SessionExecutionPlan plan) =>
      ProgrammeAdaptationFingerprints.plan(plan);

  void _assertUnchanged(
    PreparedExecutionPackage package,
    String beforePackage,
    String beforePlan,
  ) {
    assert(() {
      final afterPackage = ProgrammeAdaptationFingerprints.package(package);
      final afterPlan = ProgrammeAdaptationFingerprints.plan(package.plan);
      return afterPackage == beforePackage && afterPlan == beforePlan;
    }());
  }

  Future<void> _showSafeMessage(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adapt', style: CohortTextStyles.h2),
        content: Text(message, style: CohortTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
