import '../../core/services/supabase_service.dart';
import '../../models/exercise_history_raw_row.dart';
import '../../models/previous_exercise_performance.dart';
import '../../models/strength_set_performance.dart';

class TrainingSessionSetRepository {
  const TrainingSessionSetRepository();

  static const _tableName = 'training_session_sets';
  static const _upsertConflict =
      'training_session_id,protocol_step_id,set_number,is_extra_set';
  static const _historyDiscoveryRowLimit = 500;
  static const _sessionCompletionFields =
      'completed_at, protocol_id, athlete_id, status, ended_early, completion_reason';

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

  /// Fetches completed set rows for up to [sessionLimit] recent sessions.
  ///
  /// Completed sessions only. Grouping and summaries belong in
  /// [ExerciseHistoryService].
  ///
  /// Future work: cursor pagination using `(completed_at, training_session_id)`
  /// rather than a fixed recent-session window.
  Future<List<ExerciseHistoryRawRow>> getCompletedExerciseHistory({
    required String athleteId,
    required String exerciseId,
    int sessionLimit = 20,
  }) async {
    final sessionHeaders = await _fetchRecentCompletedSessionHeaders(
      athleteId: athleteId,
      exerciseId: exerciseId,
      sessionLimit: sessionLimit,
    );

    if (sessionHeaders.isEmpty) {
      return const [];
    }

    final sessionIds =
        sessionHeaders.map((header) => header.trainingSessionId).toList();

    final response = await SupabaseService.client
        .from(_tableName)
        .select(
          '*, training_sessions!inner($_sessionCompletionFields)',
        )
        .eq('exercise_id', exerciseId)
        .eq('completed', true)
        .inFilter('training_session_id', sessionIds)
        .eq('training_sessions.athlete_id', athleteId)
        .eq('training_sessions.status', 'completed')
        .order('set_number')
        .order('is_extra_set');

    final rows = response
        .map(
          (row) => ExerciseHistoryRawRow.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();

    final completedAtBySessionId = {
      for (final header in sessionHeaders)
        header.trainingSessionId: header.sessionCompletedAt,
    };

    rows.sort((left, right) {
      final leftCompletedAt = completedAtBySessionId[left.trainingSessionId];
      final rightCompletedAt = completedAtBySessionId[right.trainingSessionId];

      if (leftCompletedAt != null && rightCompletedAt != null) {
        final compare = rightCompletedAt.compareTo(leftCompletedAt);
        if (compare != 0) {
          return compare;
        }
      }

      final extraCompare = (left.performance.isExtraSet ? 1 : 0)
          .compareTo(right.performance.isExtraSet ? 1 : 0);
      if (extraCompare != 0) {
        return extraCompare;
      }

      return left.performance.setNumber.compareTo(right.performance.setNumber);
    });

    return rows;
  }

  Future<List<ExerciseHistorySessionHeader>> _fetchRecentCompletedSessionHeaders({
    required String athleteId,
    required String exerciseId,
    required int sessionLimit,
  }) async {
    final response = await SupabaseService.client
        .from(_tableName)
        .select(
          'training_session_id, training_sessions!inner($_sessionCompletionFields)',
        )
        .eq('exercise_id', exerciseId)
        .eq('completed', true)
        .eq('training_sessions.athlete_id', athleteId)
        .eq('training_sessions.status', 'completed')
        .limit(_historyDiscoveryRowLimit);

    final headersBySessionId = <int, ExerciseHistorySessionHeader>{};

    for (final row in response) {
      final map = Map<String, dynamic>.from(row);
      final sessionId = map['training_session_id'];
      if (sessionId is! int) {
        continue;
      }

      final session = map['training_sessions'];
      if (session is! Map) {
        continue;
      }

      final sessionMap = Map<String, dynamic>.from(session);
      final completedAt = _parseDateTime(sessionMap['completed_at']);
      final protocolId = sessionMap['protocol_id']?.toString().trim() ?? '';

      final existing = headersBySessionId[sessionId];
      if (existing == null ||
          (completedAt != null &&
              (existing.sessionCompletedAt == null ||
                  completedAt.isAfter(existing.sessionCompletedAt!)))) {
        headersBySessionId[sessionId] = ExerciseHistorySessionHeader(
          trainingSessionId: sessionId,
          protocolId: protocolId,
          sessionCompletedAt: completedAt,
        );
      }
    }

    final headers = headersBySessionId.values.toList()
      ..sort((left, right) {
        final leftDate = left.sessionCompletedAt;
        final rightDate = right.sessionCompletedAt;

        if (leftDate == null && rightDate == null) {
          return right.trainingSessionId.compareTo(left.trainingSessionId);
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }

        return rightDate.compareTo(leftDate);
      });

    return headers.take(sessionLimit).toList(growable: false);
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
