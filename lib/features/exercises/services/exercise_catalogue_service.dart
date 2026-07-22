import '../../../data/repositories/exercise_repository.dart';
import '../../../models/exercise.dart';

/// Canonical published exercise catalogue — same source as [ExerciseLibraryScreen].
class ExerciseCatalogueService implements ExerciseCatalogueLoader {
  ExerciseCatalogueService({ExerciseRepository? repository})
      : _repository = repository ?? ExerciseRepository();

  final ExerciseRepository _repository;

  @override
  Future<List<Exercise>> loadPublishedExercises() {
    return _repository.getExercises();
  }

  /// Shared search/filter logic with the standalone Exercise Library.
  static List<Exercise> filter(List<Exercise> exercises, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return List<Exercise>.from(exercises);
    }

    final normalized = trimmed.toLowerCase();
    return exercises.where((exercise) {
      return exercise.name.toLowerCase().contains(normalized) ||
          (exercise.movementPattern ?? '').toLowerCase().contains(normalized) ||
          (exercise.primaryMuscles ?? '').toLowerCase().contains(normalized) ||
          (exercise.equipment ?? '').toLowerCase().contains(normalized);
    }).toList(growable: false);
  }

  static Exercise? findById(List<Exercise> exercises, String exerciseId) {
    for (final exercise in exercises) {
      if (exercise.exerciseId == exerciseId) {
        return exercise;
      }
    }
    return null;
  }
}

/// Test seam for injecting catalogue behaviour into pickers.
abstract class ExerciseCatalogueLoader {
  Future<List<Exercise>> loadPublishedExercises();
}
