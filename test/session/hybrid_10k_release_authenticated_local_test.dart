// Opt-in loopback-only proof. Real approved content; synthetic disposable actors,
// eligibility, acquisitions and actuals. No hosted/client credentials are retained.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_role.dart';
import 'package:cohort_platform/features/auth/repositories/supabase_profile_repository.dart';
import 'package:cohort_platform/features/auth/services/auth_service.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_store.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_supabase_store.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/session/services/running_target_admission_store.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/authored_timed_running_execution.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/features/session/models/production_restore_envelope.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/production_session_ui_cursor.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/repositories/supabase_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/programme/content/hybrid_10k_release_copy.dart';

const candidate = 'docs/programmes/hybrid_10k/release_candidate_2026_11_04';

class CapturingCompletion implements AthleteProgrammeCompletionStore {
  CapturingCompletion(this.client);
  final SupabaseClient client;
  Map<String, dynamic>? last;
  bool lose = false;
  @override
  Future<Map<String, dynamic>> completeAndAdvance(
    Map<String, dynamic> payload,
  ) async {
    last = payload;
    final result = Map<String, dynamic>.from(
      await client.rpc(
            'complete_fixed_programme_occurrence_and_advance',
            params: {'payload': payload},
          )
          as Map,
    );
    if (lose) {
      lose = false;
      throw const SocketException('Simulated lost local response after commit');
    }
    return result;
  }
}

void main() {
  final path = Platform.environment['COHORT_H10K_CONFIG'];
  test(
    'genuine release: ordinary local auth/acquisition, starts, persistence, expiry/renewal, completion/retry/correction/History',
    () async {
      final config = jsonDecode(File(path!).readAsStringSync()) as Map;
      final api = Uri.parse(config['API_URL'] as String);
      expect(api.scheme, 'http');
      expect(api.host, '127.0.0.1');
      final container = config['CONTAINER'] as String;
      expect(container, startsWith('supabase_db_s12g'));
      Future<String> sql(String q) async {
        final process = await Process.start('docker', [
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
        process.stdin.write(q);
        await process.stdin.close();
        final out = await utf8.decoder.bind(process.stdout).join();
        final err = await utf8.decoder.bind(process.stderr).join();
        expect(await process.exitCode, 0, reason: err);
        return out.trim();
      }

      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: api.toString(),
        publishableKey: config['ANON_KEY'] as String,
        debug: false,
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() => Supabase.instance.dispose());
      final client = Supabase.instance.client;
      final auth = AuthController(
        authService: AuthService(client: client),
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: SupabaseProfileRepository(client: client),
        ),
      );
      addTearDown(auth.dispose);
      await auth.signUp(
        email:
            'h10k-release-${DateTime.now().microsecondsSinceEpoch}@example.com',
        password: 'Local-only-${Random.secure().nextInt(1 << 32)}-aA!',
        displayName: 'Disposable Hybrid 10K actor',
        roles: {UserRole.athlete},
      );
      expect(
        client.auth.currentUser,
        isNotNull,
        reason: auth.state.errorMessage,
      );
      final uid = client.auth.currentUser!.id;
      addTearDown(CurrentUserSession.clear);
      final meta = jsonDecode(
        File('$candidate/CANDIDATE.json').readAsStringSync(),
      );
      final vid = meta['proposed_programme_version_id'] as String;
      final acq = SupabaseAcquisitionStore(athleteId: uid, client: client);
      expect((await acq.loadSetup()).complete, isFalse);
      await acq.saveSetup('Asia/Makassar', complete: false);
      final restart = SupabaseClient(
        api.toString(),
        config['ANON_KEY'] as String,
        authOptions: AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(restart.dispose);
      await restart.auth.recoverSession(
        jsonEncode(client.auth.currentSession!.toJson()),
      );
      final reopenedSetup = await SupabaseAcquisitionStore(
        athleteId: uid,
        client: restart,
      ).loadSetup();
      expect(reopenedSetup.timezone, 'Asia/Makassar');
      expect(reopenedSetup.complete, isFalse);
      await acq.saveSetup('Asia/Makassar', complete: true);
      expect(await acq.catalogue(), isEmpty);
      // Test fixture grants only, inside the positively identified disposable DB.
      await sql(
        "INSERT INTO public.private_programme_alpha_eligibility(athlete_id,programme_version_id) VALUES('$uid','$vid');",
      );
      final offers = await acq.catalogue();
      expect(offers, hasLength(1));
      expect(offers.single.ready, isTrue);
      expect(offers.single.summary, contains('56 local calendar days'));
      final today = await sql(
        "SELECT (transaction_timestamp() AT TIME ZONE 'Asia/Makassar')::date;",
      );
      // A disposable past anchor makes all selected source cases due.
      // Input freshness is still evaluated at today's actual server date.
      final anchor = DateTime.parse(today).subtract(const Duration(days: 70));
      final assignment = await acq.acquire(vid, anchor);
      expect(
        await acq.acquire(vid, anchor.add(const Duration(days: 1))),
        assignment,
      );
      final restartedAcq = SupabaseAcquisitionStore(
        athleteId: uid,
        client: restart,
      );
      expect((await restartedAcq.catalogue()).single.assignmentId, assignment);
      final ass = (await client
          .from('programme_assignments')
          .select()
          .eq('id', assignment)
          .single());
      expect(ass['materialised_package_content_hash'], meta['package_sha256']);
      expect(ass['started_at'], anchor.toIso8601String().substring(0, 10));
      final occurrences = await client
          .from('programme_schedule_occurrences')
          .select()
          .eq('assignment_id', assignment)
          .order('original_scheduled_date');
      expect(occurrences, hasLength(60));
      final targets = SupabaseRunningTargetAdmissionStore(
        athleteId: uid,
        client: client,
      );
      final start = ProgrammeTrainingSessionStartSupabaseStore(client: client);
      final launcher = ProgrammeSessionExecutionLauncher(startStore: start);
      final store = SupabasePerformanceRecordStore();
      final coordinator = PerformanceRecordSaveCoordinator(store: store);
      final completion = CapturingCompletion(client);
      final results = <Map<String, dynamic>>[];
      String day(int age) => DateTime.parse(
        today,
      ).subtract(Duration(days: age)).toIso8601String().substring(0, 10);
      for (final reference in [
        'LW10K-W01-D01',
        'LW10K-W01-D02',
        'LW10K-W01-D03',
        'LW10K-W06-D05',
        'LW10K-W10-D07',
      ]) {
        final week = int.parse(reference.substring(7, 9)),
            dayNumber = int.parse(reference.substring(11, 13));
        final occurrence = occurrences.singleWhere(
          (o) => o['week_number'] == week && o['day_key'] == 'day_$dayNumber',
        );
        final oid = occurrence['id'] as String;
        final protocol = occurrence['protocol_id'] as String;
        final loaded = await SessionExecutionLoader().load(
          protocolId: protocol,
        );
        var plan = loaded.plan;
        expect(plan.hasExecutableBlocks, isTrue);
        expect(
          plan.blocks.first.coachNotes,
          contains(
            (jsonDecode(
                      File(
                        'docs/programmes/hybrid_10k/d8_approved_integration_2026_11_04/ATHLETE_WORDING.json',
                      ).readAsStringSync(),
                    )['weekly']
                    as List)
                .singleWhere((w) => w['week'] == week)['approved_text'],
          ),
        );
        final ctx = ProgrammeExecutionContext(
          assignmentId: assignment,
          programmeVersionId: vid,
          sessionSlotId: occurrence['session_slot_id'] as String,
          weekNumber: week,
          dayKey: occurrence['day_key'] as String,
          sessionOrder: occurrence['session_order'] as int,
          plannedProtocolId: protocol,
          effectiveProtocolId: protocol,
          lineageCode: hybrid10kLineageCode,
          packageContentHash: meta['package_sha256'] as String,
          programmedSessionKey: occurrence['programmed_session_key'] as String,
          occurrenceId: oid,
          packageSchemaVersion: 2,
        );
        String? reviewHash, source;
        if (requiresZone2Admission(plan)) {
          expect(
            (await start.createOrResume({'occurrence_id': oid}))['code'],
            'running_target_review_required',
          );
          await targets.confirmZone(120, 145);
          final review = await targets.review(oid);
          expect(review['status'], 'review_required');
          reviewHash = review['review_hash'] as String;
        }
        if (requiresQualityAdmission(plan)) {
          await targets.confirmQuality(
            kind: 'five_k',
            seconds: 1500,
            date: day(57),
            sustained: true,
          );
          expect(
            (await targets.reviewQuality(oid, 'five_k'))['reason'],
            'stale_5k',
          );
          final refused = await start.createOrResume({
            'occurrence_id': oid,
            'target_source': 'five_k',
          });
          expect(refused['code'], 'running_target_review_required');
          expect(
            await sql(
              "SELECT count(*) FROM public.training_sessions WHERE athlete_id='$uid' AND protocol_id='$protocol';",
            ),
            '0',
          );
          if (week == 6) {
            expect(
              (await targets.reviewQuality(oid, 'manual_threshold'))['reason'],
              'manual_threshold_only_for_threshold',
            );
          }
          await targets.confirmQuality(
            kind: 'five_k',
            seconds: 1500,
            date: day(56),
            sustained: true,
          );
          final cutoff = await targets.reviewQuality(oid, 'five_k');
          expect(cutoff['status'], 'review_required');
          await targets.confirmQuality(
            kind: 'five_k',
            seconds: 1501,
            date: today,
            sustained: true,
          );
          expect(
            (await start.createOrResume({
              'occurrence_id': oid,
              'target_source': 'five_k',
              'target_review_hash': cutoff['review_hash'],
            }))['reason'],
            'missing_or_stale_review',
          );
          final ready = await targets.reviewQuality(oid, 'five_k');
          expect(ready['status'], 'review_required');
          expect(ready['authored_rpe_available'], isNot(true));
          reviewHash = ready['review_hash'] as String;
          source = 'five_k';
        }
        final prepared = PreparedExecutionPackage(
          programmedSessionKey: ProgrammedSessionKey.parse(
            ctx.programmedSessionKey!,
          ),
          plan: plan,
          brief: WorkoutSessionBrief(sessionName: plan.sessionTitle),
          preparedAt: DateTime.now(),
          assignmentId: assignment,
          programmeVersionId: vid,
          packageContentHash: ctx.packageContentHash,
          dayKey: ctx.dayKey,
          slotOrder: ctx.sessionOrder,
          protocolId: protocol,
        );
        final launched = await launcher.createOrResumeLaunchResult(
          athleteId: uid,
          programmeContext: ctx,
          package: prepared,
          targetReviewHash: reviewHash,
          targetSource: source,
        );
        final sid = launched.trainingSession.id;
        final frozen = launched.runningTargetAdmissionSnapshot;
        if (frozen != null) plan = applyRunningTargetAdmission(plan, frozen);
        ProductionRestoreEnvelope? persisted;
        final capture =
            PerformanceCaptureController.initializeFromExecutionPlan(
              plan: plan,
              athleteId: uid,
              trainingSessionId: sid,
              programmeContext: ctx,
            );
        if (dayNumber == 1) {
          for (final block in List.of(capture.draft.blockDrafts)) {
            for (final exercise in block.exerciseResults) {
              for (final set in exercise.sets) {
                capture.updateSet(
                  block.sourceBlockId,
                  exercise.sourceExerciseId,
                  set.setResultId,
                  (s) => s.copyWith(
                    reps: 6,
                    load: 10,
                    loadUnit: 'kg',
                    completed: true,
                  ),
                );
              }
            }
            capture.markBlockComplete(block.sourceBlockId);
          }
        } else {
          final block = plan.blocks.single;
          final run = AuthoredTimedRunningExecution.fromBlock(
            block,
            admission: frozen,
          );
          final clock = StructuredRunningController.fresh(
            execution: run,
            elapsedTime: () => Duration.zero,
          );
          clock.start();
          clock.elapse(const Duration(seconds: 7));
          clock.pause();
          final cursor = clock.cursor;
          clock.dispose();
          final envelope = ProductionRestoreEnvelope(
            identity: ProductionSessionDraft(
              schemaVersion: 1,
              athleteId: uid,
              assignmentId: assignment,
              programmeVersionId: vid,
              programmedSessionKey: ctx.programmedSessionKey!,
              packageContentHash: ctx.packageContentHash!,
              trainingSessionId: sid,
              entryMode: 'live',
              occurrenceId: oid,
            ),
            cursor: ProductionSessionUiCursor(
              schemaVersion: 4,
              athleteId: uid,
              assignmentId: assignment,
              trainingSessionId: sid,
              occurrenceId: oid,
              activeBlockId: block.blockId,
              timedRunning: {block.blockId: cursor},
            ),
          );
          final kv = InMemoryKvStore();
          await AthleteLocalRepository(kv).saveProductionRestoreEnvelope(
            athleteId: uid,
            trainingSessionId: sid,
            payload: envelope.toJson(),
          );
          final durable = jsonDecode(jsonEncode(kv.debugDump)) as Map;
          final fresh = InMemoryKvStore();
          for (final entry in durable.entries) {
            await fresh.writeString(entry.key as String, entry.value as String);
          }
          final decoded = ProductionRestoreEnvelope.fromJson(
            (await AthleteLocalRepository(fresh).readProductionRestoreEnvelope(
              athleteId: uid,
              trainingSessionId: sid,
            ))!,
          );
          persisted = decoded;
          expect(
            await AthleteLocalRepository(fresh).readProductionRestoreEnvelope(
              athleteId: 'foreign',
              trainingSessionId: sid,
            ),
            isNull,
          );
          final restored = StructuredRunningController.restore(
            execution: run,
            cursor: decoded.cursor!.timedRunning[block.blockId]!,
            wallClock: () => DateTime.utc(2099),
          );
          expect(restored.cursor.isPaused, isTrue);
          expect(
            restored.cursor.remainingMilliseconds,
            cursor.remainingMilliseconds,
          );
          restored.dispose();
          capture.updateBlockResultData(
            block.blockId,
            EnduranceResultData(
              durationSeconds: week == 10 ? 2400 : 1200,
              distance: week == 10 ? 10 : 4,
              distanceUnit: 'km',
            ),
          );
          capture.markBlockComplete(block.blockId);
          if (week == 10) {
            final distance = StructuredRunningController.fresh(
              execution: run,
              elapsedTime: () => Duration.zero,
            );
            distance.start();
            distance.elapse(const Duration(minutes: 15));
            expect(distance.isDistanceStep, isTrue);
            expect(distance.cursor.isPaused, isTrue);
            distance.start();
            distance.elapse(const Duration(minutes: 40));
            expect(distance.isDistanceStep, isTrue);
            distance.confirmDistanceStep();
            expect(distance.cursor.isPaused, isTrue);
            distance.start();
            distance.elapse(const Duration(minutes: 5));
            expect(distance.cursor.isFinished, isTrue);
            distance.dispose();
          }
        }
        expect(
          capture.validateForCompletion().isValid,
          isTrue,
          reason: capture.validateForCompletion().fieldErrors.toString(),
        );
        final saved = await coordinator.saveDraft(controller: capture);
        final reloaded = await SupabasePerformanceRecordStore()
            .getInProgressForTrainingSession(
              athleteId: uid,
              trainingSessionId: sid,
            );
        expect(reloaded, isNotNull);
        final rebuilt = coordinator.restoreControllerFromRecord(reloaded!);
        expect(
          rebuilt.draft.blockDrafts.length,
          capture.draft.blockDrafts.length,
        );
        expect(rebuilt.draft.recordId, saved.recordId);
        final savedEnvelope = persisted;
        if (savedEnvelope != null) {
          ProductionRestoreRequest request({bool completed = false}) =>
              ProductionRestoreRequest(
                athleteId: uid,
                assignmentId: assignment,
                programmeVersionId: vid,
                programmedSessionKey: ctx.programmedSessionKey!,
                packageContentHash: ctx.packageContentHash!,
                occurrenceId: oid,
                trainingSessionId: sid,
                persistedIdentity: savedEnvelope.identity,
                cursor: savedEnvelope.cursor,
                actuals: rebuilt.draft,
                hostedCompleted: completed,
              );
          expect(
            const ProductionRestoreResolver().resolve(request()).outcome,
            ProductionRestoreOutcome.resumable,
          );
          expect(
            const ProductionRestoreResolver()
                .resolve(request(completed: true))
                .outcome,
            ProductionRestoreOutcome.completedHosted,
          );
        }
        if (frozen != null) {
          await targets.confirmQuality(kind: 'five_k', withdraw: true);
          await targets.confirmZone(null, null, withdraw: true);
          await restart.auth.recoverSession(
            jsonEncode(client.auth.currentSession!.toJson()),
          );
          final resumed = await ProgrammeTrainingSessionStartSupabaseStore(
            client: restart,
          ).createOrResume({'occurrence_id': oid});
          expect(resumed['running_target_admission_snapshot'], frozen);
        }
        completion.lose = true;
        final service = AthleteProgrammeCompletionService(
          store: completion,
          performanceStore: store,
        );
        final submitted = await service.submit(
          controller: rebuilt,
          programmeContext: ctx,
          trainingSessionId: sid,
          idempotencyKey: 'h10k-local-$oid',
        );
        // A genuinely lost acknowledgement may require an explicit retry; exact same
        // payload must recover the committed identity, never a new completion.
        final replay = await completion.completeAndAdvance(completion.last!);
        expect(
          replay['status'],
          'already_committed',
          reason: '$submitted / $replay',
        );
        final terminal = await store.getById(saved.recordId);
        expect(terminal, isNotNull);
        final corrected = await store.correctCompleted(
          PerformanceCorrectionDraft(terminal!)
            ..athleteNote = 'Disposable correction for $reference',
        );
        expect(corrected.recordId, saved.recordId);
        final afterCorrection = await completion.completeAndAdvance(
          completion.last!,
        );
        expect(
          afterCorrection['completion_record']['athlete_note'],
          'Disposable correction for $reference',
        );
        expect(
          (await store.listHistory(
            athleteId: uid,
            limit: 100,
          )).any((r) => r.recordId == saved.recordId),
          isTrue,
        );
        expect(
          await sql(
            "SELECT count(*) FROM public.training_session_records WHERE training_session_id=$sid;",
          ),
          '1',
        );
        results.add({
          'source_session_id': reference,
          'authenticated_start': true,
          'draft_save_reopen': true,
          'paused_json_restart': dayNumber != 1,
          'frozen_inputs_preserved': frozen != null,
          'completion_retry_correction_history': true,
        });
      }
      final out = Platform.environment['COHORT_H10K_REPORT'];
      if (out != null) {
        File(out).writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({'classification': 'GENUINE_CANDIDATE_LOCAL_GOTRUE_POSTGREST_SYNTHETIC_ACTOR_PROOF', 'package_sha256': meta['package_sha256'], 'local_signup_onboarding_draft_restart': true, 'get_programme_free_exact_acquisition_retry': true, 'expiry_57_refused_56_eligible_and_renewal_review_required': true, 'no_real_or_hosted_account_assignment_athlete_writes': true, 'sessions': results, 'installed_device_acceptance': 'NOT_PERFORMED', 'Gate_A': 'OPEN'})}\n',
        );
      }
    },
    skip: path == null ? 'Opt-in disposable loopback only' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
