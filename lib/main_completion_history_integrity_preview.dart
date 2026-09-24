import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/widgets/local_preview_banner.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_programme_card.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_status_state.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
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
    switch (state) {
      case CompletionPreviewState.activeProgramme:
        return const AthleteProgrammeStatusState(
          badge: 'Current programme',
          headline: 'Today’s session is ready.',
          explanation: 'Active assignment. Begin remains available.',
        );
      case CompletionPreviewState.todayCompleteProgrammeContinues:
        return const AthleteProgrammeStatusState(
          badge: 'Complete',
          headline: 'Today’s session is finished.',
          explanation: 'The assignment remains active. Remaining sessions continue.',
        );
      case CompletionPreviewState.programmeJustCompleted:
      case CompletionPreviewState.completedHome:
      case CompletionPreviewState.narrow320CompletedHome:
      case CompletionPreviewState.largeTextCompletedHome:
        return AthleteHomeCompletedProgrammeCard(
          programmeTitle: 'Apollo Strength',
          supportingLine:
              'This programme is complete. Your results stay in History.',
          onViewResults: () {},
          onBrowseProgrammes: () {},
        );
      case CompletionPreviewState.completedCalendar:
        return const AthleteProgrammeStatusState(
          badge: 'Complete',
          headline: 'Apollo Strength',
          explanation: 'Complete · inspect only. No Begin or Resume.',
        );
      case CompletionPreviewState.completedProgrammes:
        return const AthleteProgrammeStatusState(
          badge: 'Complete',
          headline: 'This programme is complete.',
          explanation: 'Pinned version facts remain. Browse programmes stays available.',
        );
      case CompletionPreviewState.progressData:
        return ProgressScreen(
          summary: ProgressSummary(
            hasActivePlan: true,
            planName: 'APOLLO-BUILD-12-WEEK',
            sessionsCompleted: 12,
            compliance: const ProgressCompliance(
              completed: 12,
              planned: 12,
              percentage: 100,
              currentStreak: 0,
              longestStreak: 0,
            ),
            recentImprovements: const [],
            timeline: const [],
            history: const [],
            upcoming: null,
          ),
        );
      case CompletionPreviewState.progressEmpty:
        return ProgressScreen(
          summary: AthleteProgressSummaryBuilder.emptySummary(),
        );
      case CompletionPreviewState.progressRefreshFailed:
        return const AthleteProgrammeStatusState(
          badge: 'Refresh failed',
          headline: 'Showing last loaded evidence.',
          explanation: 'Retry remains available. This is not an empty history.',
        );
      case CompletionPreviewState.progressBlocked:
        return const AthleteProgrammeStatusState(
          badge: 'Unavailable',
          headline: 'Progress could not be loaded',
          explanation:
              'Recorded evidence is unavailable. This is not an empty history.',
        );
      case CompletionPreviewState.historyData:
        return const AthleteProgrammeStatusState(
          badge: 'History',
          headline: 'Completed sessions',
          explanation: 'Records stay attached to the athlete and programme version.',
        );
      case CompletionPreviewState.historyEmpty:
        return const AthleteProgrammeStatusState(
          badge: 'History',
          headline: 'Completed sessions will appear here.',
          explanation: 'Empty only after a successful athlete-scoped read.',
        );
      case CompletionPreviewState.historyRefreshFailed:
        return const AthleteProgrammeStatusState(
          badge: 'Refresh failed',
          headline: 'Showing last loaded history.',
          explanation: 'This list may not be current.',
        );
      case CompletionPreviewState.historyBlocked:
        return const AthleteProgrammeStatusState(
          badge: 'Unavailable',
          headline: 'Could not load history',
          explanation: 'Retry remains available.',
        );
      case CompletionPreviewState.missingAthlete:
      case CompletionPreviewState.coachOnlyDenied:
        return const AthleteProgrammeStatusState(
          badge: 'Denied',
          headline: 'Athlete access is required',
          explanation:
              'This account cannot open athlete Home, Progress, or History.',
        );
      case CompletionPreviewState.noActiveWithHistory:
        return const AthleteProgrammeStatusState(
          badge: 'No active programme',
          headline: 'Browse programmes when you are ready.',
          explanation: 'History and Progress remain available.',
        );
      case CompletionPreviewState.completedPlusNewActive:
        return const AthleteProgrammeStatusState(
          badge: 'Current programme',
          headline: 'A later enrolment is now current.',
          explanation:
              'Completed history remains inspectable and is not rewritten.',
        );
      case CompletionPreviewState.unavailableCompletedPin:
        return const AthleteProgrammeStatusState(
          badge: 'Unavailable',
          headline: 'Programme temporarily unavailable',
          explanation:
              'The pinned completed version cannot be resolved. Fail closed.',
        );
    }
  }
}
