import 'dart:async';

import 'package:cohort_platform/features/exercises/services/exercise_catalogue_service.dart';
import 'package:cohort_platform/features/session_builder/widgets/strength_exercise_prescription_sheet.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExerciseCatalogueLoader implements ExerciseCatalogueLoader {
  _FakeExerciseCatalogueLoader(
    this.exercises, {
    this.delay = Duration.zero,
    this.shouldFail = false,
  });

  final List<Exercise> exercises;
  final Duration delay;
  final bool shouldFail;

  @override
  Future<List<Exercise>> loadPublishedExercises() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (shouldFail) {
      throw Exception('network failure');
    }
    return exercises;
  }
}

void main() {
  const catalogue = [
    Exercise(
      exerciseId: 'PULL-001',
      name: 'Weighted Pull-up',
      published: true,
    ),
    Exercise(
      exerciseId: 'BP-001',
      name: 'Dumbbell Bench Press',
      published: true,
    ),
    Exercise(
      exerciseId: 'LAT-001',
      name: 'Lateral Raise',
      published: true,
    ),
  ];

  Future<void> pumpSheet(
    WidgetTester tester, {
    required ExerciseCatalogueLoader catalogueLoader,
    String? initialExerciseId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showStrengthExercisePrescriptionSheet(
                      context: context,
                      catalogueLoader: catalogueLoader,
                      initialExerciseId: initialExerciseId,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
  }

  testWidgets('shows loading then exercises from canonical catalogue loader',
      (tester) async {
    final loader = _FakeExerciseCatalogueLoader(
      catalogue,
      delay: const Duration(milliseconds: 100),
    );

    await pumpSheet(tester, catalogueLoader: loader);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Weighted Pull-up'), findsWidgets);
    expect(find.textContaining('PULL-001'), findsNothing);
  });

  testWidgets('search for pull returns matching exercises', (tester) async {
    await pumpSheet(
      tester,
      catalogueLoader: _FakeExerciseCatalogueLoader(catalogue),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'pull');
    await tester.pumpAndSettle();

    expect(find.text('Weighted Pull-up'), findsWidgets);
    expect(find.text('Dumbbell Bench Press'), findsNothing);
  });

  testWidgets('true empty catalogue shows guidance', (tester) async {
    await pumpSheet(
      tester,
      catalogueLoader: _FakeExerciseCatalogueLoader(const []),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No exercises are available in the library yet'),
      findsOneWidget,
    );
  });

  testWidgets('repository failure shows safe error', (tester) async {
    await pumpSheet(
      tester,
      catalogueLoader: _FakeExerciseCatalogueLoader(
        catalogue,
        shouldFail: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Exercises could not be loaded right now'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('initial exercise id resolves after async load', (tester) async {
    await pumpSheet(
      tester,
      catalogueLoader: _FakeExerciseCatalogueLoader(
        catalogue,
        delay: const Duration(milliseconds: 50),
      ),
      initialExerciseId: 'BP-001',
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Dumbbell Bench Press'), findsWidgets);
  });
}
