import '../../core/services/supabase_service.dart';
import '../../models/circuit_performance.dart';
import '../../models/training_session.dart';

/// Persistence surface used by [CircuitSessionView].
abstract class TrainingSessionCircuitStore {
  Future<CircuitPerformance> upsertCircuitPerformance(
    CircuitPerformance performance,
  );

  Future<CircuitPerformance?> getPerformanceForTrainingSession(
    int trainingSessionId,
  );
}

/// Latest completed session plus its persisted circuit row.
class ComparableCircuitSession {
  const ComparableCircuitSession({
    required this.session,
    required this.performance,
  });

  final TrainingSession session;
  final CircuitPerformance performance;
}

class TrainingSessionCircuitRepository implements TrainingSessionCircuitStore {
  const TrainingSessionCircuitRepository();

  static const _tableName = 'training_session_circuits';
  static const _upsertConflict = 'training_session_id';

  @override
  Future<CircuitPerformance> upsertCircuitPerformance(
    CircuitPerformance performance,
  ) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .upsert(
          performance.toUpsertMap(),
          onConflict: _upsertConflict,
        )
        .select()
        .single();

    return CircuitPerformance.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<CircuitPerformance?> getPerformanceForTrainingSession(
    int trainingSessionId,
  ) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .select()
        .eq('training_session_id', trainingSessionId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return CircuitPerformance.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<ComparableCircuitSession?> getLatestCompletedComparableSession({
    required String athleteId,
    required String protocolId,
    int? excludeTrainingSessionId,
  }) async {
    var query = SupabaseService.client
        .from('training_sessions')
        .select()
        .eq('athlete_id', athleteId)
        .eq('protocol_id', protocolId)
        .eq('status', 'completed');

    if (excludeTrainingSessionId != null) {
      query = query.neq('id', excludeTrainingSessionId);
    }

    final sessionResponse = await query
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (sessionResponse == null) {
      return null;
    }

    final session = TrainingSession.fromMap(
      Map<String, dynamic>.from(sessionResponse),
    );

    final performance = await getPerformanceForTrainingSession(session.id);
    if (performance == null) {
      return null;
    }

    return ComparableCircuitSession(
      session: session,
      performance: performance,
    );
  }
}
