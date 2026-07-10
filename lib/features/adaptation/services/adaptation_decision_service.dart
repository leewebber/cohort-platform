import '../../../models/adaptation_decision.dart';
import '../../../models/adaptation_reason.dart';
import '../../../models/adaptation_request.dart';
import '../../../models/protocol.dart';
import 'constraint_evaluator.dart';

class AdaptationDecisionService {
  const AdaptationDecisionService();

  static const _constraintEvaluator = ConstraintEvaluator();

  AdaptationDecision evaluate({
    required Protocol currentProtocol,
    required AdaptationRequest request,
  }) {
    final keepsOriginal = _keepsOriginal(currentProtocol, request);

    return AdaptationDecision(
      decisionType: keepsOriginal
          ? AdaptationDecisionType.keepOriginal
          : AdaptationDecisionType.recommendAlternative,
      message: _messageFor(
        keepsOriginal: keepsOriginal,
        reason: request.reason,
      ),
      protocol: currentProtocol,
    );
  }

  String _messageFor({
    required bool keepsOriginal,
    required AdaptationReason reason,
  }) {
    if (keepsOriginal) {
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

  bool _keepsOriginal(Protocol protocol, AdaptationRequest request) {
    switch (request.reason) {
      case AdaptationReason.environment:
        return _constraintEvaluator
            .environmentSatisfied(protocol, request.environment)
            .satisfied;
      case AdaptationReason.equipment:
        return _constraintEvaluator
            .equipmentSatisfied(protocol, request.availableEquipment)
            .satisfied;
      case AdaptationReason.time:
        return _constraintEvaluator
            .timeSatisfied(protocol, request.availableMinutes)
            .satisfied;
      case AdaptationReason.recovery:
        return _constraintEvaluator
            .recoverySatisfied(protocol, request.recoveryState)
            .satisfied;
    }
  }
}
