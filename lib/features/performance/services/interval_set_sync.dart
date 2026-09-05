import '../../../core/utils/database_uuid.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/active_performance_draft.dart';
import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';

class IntervalSetSync {
  const IntervalSetSync._();

  static const paceUnavailableNote = 'pace_unavailable';
  static const skippedNote = 'skipped';

  static List<ExercisePerformanceDraft> ensureAuthoredRows({
    required List<ExercisePerformanceDraft> exercises,
    required IntervalResultData result,
    SessionExecutionBlock? block,
  }) {
    if (result.intervals.isEmpty) return exercises;
    if (exercises.isEmpty) {
      final title = block?.title.trim().isNotEmpty == true
          ? block!.title.trim()
          : 'Intervals';
      final syntheticId = 'interval:${block?.blockId ?? 'block'}';
      exercises = [
        ExercisePerformanceDraft(
          exerciseResultId: DatabaseUuid.newV4(),
          sourceExerciseId: syntheticId,
          exerciseSnapshot: ExercisePerformanceSnapshot(
            sourceExerciseId: syntheticId,
            displayName: title,
            position: 1,
          ),
          position: 1,
        ),
      ];
    }
    final host = exercises.first;
    final byOrdinal = {for (final set in host.sets) set.setNumber: set};
    final sets = [
      for (final row in result.intervals)
        applyRow(
          byOrdinal[row.ordinal] ??
              SetPerformanceDraft.empty(
                setNumber: row.ordinal,
                position: row.ordinal,
                distanceUnit: 'km',
              ),
          row,
        ),
    ];
    return [
      host.copyWith(sets: sets),
      ...exercises.skip(1),
    ];
  }

  static SetPerformanceDraft applyRow(
    SetPerformanceDraft set,
    IntervalWorkResult row,
  ) {
    return set.copyWith(
      setNumber: row.ordinal,
      position: row.ordinal,
      durationSeconds: row.workSeconds > 0 ? row.workSeconds : null,
      clearDurationSeconds: row.workSeconds <= 0,
      distance: row.impliedDistanceKm,
      clearDistance: row.impliedDistanceKm == null,
      distanceUnit: 'km',
      completed: row.state.countsAsCompleted,
      note: switch (row.state) {
        IntervalWorkState.paceUnavailable => paceUnavailableNote,
        IntervalWorkState.skipped => skippedNote,
        _ => null,
      },
      clearNote:
          row.state != IntervalWorkState.paceUnavailable &&
          row.state != IntervalWorkState.skipped,
    );
  }

  static IntervalWorkResult rowFromSet(
    TrainingSetResult set, {
    required int workSeconds,
    required String paceUnit,
  }) {
    final note = set.note?.trim();
    if (note == skippedNote) {
      return IntervalWorkResult(
        ordinal: set.setNumber,
        workSeconds: set.durationSeconds ?? workSeconds,
        paceUnit: paceUnit,
        state: IntervalWorkState.skipped,
      );
    }
    if (note == paceUnavailableNote ||
        (set.completed &&
            (set.distance == null || set.distance! <= 0))) {
      return IntervalWorkResult(
        ordinal: set.setNumber,
        workSeconds: set.durationSeconds ?? workSeconds,
        paceUnit: paceUnit,
        state: IntervalWorkState.paceUnavailable,
      );
    }
    final duration = set.durationSeconds ?? workSeconds;
    final pace = set.distance != null && set.distance! > 0 && duration > 0
        ? duration / set.distance!
        : null;
    return IntervalWorkResult(
      ordinal: set.setNumber,
      workSeconds: duration,
      paceSecondsPerKm: pace,
      paceUnit: paceUnit,
      state: set.completed && pace != null
          ? IntervalWorkState.completed
          : IntervalWorkState.pending,
    );
  }

  static TrainingSetResult applyToRecordedSet(
    TrainingSetResult set,
    IntervalWorkResult row,
  ) {
    return set.copyWith(
      durationSeconds: row.workSeconds > 0 ? row.workSeconds : null,
      clearDurationSeconds: row.workSeconds <= 0,
      distance: row.impliedDistanceKm,
      clearDistance: row.impliedDistanceKm == null,
      distanceUnit: 'km',
      completed: row.state.countsAsCompleted,
      note: switch (row.state) {
        IntervalWorkState.paceUnavailable => paceUnavailableNote,
        IntervalWorkState.skipped => skippedNote,
        _ => null,
      },
      clearNote:
          row.state != IntervalWorkState.paceUnavailable &&
          row.state != IntervalWorkState.skipped,
    );
  }

  static IntervalResultData hydrateFromSets({
    required IntervalResultData result,
    required List<TrainingExerciseResult> exercises,
  }) {
    if (result.usesPerIntervalCapture || result.prescribedCount == null) {
      return result;
    }
    if (exercises.isEmpty || exercises.first.setResults.isEmpty) {
      return result;
    }
    final work = result.workSeconds ?? 0;
    final rows = [
      for (final set in exercises.first.setResults)
        rowFromSet(set, workSeconds: work, paceUnit: result.paceUnit),
    ]..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return result.copyWith(intervals: rows);
  }
}
