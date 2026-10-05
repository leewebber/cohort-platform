import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/performance_tracking/programme_history_rpc_reader.dart';

/// Explicit construction only; no production registration or fallback reads.
final class SupabaseProgrammeHistoryRpcClient
    implements ProgrammeHistoryRpcClient {
  const SupabaseProgrammeHistoryRpcClient(this.client);
  final SupabaseClient client;
  @override
  String? get authenticatedAthleteId => client.auth.currentUser?.id;
  @override
  Future<Object?> readProgrammeHistory({
    required String recordId,
    required Map<String, Object?> programmeClaim,
  }) => client.rpc(
    'read_performance_tracking_programme_history_v1',
    params: {'p_record_id': recordId, 'p_programme_claim': programmeClaim},
  );
}
