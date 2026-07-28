import '../adaptation/application/adapted_session_execution_snapshot.dart';
import '../session_occurrence/session_occurrence.dart';
import '../session_occurrence/vocabulary/session_occurrence_lifecycle_state.dart';
import 'value_objects/workout_player_position.dart';
import 'vocabulary/workout_player_execution_status.dart';
import 'workout_player_lifecycle.dart';
import 'workout_player_navigation.dart';
import 'workout_player_transition_result.dart';

/// Active execution state for an in-progress [SessionOccurrence].
///
/// Prescription content lives on [executionSnapshot]; this aggregate only tracks
/// position and execution status until [TrainingSessionRecord] captures metrics.
class WorkoutPlayer {
  const WorkoutPlayer({
    required this.playerId,
    required this.occurrenceId,
    required this.executionSnapshot,
    required this.currentPosition,
    required this.executionStatus,
    this.startedAt,
    this.pausedAt,
    this.finishedAt,
  });

  final String playerId;
  final String occurrenceId;
  final AdaptedSessionExecutionSnapshot executionSnapshot;
  final WorkoutPlayerPosition currentPosition;
  final WorkoutPlayerExecutionStatus executionStatus;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? finishedAt;

  bool get isTerminal => executionStatus.isTerminal;

  int get totalStepCount =>
      WorkoutPlayerNavigation.navigableSteps(executionSnapshot).length;

  int get remainingStepCount => WorkoutPlayerNavigation.remainingStepsAfter(
        snapshot: executionSnapshot,
        current: currentPosition,
      );

  bool get isAtFirstStep => currentPosition.stepIndex == 0;

  bool get isAtLastStep => WorkoutPlayerNavigation.isAtLastStep(
        snapshot: executionSnapshot,
        current: currentPosition,
      );

  bool get hasFinished =>
      executionStatus == WorkoutPlayerExecutionStatus.completed;

  /// Opens a player in [WorkoutPlayerExecutionStatus.ready] at the first exercise.
  static WorkoutPlayerTransitionResult openReady({
    required String playerId,
    required String occurrenceId,
    required AdaptedSessionExecutionSnapshot executionSnapshot,
  }) {
    final idIssue = _validateIds(playerId: playerId, occurrenceId: occurrenceId);
    if (idIssue != null) return idIssue;

    final first = WorkoutPlayerNavigation.firstPosition(executionSnapshot);
    if (first == null) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.emptyWorkout,
      );
    }

    return WorkoutPlayerTransitionResult.success(
      WorkoutPlayer(
        playerId: playerId.trim(),
        occurrenceId: occurrenceId.trim(),
        executionSnapshot: executionSnapshot,
        currentPosition: first,
        executionStatus: WorkoutPlayerExecutionStatus.ready,
      ),
    );
  }

  /// Opens from an occurrence that is already [SessionOccurrenceLifecycleState.inProgress].
  static WorkoutPlayerTransitionResult openForOccurrence({
    required SessionOccurrence occurrence,
    required String playerId,
  }) {
    if (occurrence.lifecycleState != SessionOccurrenceLifecycleState.inProgress) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.occurrenceNotInProgress,
        detail: occurrence.lifecycleState.name,
      );
    }
    final snapshot = occurrence.executionSnapshot;
    if (snapshot == null) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.snapshotRequired,
      );
    }
    return openReady(
      playerId: playerId,
      occurrenceId: occurrence.occurrenceId,
      executionSnapshot: snapshot,
    );
  }

  WorkoutPlayerTransitionResult activate({required DateTime recordedAt}) {
    if (isTerminal) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
    }
    final check = WorkoutPlayerLifecycle.requireTransition(
      player: this,
      target: WorkoutPlayerExecutionStatus.active,
    );
    if (!check.isSuccess) return check;

    return WorkoutPlayerTransitionResult.success(
      _copyWith(
        executionStatus: WorkoutPlayerExecutionStatus.active,
        startedAt: startedAt ?? recordedAt,
        clearPausedAt: true,
      ),
    );
  }

  WorkoutPlayerTransitionResult pause({required DateTime recordedAt}) {
    if (isTerminal) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
    }
    final check = WorkoutPlayerLifecycle.requireTransition(
      player: this,
      target: WorkoutPlayerExecutionStatus.paused,
    );
    if (!check.isSuccess) return check;

    return WorkoutPlayerTransitionResult.success(
      _copyWith(
        executionStatus: WorkoutPlayerExecutionStatus.paused,
        pausedAt: recordedAt,
      ),
    );
  }

  WorkoutPlayerTransitionResult resume({required DateTime recordedAt}) {
    if (isTerminal) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
    }
    final check = WorkoutPlayerLifecycle.requireTransition(
      player: this,
      target: WorkoutPlayerExecutionStatus.active,
    );
    if (!check.isSuccess) return check;

    return WorkoutPlayerTransitionResult.success(
      _copyWith(
        executionStatus: WorkoutPlayerExecutionStatus.active,
        startedAt: startedAt ?? recordedAt,
        clearPausedAt: true,
      ),
    );
  }

  WorkoutPlayerTransitionResult abandon({required DateTime recordedAt}) {
    if (isTerminal) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
    }
    final check = WorkoutPlayerLifecycle.requireTransition(
      player: this,
      target: WorkoutPlayerExecutionStatus.abandoned,
    );
    if (!check.isSuccess) return check;

    return WorkoutPlayerTransitionResult.success(
      _copyWith(
        executionStatus: WorkoutPlayerExecutionStatus.abandoned,
        finishedAt: recordedAt,
        clearPausedAt: true,
      ),
    );
  }

  WorkoutPlayerTransitionResult finishWorkout({required DateTime recordedAt}) {
    return _complete(recordedAt: recordedAt);
  }

  WorkoutPlayerTransitionResult completeWorkout({required DateTime recordedAt}) {
    return _complete(recordedAt: recordedAt);
  }

  WorkoutPlayerTransitionResult nextExercise() {
    return _moveToStepIndex(currentPosition.stepIndex + 1);
  }

  WorkoutPlayerTransitionResult previousExercise() {
    return _moveToStepIndex(currentPosition.stepIndex - 1);
  }

  WorkoutPlayerTransitionResult nextBlock() {
    if (!executionStatus.allowsNavigation) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.invalidExecutionStatus,
        detail: executionStatus.name,
      );
    }
    final nextIndex = WorkoutPlayerNavigation.nextBlockFirstStepIndex(
      snapshot: executionSnapshot,
      current: currentPosition,
    );
    if (nextIndex == null) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.navigationBoundary,
        detail: 'next_block',
      );
    }
    return _moveToStepIndex(nextIndex, skipNavigationStatusCheck: true);
  }

  WorkoutPlayerTransitionResult _complete({required DateTime recordedAt}) {
    if (isTerminal) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
    }
    final check = WorkoutPlayerLifecycle.requireTransition(
      player: this,
      target: WorkoutPlayerExecutionStatus.completed,
    );
    if (!check.isSuccess) return check;

    return WorkoutPlayerTransitionResult.success(
      _copyWith(
        executionStatus: WorkoutPlayerExecutionStatus.completed,
        finishedAt: recordedAt,
        clearPausedAt: true,
      ),
    );
  }

  WorkoutPlayerTransitionResult _moveToStepIndex(
    int stepIndex, {
    bool skipNavigationStatusCheck = false,
  }) {
    if (isTerminal) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
    }
    if (!skipNavigationStatusCheck && !executionStatus.allowsNavigation) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.invalidExecutionStatus,
        detail: executionStatus.name,
      );
    }

    final nextPosition = WorkoutPlayerNavigation.positionAtStepIndex(
      snapshot: executionSnapshot,
      stepIndex: stepIndex,
    );
    if (nextPosition == null) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.navigationBoundary,
        detail: stepIndex.toString(),
      );
    }

    return WorkoutPlayerTransitionResult.success(
      _copyWith(currentPosition: nextPosition),
    );
  }

  static WorkoutPlayerTransitionResult? _validateIds({
    required String playerId,
    required String occurrenceId,
  }) {
    if (playerId.trim().isEmpty) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.invalidPlayerId,
      );
    }
    if (occurrenceId.trim().isEmpty) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.invalidOccurrenceId,
      );
    }
    return null;
  }

  WorkoutPlayer _copyWith({
    WorkoutPlayerPosition? currentPosition,
    WorkoutPlayerExecutionStatus? executionStatus,
    DateTime? startedAt,
    DateTime? pausedAt,
    DateTime? finishedAt,
    bool clearPausedAt = false,
  }) {
    final DateTime? nextStartedAt;
    if (startedAt != null) {
      nextStartedAt = startedAt;
    } else {
      nextStartedAt = this.startedAt;
    }

    return WorkoutPlayer(
      playerId: playerId,
      occurrenceId: occurrenceId,
      executionSnapshot: executionSnapshot,
      currentPosition: currentPosition ?? this.currentPosition,
      executionStatus: executionStatus ?? this.executionStatus,
      startedAt: nextStartedAt,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutPlayer &&
        other.playerId == playerId &&
        other.occurrenceId == occurrenceId &&
        identical(other.executionSnapshot, executionSnapshot) &&
        other.currentPosition == currentPosition &&
        other.executionStatus == executionStatus &&
        other.startedAt == startedAt &&
        other.pausedAt == pausedAt &&
        other.finishedAt == finishedAt;
  }

  @override
  int get hashCode => Object.hash(
        playerId,
        occurrenceId,
        executionSnapshot,
        currentPosition,
        executionStatus,
        startedAt,
        pausedAt,
        finishedAt,
      );
}
