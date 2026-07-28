import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';

import '../session_adaptation/session_adaptation_coach_decision_failure_code.dart';
import '../vocabulary/coach_decision_type.dart';

enum CoachDecisionOutcomeStatus {
  /// Handler returned a deterministic placeholder (framework stub).
  stubPlaceholder,

  /// Router rejected the request before delegation.
  invalidRequest,

  /// No handler registered for [CoachDecisionRequest.decisionType].
  handlerNotRegistered,

  /// Handler rejected missing or wrong typed context.
  invalidContext,

  /// Adaptation or other domain pipeline failed deterministically.
  adaptationFailed,

  /// Handler completed successfully.
  completed,
}

/// Immutable outcome of routing a [CoachDecisionRequest].
class CoachDecisionResult {
  const CoachDecisionResult({
    required this.status,
    required this.decisionType,
    required this.requestId,
    this.handlerName,
    this.placeholderCode,
    this.detail,
    this.executionSnapshot,
    this.sessionAdaptationFailureCode,
  });

  final CoachDecisionOutcomeStatus status;
  final CoachDecisionType decisionType;
  final String requestId;
  final String? handlerName;
  final String? placeholderCode;
  final String? detail;
  final AdaptedSessionExecutionSnapshot? executionSnapshot;
  final SessionAdaptationCoachDecisionFailureCode? sessionAdaptationFailureCode;

  bool get isRouterFailure =>
      status == CoachDecisionOutcomeStatus.invalidRequest ||
      status == CoachDecisionOutcomeStatus.handlerNotRegistered;

  bool get isStubPlaceholder =>
      status == CoachDecisionOutcomeStatus.stubPlaceholder;

  bool get isCompleted => status == CoachDecisionOutcomeStatus.completed;

  factory CoachDecisionResult.invalidRequest({
    required CoachDecisionType decisionType,
    required String requestId,
    String? detail,
  }) {
    return CoachDecisionResult(
      status: CoachDecisionOutcomeStatus.invalidRequest,
      decisionType: decisionType,
      requestId: requestId,
      detail: detail,
    );
  }

  factory CoachDecisionResult.handlerNotRegistered({
    required CoachDecisionType decisionType,
    required String requestId,
  }) {
    return CoachDecisionResult(
      status: CoachDecisionOutcomeStatus.handlerNotRegistered,
      decisionType: decisionType,
      requestId: requestId,
    );
  }

  factory CoachDecisionResult.invalidContext({
    required CoachDecisionType decisionType,
    required String requestId,
    required String handlerName,
    String? detail,
  }) {
    return CoachDecisionResult(
      status: CoachDecisionOutcomeStatus.invalidContext,
      decisionType: decisionType,
      requestId: requestId,
      handlerName: handlerName,
      detail: detail,
      sessionAdaptationFailureCode:
          SessionAdaptationCoachDecisionFailureCode.missingContext,
    );
  }

  factory CoachDecisionResult.stubPlaceholder({
    required CoachDecisionType decisionType,
    required String requestId,
    required String handlerName,
    required String placeholderCode,
  }) {
    return CoachDecisionResult(
      status: CoachDecisionOutcomeStatus.stubPlaceholder,
      decisionType: decisionType,
      requestId: requestId,
      handlerName: handlerName,
      placeholderCode: placeholderCode,
    );
  }

  factory CoachDecisionResult.completed({
    required CoachDecisionType decisionType,
    required String requestId,
    required String handlerName,
    required AdaptedSessionExecutionSnapshot executionSnapshot,
  }) {
    return CoachDecisionResult(
      status: CoachDecisionOutcomeStatus.completed,
      decisionType: decisionType,
      requestId: requestId,
      handlerName: handlerName,
      executionSnapshot: executionSnapshot,
    );
  }

  factory CoachDecisionResult.adaptationFailed({
    required CoachDecisionType decisionType,
    required String requestId,
    required String handlerName,
    required SessionAdaptationCoachDecisionFailureCode failureCode,
    String? detail,
  }) {
    return CoachDecisionResult(
      status: CoachDecisionOutcomeStatus.adaptationFailed,
      decisionType: decisionType,
      requestId: requestId,
      handlerName: handlerName,
      detail: detail,
      sessionAdaptationFailureCode: failureCode,
    );
  }
}
