import '../../core/services/supabase_service.dart';
import 'session_revision_delete_store.dart';

class SessionRevisionDeleteSupabaseStore extends SessionRevisionDeleteStore {
  const SessionRevisionDeleteSupabaseStore();

  static const _protocolsTable = 'performance_protocols';
  static const _stepsTable = 'protocol_steps';

  @override
  Future<void> deleteRevision(String protocolId) async {
    final normalizedProtocolId = protocolId.trim();
    if (normalizedProtocolId.isEmpty) {
      throw const SessionRevisionDeleteStoreException('protocolId is required.');
    }

    await SupabaseService.client
        .from(_stepsTable)
        .delete()
        .eq('protocol_id', normalizedProtocolId);

    await SupabaseService.client
        .from(_protocolsTable)
        .delete()
        .eq('protocol_id', normalizedProtocolId);
  }
}
