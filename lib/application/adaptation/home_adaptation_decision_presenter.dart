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
  }) {
    final keepOriginal = _keepOriginalFromCoachResult(coachResult);
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
    );
  }

  static bool _keepOriginalFromCoachResult(CoachDecisionResult coachResult) {
    if (!coachResult.isCompleted || coachResult.executionSnapshot == null) {
      return false;
    }

    return coachResult.executionSnapshot!.evaluationOutcome ==
        AdaptationEvaluationOutcome.noAdaptationRequired;
  }
}
