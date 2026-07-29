import 'package:cohort_platform/models/adaptation_reason.dart';

/// User-facing copy for Home adaptation sheets (unchanged from legacy evaluate-only path).
class AdaptationDecisionMessages {
  const AdaptationDecisionMessages._();

  static String keepOriginalMessage(AdaptationReason reason) {
    switch (reason) {
      case AdaptationReason.environment:
        return 'Good news — today\'s planned session already works in this environment. No changes needed.';
      case AdaptationReason.equipment:
        return 'Good news — today\'s planned session already fits the equipment you have. Stay with the plan.';
      case AdaptationReason.time:
        return 'Today\'s planned session already fits your available time. Stay with the plan.';
      case AdaptationReason.recovery:
        return 'Today\'s planned session is already recovery-friendly. Stay with the plan.';
    }
  }

  static String recommendAlternativeMessage(AdaptationReason reason) {
    switch (reason) {
      case AdaptationReason.equipment:
        return 'Today\'s session needs equipment you don\'t currently have. We\'ll adapt the plan while preserving the training objective.';
      case AdaptationReason.recovery:
        return 'Based on today\'s recovery, I\'d recommend reducing the training load while preserving the purpose of the session.';
      case AdaptationReason.environment:
        return 'Today\'s planned session may not fit this environment. We\'ll adapt the plan while preserving the training objective.';
      case AdaptationReason.time:
        return 'Today\'s planned session is longer than your available time. We\'ll adapt the plan while preserving the training objective.';
    }
  }
}
