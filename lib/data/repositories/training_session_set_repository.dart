import '../../core/services/supabase_service.dart';
import '../../models/previous_exercise_performance.dart';
import '../../models/strength_set_performance.dart';

class TrainingSessionSetRepository {
  const TrainingSessionSetRepository();

  static const _tableName = 'training_session_sets';
  static const _upsertConflict =
      'training_session_id,protocol_step_id,set_number,is_extra_set';

  Future<StrengthSetPerformance> upsertSetPerformance(
    StrengthSetPerformance performance,
  ) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .upsert(
          performance.toUpsertMap(),
          onConflict: _upsertConflict,
        )
        .select()
        .single();

    return StrengthSetPerformance.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<StrengthSetPerformance>> getSetsForTrainingSession(
    int trainingSessionId,
  ) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .select()
        .eq('training_session_id', trainingSessionId)
        .order('protocol_step_id')
        .order('set_number')
        .order('is_extra_set');

    return response
        .map<StrengthSetPerformance>(
          (row) => StrengthSetPerformance.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<List<StrengthSetPerformance>> getLatestCompletedSetsForExercise({
    required String athleteId,
    required String exerciseId,
    int limit = 50,
  }) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .select('*, training_sessions!inner(athlete_id, status, completed_at)')
        .eq('exercise_id', exerciseId)
        .eq('completed', true)
        .eq('training_sessions.athlete_id', athleteId)
        .eq('training_sessions.status', 'completed')
        .order('updated_at', ascending: false)
        .limit(limit);

    return response
        .map<StrengthSetPerformance>(
          (row) => StrengthSetPerformance.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<PreviousExercisePerformance?> getLatestCompletedExercisePerformance({
    required String athleteId,
    required String exerciseId,
  }) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .select('*, training_sessions!inner(athlete_id, status, completed_at)')
        .eq('exercise_id', exerciseId)
        .eq('completed', true)
        .eq('training_sessions.athlete_id', athleteId)
        .eq('training_sessions.status', 'completed')
        .order('set_number')
        .limit(100);

    if (response.isEmpty) {
      return null;
    }

    int? latestSessionId;
    DateTime? latestPerformedAt;

    for (final row in response) {
      final session = row['training_sessions'];
      if (session is! Map) {
        continue;
      }

      final sessionMap = Map<String, dynamic>.from(session);
      final completedAt = _parseDateTime(sessionMap['completed_at']);
      final sessionId = row['training_session_id'];

      if (sessionId is! int || completedAt == null) {
        continue;
      }

      if (latestPerformedAt == null || completedAt.isAfter(latestPerformedAt)) {
        latestPerformedAt = completedAt;
        latestSessionId = sessionId;
      }
    }

    if (latestSessionId == null) {
      return null;
    }

    final latestSets = response
        .where((row) => row['training_session_id'] == latestSessionId)
        .map(
          (row) => StrengthSetPerformance.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((set) => !set.isExtraSet)
        .toList()
      ..sort((a, b) {
        final extraCompare = (a.isExtraSet ? 1 : 0).compareTo(b.isExtraSet ? 1 : 0);
        if (extraCompare != 0) {
          return extraCompare;
        }

        return a.setNumber.compareTo(b.setNumber);
      });

    if (latestSets.isEmpty) {
      return null;
    }

    return PreviousExercisePerformance(
      sets: latestSets
          .map(PreviousPerformedSet.fromPerformance)
          .toList(growable: false),
      performedAt: latestPerformedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
