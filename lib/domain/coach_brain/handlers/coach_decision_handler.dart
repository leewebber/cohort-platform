import '../contracts/coach_decision_request.dart';
import '../contracts/coach_decision_result.dart';
import '../vocabulary/coach_decision_type.dart';

/// Single decision category handler — implemented by domain services or stubs.
abstract class CoachDecisionHandler {
  const CoachDecisionHandler();

  CoachDecisionType get decisionType;

  /// Stable identifier for audit and composition (not athlete-facing copy).
  String get handlerName;

  CoachDecisionResult handle(CoachDecisionRequest request);
}
