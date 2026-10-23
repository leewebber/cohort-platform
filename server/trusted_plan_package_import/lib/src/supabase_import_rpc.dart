import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:http/http.dart' as http;

import 'contracts.dart';
import 'authoritative_v3_publication.dart';

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

/// Same configured trusted service transport; version registration is excluded.
class SupabaseV3PublicationAuthority implements V3PublicationAuthority {
  const SupabaseV3PublicationAuthority({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    required this.client,
  });
  final Uri supabaseUrl;
  final String serviceRoleKey;
  final http.Client client;
  @override
  Future<Map<String, Object?>> resolveCanonicalSource(String canonicalText) =>
      _call('read_v3_publication_dependencies', {
        'p_canonical_text': canonicalText,
      });
  @override
  Future<Map<String, Object?>> publishPrivateVersion(
    Map<String, Object?> payload,
  ) =>
      _call('publish_private_exact_programme_version_v3', {'payload': payload});
  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> parameters,
  ) async {
    final response = await client.post(
      supabaseUrl.resolve('/rest/v1/rpc/$name'),
      headers: {
        'apikey': serviceRoleKey,
        'authorization': 'Bearer $serviceRoleKey',
        'content-type': 'application/json',
      },
      body: jsonEncode(parameters),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PlanPackageRpcException();
    }
    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw const PlanPackageRpcException();
    }
    return Map<String, Object?>.from(body);
  }
}
