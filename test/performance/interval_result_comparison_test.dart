import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/services/interval_result_comparison.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingSessionRecord _record({
  required String id,
  required DateTime completedAt,
  required IntervalResultData data,
}) {
  return TrainingSessionRecord(
    recordId: id,
    athleteId: 'athlete-1',
    trainingSessionId: int.parse(id.replaceAll(RegExp(r'[^0-9]'), '')),
    sourceProtocolId: 'APOLLO-W1-THU-R1',
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'APOLLO-W1-THU-R1',
      sessionTitle: 'Apollo Engine',
    ),
    startedAt: completedAt.subtract(const Duration(minutes: 50)),
    completedAt: completedAt,
    blockResults: [
      TrainingBlockResult(
        blockResultId: '$id-block',
        sessionRecordId: id,
        sourceBlockId: 'engine',
        blockSnapshot: BlockPerformanceSnapshot(
          sourceBlockId: 'engine',
          title: '5K-effort intervals',
          blockType: SessionBlockType.conditioning,
          content: '5 x 3:00',
          workoutFormat: WorkoutFormat.intervals,
          position: 1,
          workSeconds: data.workSeconds,
          comparisonFamily: data.comparisonFamily,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.interval,
        position: 1,
        resultData: data,
      ),
    ],
  );
}

IntervalResultData _fiveByThree({
  required List<double?> paces,
  String family = 'intervals:run:180s:sec_per_km',
}) {
  return IntervalResultData(
    totalIntervals: 5,
    workSeconds: 180,
    comparisonFamily: family,
    intervals: [
      for (var i = 0; i < 5; i++)
        IntervalWorkResult(
          ordinal: i + 1,
          workSeconds: 180,
          paceSecondsPerKm: paces[i],
          state: paces[i] == null
              ? IntervalWorkState.pending
              : IntervalWorkState.completed,
        ),
    ],
  );
}

void main() {
  test('previous comparable session drives Improved Maintained and Below', () {
    final previous = _record(
      id: '1',
      completedAt: DateTime.utc(2026, 9, 1),
      data: _fiveByThree(paces: [270, 268, 267, 266, 265]),
    );
    final improved = _record(
      id: '2',
      completedAt: DateTime.utc(2026, 9, 5),
      data: _fiveByThree(paces: [250, 248, 247, 245, 243]),
    );
    final maintained = _record(
      id: '3',
      completedAt: DateTime.utc(2026, 9, 6),
      data: _fiveByThree(paces: [270, 268, 267, 266, 265]),
    );
    final below = _record(
      id: '4',
      completedAt: DateTime.utc(2026, 9, 7),
      data: _fiveByThree(paces: [290, 288, 287, 286, 285]),
    );

    expect(
      IntervalResultComparison.compare(
        block: improved.blockResults.single,
        current: improved,
        athleteHistory: [previous],
      ).status,
      StrengthExerciseComparisonStatus.improved,
    );
    expect(
      IntervalResultComparison.compare(
        block: maintained.blockResults.single,
        current: maintained,
        athleteHistory: [previous],
      ).status,
      StrengthExerciseComparisonStatus.maintained,
    );
    expect(
      IntervalResultComparison.compare(
        block: below.blockResults.single,
        current: below,
        athleteHistory: [previous],
      ).status,
      StrengthExerciseComparisonStatus.belowPrevious,
    );
  });

  test('first comparable result is Baseline and not a PR', () {
    final first = _record(
      id: '5',
      completedAt: DateTime.utc(2026, 9, 5),
      data: _fiveByThree(paces: [250, 248, 247, 245, 243]),
    );
    final comparison = IntervalResultComparison.compare(
      block: first.blockResults.single,
      current: first,
      athleteHistory: const [],
    );
    expect(comparison.status, StrengthExerciseComparisonStatus.baseline);
    expect(comparison.fastestIsPersonalRecord, isFalse);
  });

  test('scoped PR is earned only against the comparable family', () {
    final previous = _record(
      id: '6',
      completedAt: DateTime.utc(2026, 9, 1),
      data: _fiveByThree(paces: [250, 248, 247, 246, 245]),
    );
    final current = _record(
      id: '7',
      completedAt: DateTime.utc(2026, 9, 5),
      data: _fiveByThree(paces: [250, 248, 247, 245, 243]),
    );
    final comparison = IntervalResultComparison.compare(
      block: current.blockResults.single,
      current: current,
      athleteHistory: [previous],
    );
    expect(comparison.fastestIsPersonalRecord, isTrue);
    expect(comparison.familyLabel, '3-minute interval best');
  });

  test('incompatible work duration is Not comparable', () {
    final strides = _record(
      id: '8',
      completedAt: DateTime.utc(2026, 9, 1),
      data: IntervalResultData(
        totalIntervals: 3,
        workSeconds: 20,
        comparisonFamily: 'intervals:run:20s:sec_per_km',
        intervals: const [
          IntervalWorkResult(
            ordinal: 1,
            workSeconds: 20,
            paceSecondsPerKm: 200,
            state: IntervalWorkState.completed,
          ),
        ],
      ),
    );
    final engine = _record(
      id: '9',
      completedAt: DateTime.utc(2026, 9, 5),
      data: _fiveByThree(paces: [250, 248, 247, 246, 245]),
    );
    expect(
      IntervalResultComparison.compare(
        block: engine.blockResults.single,
        current: engine,
        athleteHistory: [strides],
      ).status,
      StrengthExerciseComparisonStatus.baseline,
    );
  });

  test('completed projection is results-first', () {
    final previous = _record(
      id: '10',
      completedAt: DateTime.utc(2026, 9, 1),
      data: _fiveByThree(paces: [270, 268, 267, 266, 265]),
    );
    final current = _record(
      id: '11',
      completedAt: DateTime.utc(2026, 9, 5),
      data: _fiveByThree(paces: [250, 248, 247, 245, 243]),
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: [previous],
    );
    final interval = projection.blocks.single.interval;
    expect(interval, isNotNull);
    expect(interval!.rows, hasLength(5));
    expect(interval.rows.last.isFastest, isTrue);
    expect(interval.comparisonStatus, StrengthExerciseComparisonStatus.improved);
    expect(interval.personalRecordLabel, '3-minute interval best');
    expect(interval.collapsedSummary, contains('5/5 intervals'));
    expect(interval.metrics.map((metric) => metric.title), [
      'Average pace',
      'Fastest interval',
      'Completion',
    ]);
  });
}
