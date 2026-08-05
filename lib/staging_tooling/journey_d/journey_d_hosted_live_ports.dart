import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';

import 'journey_d_live_ports.dart';
import 'journey_d_protocol_publication.dart';

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
    final email = '$marker.athlete.jd@example.invalid';
    final auth = await _get(
      '/auth/v1/admin/users?email=${Uri.encodeQueryComponent(email)}',
    );
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
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('$apiUrl$path'));
      req.headers.set('apikey', serviceKey);
      req.headers.set('Authorization', 'Bearer $serviceKey');
      if (preferCount) {
        req.headers.set('Prefer', 'count=exact');
        req.headers.set('Range', '0-0');
      }
      final resp = await req.close().timeout(const Duration(seconds: 45));
      final body = await resp.transform(utf8.decoder).join();
      return _HttpResp(
        statusCode: resp.statusCode,
        body: body,
        contentRange: resp.headers.value('content-range'),
      );
    } finally {
      client.close(force: true);
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
    if (created.statusCode != 200 && created.statusCode != 201) {
      return JourneyDLiveAthleteResult(
        state: JourneyDPublicationStageState.failed,
        detail: 'auth_create_http_${created.statusCode}',
      );
    }
    final body = jsonDecode(created.body);
    if (body is! Map || body['id'] == null) {
      return const JourneyDLiveAthleteResult(
        state: JourneyDPublicationStageState.unknown,
        detail: 'auth_create_ambiguous_body',
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
      detail: 'athlete_created',
      privateUserId: userId,
      privatePassword: password,
      privateEmail: email,
    );
  }

  Future<_HttpResp> _post(
    String path,
    Map<String, Object?> body, {
    required String key,
    String? prefer,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$apiUrl$path'));
      req.headers.set('apikey', key);
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.set('Content-Type', 'application/json');
      if (prefer != null) req.headers.set('Prefer', prefer);
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close().timeout(const Duration(seconds: 60));
      final text = await resp.transform(utf8.decoder).join();
      return _HttpResp(statusCode: resp.statusCode, body: text);
    } finally {
      client.close(force: true);
    }
  }

  Future<_HttpResp> _patch(
    String path,
    Map<String, Object?> body, {
    required String key,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.patchUrl(Uri.parse('$apiUrl$path'));
      req.headers.set('apikey', key);
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close().timeout(const Duration(seconds: 60));
      final text = await resp.transform(utf8.decoder).join();
      return _HttpResp(statusCode: resp.statusCode, body: text);
    } finally {
      client.close(force: true);
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
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$apiUrl/rest/v1/rpc/$name'));
      req.headers.set('apikey', serviceKey);
      req.headers.set('Authorization', 'Bearer $serviceKey');
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(jsonEncode(params)));
      final resp = await req.close().timeout(const Duration(seconds: 90));
      final text = await resp.transform(utf8.decoder).join();
      return _HttpResp(statusCode: resp.statusCode, body: text);
    } finally {
      client.close(force: true);
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
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$apiUrl/rest/v1/rpc/$name'));
      req.headers.set('apikey', anonKey);
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(jsonEncode(params)));
      final resp = await req.close().timeout(const Duration(seconds: 90));
      final text = await resp.transform(utf8.decoder).join();
      return _HttpResp(statusCode: resp.statusCode, body: text);
    } finally {
      client.close(force: true);
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
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse(
          '$apiUrl/rest/v1/rpc/materialise_athlete_plan_from_enrolment',
        ),
      );
      req.headers.set('apikey', anonKey);
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('Content-Type', 'application/json');
      req.add(
        utf8.encode(
          jsonEncode({
            'p_programme_assignment_id': programmeAssignmentId,
            'p_timezone': 'UTC',
          }),
        ),
      );
      final resp = await req.close().timeout(const Duration(seconds: 90));
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        return JourneyDLiveStageOutcome.failed(
          'materialise_http_${resp.statusCode}',
        );
      }
      final map = jsonDecode(text);
      if (map is! Map) {
        return JourneyDLiveStageOutcome.unknown('materialise_ambiguous');
      }
      final status = map['status']?.toString();
      if (status != 'materialised' && status != 'already_materialised') {
        return JourneyDLiveStageOutcome.failed('materialise_status:$status');
      }
      return JourneyDLiveStageOutcome.applied(detail: 'materialised');
    } finally {
      client.close(force: true);
    }
  }
}

class _HttpResp {
  const _HttpResp({
    required this.statusCode,
    required this.body,
    this.contentRange,
  });
  final int statusCode;
  final String body;
  final String? contentRange;
}
