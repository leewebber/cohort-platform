import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/features/performance/models/circuit_station_actual.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/services/circuit_capture_contract.dart';
import 'package:cohort_platform/features/performance/services/emom_score_contract.dart';
import 'package:cohort_platform/features/performance/widgets/emom_result_capture.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';

/// Interactive EMOM result-capture preview.
///
/// Launch:
///   flutter run -d web-server --web-port 4183 -t lib/main_emom_result_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(theme: cohortTheme, home: const _EmomPreviewApp()));
}

enum _PreviewBeat {
  beforeStart,
  runningInterval3,
  timerCompleted,
  prescribedResult,
  adjustedResult,
  endedEarly,
  completedSummary,
  backfill,
  previousComparison,
}

class _EmomPreviewApp extends StatefulWidget {
  const _EmomPreviewApp();

  @override
  State<_EmomPreviewApp> createState() => _EmomPreviewAppState();
}

class _EmomPreviewAppState extends State<_EmomPreviewApp> {
  _PreviewBeat _beat = _PreviewBeat.beforeStart;
  late CircuitResultData _result = CircuitCaptureContract.authoredResult(
    _block(),
  );

  static const _labels = {
    _PreviewBeat.beforeStart: '1. Before start',
    _PreviewBeat.runningInterval3: '2. Running 3 of 8',
    _PreviewBeat.timerCompleted: '3. Timer completed',
    _PreviewBeat.prescribedResult: '4. 8 of 8 prescribed',
    _PreviewBeat.adjustedResult: '5. Adjusted targets',
    _PreviewBeat.endedEarly: '6. Ended early',
    _PreviewBeat.completedSummary: '7. Completed summary',
    _PreviewBeat.backfill: '8. Backfill entry',
    _PreviewBeat.previousComparison: '9. Previous comparison',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMOM result preview'),
        actions: [
          PopupMenuButton<_PreviewBeat>(
            initialValue: _beat,
            onSelected: (value) => setState(() => _beat = value),
            itemBuilder: (context) => [
              for (final entry in _labels.entries)
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_beat) {
      case _PreviewBeat.beforeStart:
        return _BeforeStart(block: _block());
      case _PreviewBeat.runningInterval3:
        return const _RunningCard();
      case _PreviewBeat.timerCompleted:
        return const _TimerDoneCard();
      case _PreviewBeat.prescribedResult:
        return EmomResultCapture(
          result: _result.copyWith(
            recordedCompletedRounds: 8,
            prescribedTargetsUsed: true,
          ),
          onChanged: (next) => setState(() => _result = next),
          onSave: (_) {},
          onCancel: () {},
        );
      case _PreviewBeat.adjustedResult:
        return EmomResultCapture(
          result: _result.copyWith(
            recordedCompletedRounds: 8,
            prescribedTargetsUsed: false,
            stations: [
              _result.stations.first.copyWith(
                calories: 10,
                state: CircuitOccurrenceState.recorded,
              ),
              _result.stations[1].copyWith(
                reps: 8,
                state: CircuitOccurrenceState.recorded,
              ),
            ],
          ),
          onChanged: (next) => setState(() => _result = next),
          onSave: (_) {},
          onCancel: () {},
        );
      case _PreviewBeat.endedEarly:
        return EmomResultCapture(
          result: _result.copyWith(
            recordedCompletedRounds: 5,
            prescribedTargetsUsed: true,
            endedEarly: true,
          ),
          onChanged: (next) => setState(() => _result = next),
          onSave: (_) {},
          onCancel: () {},
        );
      case _PreviewBeat.completedSummary:
        return Text(
          EmomScoreContract.completedSummary(
            _result.copyWith(
              recordedCompletedRounds: 8,
              prescribedTargetsUsed: true,
              scoreEntered: true,
            ),
          ),
          style: CohortTextStyles.body,
        );
      case _PreviewBeat.backfill:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backfill · no live timer', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.md),
            EmomResultCapture(
              result: _result,
              secondaryLabel: 'Return to review',
              onChanged: (next) => setState(() => _result = next),
              onSave: (_) {},
              onCancel: () {},
            ),
          ],
        );
      case _PreviewBeat.previousComparison:
        return Text(
          EmomScoreContract.comparisonLine(
            today: _result.copyWith(
              recordedCompletedRounds: 8,
              scoreEntered: true,
            ),
            previous: _result.copyWith(
              recordedCompletedRounds: 7,
              endedEarly: true,
              scoreEntered: true,
            ),
          ),
          style: CohortTextStyles.body,
        );
    }
  }
}

class _BeforeStart extends StatelessWidget {
  const _BeforeStart({required this.block});

  final SessionExecutionBlock block;

  @override
  Widget build(BuildContext context) {
    final result = CircuitCaptureContract.authoredResult(block);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(block.title, style: CohortTextStyles.h2),
        Text(block.timerSummary ?? '', style: CohortTextStyles.small),
        const SizedBox(height: CohortSpacing.md),
        Text(
          '${result.targetRounds} intervals · ${result.intervalSeconds}s',
          style: CohortTextStyles.body,
        ),
        for (final row in result.stations)
          Text(
            EmomScoreContract.prescribedStationLine(row),
            style: CohortTextStyles.body,
          ),
        const SizedBox(height: CohortSpacing.lg),
        Text('Start timer', style: CohortTextStyles.cardTitle),
        const SizedBox(height: CohortSpacing.sm),
        Text('Record result without timer', style: CohortTextStyles.cardTitle),
      ],
    );
  }
}

class _RunningCard extends StatelessWidget {
  const _RunningCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MINUTE 3 OF 8', style: CohortTextStyles.eyebrow),
        Text('ROWERG', style: CohortTextStyles.h2),
        Text('12 CALORIES', style: CohortTextStyles.cardTitle),
        Text('00:41', style: CohortTextStyles.h1.copyWith(fontSize: 64)),
        Text('Next: Burpees · 8 reps', style: CohortTextStyles.small),
        const SizedBox(height: CohortSpacing.lg),
        Text('Pause / Resume · End early', style: CohortTextStyles.small),
      ],
    );
  }
}

class _TimerDoneCard extends StatelessWidget {
  const _TimerDoneCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timer complete', style: CohortTextStyles.h2),
        Text('8 of 8 intervals ready to confirm', style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.md),
        Text('Record result', style: CohortTextStyles.cardTitle),
      ],
    );
  }
}

SessionExecutionBlock _block() {
  return SessionExecutionBlock(
    blockId: 'b1100016-0000-4000-8000-000000000016',
    title: 'Alternating EMOM',
    blockType: SessionBlockType.conditioning,
    content: 'Minute 1: RowErg 12 calories. Minute 2: Burpees 8 reps.',
    workoutFormat: WorkoutFormat.emom,
    position: 1,
    timerConfiguration: TimerConfiguration.fromJson({
      'duration_seconds': 480,
      'interval_seconds': 60,
      'alternating': [
        {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
        {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
      ],
    }),
    linkedExercises: [
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-049',
        displayName: 'RowErg',
        position: 1,
        prescription: StrengthExercisePrescription.fromJson({'calories': 12}),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-009',
        displayName: 'Burpees',
        position: 2,
        prescription: StrengthExercisePrescription.fromJson({'reps': 8}),
      ),
    ],
  );
}
