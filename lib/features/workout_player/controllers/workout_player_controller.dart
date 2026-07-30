import 'package:flutter/widgets.dart';

import '../../../core/persistence/athlete_persistence.dart';
import '../../../core/persistence/workout_execution_capture.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/workout_player_state.dart';
import '../models/workout_session_brief.dart';
import '../services/workout_player_plan_flattener.dart';

/// Owns Workout Player progression and lightweight local progress snapshots.
class WorkoutPlayerController extends ChangeNotifier
    with WidgetsBindingObserver {
  WorkoutPlayerController({
    required SessionExecutionPlan plan,
    required WorkoutSessionBrief brief,
    String? orchestrationId,
    String? athleteId,
    WorkoutPlayerPlanFlattener flattener = const WorkoutPlayerPlanFlattener(),
  }) : _athleteId = athleteId ??
           AthleteProfileSession.profile?.athleteId ??
           'athlete.local',
       _state = WorkoutPlayerState(
         plan: plan,
         brief: brief,
         steps: flattener.flatten(plan),
         phase: WorkoutPlayerPhase.overview,
         currentExerciseIndex: 0,
         currentSet: 1,
         completedExerciseIndexes: const {},
         orchestrationId: orchestrationId,
       );

  final String _athleteId;
  WorkoutPlayerState _state;
  bool _observingLifecycle = false;
  DateTime? _lastSnapshotAt;

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistProgress(force: true);
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
    _persistProgress(force: true);
  }

  void completeSet() {
    if (_state.phase != WorkoutPlayerPhase.active) return;
    final step = _state.currentStep;
    if (step == null) return;

    if (_state.currentSet < step.totalSets) {
      _state = _state.copyWith(currentSet: _state.currentSet + 1);
      notifyListeners();
      _persistProgress();
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
    _persistProgress(force: true);
  }

  void goToPrevious() {
    if (_state.phase != WorkoutPlayerPhase.active) return;
    if (_state.currentSet > 1) {
      _state = _state.copyWith(currentSet: _state.currentSet - 1);
      notifyListeners();
      _persistProgress();
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
    _persistProgress();
  }

  void goToNext() {
    if (_state.phase != WorkoutPlayerPhase.active) return;
    final step = _state.currentStep;
    if (step == null) return;
    if (_state.currentSet < step.totalSets) {
      _state = _state.copyWith(currentSet: _state.currentSet + 1);
      notifyListeners();
      _persistProgress();
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
    _persistProgress(force: true);
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

  void _persistProgress({bool force = false}) {
    if (!AthletePersistence.isInitialized) return;
    if (_state.phase != WorkoutPlayerPhase.active) return;
    final now = DateTime.now().toUtc();
    if (!force &&
        _lastSnapshotAt != null &&
        now.difference(_lastSnapshotAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSnapshotAt = now;
    final snapshot = const WorkoutExecutionCapture().snapshotFromState(
      state: _state,
      athleteId: _athleteId,
      assignmentId: AthleteProfileSession.activeAssignment?.assignmentId,
      now: now,
    );
    AthletePersistence.hydrator.saveWorkoutProgress(snapshot);
  }

  @override
  void dispose() {
    detachLifecycleObserver();
    super.dispose();
  }
}
