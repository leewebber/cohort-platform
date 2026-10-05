import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/performance_tracking/coherent_history_rpc_reader.dart';

/// Explicitly constructed read-only transport. No production registration.
final class SupabaseHistoryTrackingRpcClient
    implements HistoryTrackingRpcClient {
  const SupabaseHistoryTrackingRpcClient(this.client);
  final SupabaseClient client;

  @override
  String? get authenticatedAthleteId => client.auth.currentUser?.id;

  @override
  Future<Object?> readTrackingHistory({
    required String recordId,
    required Map<String, Object?>? programmeClaim,
  }) => client.rpc(
    'read_performance_tracking_history_v1',
    params: {'p_record_id': recordId, 'p_programme_claim': programmeClaim},
  );
}
