import '../../../core/services/supabase_service.dart';
import '../mappers/performance_record_mapper.dart';
import '../models/active_performance_draft.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import 'performance_record_store.dart';

class SupabasePerformanceRecordStore extends PerformanceRecordStore {
  SupabasePerformanceRecordStore({
    PerformanceRecordMapper? mapper,
  }) : _mapper = mapper ?? const PerformanceRecordMapper();

  final PerformanceRecordMapper _mapper;

  @override
  Future<TrainingSessionRecord?> getById(String recordId) async {
    final response = await SupabaseService.client
        .from('training_session_records')
        .select()
        .eq('record_id', recordId)
        .maybeSingle();
    if (response == null) return null;
    return _hydrateRecord(Map<String, dynamic>.from(response));
  }

  @override
  Future<TrainingSessionRecord?> getInProgressForTrainingSession({
    required String athleteId,
    required int trainingSessionId,
  }) async {
    final response = await SupabaseService.client
        .from('training_session_records')
        .select()
        .eq('athlete_id', athleteId)
        .eq('training_session_id', trainingSessionId)
        .eq('status', TrainingSessionRecordStatus.inProgress.dbValue)
        .maybeSingle();
    if (response == null) return null;
    return _hydrateRecord(Map<String, dynamic>.from(response));
  }

  @override
  Future<TrainingSessionRecord?> getTerminalForTrainingSession({
    required String athleteId,
    required int trainingSessionId,
  }) async {
    final response = await SupabaseService.client
        .from('training_session_records')
        .select()
        .eq('athlete_id', athleteId)
        .eq('training_session_id', trainingSessionId)
        .neq('status', TrainingSessionRecordStatus.inProgress.dbValue)
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return _hydrateRecord(Map<String, dynamic>.from(response));
  }

  @override
  Future<TrainingSessionRecord> createOrResumeInProgress(
    ActivePerformanceDraft draft,
  ) async {
    final existing = await getInProgressForTrainingSession(
      athleteId: draft.athleteId,
      trainingSessionId: draft.trainingSessionId,
    );
    if (existing != null) return existing;

    final terminal = await getTerminalForTrainingSession(
      athleteId: draft.athleteId,
      trainingSessionId: draft.trainingSessionId,
    );
    if (terminal != null) return terminal;

    return saveDraft(
      draft.copyWith(status: TrainingSessionRecordStatus.inProgress),
    );
  }

  @override
  Future<TrainingSessionRecord> saveDraft(ActivePerformanceDraft draft) async {
    final record = _mapper.fromDraft(draft);
    await _upsertRecordTree(record);
    final hydrated = await getById(record.recordId);
    if (hydrated == null) {
      throw PerformanceRecordStoreException('Failed to save performance draft.');
    }
    return hydrated;
  }

  @override
  Future<TrainingSessionRecord> completeRecord(
    ActivePerformanceDraft draft,
  ) async {
    final existingTerminal = await getTerminalForTrainingSession(
      athleteId: draft.athleteId,
      trainingSessionId: draft.trainingSessionId,
    );
    if (existingTerminal != null) return existingTerminal;

    try {
      final response = await SupabaseService.client.rpc(
        'complete_training_session_record',
        params: {
          'payload': _mapper.fromDraft(draft).toUpsertMap(),
        },
      );
      if (response is Map) {
        return _hydrateRecord(Map<String, dynamic>.from(response));
      }
    } catch (_) {
      // Fall back to staged upsert when RPC is unavailable in local env.
    }

    return saveDraft(draft);
  }

  @override
  Future<List<TrainingSessionRecord>> listHistory({
    required String athleteId,
    int limit = 25,
    int offset = 0,
  }) async {
    final response = await SupabaseService.client
        .from('training_session_records')
        .select()
        .eq('athlete_id', athleteId)
        .neq('status', TrainingSessionRecordStatus.inProgress.dbValue)
        .order('completed_at', ascending: false)
        .range(offset, offset + limit - 1);

    final rows = (response as List).cast<Map<String, dynamic>>();
    final records = <TrainingSessionRecord>[];
    for (final row in rows) {
      records.add(await _hydrateRecord(row));
    }
    return records;
  }

  @override
  Future<int> deleteFounderScopedRecords({
    required String athleteId,
    required String sourceProtocolId,
    String? assignmentId,
  }) async {
    final filter = SupabaseService.client
        .from('training_session_records')
        .delete()
        .eq('athlete_id', athleteId);

    final response = assignmentId != null && assignmentId.isNotEmpty
        ? await filter
            .or(
              'source_protocol_id.eq.$sourceProtocolId,'
              'assignment_id.eq.$assignmentId',
            )
            .select('record_id')
        : await filter
            .eq('source_protocol_id', sourceProtocolId)
            .select('record_id');

    return (response as List).length;
  }

  Future<void> _upsertRecordTree(TrainingSessionRecord record) async {
    await SupabaseService.client
        .from('training_session_records')
        .upsert(record.toUpsertMap(), onConflict: 'record_id');

    for (final block in record.blockResults) {
      await SupabaseService.client
          .from('training_block_results')
          .upsert(block.toUpsertMap(), onConflict: 'block_result_id');

      for (final exercise in block.exerciseResults) {
        await SupabaseService.client.from('training_exercise_results').upsert(
          exercise.toUpsertMap(),
          onConflict: 'exercise_result_id',
        );

        for (final set in exercise.setResults) {
          await SupabaseService.client.from('training_set_results').upsert(
            set.toUpsertMap(),
            onConflict: 'set_result_id',
          );
        }
      }
    }
  }

  Future<TrainingSessionRecord> _hydrateRecord(
    Map<String, dynamic> recordRow,
  ) async {
    final recordId = recordRow['record_id']?.toString() ?? '';
    final blockRows = await SupabaseService.client
        .from('training_block_results')
        .select()
        .eq('session_record_id', recordId)
        .order('position');

    final blocks = <TrainingBlockResult>[];
    for (final blockRow in (blockRows as List).cast<Map<String, dynamic>>()) {
      final blockResultId = blockRow['block_result_id']?.toString() ?? '';
      final exerciseRows = await SupabaseService.client
          .from('training_exercise_results')
          .select()
          .eq('block_result_id', blockResultId)
          .order('position');

      final exercises = <TrainingExerciseResult>[];
      for (final exerciseRow
          in (exerciseRows as List).cast<Map<String, dynamic>>()) {
        final exerciseResultId =
            exerciseRow['exercise_result_id']?.toString() ?? '';
        final setRows = await SupabaseService.client
            .from('training_set_results')
            .select()
            .eq('exercise_result_id', exerciseResultId)
            .order('position');

        final sets = (setRows as List)
            .cast<Map<String, dynamic>>()
            .map(TrainingSetResult.fromMap)
            .toList(growable: false);

        exercises.add(
          TrainingExerciseResult.fromMap(exerciseRow, setResults: sets),
        );
      }

      blocks.add(
        TrainingBlockResult.fromMap(blockRow, exerciseResults: exercises),
      );
    }

    return TrainingSessionRecord.fromMap(recordRow, blockResults: blocks);
  }
}
