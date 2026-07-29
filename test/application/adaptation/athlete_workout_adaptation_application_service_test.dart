import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/application/adaptation/athlete_workout_adaptation_application_service.dart';
import 'package:cohort_platform/models/adaptation_decision.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/adaptation_session_environment.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/recovery_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_planning_test_support.dart';

void main() {
  group('AthleteWorkoutAdaptationApplicationService', () {
    late Protocol protocol;
    late AthleteWorkoutAdaptationApplicationService service;

    setUp(() {
      final draft = buildTimedPlanningSession(protocolId: 'proto-home');
      protocol = Protocol(protocolId: 'proto-home', name: draft.name);
      service = AthleteWorkoutAdaptationApplicationService(
        loadProtocolDraft: (_) async => draft,
      );
    });

    test('time constraint satisfied maps to keepOriginal messaging', () async {
      final timedProtocol = Protocol(
        protocolId: protocol.protocolId,
        name: protocol.name,
        durationMin: 60,
      );
      const request = AdaptationRequest(
        reason: AdaptationReason.time,
        availableMinutes: 65,
      );

      final decision = await service.evaluateSessionAdaptation(
        athleteId: 'athlete-1',
        currentProtocol: timedProtocol,
        request: request,
      );

      expect(decision.decisionType, AdaptationDecisionType.keepOriginal);
      expect(
        decision.message,
        AdaptationDecisionMessages.keepOriginalMessage(AdaptationReason.time),
      );
    });

    test(
      'time constraint tight maps to recommendAlternative messaging',
      () async {
        const request = AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 20,
        );

        final decision = await service.evaluateSessionAdaptation(
          athleteId: 'athlete-1',
          currentProtocol: protocol,
          request: request,
        );

        expect(
          decision.decisionType,
          AdaptationDecisionType.recommendAlternative,
        );
        expect(
          decision.message,
          AdaptationDecisionMessages.recommendAlternativeMessage(
            AdaptationReason.time,
          ),
        );
      },
    );

    test(
      'recovery very fatigued recommends alternative when demand unknown',
      () async {
        const request = AdaptationRequest(
          reason: AdaptationReason.recovery,
          recoveryState: RecoveryState.veryFatigued,
        );

        final decision = await service.evaluateSessionAdaptation(
          athleteId: 'athlete-1',
          currentProtocol: protocol,
          request: request,
        );

        expect(
          decision.decisionType,
          AdaptationDecisionType.recommendAlternative,
        );
      },
    );

    test(
      'environment hotel gym keep original when protocol is hotel friendly',
      () async {
        final draft = buildTimedPlanningSession(
          protocolId: 'proto-hotel',
        ).copyWith(hotelFriendly: true);
        final hotelProtocol = Protocol(
          protocolId: 'proto-hotel',
          name: draft.name,
          hotelFriendly: true,
        );
        final hotelService = AthleteWorkoutAdaptationApplicationService(
          loadProtocolDraft: (_) async => draft,
        );

        const request = AdaptationRequest(
          reason: AdaptationReason.environment,
          environment: AdaptationSessionEnvironment.hotelGym,
        );

        final decision = await hotelService.evaluateSessionAdaptation(
          athleteId: 'athlete-1',
          currentProtocol: hotelProtocol,
          request: request,
        );

        expect(decision.decisionType, AdaptationDecisionType.keepOriginal);
      },
    );
  });
}
