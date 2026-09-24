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
import 'package:cohort_platform/features/programme/domain/athlete_programme_continuity.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_completion_journey_copy.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_status_state.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/preview/athlete_shell_preview_fixture.dart';
import 'package:cohort_platform/preview/completion_history_integrity_preview_fixtures.dart';
import 'package:flutter/material.dart';

/// Fixture-only Sprint 3 preview. Not imported by `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4194 --web-hostname 127.0.0.1 \
///     -t lib/main_completion_history_integrity_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const CompletionHistoryIntegrityPreviewApp(
      initialState: CompletionPreviewState.completedProgrammes,
    ),
  );
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
  late final Widget _completedCalendar =
      CompletionHistoryPreviewFixtures.completedCalendarScreen();
  late final Widget _completedProgrammes =
      CompletionHistoryPreviewFixtures.completedProgrammesScreen();
  late final Widget _completedPlusNewActive =
      CompletionHistoryPreviewFixtures.completedPlusNewActiveProgrammesScreen();
  late final Widget _progressRefreshFailed =
      CompletionHistoryPreviewFixtures.progressRefreshFailed();

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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          child: Text(
                            state.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (next) {
                      if (next == null) return;
                      setState(() => _state = next);
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _previewBody(_state)),
          ],
        ),
      ),
    );
  }

  bool _isFullSurface(CompletionPreviewState state) {
    switch (state) {
      case CompletionPreviewState.completedCalendar:
      case CompletionPreviewState.completedProgrammes:
      case CompletionPreviewState.completedPlusNewActive:
      case CompletionPreviewState.progressData:
      case CompletionPreviewState.progressEmpty:
      case CompletionPreviewState.progressRefreshFailed:
      case CompletionPreviewState.progressBlocked:
      case CompletionPreviewState.historyData:
      case CompletionPreviewState.historyEmpty:
      case CompletionPreviewState.historyRefreshFailed:
      case CompletionPreviewState.historyBlocked:
        return true;
      case CompletionPreviewState.activeProgramme:
      case CompletionPreviewState.todayCompleteProgrammeContinues:
      case CompletionPreviewState.programmeJustCompleted:
      case CompletionPreviewState.completedHome:
      case CompletionPreviewState.missingAthlete:
      case CompletionPreviewState.coachOnlyDenied:
      case CompletionPreviewState.noActiveWithHistory:
      case CompletionPreviewState.unavailableCompletedPin:
      case CompletionPreviewState.narrow320CompletedHome:
      case CompletionPreviewState.largeTextCompletedHome:
        return false;
    }
  }

  Widget _previewBody(CompletionPreviewState state) {
    final child = _previewSurface(state);
    if (_isFullSurface(state)) return child;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CohortSpacing.lg,
        0,
        CohortSpacing.lg,
        CohortSpacing.lg,
      ),
      children: [child],
    );
  }

  Widget _previewSurface(CompletionPreviewState state) {
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
        return _completedCalendar;
      case CompletionPreviewState.completedProgrammes:
        return _completedProgrammes;
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
        return _progressRefreshFailed;
      case CompletionPreviewState.progressBlocked:
        return ProgressScreen(
          athleteIdOverride: previewAthleteId,
          progressBuilder: RefreshFailingProgressBuilder(),
        );
      case CompletionPreviewState.historyData:
        return TrainingHistoryScreen(
          athleteId: previewAthleteId,
          initialRecords: [_historyRecord()],
        );
      case CompletionPreviewState.historyEmpty:
        return TrainingHistoryScreen(
          athleteId: previewAthleteId,
          initialRecords: const [],
        );
      case CompletionPreviewState.historyRefreshFailed:
        return TrainingHistoryScreen(
          athleteId: previewAthleteId,
          initialRecords: [_historyRecord()],
          initialFailure: true,
        );
      case CompletionPreviewState.historyBlocked:
        return TrainingHistoryScreen(
          athleteId: previewAthleteId,
          initialFailure: true,
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
        return _completedPlusNewActive;
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
