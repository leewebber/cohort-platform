import 'package:cohort_platform/application/athlete_workout/home_workout_execution_context.dart';
import 'package:cohort_platform/application/athlete_workout/home_workout_launch_service.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';

/// Canonical domain execution identity for a legacy M7 session launch.
class WorkoutSessionLaunchContext {
  const WorkoutSessionLaunchContext({
    required this.occurrence,
    required this.executionSnapshot,
    required this.legacyProtocolId,
    required this.workoutPlayer,
    this.homeWorkoutExecution,
  });

  factory WorkoutSessionLaunchContext.fromBundle(
    HomeWorkoutLaunchBundle bundle, {
    HomeWorkoutExecutionContext? homeWorkoutExecution,
  }) {
    return WorkoutSessionLaunchContext(
      occurrence: bundle.occurrence,
      executionSnapshot: bundle.executionSnapshot,
      legacyProtocolId: bundle.legacyProtocolId,
      workoutPlayer: bundle.workoutPlayer,
      homeWorkoutExecution: homeWorkoutExecution,
    );
  }

  final SessionOccurrence occurrence;
  final AdaptedSessionExecutionSnapshot executionSnapshot;
  final String legacyProtocolId;
  final WorkoutPlayer workoutPlayer;
  final HomeWorkoutExecutionContext? homeWorkoutExecution;

  String get occurrenceId => occurrence.occurrenceId;
}
