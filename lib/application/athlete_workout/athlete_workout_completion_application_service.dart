import 'package:cohort_platform/domain/workout_execution_record/workout_execution_record_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';

import '../ports/workout_execution_record_store.dart';
import 'athlete_workout_orchestrator.dart';
import 'athlete_workout_result.dart';
import 'home_workout_execution_context.dart';

/// Domain completion entry point for programme Home workouts.
class AthleteWorkoutCompletionApplicationService {
  const AthleteWorkoutCompletionApplicationService({
    AthleteWorkoutOrchestrator? workoutOrchestrator,
    WorkoutExecutionRecordStore? workoutExecutionRecordStore,
  }) : _workoutOrchestrator =
           workoutOrchestrator ?? const AthleteWorkoutOrchestrator(),
       _workoutExecutionRecordStore = workoutExecutionRecordStore;

  final AthleteWorkoutOrchestrator _workoutOrchestrator;
  final WorkoutExecutionRecordStore? _workoutExecutionRecordStore;

  AthleteWorkoutCompletionResult complete({
    required HomeWorkoutExecutionContext executionContext,
    required String athleteId,
    required WorkoutPlayer workoutPlayer,
    required List<WorkoutExerciseExecutionEntry> exerciseOutcomes,
    required DateTime finishedAt,
    String? recordId,
  }) {
    final domainResult = _workoutOrchestrator.completeTodayWorkout(
      athleteId: athleteId,
      date: executionContext.occurrenceDate,
      occurrenceRepository: executionContext.occurrenceRepository,
      workoutPlayer: workoutPlayer,
      exerciseOutcomes: exerciseOutcomes,
      finishedAt: finishedAt,
      recordId: recordId,
      workoutExecutionRecordStore: _workoutExecutionRecordStore,
    );

    return AthleteWorkoutCompletionResult(
      domainResult: domainResult,
      updatedExecutionContext: domainResult.completionSucceeded
          ? executionContext.withWorkout(domainResult)
          : executionContext,
    );
  }
}

class AthleteWorkoutCompletionResult {
  const AthleteWorkoutCompletionResult({
    required this.domainResult,
    required this.updatedExecutionContext,
  });

  final AthleteWorkoutResult domainResult;
  final HomeWorkoutExecutionContext updatedExecutionContext;

  bool get succeeded => domainResult.completionSucceeded;
  WorkoutExecutionRecord? get workoutExecutionRecord =>
      domainResult.workoutExecutionRecord;
}
