import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:http/http.dart' as http;

import 'contracts.dart';

/// Production adapter for the existing service-role-only atomic import RPC.
class SupabasePlanPackageImportRpc implements PlanPackageImportRpc {
  SupabasePlanPackageImportRpc({
    required Uri supabaseUrl,
    required String serviceRoleKey,
    required http.Client client,
  }) : this._(
         supabaseUrl.resolve('/rest/v1/rpc/import_authored_plan_package'),
         serviceRoleKey,
         client,
       );

  SupabasePlanPackageImportRpc._(
    this._endpoint,
    this._serviceRoleKey,
    this._client,
  );

  static const rpcName = 'import_authored_plan_package';

  final Uri _endpoint;
  final String _serviceRoleKey;
  final http.Client _client;

  @override
  Future<PlanPackageImportResult> importPackage(
    Map<String, Object?> compilerDerivedPayload,
  ) async {
    try {
      final response = await _client.post(
        _endpoint,
        headers: {
          'apikey': _serviceRoleKey,
          'authorization': 'Bearer $_serviceRoleKey',
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({'payload': compilerDerivedPayload}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const PlanPackageRpcException();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const PlanPackageRpcException();
      }
      return PlanPackageImportResult.fromRpcMap(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on PlanPackageRpcException {
      rethrow;
    } catch (_) {
      throw const PlanPackageRpcException();
    }
  }
}
