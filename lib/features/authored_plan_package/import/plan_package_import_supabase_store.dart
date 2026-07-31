import 'package:supabase_flutter/supabase_flutter.dart';

import 'plan_package_import_models.dart';
import 'plan_package_import_store.dart';

/// Invokes Plan Package RPCs via an injected [SupabaseClient].
///
/// **Never constructs a service-role client.** The caller (founder backend /
/// controlled test harness) must supply an already-authorised client. Flutter
/// app composition roots must not wire this for ordinary athlete/coach sessions.
class PlanPackageImportSupabaseStore
    implements PlanPackageImportStore, PlanPackageLifecycleStore {
  PlanPackageImportSupabaseStore(this._client);

  final SupabaseClient _client;

  static const importRpcName = 'import_authored_plan_package';
  static const publishRpcName = 'publish_cohort_global_programme_version';
  static const approveRpcName = 'approve_cohort_global_programme_version';

  @override
  Future<PlanPackageImportResult> importPackage(
    Map<String, Object?> payload,
  ) async {
    final response = await _client.rpc(
      importRpcName,
      params: {'payload': payload},
    );
    final map = _asStringKeyedMap(response);
    return PlanPackageImportResult.fromRpcMap(map);
  }

  @override
  Future<Map<String, dynamic>> publishCohortGlobalVersion({
    required String versionId,
    required String actor,
  }) async {
    final response = await _client.rpc(
      publishRpcName,
      params: {'p_version_id': versionId, 'p_actor': actor},
    );
    return _asStringKeyedMap(response);
  }

  @override
  Future<Map<String, dynamic>> approveCohortGlobalVersion({
    required String versionId,
    required String actor,
  }) async {
    final response = await _client.rpc(
      approveRpcName,
      params: {'p_version_id': versionId, 'p_actor': actor},
    );
    return _asStringKeyedMap(response);
  }

  Map<String, dynamic> _asStringKeyedMap(Object? response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) {
      return response.map((key, value) => MapEntry(key.toString(), value));
    }
    throw StateError('RPC returned unexpected payload: $response');
  }
}
