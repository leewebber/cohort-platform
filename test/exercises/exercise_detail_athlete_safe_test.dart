import 'package:cohort_platform/core/presentation/athlete_content_policy.dart';
import 'package:cohort_platform/features/exercises/exercise_detail/exercise_detail_screen.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exercise = Exercise(
    exerciseId: 'ex-1',
    name: 'Back Squat',
    published: true,
    category: 'Strength',
    movementPattern: 'Squat',
    equipment: 'Barbell',
    purpose: 'Builds lower-body strength.',
    setup: 'Set the bar securely across the upper back.',
    execution: 'Squat with control, then stand tall.',
    coachingCues: 'Keep the whole foot grounded.',
    progression: 'https://notion.so/regression-doc',
    regression: 'Goblet squat',
  );

  testWidgets('athlete exercise detail hides Used by and external links', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseDetailScreen(exercise: exercise, athleteId: 'athlete-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Used by'), findsNothing);
    expect(find.textContaining('notion.so'), findsNothing);
    expect(find.text('Scaling'), findsNothing);
    expect(find.text('Programming'), findsNothing);
    expect(AthleteContentPolicy.showExerciseUsagePanel, isFalse);
    expect(
      find.text('WHY THIS EXERCISE MATTERS', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('HOW TO PERFORM IT', skipOffstage: false), findsOneWidget);
    expect(find.text('COACHING CUES', skipOffstage: false), findsOneWidget);

    final athleteText = tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    expect(
      athleteText.indexOf('Back Squat'),
      lessThan(athleteText.indexOf('WHY THIS EXERCISE MATTERS')),
    );
    expect(
      athleteText.indexOf('WHY THIS EXERCISE MATTERS'),
      lessThan(athleteText.indexOf('ATTRIBUTES')),
    );
    expect(
      athleteText.indexOf('ATTRIBUTES'),
      lessThan(athleteText.indexOf('View exercise history')),
    );
  });

  testWidgets('purpose section is safely omitted when no guidance exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ExerciseDetailScreen(
          exercise: Exercise(
            exerciseId: 'ex-2',
            name: 'Unspecified movement',
            published: true,
          ),
        ),
      ),
    );

    expect(find.text('WHY THIS EXERCISE MATTERS'), findsNothing);
  });
}
