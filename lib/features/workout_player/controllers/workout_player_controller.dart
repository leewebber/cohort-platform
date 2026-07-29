import 'package:flutter/widgets.dart';

import '../../session/models/session_execution_plan.dart';
import '../models/workout_player_state.dart';
import '../models/workout_session_brief.dart';
import '../services/workout_player_plan_flattener.dart';

/// Owns in-memory Workout Player progression. No persistence yet.
class WorkoutPlayerController extends ChangeNotifier
    with WidgetsBindingObserver {
  WorkoutPlayerController({
    required SessionExecutionPlan plan,
    required WorkoutSessionBrief brief,
    String? orchestrationId,
    WorkoutPlayerPlanFlattener flattener = const WorkoutPlayerPlanFlattener(),
  }) : _state = WorkoutPlayerState(
         plan: plan,
         brief: brief,
         steps: flattener.flatten(plan),
         phase: WorkoutPlayerPhase.overview,
         currentExerciseIndex: 0,
         currentSet: 1,
         completedExerciseIndexes: const {},
         orchestrationId: orchestrationId,
       );

  WorkoutPlayerState _state;
  bool _observingLifecycle = false;

  WorkoutPlayerState get state => _state;

  void attachLifecycleObserver() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  void detachLifecycleObserver() {
    if (!_observingLifecycle) return;
    WidgetsBinding.instance.removeObserver(this);
    _observingLifecycle = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // State remains in memory; persistence can snapshot [state.toPersistenceMap].
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint(
        '[WorkoutPlayer] lifecycle=${state.name} '
        'snapshot=${_state.toPersistenceMap()}',
      );
    }
  }

  void startSession() {
    if (_state.steps.isEmpty) {
      _state = _state.copyWith(
        phase: WorkoutPlayerPhase.complete,
        startedAt: DateTime.now().toUtc(),
        completedAt: DateTime.now().toUtc(),
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      phase: WorkoutPlayerPhase.active,
      startedAt: DateTime.now().toUtc(),
      currentExerciseIndex: 0,
      currentSet: 1,
      clearCompletedAt: true,
    );
    notifyListeners();
  }

  void completeSet() {
    if (_state.phase != WorkoutPlayerPhase.active) return;
    final step = _state.currentStep;
    if (step == null) return;

    if (_state.currentSet < step.totalSets) {
      _state = _state.copyWith(currentSet: _state.currentSet + 1);
      notifyListeners();
      return;
    }

    final completed = {..._state.completedExerciseIndexes, _state.currentExerciseIndex};
    final nextIndex = _state.currentExerciseIndex + 1;
    if (nextIndex >= _state.steps.length) {
      _state = _state.copyWith(
        phase: WorkoutPlayerPhase.complete,
        completedExerciseIndexes: completed,
        completedAt: DateTime.now().toUtc(),
        currentSet: step.totalSets,
      );
    } else {
      _state = _state.copyWith(
        completedExerciseIndexes: completed,
        currentExerciseIndex: nextIndex,
        currentSet: 1,
      );
    }
    notifyListeners();
  }

  void goToPrevious() {
    if (_state.phase != WorkoutPlayerPhase.active) return;
    if (_state.currentSet > 1) {
      _state = _state.copyWith(currentSet: _state.currentSet - 1);
      notifyListeners();
      return;
    }
    if (_state.currentExerciseIndex <= 0) return;
    final prev = _state.currentExerciseIndex - 1;
    final prevSets = _state.steps[prev].totalSets;
    final completed = {..._state.completedExerciseIndexes}..remove(prev);
    _state = _state.copyWith(
      currentExerciseIndex: prev,
      currentSet: prevSets,
      completedExerciseIndexes: completed,
    );
    notifyListeners();
  }

  void goToNext() {
    if (_state.phase != WorkoutPlayerPhase.active) return;
    final step = _state.currentStep;
    if (step == null) return;
    if (_state.currentSet < step.totalSets) {
      _state = _state.copyWith(currentSet: _state.currentSet + 1);
      notifyListeners();
      return;
    }
    final completed = {
      ..._state.completedExerciseIndexes,
      _state.currentExerciseIndex,
    };
    final nextIndex = _state.currentExerciseIndex + 1;
    if (nextIndex >= _state.steps.length) {
      _state = _state.copyWith(
        phase: WorkoutPlayerPhase.complete,
        completedExerciseIndexes: completed,
        completedAt: DateTime.now().toUtc(),
      );
    } else {
      _state = _state.copyWith(
        completedExerciseIndexes: completed,
        currentExerciseIndex: nextIndex,
        currentSet: 1,
      );
    }
    notifyListeners();
  }

  void updateNotes(String? notes) {
    _state = _state.copyWith(notes: notes);
    notifyListeners();
  }

  void updateSessionRpe(int? rpe) {
    _state = _state.copyWith(sessionRpe: rpe);
    notifyListeners();
  }

  void markCompleteFromOverviewIfEmpty() {
    if (_state.steps.isNotEmpty) return;
    _state = _state.copyWith(
      phase: WorkoutPlayerPhase.complete,
      startedAt: DateTime.now().toUtc(),
      completedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    detachLifecycleObserver();
    super.dispose();
  }
}
