import 'package:cohort_platform/features/session/screens/block_timer_screen.dart';
import 'package:cohort_platform/features/session/services/block_timer_controller.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EMOM timer shows authored targets above the clock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlockTimerScreen(
          blockTitle: 'Alternating EMOM',
          format: WorkoutFormat.emom,
          configuration: TimerConfiguration.fromJson({
            'duration_seconds': 480,
            'interval_seconds': 60,
            'alternating': [
              {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
              {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
            ],
          }),
          stationLabels: const {'EX-049': 'RowErg', 'EX-009': 'Burpees'},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('MINUTE 1 OF 8'), findsOneWidget);
    expect(find.text('ROWERG'), findsOneWidget);
    expect(find.text('12 CAL'), findsOneWidget);
    expect(find.byKey(const ValueKey('block-timer-clock')), findsOneWidget);
    expect(find.text('Next: Burpees · 8 reps'), findsOneWidget);
  });

  testWidgets('restored for-time shows elapsed cursor and Resume', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlockTimerScreen(
          blockTitle: '21-15-9 For Time',
          format: WorkoutFormat.forTime,
          configuration: const TimerConfiguration(
            timeCapSeconds: 720,
            stopwatchEnabled: true,
          ),
          prescriptionLines: const [
            '21 thrusters, 21 pull-ups',
            '15 thrusters, 15 pull-ups',
            '9 thrusters, 9 pull-ups',
          ],
          restoredWorkNote: '2 reps left',
          initialState: const BlockTimerState(
            format: WorkoutFormat.forTime,
            phase: BlockTimerPhase.stopwatch,
            isRunning: false,
            isPaused: true,
            isFinished: false,
            primarySeconds: 412,
            secondarySeconds: 720,
            phaseLabel: 'For Time',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('For Time'), findsWidgets);
    expect(find.text('21-15-9 For Time'), findsOneWidget);
    expect(find.text('21 thrusters, 21 pull-ups'), findsOneWidget);
    expect(find.text('2 reps left'), findsOneWidget);
    expect(find.text('06:52'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Record time'), findsOneWidget);
    expect(find.text('Start timer'), findsNothing);
    expect(find.text('Rounds'), findsNothing);
  });
}
