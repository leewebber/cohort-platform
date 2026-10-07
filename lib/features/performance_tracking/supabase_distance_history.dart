import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/authenticated_identity.dart';
import '../../infrastructure/performance_tracking/supabase_history_tracking_rpc_client.dart';
import 'distance_history_controller.dart';

/// Explicit athlete composition; no identity override or fixture fallback.
DistanceHistoryController createDistanceHistoryController(
  SupabaseClient client,
) => DistanceHistoryController(
  rpc: SupabaseHistoryTrackingRpcClient(client),
  records: SupabaseDistanceRecordList(client),
  activeAthlete: AuthenticatedIdentity.maybeAthleteId,
  identityChanges: client.auth.onAuthStateChange.map((_) {}),
);

final class SupabaseDistanceRecordList implements DistanceRecordListPort {
  const SupabaseDistanceRecordList(this.client);
  final SupabaseClient client;
  @override
  String? get authenticatedAthleteId => client.auth.currentUser?.id;

  @override
  Future<List<DistanceRecordSummary>> listOwned(
    String athleteId,
    int offset,
  ) async {
    if (athleteId != authenticatedAthleteId || offset < 0) {
      throw StateError('ownership_denied');
    }
    // Owned record metadata only. Child evidence always comes through the C2 RPC.
    final rows = await client
        .from('training_session_records')
        .select(
          'record_id,athlete_id,started_at,performed_on,performed_precision,status',
        )
        .eq('athlete_id', athleteId)
        .inFilter('status', ['completed', 'partially_completed', 'abandoned'])
        .order('record_id')
        .range(offset, offset + 24);
    if (athleteId != authenticatedAthleteId) {
      throw StateError('ownership_denied');
    }
    return rows.map((row) {
      if (row['athlete_id'] != athleteId ||
          row['record_id'] is! String ||
          row['status'] is! String) {
        throw StateError('invalid_record_metadata');
      }
      final date = row['performed_precision'] == 'date'
          ? row['performed_on']
          : row['started_at'];
      return DistanceRecordSummary(
        row['record_id'] as String,
        athleteId,
        date is String ? date : 'Date unavailable',
        row['status'] as String,
      );
    }).toList();
  }
}
