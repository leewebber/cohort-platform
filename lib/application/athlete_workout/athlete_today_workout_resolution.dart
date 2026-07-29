import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';

import 'athlete_workout_result.dart';

/// Programme + domain workout view for a single Home load (bridge output).
class AthleteTodayWorkoutResolution {
  const AthleteTodayWorkoutResolution({
    required this.programmeSession,
    this.workout,
    this.occurrenceRepository,
  });

  /// Legacy programme engine resolution — still drives Home UI mapping.
  final ResolvedTodaySession programmeSession;

  /// Domain pipeline result when an executable slot was materialized (may be null).
  final AthleteWorkoutResult? workout;

  /// Ephemeral occurrence index used for this resolution (in-memory, not persisted).
  final SessionOccurrenceRepository? occurrenceRepository;
}
