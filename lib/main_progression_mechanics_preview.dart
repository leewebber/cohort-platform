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
import 'package:cohort_platform/features/progress/services/capability_radar_projection_service.dart';
import 'package:cohort_platform/features/progress/widgets/capability_radar_chart.dart';
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
        if (item.disciplinePreview)
          const _DisciplineRadarPreview()
        else ...[
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
          SizedBox(height: 640, child: ProgressScreen(summary: summary)),
        ],
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
    this.disciplinePreview = false,
  });

  final String title;
  final String subtitle;
  final TrainingSessionRecord current;
  final TrainingSessionRecord? previous;
  final String? radarNote;
  final bool disciplinePreview;
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
    subtitle:
        '84 programme sessions · 7 due · 6 complete · 1 incomplete · 77 future excluded',
    current: ProgressionMechanicsFixtures.improved20x6(),
    previous: ProgressionMechanicsFixtures.previous20x5(),
    disciplinePreview: true,
    radarNote:
        'Training Discipline = 86%. Strength / Endurance / Threshold / Power / Durability / Mobility stay unavailable without capability evidence.',
  ),
];

class _DisciplineRadarPreview extends StatefulWidget {
  const _DisciplineRadarPreview();

  @override
  State<_DisciplineRadarPreview> createState() =>
      _DisciplineRadarPreviewState();
}

class _DisciplineRadarPreviewState extends State<_DisciplineRadarPreview> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scenario = _disciplineScenarios[_index];
    final radar = const CapabilityRadarProjectionService().project(
      timeline: const [],
      compliance: scenario.compliance,
      strengthSessionCount: scenario.compliance.completed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<int>(
          value: _index,
          isExpanded: true,
          items: [
            for (var i = 0; i < _disciplineScenarios.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(_disciplineScenarios[i].label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _index = value);
          },
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(scenario.explanation, style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.md),
        Center(child: CapabilityRadarChart(model: radar)),
        const SizedBox(height: CohortSpacing.md),
        SizedBox(
          height: 640,
          child: ProgressScreen(
            summary: ProgressSummary(
              hasActivePlan: true,
              planName: 'Apollo',
              weekLabel: 'Week 2',
              sessionsCompleted: scenario.sessionsCompleted,
              compliance: scenario.compliance,
              recentImprovements: const [],
              timeline: const [],
              history: const [],
              upcoming: null,
            ),
          ),
        ),
      ],
    );
  }
}

class _DisciplineScenario {
  const _DisciplineScenario({
    required this.label,
    required this.explanation,
    required this.compliance,
    required this.sessionsCompleted,
  });

  final String label;
  final String explanation;
  final ProgressCompliance compliance;
  final int sessionsCompleted;
}

const _disciplineScenarios = <_DisciplineScenario>[
  _DisciplineScenario(
    label: '84 total / 7 due / 6 complete',
    explanation:
        'Programme has 84 sessions. Seven have become due. Six are complete, '
        'one is incomplete, seventy-seven are still future. Training Discipline '
        'is 6/7 = 86%. Future sessions are excluded from the denominator.',
    sessionsCompleted: 6,
    compliance: ProgressCompliance(
      completed: 6,
      planned: 7,
      percentage: 86,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      futureExcluded: 77,
      incompleteCount: 1,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: 'No sessions due',
    explanation:
        'First day, today still Planned. Discipline is not 0%. Copy: No sessions due yet.',
    sessionsCompleted: 0,
    compliance: ProgressCompliance(
      completed: 0,
      planned: 0,
      percentage: 0,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.noneDue,
      futureExcluded: 84,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: '100% so far',
    explanation:
        'Seven of seven due sessions complete. Future work still excluded.',
    sessionsCompleted: 7,
    compliance: ProgressCompliance(
      completed: 7,
      planned: 7,
      percentage: 100,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      futureExcluded: 77,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: 'Incomplete past session',
    explanation:
        'Yesterday unfinished is in the denominator as Incomplete (0/1).',
    sessionsCompleted: 0,
    compliance: ProgressCompliance(
      completed: 0,
      planned: 1,
      percentage: 0,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      incompleteCount: 1,
      futureExcluded: 83,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: 'Backfill restores adherence',
    explanation:
        'Same overdue occurrence after valid Backfill. Denominator stays 1; numerator becomes 1.',
    sessionsCompleted: 1,
    compliance: ProgressCompliance(
      completed: 1,
      planned: 1,
      percentage: 100,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      futureExcluded: 83,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: 'Today Planned does not lower the score',
    explanation:
        'Six of six past sessions complete. Today is still Planned, so it is not in the denominator.',
    sessionsCompleted: 6,
    compliance: ProgressCompliance(
      completed: 6,
      planned: 6,
      percentage: 100,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      futureExcluded: 77,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: 'Tomorrow excluded',
    explanation:
        'Tomorrow Planned never enters Discipline until that local date is due.',
    sessionsCompleted: 6,
    compliance: ProgressCompliance(
      completed: 6,
      planned: 7,
      percentage: 86,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      futureExcluded: 77,
      incompleteCount: 1,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: 'Multiple sessions yesterday',
    explanation:
        'Strength complete + run incomplete on the same date = 1 of 2 · 50%.',
    sessionsCompleted: 1,
    compliance: ProgressCompliance(
      completed: 1,
      planned: 2,
      percentage: 50,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      incompleteCount: 1,
      futureExcluded: 82,
      totalRequired: 84,
    ),
  ),
  _DisciplineScenario(
    label: 'Rescheduled occurrence once',
    explanation:
        'Moved from last week to next week. Counted once on the effective date, not twice.',
    sessionsCompleted: 5,
    compliance: ProgressCompliance(
      completed: 5,
      planned: 6,
      percentage: 83,
      currentStreak: 0,
      longestStreak: 0,
      availability: DisciplineAvailability.scored,
      incompleteCount: 1,
      futureExcluded: 78,
      totalRequired: 84,
    ),
  ),
];
