import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';

import 'athlete_workout_result.dart';

/// In-memory execution bridge for Home (not persisted).
class HomeWorkoutExecutionContext {
  const HomeWorkoutExecutionContext({
    required this.occurrenceDate,
    required this.occurrenceRepository,
    required this.workout,
    this.lastAdaptationCommitted = false,
  });

  final SessionOccurrenceDate occurrenceDate;
  final SessionOccurrenceRepository occurrenceRepository;
  final AthleteWorkoutResult workout;
  final bool lastAdaptationCommitted;

  SessionOccurrence? get occurrence => workout.occurrence;

  HomeWorkoutExecutionContext withWorkout(
    AthleteWorkoutResult updated, {
    bool? lastAdaptationCommitted,
  }) {
    return HomeWorkoutExecutionContext(
      occurrenceDate: occurrenceDate,
      occurrenceRepository: occurrenceRepository,
      workout: updated,
      lastAdaptationCommitted:
          lastAdaptationCommitted ?? this.lastAdaptationCommitted,
    );
  }
}
