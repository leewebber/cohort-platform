import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/today_session_service.dart';

import 'athlete_today_workout_resolution.dart';
import 'athlete_workout_orchestrator.dart';
import 'programme_occurrence_materializer.dart';

/// Single application entry point for resolving today's workout (Home bridge).
///
/// Programme resolution remains on [TodaySessionService] behind this facade.
/// When executable, also materializes an ephemeral [SessionOccurrence] and runs
/// [AthleteWorkoutOrchestrator.resolveToday] for the new architecture path.
class AthleteTodayWorkoutResolutionService {
  const AthleteTodayWorkoutResolutionService({
    required TodaySessionService todaySessionService,
    AthleteWorkoutOrchestrator? workoutOrchestrator,
    ProgrammeOccurrenceMaterializer? occurrenceMaterializer,
  }) : _todaySessionService = todaySessionService,
       _workoutOrchestrator =
           workoutOrchestrator ?? const AthleteWorkoutOrchestrator(),
       _occurrenceMaterializer =
           occurrenceMaterializer ?? const ProgrammeOccurrenceMaterializer();

  final TodaySessionService _todaySessionService;
  final AthleteWorkoutOrchestrator _workoutOrchestrator;
  final ProgrammeOccurrenceMaterializer _occurrenceMaterializer;

  /// Resolves today's programme session and mirrors executable slots into domain.
  Future<AthleteTodayWorkoutResolution> resolve({
    required String athleteId,
    DateTime? resolvedAt,
  }) async {
    final programmeSession = await _todaySessionService.resolveForAthlete(
      athleteId,
    );

    final timestamp = resolvedAt ?? DateTime.now();
    final calendarDate = SessionOccurrenceDate.fromDateTime(timestamp);

    if (programmeSession.kind != ResolvedTodaySessionKind.executable) {
      return AthleteTodayWorkoutResolution(programmeSession: programmeSession);
    }

    final occurrenceRepository = AthleteSessionOccurrenceIndex();
    final slotRegistry = InMemoryProgrammeSessionOccurrenceRegistry();

    _occurrenceMaterializer.materializeExecutable(
      athleteId: athleteId,
      programmeSession: programmeSession,
      calendarDate: calendarDate,
      recordedAt: timestamp,
      slotRegistry: slotRegistry,
      occurrenceRepository: occurrenceRepository,
    );

    final workout = _workoutOrchestrator.resolveToday(
      athleteId: athleteId,
      date: calendarDate,
      occurrenceRepository: occurrenceRepository,
    );

    return AthleteTodayWorkoutResolution(
      programmeSession: programmeSession,
      workout: workout,
      occurrenceRepository: occurrenceRepository,
    );
  }
}
