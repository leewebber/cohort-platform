// Opt-in actual GoTrue/PostgREST proof. Synthetic local accounts and programmes.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_store.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_role.dart';
import 'package:cohort_platform/features/auth/repositories/supabase_profile_repository.dart';
import 'package:cohort_platform/features/auth/services/auth_service.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';
import 'package:cohort_platform/features/session/services/running_target_admission_store.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_supabase_store.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/authored_timed_running_execution.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';

void main() {
  final path = Platform.environment['COHORT_ZONE2_CONFIG'];
  test(
    'actual owned Zone 2 confirmation, exact review/start freeze, replay, RLS and correction guards',
    () async {
      final config = jsonDecode(File(path!).readAsStringSync()) as Map;
      final api = Uri.parse(config['API_URL'] as String);
      expect(api.host, '127.0.0.1');
      expect(api.scheme, 'http');
      final container = config['CONTAINER'] as String;
      expect(container.startsWith('supabase_db_s12g'), isTrue);
      Future<String> sql(String q) async {
        final p = await Process.start('docker', [
          'exec',
          '-i',
          container,
          'psql',
          '-X',
          '-U',
          'postgres',
          '-d',
          'postgres',
          '-At',
          '-v',
          'ON_ERROR_STOP=1',
        ]);
        p.stdin.write(q);
        await p.stdin.close();
        final out = await utf8.decoder.bind(p.stdout).join();
        final err = await utf8.decoder.bind(p.stderr).join();
        expect(await p.exitCode, 0, reason: err);
        return out.trim();
      }

      SupabaseClient client() => SupabaseClient(
        api.toString(),
        config['ANON_KEY'] as String,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: _MemoryPkce(),
        ),
      );
      final a = client(), b = client(), restart = client();
      addTearDown(() async {
        await a.dispose();
        await b.dispose();
        await restart.dispose();
        CurrentUserSession.clear();
      });
      final clients = [a, b];
      for (var i = 0; i < clients.length; i++) {
        final c = clients[i];
        final auth = AuthController(
          authService: AuthService(client: c),
          profileProvisioningService: ProfileProvisioningService(
            profileRepository: SupabaseProfileRepository(client: c),
          ),
        );
        addTearDown(auth.dispose);
        await auth.signUp(
          email:
              'zone2-$i-${DateTime.now().microsecondsSinceEpoch}@example.com',
          password: 'Local-test-${Random.secure().nextInt(1 << 32)}-aA!',
          displayName: 'Synthetic Zone2 $i',
          roles: {UserRole.athlete},
        );
        expect(c.auth.currentUser, isNotNull, reason: auth.state.errorMessage);
      }
      expect(
        await sql(
          "SELECT bool_and(has_function_privilege('authenticated',f,'EXECUTE') AND NOT has_function_privilege('anon',f,'EXECUTE') AND NOT has_function_privilege('service_role',f,'EXECUTE')) FROM unnest(ARRAY['public.confirm_running_zone2(uuid,integer,integer,boolean)','public.review_running_zone2_targets(uuid)','public.create_or_resume_fixed_programme_occurrence_session(uuid,text)']) f;",
        ),
        't',
      );
      for (var i = 0; i < 2; i++) {
        final c = clients[i], other = clients[1 - i];
        final uid = c.auth.currentUser!.id;
        final version = i + 1;
        final vid = 'd2300000-0000-4000-8000-00000000006$version';
        await sql(
          "INSERT INTO public.private_programme_alpha_eligibility(athlete_id,programme_version_id) VALUES('$uid','$vid');",
        );
        final acq = SupabaseAcquisitionStore(athleteId: uid, client: c);
        await acq.saveSetup('Europe/London', complete: true);
        final assignment = await acq.acquire(vid, DateTime.now().toUtc());
        final occurrence =
            jsonDecode(
                  await sql(
                    "SELECT row_to_json(o) FROM public.programme_schedule_occurrences o WHERE assignment_id='$assignment' ORDER BY original_scheduled_date LIMIT 1;",
                  ),
                )
                as Map;
        final oid = occurrence['id'] as String;
        final store = SupabaseRunningTargetAdmissionStore(
          athleteId: uid,
          client: c,
        );
        final start = ProgrammeTrainingSessionStartSupabaseStore(client: c);
        Future<Map<String, dynamic>> begin([String? hash]) => start
            .createOrResume({'occurrence_id': oid, 'target_review_hash': hash});
        expect((await store.review(oid))['status'], 'input_required');
        expect((await begin())['code'], 'running_target_review_required');
        expect(
          await sql(
            "SELECT count(*) FROM public.training_sessions WHERE athlete_id='$uid';",
          ),
          '0',
        );
        await expectLater(
          c.rpc(
            'confirm_running_zone2',
            params: {
              'p_expected_athlete_id': uid,
              'p_lower_bpm': 150,
              'p_upper_bpm': 120,
            },
          ),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          other.rpc(
            'review_running_zone2_targets',
            params: {'p_occurrence_id': oid},
          ),
          throwsA(isA<PostgrestException>()),
        );
        await store.confirmZone(120, 145);
        final review = await store.review(oid);
        expect(review['status'], 'review_required');
        await store.confirmZone(121, 146);
        expect(
          (await begin(review['review_hash'] as String))['reason'],
          'missing_or_stale_review',
        );
        await store.confirmZone(null, null, withdraw: true);
        expect(
          (await begin(review['review_hash'] as String))['reason'],
          'withdrawn',
        );
        await store.confirmZone(120, 145);
        var ready = await store.review(oid);
        // A rejected snapshot write must roll back the canonical session/outcome.
        await sql(
          r"CREATE FUNCTION public.zone2_fail_fixture() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic_freeze_failure'; END $$; CREATE TRIGGER zone2_fail_fixture BEFORE INSERT ON public.programme_occurrence_zone2_targets FOR EACH ROW EXECUTE FUNCTION public.zone2_fail_fixture();",
        );
        expect(
          (await begin(ready['review_hash'] as String))['status'],
          'refused',
        );
        expect(
          await sql(
            "SELECT count(*) FROM public.training_sessions WHERE athlete_id='$uid';",
          ),
          '0',
        );
        await sql(
          'DROP TRIGGER zone2_fail_fixture ON public.programme_occurrence_zone2_targets; DROP FUNCTION public.zone2_fail_fixture();',
        );
        if (i == 1) {
          final raced = await Future.wait([
            begin(ready['review_hash'] as String),
            store.confirmZone(125, 150).then((_) => <String, dynamic>{}),
          ]);
          if (raced.first['status'] == 'refused') {
            ready = await store.review(oid);
          }
        }

        final generic = await c.rpc(
          'create_or_resume_programme_training_session',
          params: {
            'payload': {'assignment_id': assignment},
          },
        );
        expect(generic['code'], 'running_target_requires_fixed_occurrence');
        final rows = await c
            .from('session_blocks')
            .select()
            .eq('session_id', occurrence['protocol_id']);
        final plan = SessionExecutionPlan(
          sessionId: occurrence['protocol_id'] as String,
          sessionTitle: '[FIXTURE ONLY] Easy run',
          blocks: [
            for (final row in rows)
              SessionExecutionBlock.fromSessionBlock(
                SessionBlock.fromRow(row),
                exercisesById: const {},
              ),
          ],
        );
        final ass =
            jsonDecode(
                  await sql(
                    "SELECT row_to_json(a) FROM public.programme_assignments a WHERE id='$assignment';",
                  ),
                )
                as Map;
        final ctx = ProgrammeExecutionContext(
          assignmentId: assignment,
          programmeVersionId: vid,
          sessionSlotId: occurrence['session_slot_id'] as String,
          weekNumber: occurrence['week_number'] as int,
          dayKey: occurrence['day_key'] as String,
          sessionOrder: occurrence['session_order'] as int,
          plannedProtocolId: plan.sessionId,
          effectiveProtocolId: plan.sessionId,
          lineageCode: ass['lineage_code'] as String,
          packageContentHash:
              ass['materialised_package_content_hash'] as String,
          programmedSessionKey: occurrence['programmed_session_key'] as String,
          occurrenceId: oid,
          packageSchemaVersion: version,
        );
        final package = PreparedExecutionPackage(
          programmedSessionKey: ProgrammedSessionKey.parse(
            ctx.programmedSessionKey!,
          ),
          plan: plan,
          brief: const WorkoutSessionBrief(
            sessionName: '[FIXTURE ONLY] Easy run',
          ),
          preparedAt: DateTime.now(),
          assignmentId: assignment,
          programmeVersionId: vid,
          packageContentHash: ctx.packageContentHash,
          dayKey: ctx.dayKey,
          slotOrder: ctx.sessionOrder,
          protocolId: plan.sessionId,
        );
        final launcher = ProgrammeSessionExecutionLauncher(startStore: start);
        // Race starts and consent/input updates through real authenticated HTTP.
        final starts = await Future.wait(
          List.generate(
            4,
            (_) => launcher.createOrResumeLaunchResult(
              athleteId: uid,
              programmeContext: ctx,
              package: package,
              targetReviewHash: ready['review_hash'] as String,
            ),
          ),
        );
        expect(starts.map((s) => s.trainingSession.id).toSet().length, 1);
        final frozen = starts.first.runningTargetAdmissionSnapshot!;
        expect([
          frozen['zone2']['lower_bpm'],
          frozen['zone2']['upper_bpm'],
        ], anyOf(equals([120, 145]), equals([125, 150])));
        final accepted = applyRunningTargetAdmission(plan, frozen);
        final run = AuthoredTimedRunningExecution.fromBlock(
          accepted.blocks.single,
          admission: frozen,
        );
        expect(
          runningAtomicSteps(run.workout).elementAt(1).target,
          RunningTarget.heartRateRange(
            low: frozen['zone2']['lower_bpm'] as int,
            high: frozen['zone2']['upper_bpm'] as int,
          ),
        );
        final clock = StructuredRunningController.fresh(
          execution: run,
          elapsedTime: () => Duration.zero,
        );
        clock.start();
        clock.elapse(const Duration(seconds: 350));
        final cursor = clock.cursor;
        clock.dispose();
        await store.confirmZone(125, 150);
        await store.confirmZone(null, null, withdraw: true);
        await restart.auth.recoverSession(
          jsonEncode(c.auth.currentSession!.toJson()),
        );
        final reopened = await ProgrammeTrainingSessionStartSupabaseStore(
          client: restart,
        ).createOrResume({'occurrence_id': oid});
        expect(reopened['running_target_admission_snapshot'], frozen);
        final after = StructuredRunningController.restore(
          execution: run,
          cursor: cursor,
          wallClock: () => DateTime.utc(2099),
        );
        expect(after.cursor.isPaused, isTrue);
        expect(
          after.cursor.remainingMilliseconds,
          cursor.remainingMilliseconds,
        );
        after.dispose();
        expect(
          await other
              .from('athlete_running_zone2_inputs')
              .select()
              .eq('athlete_id', uid),
          isEmpty,
        );
        expect(
          await other
              .from('programme_occurrence_zone2_targets')
              .select()
              .eq('athlete_id', uid),
          isEmpty,
        );
        await expectLater(
          c
              .from('athlete_running_zone2_inputs')
              .update({'lower_bpm': 1})
              .eq('athlete_id', uid),
          throwsA(isA<PostgrestException>()),
        );
        final sid = starts.first.trainingSession.id;
        expect(
          await sql(
            "SELECT count(*) FROM public.programme_occurrence_zone2_targets WHERE occurrence_id='$oid';",
          ),
          '1',
        );
        final capture =
            PerformanceCaptureController.initializeFromExecutionPlan(
              plan: accepted,
              athleteId: uid,
              trainingSessionId: sid,
              programmeContext: ctx,
            );
        capture.updateBlockResultData(
          plan.blocks.single.blockId,
          const EnduranceResultData(
            durationSeconds: 1490,
            distance: 4,
            distanceUnit: 'km',
          ),
        );
        capture.markBlockComplete(plan.blocks.single.blockId);
        final record = const PerformanceRecordMapper().fromDraft(
          capture.buildPersistableDraft(
            status: TrainingSessionRecordStatus.completed,
          ),
        );
        final correctedDraft = PerformanceCorrectionDraft(record)
          ..athleteNote = 'Corrected actual note';
        final corrected = const PerformanceCorrectionService().applyLocally(
          correctedDraft,
        );
        expect(
          corrected.sessionSnapshot.runningTargetAdmissionSnapshot,
          frozen,
        );
        final draftRecord = const PerformanceRecordMapper().fromDraft(
          capture.draft,
        );
        await c
            .from('training_session_records')
            .insert(draftRecord.toUpsertMap());
        for (final block in draftRecord.blockResults) {
          await c.from('training_block_results').insert(block.toUpsertMap());
        }
        final changedSnapshot =
            jsonDecode(jsonEncode(draftRecord.sessionSnapshot.toJson()))
                as Map<String, dynamic>;
        changedSnapshot['runningTargetAdmissionV1']['zone2']['lower_bpm'] = 1;
        await expectLater(
          c
              .from('training_session_records')
              .update({'session_snapshot': changedSnapshot})
              .eq('record_id', draftRecord.recordId),
          throwsA(isA<PostgrestException>()),
        );
        expect(
          (await c
              .from('training_session_records')
              .select('session_snapshot')
              .eq('record_id', draftRecord.recordId)
              .single())['session_snapshot']['runningTargetAdmissionV1'],
          frozen,
        );
        await expectLater(
          other.rpc(
            'confirm_running_zone2',
            params: {
              'p_expected_athlete_id': uid,
              'p_lower_bpm': 100,
              'p_upper_bpm': 130,
            },
          ),
          throwsA(isA<PostgrestException>()),
        );
        final completionStore = _CompletionStore(c);
        final completed =
            await AthleteProgrammeCompletionService(
              store: completionStore,
            ).submit(
              controller: capture,
              programmeContext: ctx,
              trainingSessionId: sid,
              idempotencyKey: 'zone2-fixture-$oid',
            );
        expect(
          completed.isSuccess,
          isTrue,
          reason:
              '${completed.status.name}: ${completed.code} ${completed.message}',
        );
        final replay = await completionStore.completeAndAdvance(
          completionStore.last!,
        );
        // M2.4 recovers the committed result without changing frozen targets.
        expect(replay['status'], 'already_committed');
        expect(replay['code'], 'idempotent_replay');
        expect(
          await sql(
            "SELECT count(*) FROM public.training_session_records WHERE training_session_id=$sid;",
          ),
          '1',
        );
        final terminal = await c
            .from('training_session_records')
            .select()
            .eq('record_id', draftRecord.recordId)
            .single();
        final blocks = await c
            .from('training_block_results')
            .select()
            .eq('session_record_id', draftRecord.recordId);
        final terminalRecord = TrainingSessionRecord.fromCompletionTreeMap({
          ...terminal,
          'block_results': blocks,
        });
        expect(
          terminalRecord.sessionSnapshot.runningTargetAdmissionSnapshot,
          frozen,
        );
        final correction = PerformanceCorrectionDraft(terminalRecord)
          ..athleteNote = 'Corrected actual note';
        await c.rpc(
          'correct_completed_performance_record',
          params: {
            'payload': const PerformanceCorrectionService().toPayload(
              correction,
            ),
          },
        );
        final history = await c
            .from('training_session_records')
            .select('session_snapshot,athlete_note,status')
            .eq('record_id', draftRecord.recordId)
            .single();
        expect(history['session_snapshot']['runningTargetAdmissionV1'], frozen);
        expect(history['athlete_note'], 'Corrected actual note');
        final ended = await begin();
        expect(ended['status'], isNot(anyOf('created', 'resumed')));
        final guard = await sql(
          "SELECT has_table_privilege('authenticated','public.programme_occurrence_zone2_targets','UPDATE') OR has_function_privilege('service_role','public.cohort_fixed_with_zone2(uuid,timestamptz,text)','EXECUTE');",
        );
        expect(guard, 'f');
      }
      // Unattached v1 and the existing B2/v2 target path still delegate to the
      // original start. These are retained synthetic compatibility fixtures.
      for (var i = 0; i < 2; i++) {
        final c = clients[i], uid = c.auth.currentUser!.id;
        final version = i + 1,
            vid = 'c2000000-0000-4000-8000-00000000006${i + 1}';
        await sql(
          "INSERT INTO public.private_programme_alpha_eligibility(athlete_id,programme_version_id) VALUES('$uid','$vid');",
        );
        final assignment = await SupabaseAcquisitionStore(
          athleteId: uid,
          client: c,
        ).acquire(vid, DateTime.now().toUtc());
        final oid = await sql(
          "SELECT id FROM public.programme_schedule_occurrences WHERE assignment_id='$assignment' ORDER BY original_scheduled_date LIMIT 1;",
        );
        final store = ProgrammeTrainingSessionStartSupabaseStore(client: c);
        final started = await store.createOrResume({'occurrence_id': oid});
        expect(started['status'], 'created');
        expect(started['running_target_admission_snapshot'], isNull);
        if (version == 2) {
          expect(started['running_target_snapshot'], isA<Map>());
        }
        final resumed = await store.createOrResume({'occurrence_id': oid});
        expect(resumed['status'], 'resumed');
        expect(
          resumed['training_session']['id'],
          started['training_session']['id'],
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: path == null ? 'Run through disposable Zone 2 gate' : false,
  );
}

class _MemoryPkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

class _CompletionStore implements AthleteProgrammeCompletionStore {
  _CompletionStore(this.client);
  final SupabaseClient client;
  Map<String, dynamic>? last;
  @override
  Future<Map<String, dynamic>> completeAndAdvance(
    Map<String, dynamic> payload,
  ) async {
    last = payload;
    return Map<String, dynamic>.from(
      await client.rpc(
            'complete_fixed_programme_occurrence_and_advance',
            params: {'payload': payload},
          )
          as Map,
    );
  }
}
