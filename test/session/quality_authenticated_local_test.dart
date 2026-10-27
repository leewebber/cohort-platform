// Opt-in actual GoTrue/PostgREST proof. Synthetic local accounts and programmes.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cohort_platform/domain/running_workout/alpha_quality_targets.dart';
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
  final path = Platform.environment['COHORT_QUALITY_CONFIG'];
  test(
    'approved quality inputs, sources, dates, atomic start, original targets and legacy completion',
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
      final a = client(),
          b = client(),
          d = client(),
          e = client(),
          restart = client();
      addTearDown(() async {
        await a.dispose();
        await b.dispose();
        await d.dispose();
        await e.dispose();
        await restart.dispose();
        CurrentUserSession.clear();
      });
      final clients = [a, b, d, e];
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
              'quality-$i-${DateTime.now().microsecondsSinceEpoch}@example.com',
          password: 'Local-test-${Random.secure().nextInt(1 << 32)}-aA!',
          displayName: 'Synthetic Zone2 $i',
          roles: {UserRole.athlete},
        );
        expect(c.auth.currentUser, isNotNull, reason: auth.state.errorMessage);
      }
      expect(
        await sql(
          "SELECT bool_and(has_function_privilege('authenticated',f,'EXECUTE') AND NOT has_function_privilege('anon',f,'EXECUTE') AND NOT has_function_privilege('service_role',f,'EXECUTE')) FROM unnest(ARRAY['public.confirm_running_quality_input(uuid,text,integer,date,boolean,boolean,text)','public.review_running_quality_targets(uuid,text)','public.create_or_resume_fixed_programme_occurrence_session(uuid,text,text)']) f;",
        ),
        't',
      );
      expect(
        await sql(
          "SELECT public.cohort_alpha_5k_date_eligible_v1('2025-11-05','America/Los_Angeles','America/Los_Angeles','2026-01-01T00:30:00Z') AND NOT public.cohort_alpha_5k_date_eligible_v1('2025-11-05','Pacific/Kiritimati','Pacific/Kiritimati','2026-01-01T00:30:00Z');",
        ),
        't',
      );
      expect(
        await sql(
          "SELECT NOT public.cohort_alpha_5k_date_eligible_v1('2026-01-01','UTC','America/Los_Angeles','2026-01-01T00:30:00Z');",
        ),
        't',
      );
      // Same approved arithmetic in Dart and SQL, including exact half-second cases.
      final vectors = <String>[];
      for (final seconds in [25, 120, 1250, 1500, 1999, 3600, 86400]) {
        for (final category in alphaQualityCategories) {
          for (final source in [
            'five_k',
            if (category == 'threshold') 'manual_threshold',
          ]) {
            try {
              final w = alphaQualityPaceWindow(
                seconds: seconds,
                category: category,
                manualThreshold: source == 'manual_threshold',
              );
              vectors.add(
                "($seconds,'$category','$source',${w.lower},${w.upper})",
              );
            } on FormatException {
              /* unsupported rounded window, never admitted */
            }
          }
        }
      }
      expect(
        await sql(
          "SELECT bool_and((w->>'lower')::int=lo AND (w->>'upper')::int=hi AND w->>'unit'='seconds_per_kilometre') FROM (VALUES ${vectors.join(',')}) v(s,c,source,lo,hi) CROSS JOIN LATERAL public.cohort_alpha_quality_window_v1(s,c,source) w;",
        ),
        't',
      );
      for (var i = 0; i < clients.length; i++) {
        final c = clients[i],
            other = clients[(i + 1) % clients.length],
            uid = c.auth.currentUser!.id;
        final version = i % 2 + 1,
            vid = 'd2400000-0000-4000-8000-00000000006${i % 2 + 1}';
        final selected = [
          'five_k',
          'manual_threshold',
          'authored_rpe',
          'five_k',
        ][i];
        final tz = i == 1 ? 'America/Los_Angeles' : 'Europe/London';
        await sql(
          "INSERT INTO public.private_programme_alpha_eligibility(athlete_id,programme_version_id) VALUES('$uid','$vid');",
        );
        final acq = SupabaseAcquisitionStore(athleteId: uid, client: c);
        await acq.saveSetup(tz, complete: true);
        final today = await sql(
          "SELECT (transaction_timestamp() AT TIME ZONE '$tz')::date;",
        );
        String day(int days) => DateTime.parse(
          '${today}T00:00:00Z',
        ).subtract(Duration(days: days)).toIso8601String().substring(0, 10);
        final assignment = await acq.acquire(
          vid,
          DateTime.parse('${today}T00:00:00Z'),
        );
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
        Future<Map<String, dynamic>> begin([String? hash, String? source]) =>
            start.createOrResume({
              'occurrence_id': oid,
              'target_review_hash': hash,
              'target_source': ?source,
            });
        expect((await begin())['code'], 'running_target_review_required');
        expect(
          (await store.reviewQuality(oid, 'five_k'))['reason'],
          'missing_5k',
        );
        await expectLater(
          store.confirmQuality(
            kind: 'five_k',
            seconds: 0,
            date: today,
            sustained: true,
          ),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          store.confirmQuality(
            kind: 'five_k',
            seconds: 1500,
            date: day(-1),
            sustained: true,
          ),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          store.confirmQuality(
            kind: 'five_k',
            seconds: 1500,
            date: today,
            sustained: false,
          ),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          other.rpc(
            'review_running_quality_targets',
            params: {'p_occurrence_id': oid, 'p_target_source': 'five_k'},
          ),
          throwsA(isA<PostgrestException>()),
        );
        await store.confirmQuality(
          kind: 'five_k',
          seconds: 1500,
          date: day(57),
          sustained: true,
        );
        final stale = await store.reviewQuality(oid, 'five_k');
        expect(stale['reason'], 'stale_5k');
        expect(stale['authored_rpe_available'], true);
        expect(
          (await begin())['reason'],
          'stale_5k',
        ); // never automatic RPE/no-target fallback
        final rpe = await store.reviewQuality(oid, 'authored_rpe');
        expect(rpe['status'], 'review_required');
        expect(rpe['document']['quality_targets'].single['target'], {
          'unit': 'rpe_cr10',
          'value': 7,
        });
        await store.confirmQuality(
          kind: 'manual_threshold',
          seconds: 300,
          manualOrigin: 'garmin_read_manually',
        );
        final manual = await store.reviewQuality(oid, 'manual_threshold');
        expect(manual['document']['quality_targets'].single['target'], {
          'unit': 'seconds_per_kilometre',
          'lower': 294,
          'upper': 306,
        });
        await store.confirmQuality(
          kind: 'five_k',
          seconds: 1500,
          date: day(56),
          sustained: true,
        );
        final cutoff = await store.reviewQuality(oid, 'five_k');
        expect(cutoff['status'], 'review_required');
        expect(cutoff['document']['quality']['evaluation_timezone'], tz);
        await store.confirmQuality(
          kind: 'five_k',
          seconds: 1501,
          date: today,
          sustained: true,
        );
        expect(
          (await begin(cutoff['review_hash'] as String, 'five_k'))['reason'],
          'missing_or_stale_review',
        );
        await store.confirmQuality(kind: 'five_k', withdraw: true);
        expect(
          (await store.reviewQuality(oid, 'five_k'))['reason'],
          'withdrawn_5k',
        );
        await store.confirmQuality(
          kind: 'five_k',
          seconds: 1500,
          date: today,
          sustained: true,
        );
        final ready = await store.reviewQuality(oid, selected);
        expect(
          await sql(
            "SELECT count(*) FROM public.training_sessions WHERE athlete_id='$uid';",
          ),
          '0',
        );
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
          sessionTitle: '[FIXTURE ONLY] Quality run',
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
            sessionName: '[FIXTURE ONLY] Quality run',
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
        final starts = await Future.wait(
          List.generate(
            4,
            (_) => launcher.createOrResumeLaunchResult(
              athleteId: uid,
              programmeContext: ctx,
              package: package,
              targetReviewHash: ready['review_hash'] as String,
              targetSource: selected,
            ),
          ),
        );
        expect(starts.map((s) => s.trainingSession.id).toSet().length, 1);
        final frozen = starts.first.runningTargetAdmissionSnapshot!;
        expect(frozen['quality']['selected_source'], selected);
        final accepted = applyRunningTargetAdmission(plan, frozen);
        final run = AuthoredTimedRunningExecution.fromBlock(
          accepted.blocks.single,
          admission: frozen,
        );
        final work = runningAtomicSteps(
          run.workout,
        ).where((s) => s.stepId == 'effort').single;
        if (selected == 'authored_rpe') {
          expect(work.target, const RunningTarget.rpe(7));
        } else {
          final window = alphaQualityPaceWindow(
            seconds: selected == 'five_k' ? 1500 : 300,
            category: 'threshold',
            manualThreshold: selected == 'manual_threshold',
          );
          expect(
            work.target,
            RunningTarget.paceRange(
              low: window.lower * 1000,
              high: window.upper * 1000,
            ),
          );
        }
        final clock = StructuredRunningController.fresh(
          execution: run,
          elapsedTime: () => Duration.zero,
        );
        clock.start();
        clock.elapse(const Duration(seconds: 430));
        final cursor = clock.cursor;
        clock.dispose();
        await store.confirmQuality(
          kind: 'five_k',
          seconds: 1700,
          date: today,
          sustained: true,
        );
        await store.confirmQuality(
          kind: 'manual_threshold',
          seconds: 310,
          manualOrigin: 'manual_entry',
        );
        await store.confirmQuality(kind: 'five_k', withdraw: true);
        await store.confirmQuality(kind: 'manual_threshold', withdraw: true);
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
        expect(after.cursor.isPaused, true);
        expect(
          after.cursor.remainingMilliseconds,
          cursor.remainingMilliseconds,
        );
        after.dispose();
        expect(
          await other
              .from('athlete_running_quality_inputs')
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
              .from('athlete_running_quality_inputs')
              .update({'five_k_seconds': 1})
              .eq('athlete_id', uid),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          other.rpc(
            'confirm_running_quality_input',
            params: {
              'p_expected_athlete_id': uid,
              'p_input_kind': 'five_k',
              'p_seconds': 1500,
              'p_result_date': today,
              'p_sustained': true,
            },
          ),
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
        changedSnapshot['runningTargetAdmissionV1']['quality']['selected_source'] =
            'forged';
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
        // Existing single-slot terminal programmes refuse retry after the
        // assignment becomes ineligible. Preserve that behavior, one record,
        // and the original target; do not claim idempotent success here.
        expect(replay['status'], 'validation_failure');
        expect(replay['code'], 'fixed_assignment_ineligible');
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
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: path == null ? 'Run through disposable quality gate' : false,
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
