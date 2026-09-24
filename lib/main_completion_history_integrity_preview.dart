import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/widgets/local_preview_banner.dart';
import 'package:cohort_platform/features/auth/widgets/athlete_identity_access_state.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_programme_card.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/session_result_entry_mode.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/screens/training_history_screen.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/domain/athlete_programme_continuity.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_completion_journey_copy.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_status_state.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/preview/athlete_shell_preview_fixture.dart';
import 'package:cohort_platform/preview/athlete_shell_preview_stores.dart';
import 'package:flutter/material.dart';

/// Fixture-only Sprint 3 preview. Not imported by `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4194 --web-hostname 127.0.0.1 \
///     -t lib/main_completion_history_integrity_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CompletionHistoryIntegrityPreviewApp());
}

enum CompletionPreviewState {
  activeProgramme,
  todayCompleteProgrammeContinues,
  programmeJustCompleted,
  completedHome,
  completedCalendar,
  completedProgrammes,
  progressData,
  progressEmpty,
  progressRefreshFailed,
  progressBlocked,
  historyData,
  historyEmpty,
  historyRefreshFailed,
  historyBlocked,
  missingAthlete,
  coachOnlyDenied,
  noActiveWithHistory,
  completedPlusNewActive,
  unavailableCompletedPin,
  narrow320CompletedHome,
  largeTextCompletedHome,
}

class CompletionHistoryIntegrityPreviewApp extends StatelessWidget {
  const CompletionHistoryIntegrityPreviewApp({
    super.key,
    this.initialState = CompletionPreviewState.completedHome,
  });

  final CompletionPreviewState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: CompletionHistoryIntegrityPreviewScreen(
        key: ValueKey(initialState),
        initialState: initialState,
      ),
    );
  }
}

class CompletionHistoryIntegrityPreviewScreen extends StatefulWidget {
  const CompletionHistoryIntegrityPreviewScreen({
    super.key,
    required this.initialState,
  });

  final CompletionPreviewState initialState;

  @override
  State<CompletionHistoryIntegrityPreviewScreen> createState() =>
      _CompletionHistoryIntegrityPreviewScreenState();
}

class _CompletionHistoryIntegrityPreviewScreenState
    extends State<CompletionHistoryIntegrityPreviewScreen> {
  late CompletionPreviewState _state = widget.initialState;

  @override
  Widget build(BuildContext context) {
    final large = _state == CompletionPreviewState.largeTextCompletedHome;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(large ? 1.9 : 1),
        size: _state == CompletionPreviewState.narrow320CompletedHome
            ? const Size(320, 700)
            : MediaQuery.sizeOf(context),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Sprint 3 preview')),
        body: ListView(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          children: [
            const LocalPreviewBanner(),
            const SizedBox(height: CohortSpacing.md),
            DropdownButton<CompletionPreviewState>(
              value: _state,
              isExpanded: true,
              items: [
                for (final state in CompletionPreviewState.values)
                  DropdownMenuItem(
                    value: state,
                    child: Text(state.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (next) {
                if (next == null) return;
                setState(() => _state = next);
              },
            ),
            const SizedBox(height: CohortSpacing.lg),
            _previewBody(_state),
          ],
        ),
      ),
    );
  }

  Widget _previewBody(CompletionPreviewState state) {
    final completedHome = AthleteHomeCompletedProgrammeCard(
      programmeTitle: 'Apollo Strength',
      supportingLine:
          'This programme is complete. Your results stay in History.',
      onViewResults: () {},
      onBrowseProgrammes: () {},
    );

    switch (state) {
      case CompletionPreviewState.activeProgramme:
        return AthleteProgrammeStatusState.fromContinuity(
          const AthleteProgrammeContinuity(
            status: AthleteProgrammeContinuityStatus.currentDefault,
            timezoneHealth: AssignmentTimezoneHealth.valid,
            pinnedTitle: 'Apollo Strength',
            lineageCode: 'APOLLO-BUILD-12-WEEK',
          ),
        );
      case CompletionPreviewState.todayCompleteProgrammeContinues:
        return const AthleteProgrammeStatusState(
          badge: AthleteCompletionJourneyCopy.complete,
          headline: 'Today’s session is finished.',
          explanation:
              'The assignment remains active. Remaining sessions continue.',
        );
      case CompletionPreviewState.programmeJustCompleted:
      case CompletionPreviewState.completedHome:
      case CompletionPreviewState.narrow320CompletedHome:
      case CompletionPreviewState.largeTextCompletedHome:
        return completedHome;
      case CompletionPreviewState.completedCalendar:
        return SizedBox(
          height: 640,
          child: _completedCalendarScreen(),
        );
      case CompletionPreviewState.completedProgrammes:
        return _completedProgrammesScreen();
      case CompletionPreviewState.progressData:
        return ProgressScreen(
          athleteIdOverride: previewAthleteId,
          summary: _progressSummary(sessionsCompleted: 12),
        );
      case CompletionPreviewState.progressEmpty:
        return ProgressScreen(
          athleteIdOverride: previewAthleteId,
          summary: AthleteProgressSummaryBuilder.emptySummary(),
        );
      case CompletionPreviewState.progressRefreshFailed:
        return ProgressScreen(
          athleteIdOverride: previewAthleteId,
          summary: _progressSummary(sessionsCompleted: 8),
          refreshFailed: true,
        );
      case CompletionPreviewState.progressBlocked:
        return ProgressScreen(
          athleteIdOverride: previewAthleteId,
          progressBuilder: _FailingProgressBuilder(),
        );
      case CompletionPreviewState.historyData:
        return SizedBox(
          height: 420,
          child: TrainingHistoryScreen(
            athleteId: previewAthleteId,
            initialRecords: [_historyRecord()],
          ),
        );
      case CompletionPreviewState.historyEmpty:
        return SizedBox(
          height: 280,
          child: TrainingHistoryScreen(
            athleteId: previewAthleteId,
            initialRecords: const [],
          ),
        );
      case CompletionPreviewState.historyRefreshFailed:
        return SizedBox(
          height: 420,
          child: TrainingHistoryScreen(
            athleteId: previewAthleteId,
            initialRecords: [_historyRecord()],
            initialFailure: true,
          ),
        );
      case CompletionPreviewState.historyBlocked:
        return SizedBox(
          height: 280,
          child: TrainingHistoryScreen(
            athleteId: previewAthleteId,
            initialFailure: true,
          ),
        );
      case CompletionPreviewState.missingAthlete:
        return const AthleteIdentityAccessState.missingProfile();
      case CompletionPreviewState.coachOnlyDenied:
        return const AthleteIdentityAccessState.coachOnly();
      case CompletionPreviewState.noActiveWithHistory:
        return AthleteProgrammeStatusState.fromContinuity(
          const AthleteProgrammeContinuity(
            status: AthleteProgrammeContinuityStatus.none,
            timezoneHealth: AssignmentTimezoneHealth.valid,
          ),
        );
      case CompletionPreviewState.completedPlusNewActive:
        return AthleteProgrammeStatusState.fromContinuity(
          const AthleteProgrammeContinuity(
            status: AthleteProgrammeContinuityStatus.currentDefault,
            timezoneHealth: AssignmentTimezoneHealth.valid,
            pinnedTitle: 'Spartan',
            lineageCode: 'SPARTAN',
          ),
          completedProgrammeTitle: 'Apollo Strength',
        );
      case CompletionPreviewState.unavailableCompletedPin:
        return AthleteProgrammeStatusState.fromContinuity(
          const AthleteProgrammeContinuity(
            status: AthleteProgrammeContinuityStatus.pinnedUnavailable,
            timezoneHealth: AssignmentTimezoneHealth.valid,
            pinnedTitle: 'Apollo Strength',
          ),
        );
    }
  }

  Widget _completedCalendarScreen() {
    final assignment = _completedAssignment();
    final calendar = _completedCalendar(assignment);
    return AthleteCalendarScreen(
      athleteId: previewAthleteId,
      assignmentStore: PreviewAssignmentStore(assignment),
      fixedOccurrenceStore: PreviewProjectionStore(calendar),
    );
  }

  Widget _completedProgrammesScreen() {
    final assignment = _completedAssignment();
    final calendar = _completedCalendar(assignment);
    final bundle = AthleteShellPreviewBundle.seed(
      AthleteShellPreviewScenario.todayComplete,
    );
    bundle.assignmentStore.assignment = assignment;
    bundle.projectionStore.projection = calendar;
    return AthleteProgrammeScreen(
      athleteId: previewAthleteId,
      assignmentStore: bundle.assignmentStore,
      controller: AthleteProgrammeScreenController(
        athleteId: previewAthleteId,
        assignmentStore: bundle.assignmentStore,
        versionStore: bundle.versionStore,
      ),
      fixedOccurrenceStore: bundle.projectionStore,
    );
  }
}

ProgrammeAssignment _completedAssignment() {
  return ProgrammeAssignment(
    id: previewAssignmentId,
    athleteId: previewAthleteId,
    programmeVersionId: previewVersionId,
    lineageCode: 'APOLLO-BUILD-12-WEEK',
    status: ProgrammeAssignmentStatus.completed,
    startedAt: DateTime.utc(2026, 8, 1),
    completedAt: DateTime.utc(2026, 9, 1),
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    materialisedAt: DateTime.utc(2026, 8, 1),
    materialisedPackageContentHash: previewPackageHash,
  );
}

FixedProgrammeCalendarProjection _completedCalendar(
  ProgrammeAssignment assignment,
) {
  return FixedProgrammeCalendarProjection(
    assignmentId: assignment.id,
    programmeName: 'Apollo Strength',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-08-01',
    today: '2026-09-10',
    weekStart: '2026-09-07',
    weekEnd: '2026-09-13',
    assignmentStatus: 'completed',
    occurrences: [
      FixedProgrammeOccurrenceProjection(
        assignmentId: assignment.id,
        occurrenceId: 'occ-complete',
        sessionSlotId: previewSlotStrength,
        programmeVersionId: assignment.programmeVersionId,
        protocolId: 'BW-001',
        programmedSessionKey: 'psk-preview-complete',
        weekNumber: 1,
        dayKey: 'day_1',
        sessionOrder: 1,
        scheduledDate: '2026-09-10',
        originalScheduledDate: '2026-09-10',
        state: FixedProgrammeOccurrenceState.completed,
        sessionTitle: 'Strength',
      ),
    ],
    currentWeek: [
      for (var i = 0; i < 7; i++)
        FixedProgrammeCalendarDayProjection(
          date: '2026-09-${(7 + i).toString().padLeft(2, '0')}',
          state: i == 3
              ? FixedProgrammeOccurrenceState.completed
              : FixedProgrammeOccurrenceState.rest,
        ),
    ],
  );
}

ProgressSummary _progressSummary({required int sessionsCompleted}) {
  return ProgressSummary(
    hasActivePlan: true,
    planName: 'Apollo Strength',
    sessionsCompleted: sessionsCompleted,
    compliance: ProgressCompliance(
      completed: sessionsCompleted,
      planned: 12,
      percentage: (sessionsCompleted / 12 * 100).round(),
      currentStreak: 0,
      longestStreak: 0,
    ),
    recentImprovements: const [],
    timeline: const [],
    history: const [],
    upcoming: null,
  );
}

TrainingSessionRecord _historyRecord() {
  final at = DateTime.utc(2026, 9, 1);
  return TrainingSessionRecord(
    recordId: 'history-preview-1',
    athleteId: previewAthleteId,
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'BW-001',
      sessionTitle: 'Apollo Strength',
    ),
    startedAt: at,
    completedAt: at,
    entryMode: SessionResultEntryMode.live,
    performedOn: at,
    performedPrecision: SessionPerformedPrecision.date,
    recordedAt: at,
  );
}

class _FailingProgressBuilder extends AthleteProgressSummaryBuilder {
  @override
  Future<ProgressSummary> build({required String athleteId}) {
    throw const AthleteProgressEvidenceFailure('history_unavailable');
  }
}
