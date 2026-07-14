import '../../core/services/supabase_service.dart';
import '../../models/interval_performance.dart';
import '../../models/training_session.dart';

/// Latest completed session plus its persisted interval rows.
class ComparableIntervalSession {
  const ComparableIntervalSession({
    required this.session,
    required this.intervals,
  });

  final TrainingSession session;
  final List<IntervalPerformance> intervals;
}

class TrainingSessionIntervalRepository {
  const TrainingSessionIntervalRepository();

  static const _tableName = 'training_session_intervals';
  static const _upsertConflict =
      'training_session_id,block_index,rep_number,phase_type';

  Future<IntervalPerformance> upsertIntervalPerformance(
    IntervalPerformance performance,
  ) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .upsert(
          performance.toUpsertMap(),
          onConflict: _upsertConflict,
        )
        .select()
        .single();

    return IntervalPerformance.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<IntervalPerformance>> getIntervalsForTrainingSession(
    int trainingSessionId,
  ) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .select()
        .eq('training_session_id', trainingSessionId)
        .order('block_index')
        .order('rep_number')
        .order('phase_type');

    return response
        .map<IntervalPerformance>(
          (row) => IntervalPerformance.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<ComparableIntervalSession?> getLatestCompletedComparableSession({
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

    final intervals = await getIntervalsForTrainingSession(session.id);

    return ComparableIntervalSession(
      session: session,
      intervals: intervals,
    );
  }

  Future<List<IntervalPerformance>> getLatestCompletedIntervalSession({
    required String athleteId,
    required String protocolId,
  }) async {
    final sessionData = await getLatestCompletedComparableSession(
      athleteId: athleteId,
      protocolId: protocolId,
    );

    if (sessionData == null) {
      return const [];
    }

    return sessionData.intervals;
  }
}
