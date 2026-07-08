import '../../core/services/supabase_service.dart';
import '../../models/exercise.dart';
import 'exercise_repository.dart';

class KnowledgeRepository {
  KnowledgeRepository({
    ExerciseRepository? exerciseRepository,
  }) : _exerciseRepository =
            exerciseRepository ?? ExerciseRepository();

  final ExerciseRepository _exerciseRepository;

  Future<List<Exercise>> getExercisesForProtocol(
    String protocolId,
  ) async {
    final relationships = await SupabaseService.client
        .from('knowledge_relationships')
        .select()
        .eq('from_type', 'protocol')
        .eq('from_id', protocolId)
        .eq('relationship', 'contains')
        .order('display_order');

    final ids = relationships
        .map<String>((row) => row['to_id'] as String)
        .toList();

    if (ids.isEmpty) return [];

    final allExercises =
        await _exerciseRepository.getExercises();

    return ids
        .map(
          (id) => allExercises.firstWhere(
            (exercise) => exercise.exerciseId == id,
          ),
        )
        .toList();
  }
}