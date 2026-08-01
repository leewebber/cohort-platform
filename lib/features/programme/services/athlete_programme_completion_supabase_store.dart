import '../../../core/services/supabase_service.dart';
import 'athlete_programme_completion_store.dart';

class AthleteProgrammeCompletionSupabaseStore
    implements AthleteProgrammeCompletionStore {
  const AthleteProgrammeCompletionSupabaseStore();

  static const rpcName = 'complete_programme_session_and_advance';

  @override
  Future<Map<String, dynamic>> completeAndAdvance(
    Map<String, dynamic> payload,
  ) async {
    final response = await SupabaseService.client.rpc(
      rpcName,
      params: {'payload': payload},
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw StateError('Unexpected completion RPC response');
  }
}
