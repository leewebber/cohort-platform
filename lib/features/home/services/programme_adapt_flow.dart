import 'package:flutter/material.dart';

import '../../../application/adaptation/programme_adaptation_proposal_service.dart';
import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adaptation_bottom_sheet.dart';
import '../../../core/widgets/programme_adaptation_proposal_sheet.dart';
import '../../../models/adaptation_request.dart';
import '../../adaptation/models/programme_adaptation_proposal.dart';
import '../../session/models/prepared_execution_package.dart';
import '../../session/models/session_execution_plan.dart';

/// Athlete-initiated programme Adapt Session flow (Sprint 1.6B).
///
/// Propose → review → leave. Never mutates the prepared package, never accepts,
/// never advances cursor, never invokes Adaptive Progression.
class ProgrammeAdaptFlow {
  ProgrammeAdaptFlow({
    ProgrammeAdaptationProposalService? proposalService,
  }) : _proposalService =
           proposalService ?? ProgrammeAdaptationProposalService();

  final ProgrammeAdaptationProposalService _proposalService;

  /// Opens reason selection → evaluation → review. Always a no-op for prepared
  /// state. Returns the proposal for tests/observers; null when cancelled early.
  Future<ProgrammeAdaptationProposal?> open(
    BuildContext context, {
    required PreparedExecutionPackage package,
  }) async {
    if (!_isEligible(package)) {
      await _showSafeMessage(
        context,
        'Adaptation is only available for a prepared programme session.',
      );
      return null;
    }

    final beforeFingerprint = packageFingerprint(package);
    final beforePlanFingerprint = planFingerprint(package.plan);

    final request = await showAdaptationBottomSheet(context);
    if (request == null || !context.mounted) {
      _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
      return null;
    }

    ProgrammeAdaptationProposal proposal;
    try {
      proposal = await _proposalService.propose(
        package: package,
        request: request,
      );
    } catch (error) {
      if (!context.mounted) return null;
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
      return null;
    }

    if (!context.mounted) {
      _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
      return proposal;
    }

    await showProgrammeAdaptationProposalSheet(context, proposal);

    _assertUnchanged(package, beforeFingerprint, beforePlanFingerprint);
    return proposal;
  }

  bool _isEligible(PreparedExecutionPackage package) {
    return package.isProgrammeBacked &&
        package.protocolId != null &&
        package.protocolId!.trim().isNotEmpty &&
        package.assignmentId != null &&
        package.plan.blocks.isNotEmpty &&
        package.acceptedAdaptation == null;
  }

  static String packageFingerprint(PreparedExecutionPackage package) {
    return [
      package.programmedSessionKey.value,
      package.assignmentId ?? '',
      package.programmeVersionId ?? '',
      package.packageContentHash ?? '',
      package.protocolId ?? '',
      package.dayKey ?? '',
      '${package.slotOrder ?? ''}',
      package.acceptedAdaptation?.decisionId ?? '',
      package.preparedAt.toUtc().toIso8601String(),
      planFingerprint(package.plan),
    ].join('|');
  }

  static String planFingerprint(SessionExecutionPlan plan) {
    final blockBits = plan.blocks
        .map((b) {
          final rx = b.linkedExercises
              .map((p) {
                final sets = p.prescription?.sets;
                final reps = p.prescription?.reps;
                final rest = p.prescription?.restSeconds;
                return '${p.exerciseId}:$sets:$reps:$rest';
              })
              .join(',');
          return '${b.blockId}:${b.title}:$rx';
        })
        .join(';');
    return '${plan.protocol?.protocolId ?? ''}|${plan.blocks.length}|$blockBits';
  }

  void _assertUnchanged(
    PreparedExecutionPackage package,
    String beforePackage,
    String beforePlan,
  ) {
    // Debug-time guard for developers; never mutates. Production flow always
    // exits without writing package fields.
    assert(() {
      final afterPackage = packageFingerprint(package);
      final afterPlan = planFingerprint(package.plan);
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

/// Test helper: evaluate without UI.
Future<ProgrammeAdaptationProposal> evaluateProgrammeAdaptationProposal({
  required PreparedExecutionPackage package,
  required AdaptationRequest request,
  ProgrammeAdaptationProposalService? service,
}) {
  return (service ?? ProgrammeAdaptationProposalService()).propose(
    package: package,
    request: request,
  );
}
