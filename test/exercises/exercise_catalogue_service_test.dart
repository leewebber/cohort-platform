import 'package:cohort_platform/features/exercises/services/exercise_catalogue_service.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exercises = [
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
      exerciseId: 'ROW-001',
      name: 'Chest-Supported Row',
      published: true,
      primaryMuscles: 'Back',
    ),
  ];

  group('ExerciseCatalogueService.filter', () {
    test('search for pull returns matching exercises', () {
      final filtered = ExerciseCatalogueService.filter(exercises, 'pull');
      expect(filtered.map((exercise) => exercise.name), ['Weighted Pull-up']);
    });

    test('empty search returns full catalogue order', () {
      expect(
        ExerciseCatalogueService.filter(exercises, ''),
        exercises,
      );
    });

    test('findById resolves canonical exercise reference', () {
      final found = ExerciseCatalogueService.findById(exercises, 'BP-001');
      expect(found?.name, 'Dumbbell Bench Press');
    });
  });
}
