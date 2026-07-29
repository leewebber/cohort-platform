import 'package:cohort_platform/application/athlete_workout/athlete_workout_orchestrator.dart';
import 'package:cohort_platform/application/athlete_workout/home_workout_execution_context.dart';
import 'package:cohort_platform/application/athlete_workout/home_workout_launch_service.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_planning_test_support.dart';

void main() {
  group('HomeWorkoutLaunchService', () {
    test(
      'commitDayOfAdaptation attaches snapshot on in-memory occurrence',
      () async {
        final repository = AthleteSessionOccurrenceIndex();
        final registry = InMemoryProgrammeSessionOccurrenceRegistry();
        const factory = ProgrammeSessionOccurrenceFactory();
        final date = SessionOccurrenceDate.fromDateTime(
          DateTime.utc(2026, 8, 1),
        );
        final recordedAt = DateTime.utc(2026, 8, 1, 9);

        factory.createFromScheduledSlot(
          input: ProgrammeScheduledSlotInput(
            programmeAssignmentId: 'asgn-1',
            programmeSessionSlotId: 'slot-1',
            athleteId: 'athlete-1',
            sourceSessionId: 'proto-launch',
            plannedDate: date,
          ),
          recordedAt: recordedAt,
          registry: registry,
          occurrenceRepository: repository,
        );

        const orchestrator = AthleteWorkoutOrchestrator();
        final draft = buildTimedPlanningSession(protocolId: 'proto-launch');
        final protocol = Protocol(
          protocolId: 'proto-launch',
          name: draft.name,
          durationMin: 60,
        );

        final resolve = orchestrator.resolveToday(
          athleteId: 'athlete-1',
          date: date,
          occurrenceRepository: repository,
        );

        final context = HomeWorkoutExecutionContext(
          occurrenceDate: date,
          occurrenceRepository: repository,
          workout: resolve,
        );

        final service = HomeWorkoutLaunchService(
          workoutOrchestrator: orchestrator,
          loadProtocolDraft: (_) async => draft,
        );

        const request = AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 65,
        );

        final updated = await service.commitDayOfAdaptation(
          executionContext: context,
          athleteId: 'athlete-1',
          protocol: protocol,
          request: request,
        );

        expect(updated, isNotNull);
        expect(updated!.workout.occurrence?.executionSnapshot, isNotNull);
        expect(updated.lastAdaptationCommitted, isTrue);
      },
    );
  });
}
