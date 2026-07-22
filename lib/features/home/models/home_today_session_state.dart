import '../../../models/athlete_state.dart';
import '../../../models/programme.dart';
import '../../../models/protocol.dart';
import '../../../models/training_session.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../../programme/models/resolved_today_session.dart';

/// Resolved Home view state for the Today section.
sealed class HomeTodaySessionState {
  const HomeTodaySessionState();
}

class HomeTodaySessionLoading extends HomeTodaySessionState {
  const HomeTodaySessionLoading();
}

class HomeTodaySessionError extends HomeTodaySessionState {
  const HomeTodaySessionError({
    required this.error,
    required this.message,
  });

  final Object error;
  final String message;
}

class HomeTodaySessionEmpty extends HomeTodaySessionState {
  const HomeTodaySessionEmpty();
}

/// Programme-resolved executable slot — overrides manual protocol selection.
class HomeTodaySessionProgrammeExecutable extends HomeTodaySessionState {
  const HomeTodaySessionProgrammeExecutable({
    required this.resolution,
    required this.protocol,
    required this.executionContext,
    this.latestTrainingSession,
    this.progressSummary,
  });

  final ResolvedTodaySession resolution;
  final Protocol protocol;
  final ProgrammeExecutionContext executionContext;
  final TrainingSession? latestTrainingSession;
  final ProgrammeProgressSummary? progressSummary;
}

class HomeTodaySessionRestDay extends HomeTodaySessionState {
  const HomeTodaySessionRestDay({
    required this.resolution,
    this.progressSummary,
  });

  final ResolvedTodaySession resolution;
  final ProgrammeProgressSummary? progressSummary;
}

class HomeTodaySessionDayComplete extends HomeTodaySessionState {
  const HomeTodaySessionDayComplete({
    required this.resolution,
    this.progressSummary,
  });

  final ResolvedTodaySession resolution;
  final ProgrammeProgressSummary? progressSummary;
}

class HomeTodaySessionProgrammeComplete extends HomeTodaySessionState {
  const HomeTodaySessionProgrammeComplete({
    required this.resolution,
    this.progressSummary,
  });

  final ResolvedTodaySession resolution;
  final ProgrammeProgressSummary? progressSummary;
}

class HomeTodaySessionPaused extends HomeTodaySessionState {
  const HomeTodaySessionPaused({
    required this.resolution,
    this.progressSummary,
  });

  final ResolvedTodaySession resolution;
  final ProgrammeProgressSummary? progressSummary;
}

/// Manual ad-hoc session from athlete_state when no active programme assignment.
class HomeTodaySessionManual extends HomeTodaySessionState {
  const HomeTodaySessionManual({
    required this.athleteState,
    required this.protocol,
    this.programme,
    this.latestTrainingSession,
  });

  final AthleteState athleteState;
  final Protocol protocol;
  final Programme? programme;
  final TrainingSession? latestTrainingSession;
}
