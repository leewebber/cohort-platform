import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/colors.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_today_card.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/progression/personal_bests.dart';
import 'package:cohort_platform/features/performance/progression/progression_mechanics_fixtures.dart';
import 'package:cohort_platform/features/performance/progression/strength_progression.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_evidence_projection.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/session/models/strength_set_entry.dart';
import 'package:cohort_platform/features/session/services/strength_progress_service.dart';
import 'package:cohort_platform/features/session/widgets/shared/progress_result_card.dart';
import 'package:cohort_platform/models/previous_exercise_performance.dart';
import 'package:flutter/material.dart';

/// Local preview: identical evidence across player / Home / results / Progress.
///
///   flutter run -d chrome --web-port 4175 -t lib/main_progression_mechanics_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(theme: cohortTheme, home: const _Preview()));
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _cases.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progression Mechanics v1'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final item in _cases) Tab(text: item.title)],
          ),
        ),
        body: TabBarView(
          children: [for (final item in _cases) _CaseView(item: item)],
        ),
      ),
    );
  }
}

class _CaseView extends StatelessWidget {
  const _CaseView({required this.item});

  final _PreviewCase item;

  @override
  Widget build(BuildContext context) {
    final history = <TrainingSessionRecord>[
      if (item.previous != null) item.previous!,
      item.current,
    ];
    final previousExercise =
        item.previous?.blockResults.first.exerciseResults.first;
    final currentExercise =
        item.current.blockResults.first.exerciseResults.first;
    final engine = StrengthProgressionComparison.compare(
      current: StrengthProgressionFacts.fromExercise(currentExercise),
      previous: previousExercise == null
          ? null
          : StrengthProgressionFacts.fromExercise(previousExercise),
    );
    final pbs = PersonalBestEvaluator.announcedForCurrent(
      athleteId: ProgressionMechanicsFixtures.athleteId,
      exerciseId: ProgressionMechanicsFixtures.exerciseId,
      current: item.current,
      history: history,
    );
    final player = const StrengthProgressService().evaluate(
      previousPerformance: previousExercise == null
          ? null
          : PreviousExercisePerformance(
              performedAt: item.previous!.performanceChronologyAt,
              sets: [
                for (final set in previousExercise.setResults)
                  PreviousPerformedSet(
                    loadLabel: '${set.load?.toStringAsFixed(0)}kg',
                    reps: '${set.reps}',
                    displayLine: '${set.load} × ${set.reps}',
                    rpe: set.rpe?.toDouble(),
                  ),
              ],
            ),
      todayCompletedSets: [
        for (final set in currentExercise.setResults)
          StrengthSetEntry(
            localId: set.setResultId,
            setNumber: set.setNumber,
            actualReps: '${set.reps}',
            load: '${set.load}kg',
            rpe: set.rpe,
            completed: set.completed,
          ),
      ],
      exerciseId: ProgressionMechanicsFixtures.exerciseId,
      personalBests: pbs,
    );
    final completed = AthleteProgressEvidenceProjection.completedRecords(
      history,
    );
    final progressBests = AthleteProgressEvidenceProjection.exerciseBests(
      completed,
    );
    final summary = ProgressSummary(
      hasActivePlan: true,
      planName: 'Apollo',
      weekLabel: 'Week 2',
      phaseLabel: 'Foundation',
      sessionsCompleted: completed.length,
      compliance: ProgressCompliance(
        completed: completed.length,
        planned: completed.length,
        percentage: 100,
        currentStreak: completed.length,
        longestStreak: completed.length,
      ),
      recentImprovements: const [],
      timeline: const [],
      history: AthleteProgressEvidenceProjection.historyItems(completed),
      upcoming: AthleteProgressSummaryBuilder.emptySummary().upcoming,
      exerciseBests: progressBests,
      strengthSessionCount:
          AthleteProgressEvidenceProjection.strengthSessionCount(completed),
      enduranceSessionCount: 0,
    );
    final occurrence = FixedProgrammeOccurrenceProjection(
      assignmentId: 'preview',
      occurrenceId: 'occ',
      sessionSlotId: 'slot',
      programmeVersionId: 'ver',
      protocolId: 'p',
      programmedSessionKey: 'key',
      weekNumber: 2,
      dayKey: 'monday',
      sessionOrder: 1,
      scheduledDate: '2026-09-14',
      originalScheduledDate: '2026-09-14',
      state: FixedProgrammeOccurrenceState.completed,
      sessionTitle: item.current.sessionSnapshot.sessionTitle,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(item.subtitle, style: CohortTextStyles.muted),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          'Canonical: ${engine.conciseHighlight}',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.md),
        Text('Workout player', style: CohortTextStyles.sectionLabel),
        ProgressResultCard(
          title: player.title,
          message: player.message,
          reasons: player.reasons,
          accentColor: CohortColors.olive,
        ),
        const SizedBox(height: CohortSpacing.lg),
        Text('Completed-today Home', style: CohortTextStyles.sectionLabel),
        AthleteHomeCompletedTodayCard(
          occurrence: occurrence,
          dateLabel: 'Monday 14 Sep',
          programmeName: 'Apollo',
          weekDayLabel: 'Week 2 · Monday',
          expanded: true,
          onToggleExpanded: () {},
          onViewResults: () {},
          record: item.current,
          history: history,
        ),
        const SizedBox(height: CohortSpacing.lg),
        Text('Result detail', style: CohortTextStyles.sectionLabel),
        SizedBox(
          height: 520,
          child: CompletedSessionResultView(
            record: item.current,
            athleteHistory: history,
          ),
        ),
        const SizedBox(height: CohortSpacing.lg),
        Text('Progress', style: CohortTextStyles.sectionLabel),
        SizedBox(
          height: 640,
          child: ProgressScreen(summary: summary),
        ),
        if (item.radarNote != null) ...[
          const SizedBox(height: CohortSpacing.md),
          Text(item.radarNote!, style: CohortTextStyles.muted),
        ],
      ],
    );
  }
}

class _PreviewCase {
  const _PreviewCase({
    required this.title,
    required this.subtitle,
    required this.current,
    this.previous,
    this.radarNote,
  });

  final String title;
  final String subtitle;
  final TrainingSessionRecord current;
  final TrainingSessionRecord? previous;
  final String? radarNote;
}

final _cases = <_PreviewCase>[
  _PreviewCase(
    title: '1 Improved',
    subtitle: 'Weighted Pull-Up +20 kg × 6 vs × 5 at RPE 8',
    current: ProgressionMechanicsFixtures.improved20x6(),
    previous: ProgressionMechanicsFixtures.previous20x5(),
  ),
  _PreviewCase(
    title: '2 Matched',
    subtitle: 'Same 20 kg × 5 at RPE 8',
    current: ProgressionMechanicsFixtures.matched20x5(),
    previous: ProgressionMechanicsFixtures.previous20x5(),
  ),
  _PreviewCase(
    title: '3 Mixed',
    subtitle: '90 kg × 3 vs 80 kg × 5',
    current: ProgressionMechanicsFixtures.mixed90x3(),
    previous: ProgressionMechanicsFixtures.previous80x5(),
  ),
  _PreviewCase(
    title: '4 Below',
    subtitle: '18 kg × 5 vs 20 kg × 5',
    current: ProgressionMechanicsFixtures.below18x5(),
    previous: ProgressionMechanicsFixtures.previous20x5(),
  ),
  _PreviewCase(
    title: '5 First',
    subtitle: 'No prior comparable result',
    current: ProgressionMechanicsFixtures.first20x5(),
  ),
  _PreviewCase(
    title: '6 Changed Rx',
    subtitle: '4 × 12 vs 3 × 15 at 10 kg',
    current: ProgressionMechanicsFixtures.changedPrescription4x10x12(),
    previous: ProgressionMechanicsFixtures.previous3x10x15(),
  ),
  _PreviewCase(
    title: '7 Precise PB',
    subtitle: '25 kg × 5 vs 20 kg × 5 — heaviest completed load',
    current: ProgressionMechanicsFixtures.precisePb25x5(),
    previous: ProgressionMechanicsFixtures.previous20x5(),
  ),
  _PreviewCase(
    title: '8 Corrected',
    subtitle: 'Corrected result recomputes below last performance',
    current: ProgressionMechanicsFixtures.corrected18x5(),
    previous: ProgressionMechanicsFixtures.previous20x5(),
  ),
  _PreviewCase(
    title: '9 Backfill',
    subtitle: 'Older Backfill chronology is the prior',
    current: ProgressionMechanicsFixtures.improved20x6(),
    previous: ProgressionMechanicsFixtures.olderBackfill20x5(),
  ),
  _PreviewCase(
    title: '10 Radar',
    subtitle: 'Two completed strength sessions without a scoring contract',
    current: ProgressionMechanicsFixtures.improved20x6(),
    previous: ProgressionMechanicsFixtures.previous20x5(),
    radarNote:
        'Strength / Endurance / Threshold / Power / Durability / Mobility stay unavailable. Discipline may use adherence. No invented global capability formula.',
  ),
];
