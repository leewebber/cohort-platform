import 'package:cohort_platform/data/repositories/training_session_interval_repository.dart';
import 'package:cohort_platform/features/session/services/previous_interval_performance_service.dart';
import 'package:cohort_platform/models/interval_data_source.dart';
import 'package:cohort_platform/models/interval_modality.dart';
import 'package:cohort_platform/models/interval_performance.dart';
import 'package:cohort_platform/models/interval_phase_type.dart';
import 'package:cohort_platform/models/training_session.dart';
import 'package:cohort_platform/models/training_session_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PreviousIntervalPerformanceService();

  group('PreviousIntervalPerformanceService.buildFromSession', () {
    test('builds rep lines and summary metrics from latest completed work', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 42),
        intervals: _threeRepSession(),
      );

      expect(result, isNotNull);
      expect(result!.trainingSessionId, 42);
      expect(result.reps.length, 3);
      expect(result.reps[0].displayLine, '800 m · 3:08 · 3:55/km · RPE 7');
      expect(result.reps[1].displayLine, '800 m · 3:10 · 3:58/km · RPE 8');
      expect(result.reps[2].displayLine, '800 m · 3:11 · 3:59/km · RPE 8');
      expect(result.completedRepCount, 3);
      expect(result.averagePaceSecondsPerKm, closeTo(237.33, 0.01));
      expect(result.paceDropOffSeconds, 4);
      expect(result.averageRpe, closeTo(7.67, 0.01));
    });

    test('orders reps by blockIndex then repNumber', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 7),
        intervals: [
          _workInterval(
            id: 1,
            blockIndex: 2,
            repNumber: 1,
            durationSeconds: 200,
            paceSecondsPerKm: 250,
          ),
          _workInterval(
            id: 2,
            blockIndex: 1,
            repNumber: 2,
            durationSeconds: 190,
            paceSecondsPerKm: 240,
          ),
          _workInterval(
            id: 3,
            blockIndex: 1,
            repNumber: 1,
            durationSeconds: 188,
            paceSecondsPerKm: 238,
          ),
        ],
      );

      expect(result?.reps.map((rep) => rep.actualDurationSeconds).toList(),
          [188, 190, 200]);
    });

    test('excludes skipped work reps from performance averages', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 9),
        intervals: [
          _workInterval(
            id: 1,
            blockIndex: 1,
            repNumber: 1,
            durationSeconds: 188,
            paceSecondsPerKm: 235,
            rpe: 7,
          ),
          _workInterval(
            id: 2,
            blockIndex: 1,
            repNumber: 2,
            skipped: true,
            durationSeconds: 999,
            paceSecondsPerKm: 999,
            rpe: 10,
          ),
          _workInterval(
            id: 3,
            blockIndex: 1,
            repNumber: 3,
            durationSeconds: 191,
            paceSecondsPerKm: 239,
            rpe: 8,
          ),
        ],
      );

      expect(result?.completedRepCount, 2);
      expect(result?.averagePaceSecondsPerKm, 237);
      expect(result?.averageRpe, 7.5);
      expect(result?.reps[1].displayLine, 'Skipped');
    });

    test('returns null when no completed work phases exist', () {
      final result = service.buildFromSession(
        session: _completedSession(id: 3),
        intervals: [
          IntervalPerformance(
            id: 1,
            trainingSessionId: 3,
            blockIndex: 0,
            repNumber: 1,
            phaseType: IntervalPhaseType.recovery,
            modality: IntervalModality.running,
            completed: true,
            skipped: false,
            dataSource: IntervalDataSource.manual,
          ),
        ],
      );

      expect(result, isNull);
    });
  });

  group('PreviousIntervalPerformanceService.load', () {
    test('returns null when repository has no comparable session', () async {
      final result = await PreviousIntervalPerformanceService(
        intervalRepository: _EmptyIntervalRepository(),
      ).load(
        athleteId: 'athlete-1',
        protocolId: 'RN-006',
      );

      expect(result, isNull);
    });

    test('loads latest comparable session from repository', () async {
      final result = await PreviousIntervalPerformanceService(
        intervalRepository: _FixedIntervalRepository(
          ComparableIntervalSession(
            session: _completedSession(id: 100),
            intervals: _threeRepSession(),
          ),
        ),
      ).load(
        athleteId: 'athlete-1',
        protocolId: 'RN-006',
        excludeTrainingSessionId: 200,
      );

      expect(result?.trainingSessionId, 100);
      expect(result?.reps.length, 3);
    });
  });
}

class _EmptyIntervalRepository extends TrainingSessionIntervalRepository {
  @override
  Future<ComparableIntervalSession?> getLatestCompletedComparableSession({
    required String athleteId,
    required String protocolId,
    int? excludeTrainingSessionId,
  }) async {
    return null;
  }
}

class _FixedIntervalRepository extends TrainingSessionIntervalRepository {
  _FixedIntervalRepository(this.session);

  final ComparableIntervalSession session;

  @override
  Future<ComparableIntervalSession?> getLatestCompletedComparableSession({
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
    protocolId: 'RN-006',
    status: TrainingSessionStatus.completed,
    completedAt: DateTime.utc(2026, 7, 1, 8),
  );
}

List<IntervalPerformance> _threeRepSession() {
  return [
    _workInterval(
      id: 1,
      blockIndex: 1,
      repNumber: 1,
      durationSeconds: 188,
      paceSecondsPerKm: 235,
      rpe: 7,
    ),
    _workInterval(
      id: 2,
      blockIndex: 1,
      repNumber: 2,
      durationSeconds: 190,
      paceSecondsPerKm: 238,
      rpe: 8,
    ),
    _workInterval(
      id: 3,
      blockIndex: 1,
      repNumber: 3,
      durationSeconds: 191,
      paceSecondsPerKm: 239,
      rpe: 8,
    ),
  ];
}

IntervalPerformance _workInterval({
  required int id,
  required int blockIndex,
  required int repNumber,
  int durationSeconds = 188,
  double paceSecondsPerKm = 235,
  int? rpe,
  bool skipped = false,
}) {
  return IntervalPerformance(
    id: id,
    trainingSessionId: 42,
    blockIndex: blockIndex,
    repNumber: repNumber,
    phaseType: IntervalPhaseType.work,
    modality: IntervalModality.running,
    actualDistanceMeters: 800,
    actualDurationSeconds: durationSeconds,
    actualPaceSecondsPerKm: paceSecondsPerKm,
    rpe: rpe,
    completed: true,
    skipped: skipped,
    dataSource: IntervalDataSource.manual,
  );
}
