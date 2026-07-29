import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';

import '../contracts/coach_decision_request.dart';
import '../contracts/coach_decision_result.dart';
import '../handlers/coach_decision_handler.dart';
import '../vocabulary/coach_decision_type.dart';
import 'session_adaptation_coach_decision_context.dart';
import 'session_adaptation_coach_decision_failure_code.dart';
import 'session_adaptation_pipeline.dart';

/// Thin adapter from Coach Brain to the adaptation evaluate → plan → apply pipeline.
class SessionAdaptationCoachDecisionHandler extends CoachDecisionHandler {
  const SessionAdaptationCoachDecisionHandler({
    this.pipeline = const SessionAdaptationPipeline(),
  });

  final SessionAdaptationPipeline pipeline;

  @override
  CoachDecisionType get decisionType => CoachDecisionType.sessionAdaptation;

  @override
  String get handlerName => 'session_adaptation';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    if (request.decisionType != CoachDecisionType.sessionAdaptation) {
      return CoachDecisionResult.adaptationFailed(
        decisionType: request.decisionType,
        requestId: request.requestId,
        handlerName: handlerName,
        failureCode:
            SessionAdaptationCoachDecisionFailureCode.wrongDecisionType,
        detail: 'expected_session_adaptation',
      );
    }

    final context = request.context;
    if (context is! SessionAdaptationCoachDecisionContext) {
      return CoachDecisionResult.invalidContext(
        decisionType: CoachDecisionType.sessionAdaptation,
        requestId: request.requestId,
        handlerName: handlerName,
        detail: 'session_adaptation_context_required',
      );
    }

    final run = pipeline.run(
      plannedSession: context.plannedSession,
      constraints: context.constraints,
    );

    final application = run.application;
    if (application.isSuccess) {
      return CoachDecisionResult.completed(
        decisionType: CoachDecisionType.sessionAdaptation,
        requestId: request.requestId,
        handlerName: handlerName,
        executionSnapshot: application.snapshot!,
      );
    }

    return CoachDecisionResult.adaptationFailed(
      decisionType: CoachDecisionType.sessionAdaptation,
      requestId: request.requestId,
      handlerName: handlerName,
      failureCode: _failureCodeForApplication(
        application.status,
        run.plan.status,
      ),
      detail: application.status.name,
    );
  }

  SessionAdaptationCoachDecisionFailureCode _failureCodeForApplication(
    AdaptationPlanApplicationStatus applicationStatus,
    AdaptationPlanStatus planStatus,
  ) {
    return switch (applicationStatus) {
      AdaptationPlanApplicationStatus.rejectedInvalidPlan =>
        planStatus == AdaptationPlanStatus.unableToPlan ||
                planStatus == AdaptationPlanStatus.insufficientInformation
            ? SessionAdaptationCoachDecisionFailureCode.unableToPlan
            : SessionAdaptationCoachDecisionFailureCode.rejectedInvalidPlan,
      AdaptationPlanApplicationStatus.rejectedSourceMismatch =>
        SessionAdaptationCoachDecisionFailureCode.rejectedSourceMismatch,
      AdaptationPlanApplicationStatus.unsupportedPlanStep =>
        SessionAdaptationCoachDecisionFailureCode.unsupportedPlanStep,
      AdaptationPlanApplicationStatus.applicationFailed =>
        SessionAdaptationCoachDecisionFailureCode.applicationFailed,
      AdaptationPlanApplicationStatus.applied ||
      AdaptationPlanApplicationStatus.noAdaptationRequired =>
        SessionAdaptationCoachDecisionFailureCode.applicationFailed,
    };
  }
}
