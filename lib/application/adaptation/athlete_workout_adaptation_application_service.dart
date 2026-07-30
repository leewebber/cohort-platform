import 'package:cohort_platform/domain/coach_brain/coach_brain_domain.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/models/adaptation_decision.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';

import '../athlete_workout/athlete_workout_orchestrator.dart';
import 'adaptation_application.dart';
import 'home_adaptation_decision_presenter.dart';
import 'planned_session_protocol_metadata_merge.dart';

typedef ProtocolDraftLoader = Future<ProtocolDraft> Function(String protocolId);

/// Day-of session adaptation via Coach Brain (Home + application entry).
class AthleteWorkoutAdaptationApplicationService {
  AthleteWorkoutAdaptationApplicationService({
    CoachDecisionRouter? coachBrainRouter,
    AthleteWorkoutOrchestrator? workoutOrchestrator,
    ProtocolDraftLoader? loadProtocolDraft,
  }) : _coachBrainRouter =
           coachBrainRouter ?? CoachBrainDependencies.defaults().router,
       _workoutOrchestrator =
           workoutOrchestrator ?? const AthleteWorkoutOrchestrator(),
       _loadProtocolDraft =
           loadProtocolDraft ?? _unsupportedProtocolDraftLoader;

  final CoachDecisionRouter _coachBrainRouter;
  final AthleteWorkoutOrchestrator _workoutOrchestrator;
  final ProtocolDraftLoader _loadProtocolDraft;

  /// Evaluate-only path for Home: Coach Brain decides; UI keeps [AdaptationDecision].
  Future<AdaptationDecision> evaluateSessionAdaptation({
    required String athleteId,
    required Protocol currentProtocol,
    required AdaptationRequest request,
    ProtocolDraft? protocolDraft,
  }) async {
    const AdaptationPolicyGate().assertAllowed(
      AdaptationPolicyGate.kindsForDayOf(request.reason),
    );

    final draft =
        protocolDraft ??
        await _loadProtocolDraft(currentProtocol.protocolId.trim());

    final plannedSession = PlannedSessionProtocolMetadataMerge.merge(
      draft: draft,
      protocol: currentProtocol,
    );
    final constraints = AdaptationRequestConstraintMapper.fromRequest(request);

    final coachResult = _coachBrainRouter.route(
      CoachDecisionRequest(
        decisionType: CoachDecisionType.sessionAdaptation,
        requestId:
            'home-adapt-${currentProtocol.protocolId}-${DateTime.now().millisecondsSinceEpoch}',
        athleteId: athleteId.trim(),
        context: SessionAdaptationCoachDecisionContext(
          plannedSession: plannedSession,
          constraints: constraints,
        ),
      ),
    );

    return HomeAdaptationDecisionPresenter.fromCoachResult(
      request: request,
      protocol: currentProtocol,
      coachResult: coachResult,
      programmedSessionKey:
          AthleteProfileSession.programme?.programmedSessionKey?.value,
    );
  }

  /// Full orchestrator path when an occurrence repository is available (future Home wiring).
  AthleteWorkoutOrchestrator get workoutOrchestrator => _workoutOrchestrator;

  static Future<ProtocolDraft> _unsupportedProtocolDraftLoader(
    String protocolId,
  ) {
    throw UnsupportedError(
      'Provide protocolDraft or inject loadProtocolDraft for $protocolId',
    );
  }
}
