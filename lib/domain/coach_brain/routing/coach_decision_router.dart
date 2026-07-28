import '../contracts/coach_decision_request.dart';
import '../contracts/coach_decision_result.dart';
import 'coach_decision_handler_registry.dart';

/// Routes athlete coaching decisions to registered handlers (delegation only).
class CoachDecisionRouter {
  const CoachDecisionRouter({required this.registry});

  final CoachDecisionHandlerRegistry registry;

  CoachDecisionResult route(CoachDecisionRequest request) {
    if (!request.hasValidIdentity) {
      return CoachDecisionResult.invalidRequest(
        decisionType: request.decisionType,
        requestId: request.requestId,
        detail: 'request_id_and_athlete_id_required',
      );
    }

    final handler = registry.handlerFor(request.decisionType);
    if (handler == null) {
      return CoachDecisionResult.handlerNotRegistered(
        decisionType: request.decisionType,
        requestId: request.requestId,
      );
    }

    return handler.handle(request);
  }
}
