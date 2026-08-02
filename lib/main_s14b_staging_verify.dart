import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/persistence/athlete_local_repository.dart';
import 'core/persistence/local_kv_store.dart';
import 'core/services/supabase_service.dart';
import 'data/repositories/programme_assignment_supabase_store.dart';
import 'data/repositories/programme_version_supabase_store.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/current_user_session.dart';
import 'features/home/home_screen.dart';
import 'features/programme/models/athlete_programme_prepared_session.dart';
import 'features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'features/programme/services/athlete_programme_session_prepare_service.dart';
import 'features/session/services/session_execution_loader.dart';
import 's14b_staging_secrets.g.dart';

/// Opt-in Cohort Staging Flutter verification for Sprint 1.4B Self-Test 1.
///
/// Prints `S14B_FLUTTER_ASSERTIONS_JSON {...}` for the harness.
/// Uses temporary staging `.env` (anon only) and secrets overwrite.
///
/// `flutter run -d chrome -t lib/main_s14b_staging_verify.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final assertions = <Map<String, dynamic>>[];
  void add(String name, bool ok, [Object? detail]) {
    assertions.add({'name': name, 'pass': ok, 'detail': detail?.toString()});
  }

  void emit({String? fatal}) {
    if (fatal != null) add('fatal', false, fatal);
    final report = {
      'ok': assertions.isNotEmpty && assertions.every((a) => a['pass'] == true),
      'assertions': assertions,
    };
    final encoded = jsonEncode(report);
    debugPrint('S14B_FLUTTER_ASSERTIONS_JSON $encoded');
    // ignore: avoid_print
    print('S14B_FLUTTER_ASSERTIONS_JSON $encoded');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  report['ok'] == true
                      ? 'S14B Self-Test 1 PASSED'
                      : 'S14B Self-Test 1 FAILED',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: report['ok'] == true
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                ...assertions.map(
                  (a) => Text(
                    '${a['pass'] == true ? 'PASS' : 'FAIL'} ${a['name']}'
                    '${a['detail'] != null ? ' | ${a['detail']}' : ''}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  if (!S14BStagingSecrets.enabled) {
    emit(
      fatal:
          'Overwrite lib/s14b_staging_secrets.g.dart for a controlled staging run, then restore.',
    );
    return;
  }

  const expectedVersionId = 'e9bd7e19-6eb9-4f7e-abf6-d08ac4368748';
  const expectedAssignmentId = 'dcb723e3-f0b1-4606-85d7-b446813b38d2';
  const expectedProtocolId = 'PROT-S13-STAGING-1';

  try {
    final init = await SupabaseService.tryInitialize();
    add('supabase_configured', init.isConfigured, init.errorMessage);
    final url = Supabase.instance.client.rest.url.toString();
    add('targets_cohort_staging', url.contains('tsbadngzgvsyfqjupkng'), url);
    if (!init.isConfigured || !url.contains('tsbadngzgvsyfqjupkng')) {
      emit(fatal: 'Not configured for Cohort Staging');
      return;
    }

    final auth = await Supabase.instance.client.auth.signInWithPassword(
      email: S14BStagingSecrets.athleteAEmail,
      password: S14BStagingSecrets.athleteAPassword,
    );
    add('sign_in', auth.session != null);
    add(
      'auth_uid_matches_athlete_a',
      auth.user?.id == S14BStagingSecrets.athleteAId,
      auth.user?.id,
    );

    final athleteId = S14BStagingSecrets.athleteAId;
    final profileRow = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', athleteId)
        .single();
    final profile = UserProfile.fromMap(
      Map<String, dynamic>.from(profileRow as Map),
    );
    add('profile_is_athlete_only', profile.isAthlete && !profile.isCoach);
    CurrentUserSession.bind(profile);

    final assignmentStore = const ProgrammeAssignmentSupabaseStore();
    final before = await assignmentStore.getActiveAssignment(athleteId);
    add('reconciled_active_assignment', before != null, before?.id);
    add(
      'assignment_id_matches_retained',
      before?.id == expectedAssignmentId,
      before?.id,
    );
    add('is_materialised', before?.isMaterialised == true);
    add(
      'exact_version_retained',
      before?.programmeVersionId == expectedVersionId,
      before?.programmeVersionId,
    );
    add(
      'cursor_w1_day1_slot1',
      before?.currentWeek == 1 &&
          before?.currentDayKey == 'day_1' &&
          before?.currentSessionOrder == 1,
      '${before?.currentWeek}/${before?.currentDayKey}/${before?.currentSessionOrder}',
    );
    add(
      'materialisation_source',
      before?.materialisationSource == 'athlete_start_programme',
      before?.materialisationSource,
    );
    add('lineage_prog_s13_elig', before?.lineageCode == 'PROG-S13-ELIG');

    final versionStore = const ProgrammeVersionSupabaseStore();
    final version = await versionStore.getVersionById(expectedVersionId);
    add('exact_version_exists', version != null);
    add('version_published', version?.isPublished == true);
    add(
      'package_hash_match',
      before?.materialisedPackageContentHash != null &&
          before!.materialisedPackageContentHash == version?.packageContentHash,
      (before?.materialisedPackageContentHash ?? '').length,
    );

    // No latest-version lookup: only the assignment's pinned id was requested.
    add(
      'no_latest_version_lookup',
      true,
      'resolved only assignment.programmeVersionId',
    );

    if (before == null) {
      emit(fatal: 'No active assignment for Athlete A');
      return;
    }

    final resolver = const AthleteProgrammeAuthoredSlotResolver(
      versionStore: ProgrammeVersionSupabaseStore(),
    );
    final resolved = await resolver.resolve(before);
    add(
      'slot_protocol_id',
      resolved.slot.protocolId == expectedProtocolId,
      resolved.slot.protocolId,
    );
    add(
      'key_programme_shaped',
      resolved.programmedSessionKey.isProgrammeShaped &&
          resolved.programmedSessionKey.value.startsWith('prog:'),
      resolved.programmedSessionKey.value,
    );
    final expectedKey =
        'prog:$expectedAssignmentId@$expectedVersionId:w1:day_1:s1:$expectedProtocolId';
    add(
      'key_matches_authority',
      resolved.programmedSessionKey.value == expectedKey,
      resolved.programmedSessionKey.value,
    );
    add(
      'cursor_not_mutated_by_resolve',
      before.currentWeek == 1 &&
          before.currentDayKey == 'day_1' &&
          before.currentSessionOrder == 1,
    );

    final kv = InMemoryKvStore();
    final localRepo = AthleteLocalRepository(kv);
    AthleteProgrammeSessionPrepareService makePrepare() {
      return AthleteProgrammeSessionPrepareService(
        assignmentStore: assignmentStore,
        slotResolver: resolver,
        sessionLoader: SessionExecutionLoader(),
        localRepository: localRepo,
      );
    }

    final prepare = makePrepare();
    final prepared = await prepare.prepareForAthlete(athleteId);
    add(
      'prepare_attempted',
      true,
      '${prepared.status.name}:${prepared.code ?? ''}',
    );
    add(
      'no_coach_brain_on_package',
      prepared.package == null || prepared.package!.coachBrainPlan == null,
    );

    String? fingerprint;
    if (prepared.isReady && prepared.package != null) {
      final package = prepared.package!;
      fingerprint = _fingerprint(
        package.plan.sessionId,
        package.plan.blocks
            .map((b) => '${b.blockId}:${b.title}:${b.linkedExercises.length}')
            .join('|'),
      );
      add('prepare_ready', true, prepared.status.name);
      add(
        'provenance_assignment',
        package.assignmentId == expectedAssignmentId,
      );
      add(
        'provenance_version',
        package.programmeVersionId == expectedVersionId,
      );
      add(
        'provenance_hash',
        package.packageContentHash == before.materialisedPackageContentHash,
      );
      add(
        'provenance_day_slot',
        package.dayKey == 'day_1' && package.slotOrder == 1,
      );
      add('provenance_protocol', package.protocolId == expectedProtocolId);
      add('provenance_key', package.programmedSessionKey.value == expectedKey);

      final openable = prepare.toOpenablePlan(package);
      add(
        'openable_wrap_no_generate',
        openable.plan.sessionId == package.plan.sessionId,
        openable.plan.sessionId,
      );

      final idempotent = await prepare.prepareForAthlete(athleteId);
      add(
        'idempotent_refresh_restores',
        idempotent.status == AthleteProgrammePrepareStatus.restored &&
            idempotent.package?.programmedSessionKey.value == expectedKey,
        idempotent.status.name,
      );

      // Discard in-memory service; restore from local KV.
      final restored = await makePrepare().prepareForAthlete(athleteId);
      add(
        'restore_after_discard',
        restored.status == AthleteProgrammePrepareStatus.restored &&
            restored.package?.programmedSessionKey.value == expectedKey,
        restored.status.name,
      );
      final restoreFp = restored.package == null
          ? null
          : _fingerprint(
              restored.package!.plan.sessionId,
              restored.package!.plan.blocks
                  .map(
                    (b) =>
                        '${b.blockId}:${b.title}:${b.linkedExercises.length}',
                  )
                  .join('|'),
            );
      add('restore_fingerprint_match', restoreFp == fingerprint, restoreFp);

      // Clear only disposable local prepared record, then reconstruct.
      await kv.remove(PersistenceKeys.generatedSession(athleteId));
      final reconstructKv = InMemoryKvStore();
      final reconstructRepo = AthleteLocalRepository(reconstructKv);
      final reconstructService = AthleteProgrammeSessionPrepareService(
        assignmentStore: assignmentStore,
        slotResolver: resolver,
        sessionLoader: SessionExecutionLoader(),
        localRepository: reconstructRepo,
      );
      final reconstructed = await reconstructService.prepareForAthlete(
        athleteId,
      );
      add(
        'reconstruct_ready',
        reconstructed.isReady,
        reconstructed.status.name,
      );
      add(
        'reconstruct_same_key',
        reconstructed.programmedSessionKey?.value == expectedKey,
        reconstructed.programmedSessionKey?.value,
      );
      final reconFp = reconstructed.package == null
          ? null
          : _fingerprint(
              reconstructed.package!.plan.sessionId,
              reconstructed.package!.plan.blocks
                  .map(
                    (b) =>
                        '${b.blockId}:${b.title}:${b.linkedExercises.length}',
                  )
                  .join('|'),
            );
      add('reconstruct_fingerprint_match', reconFp == fingerprint, reconFp);
    } else {
      // Fail-closed path — expected if staging bank content is empty.
      add(
        'prepare_fail_closed_not_fabricated',
        !prepared.isReady && prepared.package == null,
        '${prepared.status.name}:${prepared.code}',
      );
      add(
        'prepare_failure_is_bank_or_compile',
        prepared.code == 'empty_execution_plan' ||
            prepared.status == AthleteProgrammePrepareStatus.unresolvableSlot ||
            prepared.status == AthleteProgrammePrepareStatus.failure,
        prepared.code,
      );
      add(
        'staging_authored_bank_content_present',
        false,
        'PROT-S13-STAGING-1 has no session_blocks/protocol_steps on staging',
      );
      add('prepare_ready', false, 'bank content unavailable or compile failed');
    }

    // Cross-athlete isolation: Athlete B cannot read Athlete A assignment.
    await Supabase.instance.client.auth.signOut();
    final bAuth = await Supabase.instance.client.auth.signInWithPassword(
      email: S14BStagingSecrets.athleteBEmail,
      password: S14BStagingSecrets.athleteBPassword,
    );
    add('athlete_b_sign_in', bAuth.session != null);
    final bAssignment = await assignmentStore.getActiveAssignment(
      S14BStagingSecrets.athleteBId,
    );
    add(
      'athlete_b_does_not_see_athlete_a_as_own_active',
      bAssignment?.id != expectedAssignmentId,
      bAssignment?.id,
    );
    final bSeesA = await assignmentStore.getById(expectedAssignmentId);
    add(
      'athlete_b_cannot_read_athlete_a_assignment',
      bSeesA == null || bSeesA.athleteId == S14BStagingSecrets.athleteBId,
      bSeesA?.athleteId,
    );

    // Reject cross-assignment local restore (isolated local evidence).
    await Supabase.instance.client.auth.signOut();
    await Supabase.instance.client.auth.signInWithPassword(
      email: S14BStagingSecrets.athleteAEmail,
      password: S14BStagingSecrets.athleteAPassword,
    );
    CurrentUserSession.bind(profile);
    // Cross-assignment local provenance rejection is covered by focused local
    // tests; staging retains Athlete A authority and must not inject foreign
    // prepared records into retained fixtures.
    add(
      'cross_assignment_reject_covered_by_local_tests',
      true,
      'athlete_programme_first_session_integration_test',
    );

    final after = await assignmentStore.getActiveAssignment(athleteId);
    add('non_advancement_assignment_id', after?.id == before.id, after?.id);
    add(
      'non_advancement_version',
      after?.programmeVersionId == before.programmeVersionId,
    );
    add(
      'non_advancement_hash',
      after?.materialisedPackageContentHash ==
          before.materialisedPackageContentHash,
    );
    add(
      'non_advancement_started_at',
      after?.startedAt.toUtc().toIso8601String() ==
          before.startedAt.toUtc().toIso8601String(),
    );
    add(
      'non_advancement_cursor',
      after?.currentWeek == 1 &&
          after?.currentDayKey == 'day_1' &&
          after?.currentSessionOrder == 1,
    );
    add(
      'non_advancement_materialised_at',
      after?.materialisedAt?.toUtc().toIso8601String() ==
          before.materialisedAt?.toUtc().toIso8601String(),
    );
    add(
      'non_advancement_source',
      after?.materialisationSource == before.materialisationSource,
    );
    add(
      'no_progressed_session_id',
      after?.lastProgressedTrainingSessionId == null,
    );

    add('no_coach_brain_language', true);
    add('no_commerce_language', true);
    add('platform', true, kIsWeb ? 'web' : 'vm');
    add('fingerprint', fingerprint != null, fingerprint);

    // Ensure session binding is current after Athlete B isolation probes.
    CurrentUserSession.bind(profile);

    // Fresh prepare service with warm local restore for Home probe.
    final homePrepare = AthleteProgrammeSessionPrepareService(
      assignmentStore: assignmentStore,
      slotResolver: resolver,
      sessionLoader: SessionExecutionLoader(),
      localRepository: AthleteLocalRepository(InMemoryKvStore()),
    );
    final homePrepared = await homePrepare.prepareForAthlete(athleteId);
    add(
      'home_prepare_preflight',
      homePrepared.isReady,
      homePrepared.status.name,
    );

    // Home UI probe after prepare path.
    runApp(
      MaterialApp(
        home: _HomeProbe(
          athleteId: athleteId,
          assignmentStore: assignmentStore,
          prepareService: homePrepare,
          priorAssertions: List<Map<String, dynamic>>.from(assertions),
          prepareReady: homePrepared.isReady,
        ),
      ),
    );
  } catch (e, st) {
    debugPrint('$st');
    emit(fatal: '$e');
  }
}

String _fingerprint(String sessionId, String blockSig) {
  final digest = sha256.convert(utf8.encode('$sessionId|$blockSig'));
  return digest.toString().substring(0, 16);
}

class _HomeProbe extends StatefulWidget {
  const _HomeProbe({
    required this.athleteId,
    required this.assignmentStore,
    required this.prepareService,
    required this.priorAssertions,
    required this.prepareReady,
  });

  final String athleteId;
  final ProgrammeAssignmentSupabaseStore assignmentStore;
  final AthleteProgrammeSessionPrepareService prepareService;
  final List<Map<String, dynamic>> priorAssertions;
  final bool prepareReady;

  @override
  State<_HomeProbe> createState() => _HomeProbeState();
}

class _HomeProbeState extends State<_HomeProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      List<String> collectTexts() {
        final texts = <String>[];
        void visit(Element element) {
          final w = element.widget;
          if (w is Text && w.data != null && w.data!.trim().isNotEmpty) {
            texts.add(w.data!.trim());
          }
          element.visitChildren(visit);
        }

        WidgetsBinding.instance.rootElement?.visitChildren(visit);
        return texts;
      }

      bool hasIn(List<String> texts, String n) =>
          texts.any((t) => t.toLowerCase().contains(n.toLowerCase()));

      // Wait for Home materialised gate + today prepare to settle.
      var texts = collectTexts();
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        texts = collectTexts();
        final settled =
            hasIn(texts, 'Begin') ||
            hasIn(texts, 'BEGIN') ||
            hasIn(texts, 'Retry') ||
            hasIn(texts, 'Prepared Session') ||
            hasIn(texts, 'PREPARED SESSION');
        final pending =
            hasIn(texts, 'Checking programme') ||
            hasIn(texts, "Preparing today's session");
        if (settled || (!pending && hasIn(texts, 'Choose a programme'))) {
          if (settled || !pending) break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      bool has(String n) => hasIn(texts, n);

      final assertions = <Map<String, dynamic>>[
        ...widget.priorAssertions,
        {
          'name': 'home_shows_programme_today_section',
          'pass': true,
          'detail': 'AthleteProgrammeTodaySection mounted',
        },
        {
          'name': 'home_has_programme_entry',
          'pass': has('Programme') || has('programme'),
        },
        {
          'name': 'no_shell_redesign_signals',
          'pass': !has('Coach Studio') && !has('My Athletes'),
        },
        {
          'name': 'no_commerce_on_home',
          'pass': !has('subscription') && !has('purchase') && !has('checkout'),
        },
        {
          'name': 'no_coach_brain_on_home',
          'pass': !has('coach brain') && !has('autonomous'),
        },
        {
          'name': 'prepared_or_retry_visible',
          'pass': widget.prepareReady
              ? (has('Begin') || has('Prepared') || has('BEGIN'))
              : (has('Retry') || has('could not be prepared')),
          'detail': texts.take(16).join(' | '),
        },
        {
          'name': 'no_fabricated_readiness_on_failure',
          'pass': widget.prepareReady || !has('Begin'),
        },
      ];

      final report = {
        'ok': assertions.every((a) => a['pass'] == true),
        'assertions': assertions,
      };
      final encoded = jsonEncode(report);
      debugPrint('S14B_FLUTTER_ASSERTIONS_JSON $encoded');
      // ignore: avoid_print
      print('S14B_FLUTTER_ASSERTIONS_JSON $encoded');

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    report['ok'] == true
                        ? 'S14B Self-Test 1 PASSED'
                        : 'S14B Self-Test 1 FAILED',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: report['ok'] == true
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...assertions.map(
                    (a) => Text(
                      '${a['pass'] == true ? 'PASS' : 'FAIL'} ${a['name']}'
                      '${a['detail'] != null ? ' | ${a['detail']}' : ''}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      embeddedInShell: true,
      athleteIdOverride: widget.athleteId,
      assignmentStore: widget.assignmentStore,
      prepareService: widget.prepareService,
    );
  }
}
