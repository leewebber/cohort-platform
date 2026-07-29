import '../adaptation/application/adapted_session_execution_snapshot.dart';
import '../workout_player/vocabulary/workout_player_execution_status.dart';
import '../workout_player/workout_player.dart';
import '../workout_player/workout_player_navigation.dart';
import 'value_objects/workout_exercise_execution_entry.dart';
import 'vocabulary/workout_exercise_execution_outcome.dart';
import 'vocabulary/workout_execution_record_lifecycle_status.dart';
import 'workout_execution_record_lifecycle.dart';
import 'workout_execution_record_transition_result.dart';

/// Immutable historical record of a performed workout (domain execution pipeline).
///
/// Prescription structure lives on [executionSnapshot]; this aggregate records
/// what the athlete did (completed / skipped / modified per exercise).
/// Distinct from M8 `TrainingSessionRecord` in
/// `lib/features/performance/models/training_session_record.dart` (Supabase
/// performance tree with block/set results).
class WorkoutExecutionRecord {
  const WorkoutExecutionRecord({
    required this.recordId,
    required this.occurrenceId,
    required this.executionSnapshot,
    required this.startedAt,
    required this.lifecycleStatus,
    this.playerId,
    this.finishedAt,
    this.athleteNotes,
    this.exerciseEntries = const [],
  });

  final String recordId;
  final String occurrenceId;
  final String? playerId;
  final AdaptedSessionExecutionSnapshot executionSnapshot;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final WorkoutExecutionRecordLifecycleStatus lifecycleStatus;
  final String? athleteNotes;
  final List<WorkoutExerciseExecutionEntry> exerciseEntries;

  bool get isTerminal => lifecycleStatus.isTerminal;

  List<WorkoutExerciseExecutionEntry> get completedExercises => exerciseEntries
      .where((e) => e.outcome == WorkoutExerciseExecutionOutcome.completed)
      .toList(growable: false);

  List<WorkoutExerciseExecutionEntry> get skippedExercises => exerciseEntries
      .where((e) => e.outcome == WorkoutExerciseExecutionOutcome.skipped)
      .toList(growable: false);

  List<WorkoutExerciseExecutionEntry> get modifiedExercises => exerciseEntries
      .where((e) => e.outcome == WorkoutExerciseExecutionOutcome.modified)
      .toList(growable: false);

  static WorkoutExecutionRecordTransitionResult beginRecording({
    required String recordId,
    required String occurrenceId,
    required AdaptedSessionExecutionSnapshot executionSnapshot,
    required DateTime startedAt,
    String? playerId,
  }) {
    if (recordId.trim().isEmpty) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.invalidRecordId,
      );
    }
    if (occurrenceId.trim().isEmpty) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.invalidOccurrenceId,
      );
    }

    return WorkoutExecutionRecordTransitionResult.success(
      WorkoutExecutionRecord(
        recordId: recordId.trim(),
        occurrenceId: occurrenceId.trim(),
        playerId: playerId?.trim().isEmpty ?? true ? null : playerId!.trim(),
        executionSnapshot: executionSnapshot,
        startedAt: startedAt,
        lifecycleStatus: WorkoutExecutionRecordLifecycleStatus.recording,
      ),
    );
  }

  /// Starts a recording session from a terminal [WorkoutPlayer] (no exercise outcomes yet).
  static WorkoutExecutionRecordTransitionResult beginFromWorkoutPlayer({
    required WorkoutPlayer player,
    required String recordId,
  }) {
    if (!player.isTerminal) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.playerNotTerminal,
        detail: player.executionStatus.name,
      );
    }
    final startedAt = player.startedAt;
    if (startedAt == null) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.playerMissingStartedAt,
      );
    }

    return beginRecording(
      recordId: recordId,
      occurrenceId: player.occurrenceId,
      executionSnapshot: player.executionSnapshot,
      startedAt: startedAt,
      playerId: player.playerId,
    );
  }

  WorkoutExecutionRecordTransitionResult recordExerciseOutcome({
    required String sourceBlockLocalId,
    required String exerciseLinkLocalId,
    required WorkoutExerciseExecutionOutcome outcome,
    String? note,
  }) {
    if (isTerminal) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.terminalState,
      );
    }
    if (!lifecycleStatus.allowsExerciseUpdates) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.invalidLifecycleStatus,
        detail: lifecycleStatus.name,
      );
    }

    final step = _lookupStep(
      sourceBlockLocalId: sourceBlockLocalId,
      exerciseLinkLocalId: exerciseLinkLocalId,
    );
    if (step == null) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.unknownExercise,
        detail: '$sourceBlockLocalId/$exerciseLinkLocalId',
      );
    }

    final key = _exerciseKey(sourceBlockLocalId, exerciseLinkLocalId);
    final existingIndex = exerciseEntries.indexWhere(
      (e) => _exerciseKey(e.sourceBlockLocalId, e.exerciseLinkLocalId) == key,
    );

    final entry = WorkoutExerciseExecutionEntry(
      sourceBlockLocalId: sourceBlockLocalId,
      exerciseLinkLocalId: exerciseLinkLocalId,
      exerciseId: step.exerciseId,
      stepIndex: step.stepIndex,
      outcome: outcome,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );

    final nextEntries = [...exerciseEntries];
    if (existingIndex >= 0) {
      nextEntries[existingIndex] = entry;
    } else {
      nextEntries.add(entry);
    }
    nextEntries.sort((a, b) => a.stepIndex.compareTo(b.stepIndex));

    return WorkoutExecutionRecordTransitionResult.success(
      _copyWith(exerciseEntries: List.unmodifiable(nextEntries)),
    );
  }

  WorkoutExecutionRecordTransitionResult completeRecording({
    required DateTime finishedAt,
    String? athleteNotes,
  }) {
    return _finalize(
      target: WorkoutExecutionRecordLifecycleStatus.completed,
      finishedAt: finishedAt,
      athleteNotes: athleteNotes,
    );
  }

  WorkoutExecutionRecordTransitionResult abandonRecording({
    required DateTime finishedAt,
    String? athleteNotes,
  }) {
    return _finalize(
      target: WorkoutExecutionRecordLifecycleStatus.abandoned,
      finishedAt: finishedAt,
      athleteNotes: athleteNotes,
    );
  }

  /// Applies outcomes then finalizes lifecycle to match the player's terminal status.
  static WorkoutExecutionRecordTransitionResult finalizeFromWorkoutPlayer({
    required WorkoutPlayer player,
    required String recordId,
    required List<WorkoutExerciseExecutionEntry> exerciseOutcomes,
    String? athleteNotes,
  }) {
    final opened = beginFromWorkoutPlayer(player: player, recordId: recordId);
    if (!opened.isSuccess) return opened;

    var record = opened.record!;
    for (final outcome in exerciseOutcomes) {
      final step = record._lookupStep(
        sourceBlockLocalId: outcome.sourceBlockLocalId,
        exerciseLinkLocalId: outcome.exerciseLinkLocalId,
      );
      if (step == null) {
        return WorkoutExecutionRecordTransitionResult.singleFailure(
          WorkoutExecutionRecordTransitionIssueCode.unknownExercise,
          detail:
              '${outcome.sourceBlockLocalId}/${outcome.exerciseLinkLocalId}',
        );
      }
      if (step.exerciseId != outcome.exerciseId) {
        return WorkoutExecutionRecordTransitionResult.singleFailure(
          WorkoutExecutionRecordTransitionIssueCode.snapshotPlayerMismatch,
          detail: outcome.exerciseLinkLocalId,
        );
      }

      final applied = record.recordExerciseOutcome(
        sourceBlockLocalId: outcome.sourceBlockLocalId,
        exerciseLinkLocalId: outcome.exerciseLinkLocalId,
        outcome: outcome.outcome,
        note: outcome.note,
      );
      if (!applied.isSuccess) return applied;
      record = applied.record!;
    }

    final finishedAt = player.finishedAt ?? player.startedAt!;
    return switch (player.executionStatus) {
      WorkoutPlayerExecutionStatus.completed => record.completeRecording(
        finishedAt: finishedAt,
        athleteNotes: athleteNotes,
      ),
      WorkoutPlayerExecutionStatus.abandoned => record.abandonRecording(
        finishedAt: finishedAt,
        athleteNotes: athleteNotes,
      ),
      _ => WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.playerNotTerminal,
        detail: player.executionStatus.name,
      ),
    };
  }

  WorkoutExecutionRecordTransitionResult _finalize({
    required WorkoutExecutionRecordLifecycleStatus target,
    required DateTime finishedAt,
    String? athleteNotes,
  }) {
    if (isTerminal) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.terminalState,
      );
    }
    if (finishedAt.isBefore(startedAt)) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.invalidTimestamp,
        detail: 'finished_before_start',
      );
    }

    final check = WorkoutExecutionRecordLifecycle.requireTransition(
      record: this,
      target: target,
    );
    if (!check.isSuccess) return check;

    return WorkoutExecutionRecordTransitionResult.success(
      _copyWith(
        lifecycleStatus: target,
        finishedAt: finishedAt,
        athleteNotes: athleteNotes?.trim().isEmpty ?? true
            ? this.athleteNotes
            : athleteNotes!.trim(),
      ),
    );
  }

  _NavigableExerciseStep? _lookupStep({
    required String sourceBlockLocalId,
    required String exerciseLinkLocalId,
  }) {
    final steps = WorkoutPlayerNavigation.navigableSteps(executionSnapshot);
    for (final step in steps) {
      if (step.sourceBlockLocalId != sourceBlockLocalId ||
          step.exerciseLinkLocalId != exerciseLinkLocalId) {
        continue;
      }
      for (final block in executionSnapshot.retainedBlocks) {
        if (block.sourceBlockLocalId != sourceBlockLocalId) continue;
        for (final exercise in block.exercises) {
          if (exercise.exerciseLinkLocalId == exerciseLinkLocalId) {
            return _NavigableExerciseStep(
              stepIndex: step.stepIndex,
              exerciseId: exercise.exerciseId,
            );
          }
        }
      }
    }
    return null;
  }

  static String _exerciseKey(String blockLocalId, String exerciseLinkLocalId) {
    return '$blockLocalId::$exerciseLinkLocalId';
  }

  WorkoutExecutionRecord _copyWith({
    WorkoutExecutionRecordLifecycleStatus? lifecycleStatus,
    DateTime? finishedAt,
    String? athleteNotes,
    List<WorkoutExerciseExecutionEntry>? exerciseEntries,
  }) {
    return WorkoutExecutionRecord(
      recordId: recordId,
      occurrenceId: occurrenceId,
      playerId: playerId,
      executionSnapshot: executionSnapshot,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      athleteNotes: athleteNotes ?? this.athleteNotes,
      exerciseEntries: exerciseEntries ?? this.exerciseEntries,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutExecutionRecord &&
        other.recordId == recordId &&
        other.occurrenceId == occurrenceId &&
        other.playerId == playerId &&
        identical(other.executionSnapshot, executionSnapshot) &&
        other.startedAt == startedAt &&
        other.finishedAt == finishedAt &&
        other.lifecycleStatus == lifecycleStatus &&
        other.athleteNotes == athleteNotes &&
        _listEquals(other.exerciseEntries, exerciseEntries);
  }

  @override
  int get hashCode => Object.hash(
    recordId,
    occurrenceId,
    playerId,
    executionSnapshot,
    startedAt,
    finishedAt,
    lifecycleStatus,
    athleteNotes,
    Object.hashAll(exerciseEntries),
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _NavigableExerciseStep {
  const _NavigableExerciseStep({
    required this.stepIndex,
    required this.exerciseId,
  });

  final int stepIndex;
  final String exerciseId;
}
