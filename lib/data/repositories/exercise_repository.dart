import '../../core/services/supabase_service.dart';
import '../../models/exercise.dart';

class ExerciseRepository {
  Future<List<Exercise>> getExercises() async {
    final response = await SupabaseService.client
        .from('exercises_v2')
        .select()
        .eq('published', true)
        .order('name');

    return response
        .map<Exercise>((item) => Exercise.fromMap(item))
        .toList();
  }
}