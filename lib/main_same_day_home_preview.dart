import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_today_card.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_same_day_sessions_section.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_today_session_panel.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';

/// Isolated same-day Home preview. Never imported by production `main`.
///
///   flutter run -d chrome --web-port 4174 -t lib/main_same_day_home_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SameDayHomePreviewApp());
}

enum SameDayHomePreviewScenario {
  sundayBothIncomplete,
  sundayAmComplete,
  sundayAmInProgress,
  sundayPmCompleteFirst,
  sundayBothComplete,
  mondayDouble,
}

class SameDayHomePreviewApp extends StatefulWidget {
  const SameDayHomePreviewApp({super.key});

  @override
  State<SameDayHomePreviewApp> createState() => _SameDayHomePreviewAppState();
}

class _SameDayHomePreviewAppState extends State<SameDayHomePreviewApp> {
  SameDayHomePreviewScenario _scenario =
      SameDayHomePreviewScenario.sundayBothIncomplete;
  bool _narrow = false;
  bool _largeText = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(_narrow ? 320 : 390, 844),
          textScaler: TextScaler.linear(_largeText ? 1.6 : 1),
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Same-day Home preview')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final scenario in SameDayHomePreviewScenario.values)
                    ChoiceChip(
                      label: Text(scenario.name),
                      selected: _scenario == scenario,
                      onSelected: (_) => setState(() => _scenario = scenario),
                    ),
                  FilterChip(
                    label: const Text('Narrow'),
                    selected: _narrow,
                    onSelected: (value) => setState(() => _narrow = value),
                  ),
                  FilterChip(
                    label: const Text('Large text'),
                    selected: _largeText,
                    onSelected: (value) => setState(() => _largeText = value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _PreviewBody(scenario: _scenario),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.scenario});

  final SameDayHomePreviewScenario scenario;

  @override
  Widget build(BuildContext context) {
    final monday = scenario == SameDayHomePreviewScenario.mondayDouble;
    final dateLabel = monday
        ? 'Monday 28 September'
        : 'Sunday 27 September';
    final cards = _cards(scenario);
    return AthleteHomeSameDaySessionsSection(
      dateLabel: dateLabel,
      sessionCount: cards.length,
      children: cards,
    );
  }

  List<Widget> _cards(SameDayHomePreviewScenario scenario) {
    final monday = scenario == SameDayHomePreviewScenario.mondayDouble;
    final amTitle = monday
        ? 'Threshold A — BikeErg'
        : 'Long Aerobic — BikeErg';
    final pmTitle = monday
        ? 'Muscular Endurance'
        : 'Strength B — Upper Strength';
    final amState = switch (scenario) {
      SameDayHomePreviewScenario.sundayAmComplete ||
      SameDayHomePreviewScenario.sundayBothComplete =>
        FixedProgrammeOccurrenceState.completed,
      SameDayHomePreviewScenario.sundayAmInProgress =>
        FixedProgrammeOccurrenceState.inProgress,
      _ => FixedProgrammeOccurrenceState.today,
    };
    final pmState = switch (scenario) {
      SameDayHomePreviewScenario.sundayPmCompleteFirst ||
      SameDayHomePreviewScenario.sundayBothComplete =>
        FixedProgrammeOccurrenceState.completed,
      _ => FixedProgrammeOccurrenceState.planned,
    };
    final date = monday ? '2026-09-28' : '2026-09-27';
    return [
      _card(
        id: 'am',
        title: amTitle,
        timeOfDay: ProgrammeSessionTimeOfDay.morning,
        state: amState,
        date: date,
      ),
      _card(
        id: 'pm',
        title: pmTitle,
        timeOfDay: ProgrammeSessionTimeOfDay.afternoon,
        state: pmState,
        date: date,
      ),
    ];
  }

  Widget _card({
    required String id,
    required String title,
    required ProgrammeSessionTimeOfDay timeOfDay,
    required FixedProgrammeOccurrenceState state,
    required String date,
  }) {
    final occurrence = FixedProgrammeOccurrenceProjection(
      assignmentId: 'preview',
      occurrenceId: id,
      sessionSlotId: 'slot-$id',
      programmeVersionId: 'version',
      protocolId: 'PROT-$id',
      programmedSessionKey:
          'prog:preview@version:w1:day_2:s${id == 'am' ? 1 : 2}:PROT-$id',
      weekNumber: 1,
      dayKey: 'day_2',
      sessionOrder: id == 'am' ? 1 : 2,
      scheduledDate: date,
      originalScheduledDate: date,
      state: state,
      sessionTitle: title,
      sessionType: id == 'am' ? 'Aerobic' : 'Strength',
      timeOfDay: timeOfDay,
    );
    if (state == FixedProgrammeOccurrenceState.completed) {
      return AthleteHomeCompletedTodayCard(
        occurrence: occurrence,
        grouped: true,
        dateLabel: date,
        programmeName: 'Lee Bali Hybrid Base',
        weekDayLabel: '',
        onViewResults: () {},
      );
    }
    return AthleteHomeTodaySessionPanel(
      package: PreparedExecutionPackage(
        programmedSessionKey: ProgrammedSessionKey.parse(
          occurrence.programmedSessionKey,
        ),
        plan: SessionExecutionPlan(
          sessionId: occurrence.protocolId,
          sessionTitle: title,
          durationMin: 60,
          blocks: const [],
        ),
        brief: WorkoutSessionBrief(
          sessionName: title,
          estimatedDurationMinutes: 60,
          trainingIntent: occurrence.sessionType,
        ),
        preparedAt: DateTime.utc(2026, 9, 27),
      ),
      grouped: true,
      dateLabel: date,
      occurrence: occurrence,
      status: occurrence.isResumable ? 'In progress' : 'Not started',
      primaryLabel: occurrence.isResumable ? 'Resume' : 'Begin',
      onPrimary: () {},
      onViewFullSession: () {},
    );
  }
}
