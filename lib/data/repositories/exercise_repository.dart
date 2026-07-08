import '../../models/exercise.dart';
import 'base_repository.dart';

class ExerciseRepository extends BaseRepository<Exercise> {
  @override
  String get tableName => 'exercises_v2';

  @override
  Exercise fromMap(Map<String, dynamic> map) {
    return Exercise.fromMap(map);
  }

  Future<List<Exercise>> getExercises() {
    return getWhere(
      column: 'published',
      value: true,
      orderBy: 'name',
    );
  }

  Future<Exercise?> getExerciseById(String exerciseId) async {
    final results = await getWhere(
      column: 'exercise_id',
      value: exerciseId,
    );

    if (results.isEmpty) return null;

    return results.first;
  }
}