import '../../../core/services/supabase_service.dart';
import 'programme_training_session_start_store.dart';

class ProgrammeTrainingSessionStartSupabaseStore
    implements ProgrammeTrainingSessionStartStore {
  const ProgrammeTrainingSessionStartSupabaseStore();

  static const rpcName = 'create_or_resume_programme_training_session';

  @override
  Future<Map<String, dynamic>> createOrResume(
    Map<String, dynamic> payload,
  ) async {
    final occurrenceId = payload['occurrence_id']?.toString().trim();
    if (occurrenceId != null && occurrenceId.isNotEmpty) {
      final response = await SupabaseService.client.rpc(
        'create_or_resume_fixed_programme_occurrence_session',
        params: {'p_occurrence_id': occurrenceId},
      );
      if (response is Map) return Map<String, dynamic>.from(response);
      throw StateError('Unexpected fixed programme occurrence start response');
    }
    final response = await SupabaseService.client.rpc(
      rpcName,
      params: {'payload': payload},
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw StateError('Unexpected programme training-session start response');
  }
}
