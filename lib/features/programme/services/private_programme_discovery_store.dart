import '../../../core/services/supabase_service.dart';
import '../models/private_programme_summary.dart';

abstract class PrivateProgrammeDiscoveryStore {
  Future<List<PrivateProgrammeSummary>> listMine();
}

class PrivateProgrammeDiscoverySupabaseStore
    implements PrivateProgrammeDiscoveryStore {
  const PrivateProgrammeDiscoverySupabaseStore();

  static const rpcName = 'list_my_private_programme_versions';

  @override
  Future<List<PrivateProgrammeSummary>> listMine() async {
    final response = await SupabaseService.client.rpc(rpcName);
    final map = _asMap(response);
    if (map['status']?.toString() != 'ok') {
      return const [];
    }
    final raw = map['programmes'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) => PrivateProgrammeSummary.fromRpcMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.versionId.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(Object? response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) {
      return response.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }
}
