import 'package:cohort_platform/application/athlete_workout/athlete_today_workout_resolution_service.dart';
import 'package:cohort_platform/application/athlete_workout/athlete_workout_application.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/today_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubTodaySessionService implements TodaySessionService {
  _StubTodaySessionService(this.resolution);

  final ResolvedTodaySession resolution;

  @override
  Future<ResolvedTodaySession> resolveForAthlete(String athleteId) async {
    return resolution;
  }
}

void main() {
  group('AthleteTodayWorkoutResolutionService', () {
    test('delegates programme resolution to TodaySessionService', () async {
      const programmeSession = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.restDay,
        assignmentId: 'asgn-1',
      );

      final service = AthleteTodayWorkoutResolutionService(
        todaySessionService: _StubTodaySessionService(programmeSession),
      );

      final result = await service.resolve(athleteId: 'athlete-1');

      expect(result.programmeSession.kind, ResolvedTodaySessionKind.restDay);
      expect(result.workout, isNull);
      expect(result.occurrenceRepository, isNull);
    });

    test('executable programme materializes domain workout mirror', () async {
      final programmeSession = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.executable,
        assignmentId: 'asgn-1',
        slotId: 'slot-1',
        effectiveProtocolId: 'proto-1',
      );

      final service = AthleteTodayWorkoutResolutionService(
        todaySessionService: _StubTodaySessionService(programmeSession),
      );

      final result = await service.resolve(
        athleteId: 'athlete-1',
        resolvedAt: DateTime.utc(2026, 8, 1, 12),
      );

      expect(result.programmeSession.effectiveProtocolId, 'proto-1');
      expect(result.workout, isNotNull);
      expect(result.workout!.hasWorkout, isTrue);
      expect(
        result.workout!.status,
        AthleteWorkoutResolutionStatus.workoutPlanned,
      );
      expect(result.occurrenceRepository, isNotNull);
    });
  });
}
