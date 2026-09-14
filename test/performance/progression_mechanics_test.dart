import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/session_result_entry_mode.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/progression/eligible_performance_evidence.dart';
import 'package:cohort_platform/features/performance/progression/endurance_progression.dart';
import 'package:cohort_platform/features/performance/progression/interval_progression.dart';
import 'package:cohort_platform/features/performance/progression/personal_bests.dart';
import 'package:cohort_platform/features/performance/progression/progression_comparison.dart';
import 'package:cohort_platform/features/performance/progression/strength_progression.dart';
import 'package:cohort_platform/features/performance/services/performance_chronology.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingSetResult set({
    int n = 1,
    double? load = 80,
    int? reps = 5,
    int? rpe,
  }) {
    return TrainingSetResult(
      setResultId: 's$n',
      exerciseResultId: 'e',
      setNumber: n,
      position: n,
      load: load,
      loadUnit: 'kg',
      reps: reps,
      rpe: rpe,
      completed: true,
    );
  }

  StrengthProgressionFacts facts({
    String id = 'EX-095',
    List<TrainingSetResult>? sets,
    int? prescribed,
  }) {
    return StrengthProgressionFacts(
      exerciseId: id,
      loadKind: StrengthActualLoadKind.external,
      sets: sets ?? [set()],
      prescribedSetCount: prescribed,
    );
  }

  test('first performance', () {
    final result = StrengthProgressionComparison.compare(current: facts());
    expect(result.outcome, ProgressionOutcome.firstPerformance);
  });

  test('identical performance is matched', () {
    final result = StrengthProgressionComparison.compare(
      current: facts(),
      previous: facts(),
    );
    expect(result.outcome, ProgressionOutcome.matched);
  });

  test('heavier same reps is improved', () {
    final result = StrengthProgressionComparison.compare(
      current: facts(sets: [set(load: 85, reps: 5)]),
      previous: facts(),
    );
    expect(result.outcome, ProgressionOutcome.improved);
    expect(result.summary, contains('+5 kg'));
  });

  test('same load more reps is improved', () {
    final result = StrengthProgressionComparison.compare(
      current: facts(sets: [set(load: 80, reps: 6)]),
      previous: facts(),
    );
    expect(result.outcome, ProgressionOutcome.improved);
  });

  test('same work lower RPE is improved', () {
    final result = StrengthProgressionComparison.compare(
      current: facts(sets: [set(rpe: 7)]),
      previous: facts(sets: [set(rpe: 8)]),
    );
    expect(result.outcome, ProgressionOutcome.improved);
  });

  test('heavier but fewer reps is mixed', () {
    final result = StrengthProgressionComparison.compare(
      current: facts(sets: [set(load: 90, reps: 3)]),
      previous: facts(sets: [set(load: 80, reps: 5)]),
    );
    expect(result.outcome, ProgressionOutcome.mixed);
  });

  test('more volume only because more sets prescribed is mixed', () {
    final result = StrengthProgressionComparison.compare(
      current: facts(
        sets: [set(n: 1), set(n: 2, load: 75, reps: 5), set(n: 3, load: 75, reps: 5), set(n: 4, load: 75, reps: 5)],
        prescribed: 4,
      ),
      previous: facts(
        sets: [set(n: 1), set(n: 2, load: 80, reps: 5), set(n: 3, load: 80, reps: 5)],
        prescribed: 3,
      ),
    );
    expect(result.outcome, ProgressionOutcome.mixed);
  });

  test('exercise variant mismatch is not comparable', () {
    final result = StrengthProgressionComparison.compare(
      current: facts(id: 'EX-073'),
      previous: facts(id: 'EX-095'),
    );
    expect(result.outcome, ProgressionOutcome.notComparable);
  });

  test('abandoned records are not eligible priors', () {
    final current = _record('now', DateTime.utc(2026, 9, 14));
    final abandoned = _record(
      'old',
      DateTime.utc(2026, 9, 7),
      status: TrainingSessionRecordStatus.abandoned,
    );
    expect(
      EligiblePerformanceEvidence.isEligiblePrior(
        candidate: abandoned,
        current: current,
      ),
      isFalse,
    );
  });

  test('older Backfill sorts before later live by performed date', () {
    final live = _record('live', DateTime.utc(2026, 9, 7));
    final backfill = _record(
      'bf',
      DateTime.utc(2026, 9, 13),
      performedOn: DateTime.utc(2026, 8, 1),
      entryMode: SessionResultEntryMode.backfill,
    );
    expect(PerformanceChronology.compare(backfill, live), lessThan(0));
  });

  test('endurance faster without intensity evidence is insufficient', () {
    final result = EnduranceProgressionComparison.compare(
      current: const EnduranceResultData(
        distance: 5,
        durationSeconds: 1400,
      ),
      previous: const EnduranceResultData(
        distance: 5,
        durationSeconds: 1500,
      ),
    );
    expect(result.outcome, ProgressionOutcome.insufficientEvidence);
    expect(result.summary, contains('intensity'));
  });

  test('interval faster and consistent is improved', () {
    final previous = _intervals(pace: 240);
    final current = _intervals(pace: 228);
    final result = IntervalProgressionComparison.compare(
      current: current,
      previous: previous,
    );
    expect(result.outcome, ProgressionOutcome.improved);
  });

  test('interval faster but less consistent is mixed', () {
    final previous = _intervals(pace: 240, spread: 2);
    final current = _intervals(pace: 200, spread: 50);
    final result = IntervalProgressionComparison.compare(
      current: current,
      previous: previous,
    );
    expect(result.outcome, ProgressionOutcome.mixed);
  });

  test('PB heaviest load uses actuals not prescription', () {
    final history = [
      _strengthRecord('a', DateTime.utc(2026, 9, 7), 10),
      _strengthRecord('b', DateTime.utc(2026, 9, 14), 20),
    ];
    final bests = PersonalBestEvaluator.forExercise(
      athleteId: 'lee',
      exerciseId: 'EX-095',
      history: history,
    );
    expect(bests.first.kind, PersonalBestKind.heaviestLoad);
    expect(bests.first.detail, contains('20'));
  });
}

IntervalResultData _intervals({required int pace, int spread = 0}) {
  return IntervalResultData(
    workSeconds: 180,
    comparisonFamily: '3:00-run',
    intervals: [
      IntervalWorkResult(
        ordinal: 1,
        workSeconds: 180,
        paceSecondsPerKm: pace.toDouble(),
        state: IntervalWorkState.completed,
      ),
      IntervalWorkResult(
        ordinal: 2,
        workSeconds: 180,
        paceSecondsPerKm: (pace + spread).toDouble(),
        state: IntervalWorkState.completed,
      ),
    ],
  );
}

TrainingSessionRecord _record(
  String id,
  DateTime startedAt, {
  TrainingSessionRecordStatus status = TrainingSessionRecordStatus.completed,
  DateTime? performedOn,
  SessionResultEntryMode entryMode = SessionResultEntryMode.live,
}) {
  return TrainingSessionRecord(
    recordId: id,
    athleteId: 'lee',
    status: status,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: '',
      sessionTitle: 'S',
    ),
    startedAt: startedAt,
    completedAt: startedAt,
    performedOn: performedOn,
    entryMode: entryMode,
  );
}

TrainingSessionRecord _strengthRecord(String id, DateTime at, double load) {
  return TrainingSessionRecord(
    recordId: id,
    athleteId: 'lee',
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: '',
      sessionTitle: 'S',
    ),
    startedAt: at,
    completedAt: at,
    blockResults: [
      TrainingBlockResult(
        blockResultId: 'b$id',
        sessionRecordId: id,
        sourceBlockId: 'str',
        resultType: PerformanceResultType.strength,
        status: TrainingBlockResultStatus.completed,
        position: 1,
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'str',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: '',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        exerciseResults: [
          TrainingExerciseResult(
            exerciseResultId: 'e$id',
            blockResultId: 'b$id',
            sourceExerciseId: 'EX-095',
            position: 1,
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'EX-095',
              displayName: 'Weighted Pull-Up',
              position: 1,
              loadKind: StrengthActualLoadKind.external,
            ),
            setResults: [
              TrainingSetResult(
                setResultId: 's$id',
                exerciseResultId: 'e$id',
                setNumber: 1,
                position: 1,
                load: load,
                loadUnit: 'kg',
                reps: 5,
                completed: true,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
