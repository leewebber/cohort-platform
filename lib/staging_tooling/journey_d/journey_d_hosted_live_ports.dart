import 'dart:convert';

import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';

import 'journey_d_bounded_http.dart';
import 'journey_d_fixture_identity.dart';
import 'journey_d_live_ports.dart';
import 'journey_d_protocol_publication.dart';
import 'journey_d_write_accounting.dart';

/// Staging HTTP ports for Journey D live creation (no production-linked CLI).
///
/// Uses exact filters only. Never enumerates athletes or catalogues.
class JourneyDHostedHttpPreflight implements JourneyDLivePreflight {
  JourneyDHostedHttpPreflight({required this.apiUrl, required this.serviceKey});

  final String apiUrl;
  final String serviceKey;

  @override
  Future<JourneyDLiveStageOutcome> checkUnique({
    required String marker,
    required String lineageCode,
  }) async {
    final email = journeyDFixtureEmail(marker);
    // GoTrue admin listUsers filters via `filter`, not `email`.
    // `?email=` is ignored and returns an unfiltered page — false UNIQUE.
    final auth = await _get(
      '/auth/v1/admin/users?filter=${Uri.encodeQueryComponent(email)}',
    );
    if (auth.timedOut) {
      return auth.dispatched
          ? JourneyDLiveStageOutcome.unknown(
              'auth_preflight_timed_out_dispatched',
            )
          : JourneyDLiveStageOutcome.timedOut('auth_preflight_timed_out');
    }
    if (auth.statusCode != 200) {
      return JourneyDLiveStageOutcome.unknown(
        'auth_preflight_http_${auth.statusCode}',
      );
    }
    final authBody = jsonDecode(auth.body);
    var authHits = 0;
    if (authBody is Map && authBody['users'] is List) {
      authHits = (authBody['users'] as List)
          .whereType<Map>()
          .where((u) => (u['email'] ?? '') == email)
          .length;
    } else if (authBody is Map && authBody['email'] == email) {
      authHits = 1;
    } else if (authBody is List) {
      authHits = authBody
          .whereType<Map>()
          .where((u) => (u['email'] ?? '') == email)
          .length;
    }
    final lin = await _get(
      '/rest/v1/programme_lineages?select=id&code=eq.'
      '${Uri.encodeQueryComponent(lineageCode)}',
      preferCount: true,
    );
    if (lin.timedOut) {
      return lin.dispatched
          ? JourneyDLiveStageOutcome.unknown(
              'lineage_preflight_timed_out_dispatched',
            )
          : JourneyDLiveStageOutcome.timedOut('lineage_preflight_timed_out');
    }
    if (lin.statusCode != 200) {
      return JourneyDLiveStageOutcome.unknown(
        'lineage_preflight_http_${lin.statusCode}',
      );
    }
    final lineageHits =
        _countFromContentRange(lin.contentRange) ??
        ((jsonDecode(lin.body) is List)
            ? (jsonDecode(lin.body) as List).length
            : null);
    if (lineageHits == null) {
      return JourneyDLiveStageOutcome.unknown('lineage_count_unknown');
    }
    if (authHits > 0 || lineageHits > 0) {
      return JourneyDLiveStageOutcome.failed(
        'preflight_collision auth=$authHits lineage=$lineageHits',
      );
    }
    return JourneyDLiveStageOutcome.applied(
      detail: 'UNIQUE',
      hostedWrite: false,
    );
  }

  Future<_HttpResp> _get(String path, {bool preferCount = false}) async {
    try {
      final headers = <String, String>{
        'apikey': serviceKey,
        'Authorization': 'Bearer $serviceKey',
        if (preferCount) 'Prefer': 'count=exact',
        if (preferCount) 'Range': '0-0',
      };
      final resp = await JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 45),
      ).get(Uri.parse('$apiUrl$path'), headers: headers);
      return _HttpResp(
        statusCode: resp.statusCode,
        body: resp.body,
        contentRange: resp.contentRange,
        dispatched: resp.dispatched,
      );
    } on JourneyDHttpTimeoutException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.toString(),
        dispatched: e.dispatched,
        timedOut: true,
      );
    } on JourneyDHttpTransportException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.detail,
        dispatched: e.dispatched,
      );
    }
  }

  static int? _countFromContentRange(String? cr) {
    if (cr == null || !cr.contains('/')) return null;
    final total = cr.split('/').last;
    if (total == '*') return null;
    return int.tryParse(total);
  }
}

class JourneyDHostedHttpAthleteFactory implements JourneyDLiveAthleteFactory {
  JourneyDHostedHttpAthleteFactory({
    required this.apiUrl,
    required this.serviceKey,
    required this.anonKey,
  });

  final String apiUrl;
  final String serviceKey;
  final String anonKey;

  @override
  Future<JourneyDLiveAthleteResult> create({
    required String marker,
    required String email,
    required String displayName,
  }) async {
    // Exact identity lock: create must use the same email as uniqueness/verify.
    final expected = journeyDFixtureEmail(marker);
    if (email != expected) {
      return JourneyDLiveAthleteResult(
        state: JourneyDPublicationStageState.failed,
        detail: 'auth_create_email_identity_mismatch',
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
        ),
      );
    }
    final password =
        'Jd${DateTime.now().microsecondsSinceEpoch}!aA1${marker.hashCode.abs()}';
    // Process-local only until private credential handoff write.
    JourneyDHostedSession.instance.athletePassword = password;
    JourneyDHostedSession.instance.athleteEmail = email;
    final created = await _post('/auth/v1/admin/users', {
      'email': email,
      'password': password,
      'email_confirm': true,
      'user_metadata': {
        'display_name': displayName,
        'purpose': 's17_journey_d_adaptation_fixture',
        'label': 'S17-JD-ADAPT-FIXTURE',
        'run_id': marker,
        'roles': ['athlete'],
      },
    }, key: serviceKey);
    if (created.timedOut) {
      return JourneyDLiveAthleteResult(
        state: created.dispatched
            ? JourneyDPublicationStageState.unknown
            : JourneyDPublicationStageState.timedOut,
        detail: created.dispatched
            ? 'auth_create_timed_out_dispatched'
            : 'auth_create_timed_out',
        writeAccounting: JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: created.dispatched,
          outcomeUncertain: created.dispatched,
        ),
      );
    }
    if (created.statusCode != 200 && created.statusCode != 201) {
      return JourneyDLiveAthleteResult(
        state: JourneyDPublicationStageState.failed,
        detail: authCreateFailureDetail(created.statusCode, created.body),
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
        ),
      );
    }
    final body = jsonDecode(created.body);
    if (body is! Map || body['id'] == null) {
      return const JourneyDLiveAthleteResult(
        state: JourneyDPublicationStageState.unknown,
        detail: 'auth_create_ambiguous_body',
        writeAccounting: JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
          outcomeUncertain: true,
        ),
      );
    }
    final userId = body['id'].toString();
    var profile = await _post(
      '/rest/v1/profiles',
      {
        'id': userId,
        'display_name': displayName,
        'is_coach': false,
        'is_athlete': true,
      },
      key: serviceKey,
      prefer: 'return=representation',
    );
    if (profile.statusCode != 200 && profile.statusCode != 201) {
      profile = await _patch('/rest/v1/profiles?id=eq.$userId', {
        'display_name': displayName,
        'is_coach': false,
        'is_athlete': true,
      }, key: serviceKey);
      if (profile.statusCode != 200 && profile.statusCode != 204) {
        return JourneyDLiveAthleteResult(
          state: JourneyDPublicationStageState.failed,
          userIdRedacted: '${userId.substring(0, 8)}…',
          detail: 'profile_create_failed',
          writeAccounting: const JourneyDWriteAccounting(
            invocationAttempted: true,
            requestDispatched: true,
            responseReceived: true,
            // Auth user id was returned; profile write failed.
            mutationConfirmed: true,
            outcomeUncertain: true,
          ),
        );
      }
    }
    final login = await _post('/auth/v1/token?grant_type=password', {
      'email': email,
      'password': password,
    }, key: anonKey);
    if (login.statusCode != 200) {
      return JourneyDLiveAthleteResult(
        state: JourneyDPublicationStageState.failed,
        userIdRedacted: '${userId.substring(0, 8)}…',
        detail: 'athlete_login_failed',
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
          mutationConfirmed: true,
          outcomeUncertain: true,
        ),
      );
    }
    final loginBody = jsonDecode(login.body);
    final token = loginBody is Map ? loginBody['access_token'] : null;
    // Stash token + identity for enrol/materialise and private credential handoff.
    if (token is String) {
      JourneyDHostedSession.instance.athleteAccessToken = token;
      JourneyDHostedSession.instance.athleteUserId = userId;
    }
    return JourneyDLiveAthleteResult(
      state: JourneyDPublicationStageState.applied,
      userIdRedacted: '${userId.substring(0, 8)}…',
      accessTokenPresent: token is String,
      detail: 'athlete_created_response_received',
      privateUserId: userId,
      privatePassword: password,
      privateEmail: email,
      // Response proved an id; creator does not re-GET the user. Post-create
      // verifiers must set object_observed_post_attempt separately.
      writeAccounting: const JourneyDWriteAccounting(
        invocationAttempted: true,
        requestDispatched: true,
        responseReceived: true,
        mutationConfirmed: true,
        objectObservedPostAttempt: false,
      ),
    );
  }

  Future<_HttpResp> _post(
    String path,
    Map<String, Object?> body, {
    required String key,
    String? prefer,
  }) async {
    try {
      final resp = await JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 60),
      ).post(
        Uri.parse('$apiUrl$path'),
        headers: {
          'apikey': key,
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          if (prefer != null) 'Prefer': prefer,
        },
        body: body,
      );
      return _HttpResp(
        statusCode: resp.statusCode,
        body: resp.body,
        dispatched: resp.dispatched,
      );
    } on JourneyDHttpTimeoutException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.toString(),
        dispatched: e.dispatched,
        timedOut: true,
      );
    } on JourneyDHttpTransportException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.detail,
        dispatched: e.dispatched,
      );
    }
  }

  Future<_HttpResp> _patch(
    String path,
    Map<String, Object?> body, {
    required String key,
  }) async {
    try {
      final resp = await JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 60),
      ).patch(
        Uri.parse('$apiUrl$path'),
        headers: {
          'apikey': key,
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      return _HttpResp(
        statusCode: resp.statusCode,
        body: resp.body,
        dispatched: resp.dispatched,
      );
    } on JourneyDHttpTimeoutException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.toString(),
        dispatched: e.dispatched,
        timedOut: true,
      );
    } on JourneyDHttpTransportException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.detail,
        dispatched: e.dispatched,
      );
    }
  }
}

/// Process-local session for athlete JWT between stages (hosted only).
class JourneyDHostedSession {
  JourneyDHostedSession._();
  static final instance = JourneyDHostedSession._();
  String? athleteAccessToken;
  String? athleteUserId;
  String? athletePassword;
  String? athleteEmail;
  String? assignmentId;
  String? versionId;

  void clearSecrets() {
    athleteAccessToken = null;
    athletePassword = null;
  }
}

class JourneyDHostedProgrammeLifecycle
    implements JourneyDLiveProgrammeLifecycle {
  JourneyDHostedProgrammeLifecycle({
    required this.apiUrl,
    required this.serviceKey,
  });

  final String apiUrl;
  final String serviceKey;

  @override
  Future<JourneyDLiveStageOutcome> importValidatedPackage({
    required Map<String, Object?> payload,
    required String importedBy,
  }) async {
    if (payload.toString().contains('SL-S17-JD-ADAPT-')) {
      return JourneyDLiveStageOutcome.failed(
        'symbolic_lineage_reached_import_payload',
      );
    }
    final resp = await _rpc('import_authored_plan_package', {
      'payload': payload,
    });
    if (resp.timedOut) {
      return resp.dispatched
          ? JourneyDLiveStageOutcome.unknown('import_timed_out_dispatched')
          : JourneyDLiveStageOutcome.failed('import_timed_out');
    }
    if (resp.statusCode != 200) {
      return JourneyDLiveStageOutcome.failed('import_http_${resp.statusCode}');
    }
    try {
      final map = jsonDecode(resp.body);
      if (map is! Map) {
        return JourneyDLiveStageOutcome.unknown('import_ambiguous_body');
      }
      final result = PlanPackageImportResult.fromRpcMap(
        map.map((k, v) => MapEntry(k.toString(), v)),
      );
      if (!result.isSuccess || result.programmeVersionId == null) {
        return JourneyDLiveStageOutcome.failed(
          'import_not_success:${result.status.name}',
        );
      }
      final vid = result.programmeVersionId!;
      return JourneyDLiveStageOutcome.applied(
        detail: 'imported',
        versionId: vid,
        versionIdRedacted: '${vid.substring(0, 8)}…',
      );
    } catch (e) {
      return JourneyDLiveStageOutcome.unknown('import_parse:$e');
    }
  }

  @override
  Future<JourneyDLiveStageOutcome> publishAndApprove({
    required String versionId,
    required String actor,
  }) async {
    final pub = await _rpc('publish_cohort_global_programme_version', {
      'p_version_id': versionId,
      'p_actor': actor,
    });
    if (pub.statusCode != 200) {
      return JourneyDLiveStageOutcome.failed('publish_http_${pub.statusCode}');
    }
    final appr = await _rpc('approve_cohort_global_programme_version', {
      'p_version_id': versionId,
      'p_actor': actor,
    });
    if (appr.statusCode != 200) {
      return JourneyDLiveStageOutcome.failed('approve_http_${appr.statusCode}');
    }
    return JourneyDLiveStageOutcome.applied(detail: 'published_approved');
  }

  Future<_HttpResp> _rpc(String name, Map<String, Object?> params) async {
    try {
      final resp = await JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 90),
      ).post(
        Uri.parse('$apiUrl/rest/v1/rpc/$name'),
        headers: {
          'apikey': serviceKey,
          'Authorization': 'Bearer $serviceKey',
          'Content-Type': 'application/json',
        },
        body: params,
      );
      return _HttpResp(
        statusCode: resp.statusCode,
        body: resp.body,
        dispatched: resp.dispatched,
      );
    } on JourneyDHttpTimeoutException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.toString(),
        dispatched: e.dispatched,
        timedOut: true,
      );
    } on JourneyDHttpTransportException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.detail,
        dispatched: e.dispatched,
      );
    }
  }
}

class JourneyDHostedEnrolment implements JourneyDLiveEnrolment {
  JourneyDHostedEnrolment({required this.apiUrl, required this.anonKey});

  final String apiUrl;
  final String anonKey;

  @override
  Future<JourneyDLiveEnrolResult> enrol({
    required String programmeVersionId,
  }) async {
    final token = JourneyDHostedSession.instance.athleteAccessToken;
    if (token == null) {
      return const JourneyDLiveEnrolResult(
        state: JourneyDPublicationStageState.failed,
        detail: 'missing_athlete_token',
      );
    }
    final resp =
        await _athleteRpc('enrol_athlete_in_catalogue_programme_version', {
          'p_programme_version_id': programmeVersionId,
          'p_timezone': 'UTC',
          'p_replace_active': false,
        }, token: token);
    if (resp.statusCode != 200) {
      return JourneyDLiveEnrolResult(
        state: JourneyDPublicationStageState.failed,
        detail: 'enrol_http_${resp.statusCode}',
      );
    }
    try {
      final map = jsonDecode(resp.body);
      if (map is! Map) {
        return const JourneyDLiveEnrolResult(
          state: JourneyDPublicationStageState.unknown,
          detail: 'enrol_ambiguous',
        );
      }
      final status = map['status']?.toString();
      if (status != 'enrolled' && status != 'already_enrolled') {
        return JourneyDLiveEnrolResult(
          state: JourneyDPublicationStageState.failed,
          detail: 'enrol_status:$status',
        );
      }
      final assignmentId = (map['enrolment_id'] ?? map['assignment_id'])
          ?.toString();
      if (assignmentId == null || assignmentId.isEmpty) {
        return const JourneyDLiveEnrolResult(
          state: JourneyDPublicationStageState.failed,
          detail: 'enrol_missing_assignment',
        );
      }
      return JourneyDLiveEnrolResult(
        state: JourneyDPublicationStageState.applied,
        assignmentId: assignmentId,
        assignmentIdRedacted: '${assignmentId.substring(0, 8)}…',
        detail: 'enrolled',
      );
    } catch (e) {
      return JourneyDLiveEnrolResult(
        state: JourneyDPublicationStageState.unknown,
        detail: 'enrol_parse:$e',
      );
    }
  }

  Future<_HttpResp> _athleteRpc(
    String name,
    Map<String, Object?> params, {
    required String token,
  }) async {
    try {
      final resp = await JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 90),
      ).post(
        Uri.parse('$apiUrl/rest/v1/rpc/$name'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: params,
      );
      return _HttpResp(
        statusCode: resp.statusCode,
        body: resp.body,
        dispatched: resp.dispatched,
      );
    } on JourneyDHttpTimeoutException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.toString(),
        dispatched: e.dispatched,
        timedOut: true,
      );
    } on JourneyDHttpTransportException catch (e) {
      return _HttpResp(
        statusCode: 0,
        body: '',
        detail: e.detail,
        dispatched: e.dispatched,
      );
    }
  }
}

class JourneyDHostedMaterialisation implements JourneyDLiveMaterialisation {
  JourneyDHostedMaterialisation({required this.apiUrl, required this.anonKey});

  final String apiUrl;
  final String anonKey;

  @override
  Future<JourneyDLiveStageOutcome> materialise({
    required String programmeAssignmentId,
  }) async {
    final token = JourneyDHostedSession.instance.athleteAccessToken;
    if (token == null) {
      return JourneyDLiveStageOutcome.failed('missing_athlete_token');
    }
    late final _HttpResp resp;
    try {
      final bounded = await JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 90),
      ).post(
        Uri.parse(
          '$apiUrl/rest/v1/rpc/materialise_athlete_plan_from_enrolment',
        ),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: {
          'p_programme_assignment_id': programmeAssignmentId,
          'p_timezone': 'UTC',
        },
      );
      resp = _HttpResp(
        statusCode: bounded.statusCode,
        body: bounded.body,
        dispatched: bounded.dispatched,
      );
    } on JourneyDHttpTimeoutException catch (e) {
      return e.dispatched
          ? JourneyDLiveStageOutcome.unknown(
              'materialise_timed_out_dispatched',
            )
          : JourneyDLiveStageOutcome.failed('materialise_timed_out');
    } on JourneyDHttpTransportException catch (e) {
      return JourneyDLiveStageOutcome.failed('materialise_${e.detail}');
    }
    if (resp.statusCode != 200) {
      return JourneyDLiveStageOutcome.failed(
        'materialise_http_${resp.statusCode}',
      );
    }
    final map = jsonDecode(resp.body);
    if (map is! Map) {
      return JourneyDLiveStageOutcome.unknown('materialise_ambiguous');
    }
    final status = map['status']?.toString();
    if (status != 'materialised' && status != 'already_materialised') {
      return JourneyDLiveStageOutcome.failed('materialise_status:$status');
    }
    return JourneyDLiveStageOutcome.applied(detail: 'materialised');
  }
}

/// Redacted Auth Admin create failure detail for durable ledgers.
///
/// Preserves GoTrue `error_code` / `msg` so HTTP 422 cannot consume another
/// creator allowance without an identifiable Auth cause.
String authCreateFailureDetail(int statusCode, String body) {
  final parsed = _parseAuthErrorBody(body);
  final code = parsed.$1;
  final message = parsed.$2;
  final parts = <String>['auth_create_http_$statusCode'];
  if (code != null && code.isNotEmpty) {
    parts.add(code);
  }
  if (message != null && message.isNotEmpty) {
    parts.add(message);
  }
  return parts.join(':');
}

/// True when Auth create failure indicates an existing Auth email identity.
bool authCreateFailureIsEmailCollision(String detail) {
  final lower = detail.toLowerCase();
  return lower.contains('email_exists') ||
      lower.contains('user_already_exists') ||
      lower.contains('already registered') ||
      lower.contains('already been registered');
}

(String?, String?) _parseAuthErrorBody(String body) {
  if (body.trim().isEmpty) return (null, null);
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return (null, null);
    final map = Map<String, dynamic>.from(decoded);
    final code = (map['error_code'] ?? map['code'] ?? map['error'])?.toString();
    final message = (map['msg'] ?? map['message'] ?? map['error_description'])
        ?.toString();
    return (
      code == null ? null : _redactAuthText(code),
      message == null ? null : _redactAuthText(message),
    );
  } on Object {
    return (null, null);
  }
}

String _redactAuthText(String value) {
  var out = value.trim();
  out = out.replaceAll(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    '***email***',
  );
  out = out.replaceAll(
    RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ),
    '***id***',
  );
  if (out.length > 160) {
    out = '${out.substring(0, 160)}…';
  }
  return out;
}

class _HttpResp {
  const _HttpResp({
    required this.statusCode,
    required this.body,
    this.contentRange,
    this.detail = '',
    this.dispatched = true,
    this.timedOut = false,
  });
  final int statusCode;
  final String body;
  final String? contentRange;
  final String detail;
  final bool dispatched;
  final bool timedOut;
}
