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
  });
}
