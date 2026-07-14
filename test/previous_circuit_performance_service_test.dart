import 'package:cohort_platform/data/repositories/training_session_circuit_repository.dart';
import 'package:cohort_platform/features/session/services/previous_circuit_performance_service.dart';
import 'package:cohort_platform/models/circuit_data_source.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_performance.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/training_session.dart';
import 'package:cohort_platform/models/training_session_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PreviousCircuitPerformanceService();

  group('PreviousCircuitPerformanceService.buildFromSession', () {
    test('returns null when performance is not completed', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 1),
        performance: _performance(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 5,
          completed: false,
        ),
      );

      expect(result, isNull);
    });

    test('builds AMRAP display summary', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 2),
        performance: _performance(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 8,
          additionalReps: 12,
          rpe: 8,
        ),
      );

      expect(result?.displaySummary, '8 rounds + 12 reps');
      expect(result?.averageRpe, 8);
      expect(result?.todayOpportunities, isNotEmpty);
    });

    test('builds for-time display summary', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 3),
        performance: _performance(
          scoreType: CircuitScoreType.elapsedTime,
          elapsedDurationSeconds: 1122,
          rpe: 7,
        ),
      );

      expect(result?.displaySummary, '18:42');
      expect(result?.averageRpe, 7);
    });

    test('builds EMOM display summary with prescribed interval count', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 4),
        performance: _performance(
          scoreType: CircuitScoreType.roundsCompleted,
          circuitFormat: CircuitFormat.emom,
          completedIntervals: 18,
        ),
        prescribedIntervalCount: 20,
      );

      expect(result?.displaySummary, '18 / 20 intervals');
      expect(result?.completedIntervals, 18);
    });

    test('shows athlete note when present', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 5),
        performance: _performance(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 4,
          athleteNote: 'Pacing felt strong on round 3.',
        ),
      );

      expect(result?.athleteNote, 'Pacing felt strong on round 3.');
    });
  });

  group('PreviousCircuitPerformanceService.load', () {
    test('returns null when repository has no comparable session', () async {
      final result = await PreviousCircuitPerformanceService(
        circuitRepository: _EmptyCircuitRepository(),
      ).load(
        athleteId: 'athlete-1',
        protocolId: 'WOD-001',
      );

      expect(result, isNull);
    });

    test('loads latest comparable session from repository', () async {
      final result = await PreviousCircuitPerformanceService(
        circuitRepository: _FixedCircuitRepository(
          ComparableCircuitSession(
            session: _completedSession(id: 100),
            performance: _performance(
              scoreType: CircuitScoreType.roundsAndReps,
              completedRounds: 6,
              additionalReps: 3,
            ),
          ),
        ),
      ).load(
        athleteId: 'athlete-1',
        protocolId: 'WOD-001',
        excludeTrainingSessionId: 200,
        prescribedIntervalCount: 20,
      );

      expect(result?.displaySummary, '6 rounds + 3 reps');
    });
  });
}

class _EmptyCircuitRepository extends TrainingSessionCircuitRepository {
  @override
  Future<ComparableCircuitSession?> getLatestCompletedComparableSession({
    required String athleteId,
    required String protocolId,
    int? excludeTrainingSessionId,
  }) async {
    return null;
  }
}

class _FixedCircuitRepository extends TrainingSessionCircuitRepository {
  _FixedCircuitRepository(this.session);

  final ComparableCircuitSession session;

  @override
  Future<ComparableCircuitSession?> getLatestCompletedComparableSession({
    required String athleteId,
    required String protocolId,
    int? excludeTrainingSessionId,
  }) async {
    return session;
  }
}

TrainingSession _completedSession({required int id}) {
  return TrainingSession(
    id: id,
    athleteId: 'athlete-1',
    protocolId: 'WOD-001',
    status: TrainingSessionStatus.completed,
    completedAt: DateTime.utc(2026, 7, 1, 8),
  );
}

CircuitPerformance _performance({
  CircuitFormat circuitFormat = CircuitFormat.amrap,
  required CircuitScoreType scoreType,
  int? elapsedDurationSeconds,
  int? completedRounds,
  int? additionalReps,
  int? completedIntervals,
  int? rpe,
  String? athleteNote,
  bool completed = true,
}) {
  return CircuitPerformance(
    id: 1,
    trainingSessionId: 42,
    protocolId: 'WOD-001',
    circuitFormat: circuitFormat,
    scoreType: scoreType,
    elapsedDurationSeconds: elapsedDurationSeconds,
    completedRounds: completedRounds,
    additionalReps: additionalReps,
    completedIntervals: completedIntervals,
    rpe: rpe,
    completed: completed,
    timeCapped: false,
    skipped: false,
    dataSource: CircuitDataSource.manual,
    athleteNote: athleteNote,
  );
}
