import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/coach_brain/coach_brain_domain.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_application_test_support.dart';
import '../../support/adaptation_planning_test_support.dart';

void main() {
  const handler = SessionAdaptationCoachDecisionHandler();

  late ProtocolDraft timedDraft;
  late PlannedSessionAdaptationInput timedInput;

  setUp(() {
    timedDraft = buildTimedPlanningSession(protocolId: 'm3a-session-adapt');
    timedInput = timedPlanningInputFromDraft(timedDraft);
  });

  CoachDecisionRequest _sessionRequest({
    SessionAdaptationCoachDecisionContext? context,
    CoachDecisionType type = CoachDecisionType.sessionAdaptation,
    String requestId = 'req-1',
  }) {
    return CoachDecisionRequest(
      decisionType: type,
      requestId: requestId,
      athleteId: 'athlete-1',
      context: context,
    );
  }

  SessionAdaptationCoachDecisionContext _context({
    AdaptationConstraintContext constraints =
        const AdaptationConstraintContext(availableDurationMin: 50),
  }) {
    return SessionAdaptationCoachDecisionContext(
      plannedSession: timedInput,
      constraints: constraints,
    );
  }

  group('SessionAdaptationCoachDecisionHandler', () {
    test('returns completed with execution snapshot on successful pipeline', () {
      final result = handler.handle(
        _sessionRequest(context: _context()),
      );
      expect(result.status, CoachDecisionOutcomeStatus.completed);
      expect(result.handlerName, 'session_adaptation');
      expect(result.executionSnapshot, isNotNull);
      expect(result.executionSnapshot!.sourceProtocolId, timedInput.protocolId);
    });

    test('noPlanRequired path returns snapshot without adaptation audit', () {
      final result = handler.handle(
        _sessionRequest(
          context: _context(
            constraints: AdaptationConstraintContext.empty(),
          ),
        ),
      );
      expect(result.status, CoachDecisionOutcomeStatus.completed);
      expect(result.executionSnapshot!.appliedAdaptationAudit, isEmpty);
    });

    test('missing context returns invalidContext', () {
      final result = handler.handle(_sessionRequest());
      expect(result.status, CoachDecisionOutcomeStatus.invalidContext);
      expect(
        result.sessionAdaptationFailureCode,
        SessionAdaptationCoachDecisionFailureCode.missingContext,
      );
    });

    test('wrong decision type returns adaptationFailed', () {
      final result = handler.handle(
        _sessionRequest(
          type: CoachDecisionType.rescheduling,
          context: _context(),
        ),
      );
      expect(result.status, CoachDecisionOutcomeStatus.adaptationFailed);
      expect(
        result.sessionAdaptationFailureCode,
        SessionAdaptationCoachDecisionFailureCode.wrongDecisionType,
      );
    });

    test('unable to plan maps to adaptationFailed with unableToPlan code', () {
      final result = handler.handle(
        _sessionRequest(
          context: _context(
            constraints: const AdaptationConstraintContext(availableDurationMin: 20),
          ),
        ),
      );
      expect(result.status, CoachDecisionOutcomeStatus.adaptationFailed);
      expect(
        result.sessionAdaptationFailureCode,
        SessionAdaptationCoachDecisionFailureCode.unableToPlan,
      );
    });

    test('deterministic: identical requests yield equivalent snapshots', () {
      final request = _sessionRequest(context: _context());
      final a = handler.handle(request);
      final b = handler.handle(request);
      expect(a.status, b.status);
      expect(
        snapshotSemanticallyEqual(a.executionSnapshot!, b.executionSnapshot!),
        isTrue,
      );
    });
  });

  group('CoachBrainDependencies session adaptation wiring', () {
    test('defaults registry includes production session handler', () {
      final deps = CoachBrainDependencies.defaults();
      final registered = deps.registry.handlerFor(
        CoachDecisionType.sessionAdaptation,
      );
      expect(registered, isA<SessionAdaptationCoachDecisionHandler>());
    });

    test('router delegates session adaptation through pipeline end-to-end', () {
      final deps = CoachBrainDependencies.defaults();
      final result = deps.router.route(
        CoachDecisionRequest(
          decisionType: CoachDecisionType.sessionAdaptation,
          requestId: 'route-1',
          athleteId: 'athlete-1',
          context: _context(),
        ),
      );
      expect(result.status, CoachDecisionOutcomeStatus.completed);
      expect(result.executionSnapshot, isNotNull);
    });

    test('matches direct applyTimedSessionPlan snapshot semantics', () {
      const constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final direct = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: constraints,
      );
      final routed = CoachBrainDependencies.defaults().router.route(
            CoachDecisionRequest(
              decisionType: CoachDecisionType.sessionAdaptation,
              requestId: 'equiv-1',
              athleteId: 'athlete-1',
              context: SessionAdaptationCoachDecisionContext(
                plannedSession: timedInput,
                constraints: constraints,
              ),
            ),
          );
      expect(routed.status, CoachDecisionOutcomeStatus.completed);
      expect(
        snapshotSemanticallyEqual(
          direct.snapshot!,
          routed.executionSnapshot!,
        ),
        isTrue,
      );
    });
  });
}
