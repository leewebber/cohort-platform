import 'dart:convert';

import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_supabase_store.dart';
import 'package:cohort_platform/data/repositories/programme_version_supabase_store.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_schema.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'journey_d_bounded_http.dart';
import 'journey_d_execute_workflow.dart';
import 'journey_d_fixture_identity.dart';

/// Hosted ports for Journey D execute (Cohort Staging only).
class HostedJourneyDExecutePorts implements JourneyDExecutePorts {
  HostedJourneyDExecutePorts({
    required this.apiUrl,
    required this.serviceKey,
    required this.anonKey,
    AthleteProgrammeSessionPrepareService? prepareService,
  }) : _prepareOverride = prepareService;

  final String apiUrl;
  final String serviceKey;
  final String anonKey;
  final AthleteProgrammeSessionPrepareService? _prepareOverride;
  AthleteProgrammeSessionPrepareService? _prepare;

  AthleteProgrammeSessionPrepareService get prepareService {
    return _prepare ??=
        _prepareOverride ??
        AthleteProgrammeSessionPrepareService(
          assignmentStore: const ProgrammeAssignmentSupabaseStore(),
          slotResolver: const AthleteProgrammeAuthoredSlotResolver(
            versionStore: ProgrammeVersionSupabaseStore(),
          ),
          sessionLoader: SessionExecutionLoader(),
          localRepository: AthleteLocalRepository(InMemoryKvStore()),
        );
  }

  @override
  Future<JourneyDFixtureResolution> resolveFixture({
    required String marker,
    required String athleteId,
    required String assignmentId,
    required String versionId,
  }) async {
    // Auth stores emails lowercased — filter/compare with normalized form.
    final email = journeyDNormalizedFixtureEmail(marker);
    final users = await _getJson(
      // GoTrue admin listUsers filters via `filter`, not `email`.
      '/auth/v1/admin/users?filter=${Uri.encodeComponent(email)}',
      key: serviceKey,
      requirePredicate: marker.toLowerCase(),
    );
    final list = _asList(users);
    final exact = [
      for (final u in list)
        if ((u['email'] ?? '').toString().trim().toLowerCase() == email) u,
    ];
    if (exact.isEmpty) {
      throw JourneyDExecuteAmbiguity('fixture_identity_missing');
    }
    if (exact.length > 1) {
      throw JourneyDExecuteAmbiguity('fixture_identity_duplicate');
    }
    final uid = exact.first['id']?.toString() ?? '';
    if (uid != athleteId) {
      throw JourneyDExecuteAmbiguity('fixture_identity_mismatch');
    }

    final assigns = await _getJson(
      '/rest/v1/programme_assignments?select=id,programme_version_id,athlete_id'
      '&athlete_id=eq.${Uri.encodeComponent(athleteId)}'
      '&programme_version_id=eq.${Uri.encodeComponent(versionId)}',
      key: serviceKey,
      requirePredicate: 'athlete_id=eq.$athleteId',
      preferCount: true,
    );
    final assignList = _asList(assigns);
    if (assignList.length != 1) {
      throw JourneyDExecuteAmbiguity(
        assignList.isEmpty
            ? 'fixture_assignment_missing'
            : 'fixture_assignment_ambiguous',
      );
    }
    final aid = assignList.first['id']?.toString() ?? '';
    if (aid != assignmentId) {
      throw JourneyDExecuteAmbiguity('fixture_assignment_mismatch');
    }

    // Canonical occurrence schema: assignment_id + protocol_id + authored order.
    final occ = await _getJson(
      '/rest/v1/programme_schedule_occurrences'
      '?select=id,protocol_id,week_number,day_key,session_order,programmed_session_key'
      '&assignment_id=eq.${Uri.encodeComponent(assignmentId)}',
      key: serviceKey,
      requirePredicate: 'assignment_id=eq.$assignmentId',
      preferCount: true,
    );
    final occList = _asList(occ);
    if (occList.length != 2) {
      throw JourneyDExecuteAmbiguity(
        occList.isEmpty
            ? 'fixture_occurrences_missing'
            : 'fixture_occurrences_ambiguous',
      );
    }
    final protocols = [
      for (final o in occList) (o['protocol_id'] ?? '').toString(),
    ];
    if (!protocols.contains(kJourneyDIntendedProtocolId) ||
        !protocols.contains(kJourneyDLaterProtocolId)) {
      throw JourneyDExecuteAmbiguity('fixture_occurrence_keys_unexpected');
    }

    return JourneyDFixtureResolution(
      marker: marker,
      athleteId: athleteId,
      assignmentId: assignmentId,
      versionId: versionId,
      intendedOccurrenceKey: kJourneyDIntendedSessionKey,
      laterOccurrenceKey: kJourneyDLaterSessionKey,
    );
  }

  @override
  Future<void> authenticate({
    required String email,
    required String password,
    required String expectedAthleteId,
  }) async {
    final client = Supabase.instance.client;
    final auth = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (auth.session == null || auth.user?.id != expectedAthleteId) {
      throw StateError('athlete_auth_failed');
    }
    final profileRow = await client
        .from('profiles')
        .select()
        .eq('id', expectedAthleteId)
        .single();
    final profile = UserProfile.fromMap(
      Map<String, dynamic>.from(profileRow as Map),
    );
    CurrentUserSession.bind(profile);
  }

  @override
  Future<JourneyDPreparedOccurrence> prepareIntended({
    required String athleteId,
  }) async {
    final prepared = await prepareService.prepareForAthlete(athleteId);
    if (!prepared.isReady ||
        prepared.package == null ||
        prepared.executionContext == null) {
      throw JourneyDExecuteAmbiguity('prepared_session_not_ready');
    }
    return JourneyDPreparedOccurrence(
      package: prepared.package!,
      executionContext: prepared.executionContext!,
      sessionKey: prepared.package!.programmedSessionKey.value,
    );
  }

  @override
  Future<List<PlanPackageAdaptationPermission>> loadPermissions({
    required String versionId,
  }) async {
    final rows = await _getJson(
      '/rest/v1/programme_version_adaptation_permissions'
      '?select=permission_key,change_kind,target_ref,athlete_agreement_required,scope_note'
      '&version_id=eq.${Uri.encodeComponent(versionId)}',
      key: serviceKey,
      requirePredicate: 'version_id=eq.$versionId',
    );
    final list = _asList(rows);
    final out = <PlanPackageAdaptationPermission>[];
    for (final row in list) {
      final kindRaw = row['change_kind']?.toString() ?? '';
      final kind = PlanPackageSchema.adaptationKindFromYaml(kindRaw);
      if (kind == null) continue;
      out.add(
        PlanPackageAdaptationPermission(
          id: row['permission_key']?.toString() ?? kindRaw,
          changeKind: kind,
          targetRef: row['target_ref']?.toString() ?? 'programme',
          athleteAgreementRequired: row['athlete_agreement_required'] == true,
          scopeNote: row['scope_note']?.toString(),
        ),
      );
    }
    return out;
  }

  @override
  Future<bool> laterPushUpIntact({
    required String marker,
    required String assignmentId,
  }) async {
    // Programme source protocol must still reference push_up for LATER.
    final protocols = await _getJson(
      '/rest/v1/performance_protocols?select=protocol_id,id,session_lineage_id'
      '&protocol_id=eq.${Uri.encodeComponent(kJourneyDLaterProtocolId)}',
      key: serviceKey,
      requirePredicate: 'protocol_id=eq.$kJourneyDLaterProtocolId',
    );
    final plist = _asList(protocols);
    if (plist.length != 1) return false;
    final sessionId =
        plist.first['id']?.toString() ??
        plist.first['protocol_id']?.toString() ??
        '';
    // session_blocks.session_id references protocol identity used at publish.
    final blocks = await _getJson(
      '/rest/v1/session_blocks?select=block_id,session_id'
      '&session_id=eq.${Uri.encodeComponent(sessionId)}',
      key: serviceKey,
      requirePredicate: 'session_id=eq.$sessionId',
    );
    var blockList = _asList(blocks);
    if (blockList.isEmpty) {
      // Fallback: session_id may equal protocol_id string.
      final blocks2 = await _getJson(
        '/rest/v1/session_blocks?select=block_id,session_id'
        '&session_id=eq.${Uri.encodeComponent(kJourneyDLaterProtocolId)}',
        key: serviceKey,
        requirePredicate: 'session_id=eq.$kJourneyDLaterProtocolId',
      );
      blockList = _asList(blocks2);
    }
    if (blockList.isEmpty) {
      // Soft check: exercises jsonb on protocol row if present in OpenAPI.
      final full = await _getJson(
        '/rest/v1/performance_protocols?select=protocol_id,exercises,main_session'
        '&protocol_id=eq.${Uri.encodeComponent(kJourneyDLaterProtocolId)}',
        key: serviceKey,
        requirePredicate: 'protocol_id=eq.$kJourneyDLaterProtocolId',
      );
      final blob = jsonEncode(full);
      return blob.contains(kJourneyDLaterExerciseId) ||
          blob.contains('push_up');
    }
    for (final b in blockList) {
      final bid = b['block_id']?.toString() ?? '';
      if (bid.isEmpty) continue;
      final links = await _getJson(
        '/rest/v1/session_block_exercises?select=exercise_id'
        '&block_id=eq.${Uri.encodeComponent(bid)}',
        key: serviceKey,
        requirePredicate: 'block_id=eq.$bid',
      );
      for (final link in _asList(links)) {
        final eid = link['exercise_id']?.toString() ?? '';
        if (eid == kJourneyDLaterExerciseId || eid.endsWith('push_up')) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<void> recordExecutionEvidence({
    required JourneyDExecuteEvidence evidence,
  }) async {
    // Merge non-secret Journey D execution metadata onto Auth user.
    final getUser = await _getJson(
      '/auth/v1/admin/users/${evidence.athleteId}',
      key: serviceKey,
      requirePredicate: evidence.athleteId,
    );
    if (getUser is! Map) {
      throw StateError('evidence_user_lookup_failed');
    }
    final existingMeta = Map<String, dynamic>.from(
      (getUser['user_metadata'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          const {},
    );
    if ((existingMeta['run_id']?.toString() ?? '') != evidence.marker &&
        (existingMeta['run_id']?.toString() ?? '').isNotEmpty) {
      throw JourneyDExecuteAmbiguity('evidence_marker_mismatch');
    }
    if (existingMeta['journey_d_execution_count'] == 1) {
      throw JourneyDExecuteAmbiguity('journey_d_already_recorded');
    }
    existingMeta.addAll(evidence.toMetadata());
    final resp = await _putJson(
      '/auth/v1/admin/users/${evidence.athleteId}',
      {'user_metadata': existingMeta},
      key: serviceKey,
    );
    if (resp.statusCode != 200) {
      throw StateError('evidence_write_http_${resp.statusCode}');
    }
  }

  Future<Object?> _getJson(
    String path, {
    required String key,
    required String requirePredicate,
    bool preferCount = false,
  }) async {
    if (!path.contains(requirePredicate) &&
        !path.contains(Uri.encodeComponent(requirePredicate))) {
      throw StateError('query_not_predicate_bound');
    }
    final resp = await JourneyDBoundedHttp(
      defaultTimeout: const Duration(seconds: 60),
    ).get(
      Uri.parse('$apiUrl$path'),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
        if (preferCount) 'Prefer': 'count=exact',
      },
    );
    if (resp.statusCode != 200) {
      throw StateError('http_${resp.statusCode}');
    }
    return jsonDecode(resp.body);
  }

  Future<_HttpResp> _putJson(
    String path,
    Map<String, Object?> body, {
    required String key,
  }) async {
    final resp = await JourneyDBoundedHttp(
      defaultTimeout: const Duration(seconds: 60),
    ).put(
      Uri.parse('$apiUrl$path'),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    return _HttpResp(statusCode: resp.statusCode, body: resp.body);
  }

  List<Map<String, dynamic>> _asList(Object? body) {
    if (body is List) {
      return [
        for (final e in body)
          if (e is Map) e.map((k, v) => MapEntry(k.toString(), v)),
      ];
    }
    if (body is Map && body['users'] is List) {
      return _asList(body['users']);
    }
    return const [];
  }
}

class _HttpResp {
  _HttpResp({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}
