import '../../../core/services/supabase_service.dart';

class AthleteRuntimeCapabilities {
  const AthleteRuntimeCapabilities({
    this.overdueRecovery = false,
    this.backfillResults = false,
    this.schemaVersion = 0,
  });

  final bool overdueRecovery;
  final bool backfillResults;
  final int schemaVersion;

  static const unavailable = AthleteRuntimeCapabilities();
}

/// Single hosted capability probe. UI must not catch RPC-not-found locally.
class SupabaseAthleteRuntimeCapabilityStore {
  const SupabaseAthleteRuntimeCapabilityStore();

  static const rpcName = 'cohort_athlete_runtime_capabilities';

  Future<AthleteRuntimeCapabilities> load() async {
    try {
      final client = SupabaseService.client;
      final response = await client.rpc(rpcName);
      if (response is! Map) return AthleteRuntimeCapabilities.unavailable;
      final map = Map<String, dynamic>.from(response);
      if (map['status']?.toString() != 'ok') {
        return AthleteRuntimeCapabilities.unavailable;
      }
      return AthleteRuntimeCapabilities(
        overdueRecovery: map['overdue_recovery'] == true,
        backfillResults: map['backfill_results'] == true,
        schemaVersion: int.tryParse(map['schema_version']?.toString() ?? '') ?? 0,
      );
    } catch (error) {
      if (_isMissingCapabilityContract(error)) {
        return AthleteRuntimeCapabilities.unavailable;
      }
      return AthleteRuntimeCapabilities.unavailable;
    }
  }

  static bool _isMissingCapabilityContract(Object error) {
    final code = _errorCode(error);
    return code == 'PGRST202' || code == '42883';
  }

  static String? _errorCode(Object error) {
    try {
      final dynamic value = error;
      final code = value.code;
      return code?.toString();
    } catch (_) {
      return null;
    }
  }
}
