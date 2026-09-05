import 'package:cohort_platform/features/session/screens/block_timer_screen.dart';
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
}
