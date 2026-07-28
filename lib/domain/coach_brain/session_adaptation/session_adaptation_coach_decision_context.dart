import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';

import '../contracts/coach_decision_context.dart';

/// Strongly typed context for [CoachDecisionType.sessionAdaptation].
class SessionAdaptationCoachDecisionContext extends CoachDecisionContext {
  const SessionAdaptationCoachDecisionContext({
    required this.plannedSession,
    required this.constraints,
  });

  final PlannedSessionAdaptationInput plannedSession;
  final AdaptationConstraintContext constraints;
}
