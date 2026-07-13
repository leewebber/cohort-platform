import '../../core/services/supabase_service.dart';
import '../../models/training_session.dart';
import '../../models/training_session_completion_context.dart';
import '../../models/training_session_status.dart';
import 'base_repository.dart';

class TrainingSessionRepository extends BaseRepository<TrainingSession> {
  const TrainingSessionRepository();

  @override
  String get tableName => 'training_sessions';

  @override
  TrainingSession fromMap(Map<String, dynamic> map) {
    return TrainingSession.fromMap(map);
  }

  Future<TrainingSession> createSession({
    required String athleteId,
    required String protocolId,
    TrainingSessionStatus status = TrainingSessionStatus.planned,
    String? programmeId,
    int? weekNumber,
    String? day,
    DateTime? startedAt,
    DateTime? completedAt,
  }) async {
    final effectiveStartedAt = startedAt ??
        (status == TrainingSessionStatus.inProgress
            ? DateTime.now().toUtc()
            : null);

    final session = TrainingSession(
      id: 0,
      athleteId: athleteId,
      protocolId: protocolId,
      status: status,
      programmeId: programmeId,
      weekNumber: weekNumber,
      day: day,
      startedAt: effectiveStartedAt,
      completedAt: completedAt,
    );

    final response = await SupabaseService.client
        .from(tableName)
        .insert(session.toInsertMap())
        .select()
        .single();

    return fromMap(response);
  }

  Future<TrainingSession?> getSessionById(int id) async {
    final response = await SupabaseService.client
        .from(tableName)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    return fromMap(response);
  }

  Future<List<TrainingSession>> getSessionsForAthlete(
    String athleteId,
  ) {
    return getWhere(
      column: 'athlete_id',
      value: athleteId,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<TrainingSession?> getLatestSessionForAthleteAndProtocol({
    required String athleteId,
    required String protocolId,
  }) async {
    final response = await SupabaseService.client
        .from(tableName)
        .select()
        .eq('athlete_id', athleteId)
        .eq('protocol_id', protocolId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    return fromMap(response);
  }

  Future<TrainingSession?> completeSession(
    int id, {
    TrainingSessionCompletionContext? completion,
  }) async {
    final existing = await getSessionById(id);
    if (existing == null) return null;

    final completedAt = DateTime.now().toUtc();
    final context = completion ?? const TrainingSessionCompletionContext();
    final sessionNote = context.sessionNote?.trim();
    final completionReason = context.completionReason?.trim();

    final updateMap = <String, dynamic>{
      'status': TrainingSessionStatus.completed.dbValue,
      'completed_at': completedAt.toIso8601String(),
      'ended_early': context.endedEarly,
      if (sessionNote != null && sessionNote.isNotEmpty)
        'session_note': sessionNote,
      if (completionReason != null && completionReason.isNotEmpty)
        'completion_reason': completionReason,
      if (context.completedExerciseCount != null)
        'completed_exercise_count': context.completedExerciseCount,
      if (context.totalExerciseCount != null)
        'total_exercise_count': context.totalExerciseCount,
    };

    if (existing.startedAt != null) {
      updateMap['duration_seconds'] =
          completedAt.difference(existing.startedAt!).inSeconds;
    }

    final response = await SupabaseService.client
        .from(tableName)
        .update(updateMap)
        .eq('id', id)
        .select()
        .single();

    return fromMap(response);
  }
}
