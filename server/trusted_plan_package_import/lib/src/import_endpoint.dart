import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:shelf/shelf.dart';

import 'contracts.dart';

class TrustedFounderPlanPackageImportEndpoint {
  factory TrustedFounderPlanPackageImportEndpoint({
    required AuthTokenVerifier authVerifier,
    required FounderAuthorityVerifier founderAuthority,
    required PlanPackageImportRpc importRpc,
    PlanPackageCompiler compiler = const PlanPackageCompiler(),
    PlanPackageImportPayloadBuilder payloadBuilder =
        const PlanPackageImportPayloadBuilder(),
    int maxYamlBytes = 1024 * 1024,
  }) {
    return TrustedFounderPlanPackageImportEndpoint._(
      authVerifier,
      founderAuthority,
      importRpc,
      compiler,
      payloadBuilder,
      maxYamlBytes,
    );
  }

  TrustedFounderPlanPackageImportEndpoint._(
    this._authVerifier,
    this._founderAuthority,
    this._importRpc,
    this.compiler,
    this.payloadBuilder,
    this.maxYamlBytes,
  );

  static const route = 'v1/founder/plan-packages/import';

  final AuthTokenVerifier _authVerifier;
  final FounderAuthorityVerifier _founderAuthority;
  final PlanPackageImportRpc _importRpc;
  final PlanPackageCompiler compiler;
  final PlanPackageImportPayloadBuilder payloadBuilder;
  final int maxYamlBytes;

  Future<Response> call(Request request) async {
    if (request.url.path != route) {
      return _json(404, {'status': 'not_found', 'code': 'route_not_found'});
    }
    if (request.method != 'POST') {
      return _json(
        405,
        {'status': 'method_not_allowed', 'code': 'method_not_allowed'},
        headers: {'allow': 'POST'},
      );
    }

    final token = _bearerToken(request.headers['authorization']);
    if (token == null) {
      return _json(401, {
        'status': 'authorization_failure',
        'code': 'bearer_token_required',
      });
    }

    final AuthenticatedPrincipal? principal;
    try {
      principal = await _authVerifier.verifyBearerToken(token);
    } on TrustedAuthenticationException {
      return _json(503, {
        'status': 'authorization_failure',
        'code': 'authentication_unavailable',
      });
    }
    if (principal == null) {
      return _json(401, {
        'status': 'authorization_failure',
        'code': 'invalid_or_expired_token',
      });
    }

    final bool isFounder;
    try {
      isFounder = await _founderAuthority.isAuthorisedFounder(principal);
    } on FounderAuthorityLookupException {
      return _json(503, {
        'status': 'authorization_failure',
        'code': 'founder_authority_unavailable',
      });
    }
    if (!isFounder) {
      return _json(403, {
        'status': 'authorization_failure',
        'code': 'founder_authority_required',
      });
    }

    final contentType = request.headers['content-type']
        ?.split(';')
        .first
        .trim();
    if (contentType != 'application/yaml' &&
        contentType != 'application/x-yaml' &&
        contentType != 'text/yaml') {
      return _json(415, {
        'status': 'validation_failure',
        'code': 'yaml_content_type_required',
      });
    }
    final declaredLength = int.tryParse(
      request.headers['content-length']?.trim() ?? '',
    );
    if (declaredLength != null && declaredLength > maxYamlBytes) {
      return _json(413, {
        'status': 'validation_failure',
        'code': 'yaml_too_large',
      });
    }

    final String yamlSource;
    try {
      yamlSource = await _readBoundedYaml(request);
    } on _RequestTooLarge {
      return _json(413, {
        'status': 'validation_failure',
        'code': 'yaml_too_large',
      });
    } on FormatException {
      return _json(422, {
        'status': 'validation_failure',
        'code': 'yaml_must_be_utf8',
      });
    }

    final compileResult = compiler.compile(yamlSource);
    if (!compileResult.isValid || compileResult.manifest == null) {
      return _json(422, {
        'status': 'validation_failure',
        'code': 'compile_validation_failed',
        'issues': [
          for (final issue in compileResult.issues)
            {'path': issue.path, 'code': issue.code, 'message': issue.message},
        ],
      });
    }

    final payload = payloadBuilder.build(
      compileResult: compileResult,
      importedBy: principal.userId,
    );

    final PlanPackageImportResult result;
    try {
      result = await _importRpc.importPackage(payload);
    } on PlanPackageRpcException {
      return _json(502, {
        'status': 'database_failure',
        'code': 'import_rpc_unavailable',
      });
    }

    if (result.isSuccess &&
        (result.lifecycleStatus != 'draft' ||
            result.approvedForGlobal != false)) {
      return _json(502, {
        'status': 'database_failure',
        'code': 'invalid_import_lifecycle_result',
      });
    }

    return _resultResponse(result);
  }

  Future<String> _readBoundedYaml(Request request) async {
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      if (bytes.length + chunk.length > maxYamlBytes) {
        throw const _RequestTooLarge();
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  Response _resultResponse(PlanPackageImportResult result) {
    final statusCode = switch (result.status) {
      PlanPackageImportStatus.importedDraft ||
      PlanPackageImportStatus.idempotentExistingDraft => 200,
      PlanPackageImportStatus.versionCollision ||
      PlanPackageImportStatus.publishedVersionConflict ||
      PlanPackageImportStatus.partialStateConflict => 409,
      PlanPackageImportStatus.sessionResolutionFailure ||
      PlanPackageImportStatus.validationFailure => 422,
      PlanPackageImportStatus.authorizationFailure => 403,
      PlanPackageImportStatus.databaseFailure => 502,
    };

    return _json(statusCode, {
      'status': _statusValue(result.status),
      'code': _safeResultCode(result.status),
      if (result.programmeVersionId != null)
        'programme_version_id': result.programmeVersionId,
      if (result.lineageId != null) 'lineage_id': result.lineageId,
      if (result.lineageCode != null) 'lineage_code': result.lineageCode,
      if (result.versionNumber != null) 'version_number': result.versionNumber,
      if (result.packageContentHash != null)
        'package_content_hash': result.packageContentHash,
      if (result.lifecycleStatus != null)
        'lifecycle_status': result.lifecycleStatus,
      if (result.approvedForGlobal != null)
        'approved_for_global': result.approvedForGlobal,
    });
  }

  String _statusValue(PlanPackageImportStatus status) {
    return switch (status) {
      PlanPackageImportStatus.importedDraft => 'imported_draft',
      PlanPackageImportStatus.idempotentExistingDraft =>
        'idempotent_existing_draft',
      PlanPackageImportStatus.versionCollision => 'version_collision',
      PlanPackageImportStatus.publishedVersionConflict =>
        'published_version_conflict',
      PlanPackageImportStatus.partialStateConflict => 'partial_state_conflict',
      PlanPackageImportStatus.sessionResolutionFailure =>
        'session_resolution_failure',
      PlanPackageImportStatus.validationFailure => 'validation_failure',
      PlanPackageImportStatus.authorizationFailure => 'authorization_failure',
      PlanPackageImportStatus.databaseFailure => 'database_failure',
    };
  }

  String _safeResultCode(PlanPackageImportStatus status) {
    return switch (status) {
      PlanPackageImportStatus.importedDraft => 'created_hidden_draft',
      PlanPackageImportStatus.idempotentExistingDraft =>
        'same_hash_existing_draft',
      PlanPackageImportStatus.versionCollision => 'hash_collision',
      PlanPackageImportStatus.publishedVersionConflict =>
        'published_version_exists',
      PlanPackageImportStatus.partialStateConflict => 'partial_existing_draft',
      PlanPackageImportStatus.sessionResolutionFailure =>
        'session_resolution_failure',
      PlanPackageImportStatus.validationFailure => 'import_validation_failure',
      PlanPackageImportStatus.authorizationFailure => 'authorization_failure',
      PlanPackageImportStatus.databaseFailure => 'database_failure',
    };
  }

  String? _bearerToken(String? authorization) {
    if (authorization == null) return null;
    final match = RegExp(
      r'^Bearer[ ]+([^ ]+)$',
      caseSensitive: false,
    ).firstMatch(authorization.trim());
    final token = match?.group(1)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Response _json(
    int statusCode,
    Map<String, Object?> body, {
    Map<String, String>? headers,
  }) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
        ...?headers,
      },
    );
  }
}

class _RequestTooLarge implements Exception {
  const _RequestTooLarge();
}
