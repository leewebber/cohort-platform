import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/coach_brain/coach_brain_domain.dart';
import 'package:cohort_platform/models/adaptation_decision.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol.dart';

import 'adaptation_decision_messages.dart';

/// Maps Coach Brain pipeline outcomes to Home [AdaptationDecision] view models.
///
/// Does not evaluate constraints — only interprets [CoachDecisionResult].
class HomeAdaptationDecisionPresenter {
  const HomeAdaptationDecisionPresenter._();

  static AdaptationDecision fromCoachResult({
    required AdaptationRequest request,
    required Protocol protocol,
    required CoachDecisionResult coachResult,
    String? programmedSessionKey,
  }) {
    final keepOriginal = _keepOriginalFromCoachResult(coachResult);
    final snapshot = coachResult.executionSnapshot;
    final changeSummary = keepOriginal
        ? const <String>[]
        : _changeSummaryFromSnapshot(snapshot);
    return AdaptationDecision(
      decisionType: keepOriginal
          ? AdaptationDecisionType.keepOriginal
          : AdaptationDecisionType.recommendAlternative,
      message: keepOriginal
          ? AdaptationDecisionMessages.keepOriginalMessage(request.reason)
          : AdaptationDecisionMessages.recommendAlternativeMessage(
              request.reason,
            ),
      protocol: protocol,
      changeSummary: changeSummary,
      programmedSessionKey: programmedSessionKey,
      preservedIntent: snapshot?.primarySessionIntent?.name,
    );
  }

  static bool _keepOriginalFromCoachResult(CoachDecisionResult coachResult) {
    if (!coachResult.isCompleted || coachResult.executionSnapshot == null) {
      return false;
    }

    return coachResult.executionSnapshot!.evaluationOutcome ==
        AdaptationEvaluationOutcome.noAdaptationRequired;
  }

  static List<String> _changeSummaryFromSnapshot(
    AdaptedSessionExecutionSnapshot? snapshot,
  ) {
    if (snapshot == null) return const [];
    final lines = <String>[];
    for (final entry in snapshot.appliedAdaptationAudit) {
      lines.add(
        '${entry.actionType.name} · ${entry.targetScopeDbValue} · '
        '${entry.targetId}',
      );
    }
    for (final omitted in snapshot.omittedBlocks) {
      lines.add(
        'omit block ${omitted.sourceBlockLocalId} '
        '(${omitted.omissionAction.name})',
      );
    }
    return List.unmodifiable(lines);
  }
}
