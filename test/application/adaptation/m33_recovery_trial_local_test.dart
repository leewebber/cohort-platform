// Opt-in authenticated verification. The runner creates and removes the stack.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cohort_platform/application/adaptation/approved_recovery_option.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_acceptance_service.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_permission_reader.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_proposal_service.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/core/widgets/programme_adaptation_proposal_sheet.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_supabase_store.dart';
import 'package:cohort_platform/data/repositories/programme_version_supabase_store.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/models/user_role.dart';
import 'package:cohort_platform/features/auth/repositories/supabase_profile_repository.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/repositories/supabase_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_supabase_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_supabase_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/recovery_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _version = '7e1d15e7-20ee-46d4-b5e9-0d6449010330';
const _protocol = 'protocol-7e1d15e7-20ee-46d4-b5e9-0d6449010334';
const _timeVersion = 'd0576566-e080-4e6f-9428-6bb10d82826a';
const _approvals = 'programme_strength_recovery_approvals';
const _issue = 'approve_private_strength_recovery_option_v1';
const _read = 'read_my_approved_recovery_option_v1';

const _timeHistoryDigest =
    '''
WITH assignments AS (
  SELECT a.* FROM public.programme_assignments a WHERE a.programme_version_id = '$_timeVersion'
    AND EXISTS (SELECT FROM public.training_session_records r WHERE r.assignment_id = a.id
      AND r.status IN ('completed', 'partially_completed'))
), records AS (
  SELECT r.* FROM public.training_session_records r JOIN assignments a ON a.id = r.assignment_id
), blocks AS (
  SELECT b.* FROM public.training_block_results b JOIN records r ON r.record_id = b.session_record_id
), exercises AS (
  SELECT e.* FROM public.training_exercise_results e JOIN blocks b USING (block_result_id)
)
SELECT jsonb_build_object(
  'completed', (SELECT count(*) FROM records WHERE status = 'completed'),
  'digest', encode(extensions.digest(jsonb_build_array(
    (SELECT jsonb_agg(a ORDER BY id) FROM assignments a),
    (SELECT jsonb_agg(r ORDER BY record_id) FROM records r),
    (SELECT jsonb_agg(b ORDER BY block_result_id) FROM blocks b),
    (SELECT jsonb_agg(e ORDER BY exercise_result_id) FROM exercises e),
    (SELECT jsonb_agg(s ORDER BY set_result_id) FROM public.training_set_results s JOIN exercises e USING(exercise_result_id)),
    (SELECT jsonb_agg(o ORDER BY o.id) FROM public.programme_slot_outcomes o JOIN assignments a ON a.id = o.assignment_id),
    (SELECT to_jsonb(t) FROM public.programme_strength_time_approvals t WHERE version_id = '$_timeVersion'),
    (SELECT to_jsonb(p) FROM public.programme_publication_artifacts p WHERE programme_version_id = '$_timeVersion')
  )::text, 'sha256'), 'hex')
);
''';

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  final configFile = Platform.environment['M33_LOCAL_CONFIG'];
  testWidgets(
    'Recovery approval and execution through authenticated Supabase',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final journey = (await tester.runAsync(() async {
        final config = jsonDecode(File(configFile!).readAsStringSync()) as Map;
        final api = Uri.parse(config['API_URL'] as String);
        expect(api.scheme, 'http');
        expect(api.host, '127.0.0.1');
        final container = config['CONTAINER'] as String;
        expect(container, matches(r'^supabase_db_s12g[0-9a-f]+$'));
        final exact = await Process.run('docker', [
          'inspect',
          '-f',
          '{{.Name}}',
          container,
        ]);
        expect(exact.exitCode, 0);
        expect((exact.stdout as String).trim(), '/$container');
        Future<String> sql(String statement) async {
          final result = await Process.run('docker', [
            'exec',
            container,
            'psql',
            '-X',
            '-U',
            'postgres',
            '-d',
            'postgres',
            '-qAt',
            '-v',
            'ON_ERROR_STOP=1',
            '-c',
            statement,
          ]);
          expect(result.exitCode, 0, reason: result.stderr.toString());
          return (result.stdout as String).trim();
        }

        SharedPreferences.setMockInitialValues({});
        final anonKey = config['ANON_KEY'] as String;
        IOClient loopback() {
          final http = HttpOverrides.runWithHttpOverrides(
            () => IOClient(HttpClient()),
            _LoopbackHttpOverrides(),
          );
          addTearDown(http.close);
          return http;
        }

        SupabaseClient localClient(String key) {
          final result = SupabaseClient(
            api.toString(),
            key,
            httpClient: loopback(),
            authOptions: const AuthClientOptions(
              autoRefreshToken: false,
              authFlowType: AuthFlowType.implicit,
            ),
          );
          addTearDown(result.dispose);
          return result;
        }

        await Supabase.initialize(
          url: api.toString(),
          publishableKey: anonKey,
          httpClient: loopback(),
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
          ),
        );
        addTearDown(Supabase.instance.dispose);
        final client = Supabase.instance.client;
        final stranger = localClient(anonKey);
        final anonymous = localClient(anonKey);
        final publisher = localClient(config['SERVICE_ROLE_KEY'] as String);
        Future<UserProfile> register(SupabaseClient actor) async {
          final suffix = Random.secure().nextInt(1 << 32);
          final response = await actor.auth.signUp(
            email: 'recovery-local-$suffix@example.com',
            password: 'Local-only-$suffix-aA!',
            data: {
              'display_name': 'Disposable athlete',
              'roles': ['athlete'],
            },
          );
          expect(response.session, isNotNull);
          final uid = response.user!.id;
          expect(uid, matches(r'^[0-9a-f-]{36}$'));
          final profile =
              await ProfileProvisioningService(
                profileRepository: SupabaseProfileRepository(client: actor),
              ).provisionProfile(
                userId: uid,
                displayName: 'Disposable athlete',
                roles: {UserRole.athlete},
              );
          expect(profile.isAthlete, isTrue);
          expect(profile.isCoach, isFalse);
          return profile;
        }

        final profile = await register(client);
        final athleteId = profile.id;
        final strangerId = (await register(stranger)).id;
        final acquire = SupabaseAcquisitionStore(
          athleteId: athleteId,
          client: client,
        );
        final acquireTime = SupabaseAcquisitionStore(
          athleteId: strangerId,
          client: stranger,
        );
        await acquire.saveSetup('Asia/Makassar', complete: true);
        await acquireTime.saveSetup('Asia/Makassar', complete: true);
        final today = await sql(
          "SELECT (now() AT TIME ZONE 'Asia/Makassar')::date",
        );
        expect(today, matches(r'^\d{4}-\d{2}-\d{2}$'));

        final originalHistory = await sql(_timeHistoryDigest);
        expect(
          (jsonDecode(originalHistory) as Map)['completed'],
          greaterThan(0),
        );

        final payload =
            jsonDecode(
                  File(
                    Platform.environment['M33_LOCAL_PAYLOAD']!,
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        payload['owner_id'] = 'a3200000-0000-4000-8000-000000000001';
        Future<dynamic> publish() => publisher.rpc(
          'publish_private_exact_programme_version_retained_v1',
          params: {'payload': payload},
        );
        expect(await publish(), containsPair('status', 'published'));
        expect(await publish(), containsPair('status', 'already_published'));
        final seal =
            jsonDecode(
                  await sql("""
          SELECT jsonb_build_object(
            'slot', scope_seal_text::jsonb#>>'{slots,0,slot_id}',
            'hash', scope_seal_hash,
            'matches_live', scope_seal_text::jsonb =
              public.cohort_tracking_scope_seal(programme_version_id, canonical_text::jsonb)
          ) FROM public.programme_publication_artifacts WHERE programme_version_id = '$_version';
        """),
                )
                as Map;
        expect(seal['matches_live'], isTrue);
        final slotId = seal['slot'] as String;
        final sealHash = seal['hash'] as String;
        expect(slotId, matches(r'^[0-9a-f-]{36}$'));
        expect(slotId, isNot('7e1d15e7-20ee-46d4-b5e9-0d6449010331'));

        // Local-only recipient grants. Publication and both acquisitions use
        // their normal RPCs, including normal UUID defaults.
        await sql("""
          INSERT INTO public.private_programme_alpha_eligibility(athlete_id,programme_version_id)
          VALUES ('$athleteId','$_version'), ('$strangerId','$_timeVersion'), ('$strangerId','$_version');
        """);
        final assignmentId = await acquire.acquire(
          _version,
          DateTime.parse(today),
        );
        expect(
          await acquire.acquire(_version, DateTime.parse(today)),
          assignmentId,
        );
        Future<Map<String, dynamic>> occurrenceFor(
          SupabaseClient actor,
          String assignment,
        ) => actor
            .from('programme_schedule_occurrences')
            .select()
            .eq('assignment_id', assignment)
            .single();
        final occurrenceRow = await occurrenceFor(client, assignmentId);
        final occurrenceId = occurrenceRow['id'] as String;
        expect(occurrenceId, matches(r'^[0-9a-f-]{36}$'));
        expect(occurrenceId, isNot('7e1d15e7-20ee-46d4-b5e9-0d6449010332'));
        expect(occurrenceRow['session_slot_id'], slotId);
        expect(occurrenceRow['protocol_id'], _protocol);
        Map<String, dynamic> issueFor(
          String athlete,
          String assignment,
          String occurrence,
        ) => {
          'p_version_id': _version,
          'p_athlete_id': athlete,
          'p_assignment_id': assignment,
          'p_slot_id': slotId,
          'p_occurrence_id': occurrence,
          'p_scheduled_date': today,
          'p_scope_seal_hash': sealHash,
        };
        final issueParams = issueFor(athleteId, assignmentId, occurrenceId);
        final timeAssignment = await acquireTime.acquire(
          _timeVersion,
          DateTime.parse(today),
        );
        final timeRow = await stranger
            .from('programme_schedule_occurrences')
            .select()
            .eq('assignment_id', timeAssignment)
            .single();
        final timeProtocol = timeRow['protocol_id'] as String;
        expect(
          await stranger.rpc(
            'read_my_approved_time_option_v1',
            params: {
              'p_assignment_id': timeAssignment,
              'p_version_id': _timeVersion,
              'p_occurrence_id': timeRow['id'],
              'p_slot_key': 'M32-W01-D01-STRENGTH',
            },
          ),
          isNotNull,
        );
        expect(
          await stranger.rpc(
            _read,
            params: {
              'p_assignment_id': timeAssignment,
              'p_version_id': _timeVersion,
              'p_slot_id': timeRow['session_slot_id'],
              'p_occurrence_id': timeRow['id'],
              'p_protocol_id': timeProtocol,
            },
          ),
          isNull,
        );
        expect(
          await publisher.rpc(
            _issue,
            params: {
              ...issueParams,
              'p_version_id': _timeVersion,
              'p_slot_id': timeRow['session_slot_id'],
              'p_occurrence_id': timeRow['id'],
            },
          ),
          'scope_mismatch',
        );
        await acquireTime.endProgramme(
          assignmentId: timeAssignment,
          programmeVersionId: _timeVersion,
        );
        final strangerAssignment = await acquireTime.acquire(
          _version,
          DateTime.parse(today),
        );
        final strangerOccurrence = await stranger
            .from('programme_schedule_occurrences')
            .select('id')
            .eq('assignment_id', strangerAssignment)
            .single();

        final params = {
          'p_version_id': _version,
          'p_slot_id': slotId,
          'p_occurrence_id': occurrenceId,
          'p_assignment_id': assignmentId,
          'p_protocol_id': _protocol,
        };
        Future<dynamic> read() async => client.rpc(_read, params: params);
        expect(await read(), isNull);
        for (final changed in [
          {'p_athlete_id': strangerId},
          {'p_slot_id': occurrenceId},
          {'p_scope_seal_hash': '0' * 64},
        ]) {
          expect(
            await publisher.rpc(_issue, params: {...issueParams, ...changed}),
            'scope_mismatch',
          );
        }
        Future<void> setWarmup(String content) => sql("""
          UPDATE public.session_blocks SET content = '$content'
          WHERE session_id = '$_protocol' AND position = 1;
        """);
        await setWarmup('Unreviewed drift');
        expect(
          await publisher.rpc(_issue, params: issueParams),
          'scope_mismatch',
        );
        await setWarmup('Five minutes of easy walking to warm up.');
        expect(await sql('SELECT count(*) FROM public.$_approvals'), '0');

        await _competeWithIssuance(
          container: container,
          sql: sql,
          athlete: strangerId,
          action:
              "public.end_my_fixed_programme('$strangerId', '$strangerAssignment', '$_version')",
          actionStatus: 'ok',
          issue: () => publisher.rpc(
            _issue,
            params: issueFor(
              strangerId,
              strangerAssignment,
              strangerOccurrence['id'] as String,
            ),
          ),
        );
        final startAssignment = await acquireTime.acquire(
          _version,
          DateTime.parse(today),
        );
        final startOccurrence =
            (await occurrenceFor(stranger, startAssignment))['id'] as String;
        await _competeWithIssuance(
          container: container,
          sql: sql,
          athlete: strangerId,
          action:
              "public.create_or_resume_fixed_programme_occurrence_session('$startOccurrence')",
          actionStatus: 'created',
          issue: () => publisher.rpc(
            _issue,
            params: issueFor(strangerId, startAssignment, startOccurrence),
          ),
        );
        expect(await sql('SELECT count(*) FROM public.$_approvals'), '0');

        final issued = await Future.wait([
          publisher.rpc(_issue, params: issueParams),
          publisher.rpc(_issue, params: issueParams),
        ]);
        expect(issued, unorderedEquals(['approved', 'already_approved']));
        expect(
          await publisher.rpc(
            _issue,
            params: {...issueParams, 'p_scope_seal_hash': '0' * 64},
          ),
          'approval_conflict',
        );
        expect(await sql('SELECT count(*) FROM public.$_approvals'), '1');
        expect(
          await publisher.rpc(_issue, params: issueParams),
          'already_approved',
        );
        final approved = (await read()) as Map;
        expect(approved, containsPair('athlete_id', athleteId));
        expect(approved, containsPair('scheduled_date', today));
        expect(approved, containsPair('omitted_block_position', 3));
        expect(
          approved,
          containsPair('omitted_block_id', approved['blocks'][2]['block_id']),
        );
        expect(approved['scope_seal_hash'], matches(r'^[0-9a-f]{64}$'));
        expect(await stranger.rpc(_read, params: params), isNull);
        expect(
          await stranger.rpc(
            _read,
            params: {
              ...params,
              'p_assignment_id': strangerAssignment,
              'p_occurrence_id': strangerOccurrence['id'],
            },
          ),
          isNull,
        );
        for (final mismatch in [
          {'p_assignment_id': strangerAssignment},
          {'p_version_id': _timeVersion},
          {'p_slot_id': occurrenceId},
          {'p_occurrence_id': strangerOccurrence['id']},
          {'p_protocol_id': timeProtocol},
        ]) {
          expect(
            await client.rpc(_read, params: {...params, ...mismatch}),
            isNull,
          );
        }

        final denied = throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        );
        await expectLater(anonymous.rpc(_read, params: params), denied);
        await expectLater(publisher.rpc(_read, params: params), denied);
        await expectLater(client.rpc(_issue, params: issueParams), denied);
        await expectLater(client.from(_approvals).select(), denied);
        await expectLater(
          client.from(_approvals).insert({
            'version_id': _version,
            'slot_id': slotId,
            'occurrence_id': occurrenceId,
            'scope': {},
          }),
          denied,
        );
        await expectLater(
          client
              .from(_approvals)
              .update({'scope': {}})
              .eq('version_id', _version),
          denied,
        );
        await expectLater(
          client.from(_approvals).delete().eq('version_id', _version),
          denied,
        );
        await expectLater(
          publisher
              .from(_approvals)
              .update({'scope': {}})
              .eq('version_id', _version),
          denied,
        );
        await sql("""
        DO \$\$
        BEGIN
          BEGIN
            UPDATE public.$_approvals SET scope = '{}' WHERE version_id = '$_version';
            RAISE EXCEPTION 'immutable trigger did not reject update';
          EXCEPTION WHEN integrity_constraint_violation THEN NULL;
          END;
        END \$\$;
        """);

        Future<void> schedule(String date) => sql("""
        -- Disposable-only control of the clock boundary; keep the write guard
        -- intact and use the real reader on each resulting state.
        BEGIN;
        SET LOCAL cohort.allow_schedule_write = 'on';
        UPDATE public.programme_schedule_occurrences SET scheduled_date = $date
        WHERE id = '$occurrenceId';
        COMMIT;
        """);
        for (final offset in [1, -1]) {
          await schedule("date '$today' + $offset");
          expect(await read(), isNull);
        }
        await schedule("date '$today'");
        // Prove the terminal state using the real End RPC under the athlete
        // role, then roll back the disposable branch so the same occurrence
        // remains available for the positive journey.
        await sql("""
          BEGIN;
          SET LOCAL ROLE authenticated;
          SET LOCAL "request.jwt.claim.sub" = '$athleteId';
          SET LOCAL "request.jwt.claims" = '{"sub":"$athleteId","role":"authenticated"}';
          DO \$\$
          BEGIN
            IF public.end_my_fixed_programme(
              '$athleteId', '$assignmentId', '$_version'
            )->>'status' IS DISTINCT FROM 'ok' THEN
              RAISE EXCEPTION 'End programme failed';
            END IF;
            IF public.$_read('$assignmentId', '$_version', '$slotId',
              '$occurrenceId', '$_protocol') IS NOT NULL THEN
              RAISE EXCEPTION 'Ended assignment still exposes approval';
            END IF;
          END \$\$;
          ROLLBACK;
          """);
        expect(await read(), approved);
        await sql("""
        UPDATE public.session_blocks SET content = 'Unreviewed drift'
        WHERE session_id = '$_protocol' AND position = 1;
        """);
        expect(await read(), isNull);
        await sql("""
        UPDATE public.session_blocks SET content = 'Five minutes of easy walking to warm up.'
        WHERE session_id = '$_protocol' AND position = 1;
        """);
        expect(await read(), approved);

        const assignments = ProgrammeAssignmentSupabaseStore();
        final assignment = (await assignments.getActiveAssignment(athleteId))!;
        final kv = InMemoryKvStore();
        AthleteProgrammeSessionPrepareService prepareWith(
          InMemoryKvStore store,
        ) => AthleteProgrammeSessionPrepareService(
          assignmentStore: assignments,
          slotResolver: AthleteProgrammeAuthoredSlotResolver(
            versionStore: const ProgrammeVersionSupabaseStore(),
          ),
          sessionLoader: SessionExecutionLoader(),
          localRepository: AthleteLocalRepository(store),
        );
        final prepare = prepareWith(kv);
        final occurrence = (await prepare.fixedOccurrenceStore.resolveActive())!
            .occurrences
            .single;
        final prepared = await prepare.prepareFixedOccurrence(
          assignment,
          occurrence,
        );
        expect(
          prepared.isReady,
          isTrue,
          reason: '${prepared.code}: ${prepared.message}',
        );
        final original = prepared.package!;
        final context = prepared.executionContext!;
        final before = jsonEncode(kv.debugDump);
        CurrentUserSession.bind(profile);
        addTearDown(CurrentUserSession.clear);
        const reader = ProgrammeAdaptationPermissionReader();
        expect(await reader.loadApprovedTime(context), isNull);
        final proposals = ProgrammeAdaptationProposalService();
        final acceptance = ProgrammeAdaptationAcceptanceService(
          prepareService: prepare,
        );
        const poorSleep = AdaptationRequest(
          reason: AdaptationReason.recovery,
          recoveryState: RecoveryState.poorSleep,
        );
        var open = true;
        var readCount = 0;
        RecoveryReview newReview() => RecoveryReview(
          athleteId: athleteId,
          prepareService: prepare,
          isOpen: () => open,
          loadApproval: (context) {
            readCount++;
            return reader.loadApprovedRecovery(context);
          },
        );
        final declinedReview = newReview();
        final noAnswer = await proposals.propose(
          package: original,
          request: const AdaptationRequest(reason: AdaptationReason.recovery),
          executionContext: context,
          recoveryReview: declinedReview,
        );
        expect(noAnswer.isAcceptable, isFalse);
        expect(readCount, 0);
        final declinedProposal = await proposals.propose(
          package: original,
          request: poorSleep,
          executionContext: context,
          recoveryReview: declinedReview,
        );
        expect(
          declinedProposal.isAcceptable,
          isTrue,
          reason: declinedProposal.athleteFacingMessage,
        );
        declinedReview.bindProposal(declinedProposal);

        return (
          proposal: declinedProposal,
          decline: () async {
            open = false;
            expect(jsonEncode(kv.debugDump), before);
            final stale = await acceptance.accept(
              athleteId: athleteId,
              currentPackage: original,
              proposal: declinedProposal,
              executionContext: context,
              recoveryReview: declinedReview,
            );
            expect(stale.success, isFalse);
            expect(readCount, 1);
            expect(jsonEncode(kv.debugDump), before);
            final reopened = await prepareWith(
              kv,
            ).prepareFixedOccurrence(assignment, occurrence);
            expect(reopened.package!.plan.blocks, hasLength(3));
            expect(reopened.package!.hasAcceptedAdaptation, isFalse);
          },
          fresh: () async {
            open = true;
            final review = newReview();
            final proposal = await proposals.propose(
              package: original,
              request: poorSleep,
              executionContext: context,
              recoveryReview: review,
            );
            expect(
              proposal.isAcceptable,
              isTrue,
              reason: proposal.athleteFacingMessage,
            );
            review.bindProposal(proposal);
            // Even a live comparison cannot accept if the authenticated reader
            // stops returning that approval between review and acceptance.
            await schedule("date '$today' + 1");
            final unavailable = await acceptance.accept(
              athleteId: athleteId,
              currentPackage: original,
              proposal: proposal,
              executionContext: context,
              recoveryReview: review,
            );
            expect(unavailable.success, isFalse);
            expect(jsonEncode(kv.debugDump), before);
            await schedule("date '$today'");
            final freshReview = newReview();
            final freshProposal = await proposals.propose(
              package: original,
              request: poorSleep,
              executionContext: context,
              recoveryReview: freshReview,
            );
            expect(freshProposal.isAcceptable, isTrue);
            freshReview.bindProposal(freshProposal);
            return (
              proposal: freshProposal,
              accept: () async {
                final readsBefore = readCount;
                final accepted = await acceptance.accept(
                  athleteId: athleteId,
                  currentPackage: original,
                  proposal: freshProposal,
                  executionContext: context,
                  recoveryReview: freshReview,
                );
                expect(
                  accepted.success,
                  isTrue,
                  reason: '${accepted.errorCode}: ${accepted.message}',
                );
                expect(readCount, greaterThan(readsBefore));
                final adapted = accepted.package!;
                const codec = SessionExecutionPlanCodec();
                final originalBlocks =
                    codec.encodePlan(original.plan)['blocks'] as List;
                final adaptedBlocks =
                    codec.encodePlan(adapted.plan)['blocks'] as List;
                expect(adaptedBlocks, originalBlocks.take(2).toList());
                expect(adapted.plan.durationMin, 30);
                expect(
                  adapted.plan.blocks.first.timerConfiguration!.durationSeconds,
                  300,
                );
                final bench = adapted.plan.blocks[1].linkedExercises.single;
                expect(bench.exerciseId, 'EX-083');
                expect(bench.prescription!.toJson(), {
                  'sets': 4,
                  'reps': {'type': 'exact', 'exact_reps': 8},
                  'rest_seconds': 120,
                  'load': {'type': 'athleteSelected'},
                });

                final launcher = ProgrammeSessionExecutionLauncher(
                  startStore: ProgrammeTrainingSessionStartSupabaseStore(
                    client: client,
                  ),
                );
                final launched = await launcher.createOrResumeLaunchResult(
                  athleteId: athleteId,
                  programmeContext: context,
                  package: adapted,
                );
                final sessionId = launched.trainingSession.id;
                expect(
                  await read(),
                  isNull,
                  reason: 'A started occurrence cannot read the approval',
                );
                final capture =
                    PerformanceCaptureController.initializeFromExecutionPlan(
                      plan: adapted.plan,
                      athleteId: athleteId,
                      trainingSessionId: sessionId,
                      programmeContext: context,
                    );
                for (final block in List.of(capture.draft.blockDrafts)) {
                  for (final exercise in block.exerciseResults.where(
                    (e) => e.sourceExerciseId == 'EX-083',
                  )) {
                    for (final set in exercise.sets) {
                      capture.updateSet(
                        block.sourceBlockId,
                        exercise.sourceExerciseId,
                        set.setResultId,
                        (s) => s.copyWith(
                          reps: 8,
                          load: 16,
                          loadUnit: 'kg',
                          completed: true,
                        ),
                      );
                    }
                  }
                  capture.markBlockComplete(block.sourceBlockId);
                }
                final store = SupabasePerformanceRecordStore();
                final coordinator = PerformanceRecordSaveCoordinator(
                  store: store,
                );
                final saved = await coordinator.saveDraft(controller: capture);

                final restoredKv = InMemoryKvStore();
                for (final entry in kv.debugDump.entries) {
                  await restoredKv.writeString(entry.key, entry.value);
                }
                final restored = prepareWith(restoredKv);
                final inProgress =
                    (await restored.fixedOccurrenceStore.resolveActive())!
                        .occurrences
                        .single;
                expect(inProgress.trainingSessionId, sessionId);
                final reopened = await restored.prepareFixedOccurrence(
                  assignment,
                  inProgress,
                );
                expect(reopened.package!.hasAcceptedAdaptation, isTrue);
                expect(
                  codec.encodePlan(reopened.package!.plan)['blocks'],
                  adaptedBlocks,
                );
                final resumed = await launcher.createOrResumeLaunchResult(
                  athleteId: athleteId,
                  programmeContext: reopened.executionContext!,
                  package: reopened.package!,
                );
                expect(resumed.trainingSession.id, sessionId);
                final draft = (await store.getInProgressForTrainingSession(
                  athleteId: athleteId,
                  trainingSessionId: sessionId,
                ))!;
                expect(draft.recordId, saved.recordId);
                expect(
                  draft.blockResults.last.exerciseResults.single.setResults.map(
                    (s) => s.load,
                  ),
                  [16, 16, 16, 16],
                );
                final completion =
                    await AthleteProgrammeCompletionService(
                      store: const AthleteProgrammeCompletionSupabaseStore(),
                      performanceStore: store,
                    ).submit(
                      controller: coordinator.restoreControllerFromRecord(
                        draft,
                      ),
                      programmeContext: reopened.executionContext!,
                      trainingSessionId: sessionId,
                      idempotencyKey: 'm33-local-$occurrenceId',
                    );
                expect(
                  completion.isSuccess,
                  isTrue,
                  reason: '${completion.code}: ${completion.message}',
                );
                expect(
                  await sql("""
                SELECT count(*) FROM public.programme_slot_outcomes
                WHERE assignment_id = '$assignmentId' AND session_slot_id = '$slotId'
                  AND outcome_status = 'completed' AND training_session_id = $sessionId;
                """),
                  '1',
                );
                final record = (await store.listHistory(
                  athleteId: athleteId,
                )).single;
                expect(record.recordId, saved.recordId);
                expect(record.blockResults.map((b) => b.position), [1, 2]);
                final actual = record.blockResults.last.exerciseResults.single;
                expect(actual.sourceExerciseId, 'EX-083');
                expect(
                  actual.setResults.map(
                    (s) => [s.reps, s.load, s.loadUnit, s.completed],
                  ),
                  List.filled(4, [8, 16, 'kg', true]),
                );
                expect(
                  await publisher.rpc(_issue, params: issueParams),
                  'already_approved',
                );
                expect(await read(), isNull);
                expect(await sql(_timeHistoryDigest), originalHistory);
                debugPrint(
                  'Generated IDs, exact retries, start/end races, seal drift and unchanged M3.2 History passed.',
                );
                return record;
              },
            );
          },
        );
      }))!;

      Future<bool?> tapReview(
        ProgrammeAdaptationProposal proposal,
        String action,
      ) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showProgrammeAdaptationProposalSheet(
                      context,
                      proposal,
                    );
                  },
                  child: const Text('Open trial review'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open trial review'));
        await tester.pumpAndSettle();
        expect(find.textContaining('You reported poor sleep'), findsOneWidget);
        expect(
          find.textContaining('Skip optional lateral raises'),
          findsOneWidget,
        );
        expect(find.textContaining('45 → 30 min estimated'), findsOneWidget);
        await tester.ensureVisible(find.text(action));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        return result;
      }

      expect(
        await tapReview(journey.proposal, 'Keep Original Session'),
        isFalse,
      );
      await tester.runAsync(journey.decline);
      final fresh = (await tester.runAsync(journey.fresh))!;
      expect(await tapReview(fresh.proposal, 'Accept Adaptation'), isTrue);
      final record = (await tester.runAsync(fresh.accept))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionResultView(
              record: record,
              athleteHistory: [record],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bench = find.text('Barbell bench press');
      await tester.scrollUntilVisible(bench, 200);
      await tester.tap(bench);
      await tester.pumpAndSettle();
      expect(find.textContaining('16 kg'), findsWidgets);
      expect(find.textContaining('lateral raise'), findsNothing);
    },
    skip: configFile == null,
  );
}

// Hold the real start/end transaction open until pg_blocking_pids confirms
// the issuer is waiting on it. This tests commit order without timing guesses.
Future<void> _competeWithIssuance({
  required String container,
  required Future<String> Function(String) sql,
  required String athlete,
  required String action,
  required String actionStatus,
  required Future<dynamic> Function() issue,
}) async {
  final actor = await Process.start('docker', [
    'exec',
    '-i',
    container,
    'psql',
    '-X',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-qAt',
    '-v',
    'ON_ERROR_STOP=1',
  ]);
  final errors = actor.stderr.transform(utf8.decoder).join();
  final lines = StreamIterator(
    actor.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );
  try {
    actor.stdin.writeln("""
      SELECT pg_backend_pid();
      BEGIN;
      SET LOCAL ROLE authenticated;
      SET LOCAL "request.jwt.claim.sub" = '$athlete';
      SET LOCAL "request.jwt.claims" = '{"sub":"$athlete","role":"authenticated"}';
      SELECT $action->>'status';
    """);
    await actor.stdin.flush();
    expect(await lines.moveNext().timeout(const Duration(seconds: 10)), isTrue);
    final actorPid = int.parse(lines.current);
    expect(await lines.moveNext().timeout(const Duration(seconds: 10)), isTrue);
    expect(lines.current, actionStatus);
    final result = issue();
    // Install an error listener before polling so a failed RPC cannot become
    // an unhandled async error before the transaction is closed.
    unawaited(result.then<void>((_) {}, onError: (Object _) {}));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    var blocked = false;
    while (!blocked && DateTime.now().isBefore(deadline)) {
      blocked =
          await sql("""
        SELECT EXISTS (
          SELECT FROM pg_stat_activity
          WHERE $actorPid = ANY(pg_blocking_pids(pid))
            AND query LIKE '%$_issue%'
        );
        """) ==
          't';
    }
    actor.stdin.writeln('COMMIT;');
    await actor.stdin.close();
    expect(
      await actor.exitCode.timeout(const Duration(seconds: 10)),
      0,
      reason: await errors,
    );
    expect(blocked, isTrue, reason: 'The issuer must wait for $actionStatus');
    expect(await result, 'scope_mismatch');
  } finally {
    await lines.cancel();
    actor.kill();
  }
}
