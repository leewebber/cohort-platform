import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session builders default to ExerciseCatalogueService not empty list', () {
    final embedded = File(
      'lib/features/programme_builder/screens/embedded_session_builder_screen.dart',
    ).readAsStringSync();
    final library = File(
      'lib/features/training_library/screens/library_session_builder_screen.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/features/session_builder/widgets/strength_exercise_prescription_sheet.dart',
    ).readAsStringSync();

    expect(embedded, contains('ExerciseCatalogueService().loadPublishedExercises()'));
    expect(library, contains('ExerciseCatalogueService().loadPublishedExercises()'));
    expect(sheet, contains('ExerciseCatalogueService()'));
    expect(sheet, contains('ExercisePickerField'));
    expect(sheet, isNot(contains('required List<Exercise> exercises')));
  });

  test('exercise library and picker share catalogue filter helper', () {
    final library = File(
      'lib/features/exercises/exercise_library/exercise_library_screen.dart',
    ).readAsStringSync();
    final picker = File(
      'lib/features/exercises/widgets/exercise_picker_field.dart',
    ).readAsStringSync();

    expect(library, contains('ExerciseCatalogueService.filter'));
    expect(picker, contains('ExerciseCatalogueService.filter'));
  });
}
