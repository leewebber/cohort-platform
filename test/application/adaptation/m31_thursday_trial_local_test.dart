// Opt-in against a positively identified disposable local Supabase stack.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cohort_platform/application/adaptation/m31_thursday_equipment_trial.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_acceptance_service.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_permission_reader.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_proposal_service.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/core/widgets/programme_adaptation_proposal_sheet.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_supabase_store.dart';
import 'package:cohort_platform/data/repositories/programme_version_supabase_store.dart';
import 'package:cohort_platform/features/auth/models/user_role.dart';
import 'package:cohort_platform/features/auth/repositories/supabase_profile_repository.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/performance/repositories/supabase_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  final configFile = Platform.environment['M31_LOCAL_CONFIG'];
  testWidgets(
    'ordinary local athlete admits, reviews, restarts and completes the exact Thursday trial',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final trial = (await tester.runAsync(() async {
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
            '-At',
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
        // Widget tests normally substitute a 400-only HTTP client. These two
        // clients use the explicitly checked disposable loopback endpoint.
        IOClient loopbackClient() => HttpOverrides.runWithHttpOverrides(
          () => IOClient(HttpClient()),
          _LoopbackHttpOverrides(),
        );
        final athleteHttp = loopbackClient();
        final strangerHttp = loopbackClient();
        addTearDown(athleteHttp.close);
        addTearDown(strangerHttp.close);
        await Supabase.initialize(
          url: api.toString(),
          publishableKey: anonKey,
          httpClient: athleteHttp,
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
          ),
        );
        addTearDown(Supabase.instance.dispose);
        final client = Supabase.instance.client;
        final stranger = SupabaseClient(
          api.toString(),
          anonKey,
          httpClient: strangerHttp,
          authOptions: const AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.implicit,
          ),
        );
        addTearDown(stranger.dispose);
        Future<String> register(SupabaseClient actor) async {
          final suffix = Random.secure().nextInt(1 << 32);
          final response = await actor.auth.signUp(
            email: 'm31-local-$suffix@example.com',
            password: 'Local-only-$suffix-aA!',
            data: {
              'display_name': 'Disposable M3.1 athlete',
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
                displayName: 'Disposable M3.1 athlete',
                roles: {UserRole.athlete},
              );
          expect(profile.isAthlete, isTrue);
          expect(profile.isCoach, isFalse);
          return uid;
        }

        final athleteId = await register(client);
        await register(stranger);
        const versionId = M31ThursdayEquipmentTrial.versionId;
        const slotKey = M31ThursdayEquipmentTrial.slotKey;
        const protocolId = M31ThursdayEquipmentTrial.protocolId;
        const reader = ProgrammeAdaptationPermissionReader();
        Future<List<Object>> permissions(String assignmentId) async =>
            reader.loadThursdayTrial(
              assignmentId: assignmentId,
              versionId: versionId,
              slotKey: slotKey,
            );
        expect(await permissions(versionId), isEmpty);
        final acquisition = SupabaseAcquisitionStore(
          athleteId: athleteId,
          client: client,
        );
        await acquisition.saveSetup('Asia/Makassar', complete: true);
        await sql(
          "INSERT INTO public.private_programme_alpha_eligibility"
          "(athlete_id,programme_version_id) VALUES('$athleteId','$versionId')",
        );
        expect(
          await permissions(versionId),
          isEmpty,
          reason: 'Eligibility alone grants no permission',
        );
        final today = await sql(
          "SELECT (now() AT TIME ZONE 'Asia/Makassar')::date",
        );
        final anchor = DateTime.parse(today).subtract(const Duration(days: 3));
        final assignmentId = await acquisition.acquire(versionId, anchor);
        final rows = await reader.loadThursdayTrial(
          assignmentId: assignmentId,
          versionId: versionId,
          slotKey: slotKey,
        );
        expect(rows.single.id, M31ThursdayEquipmentTrial.permissionId);
        expect(rows.single.targetRef, slotKey);
        expect(rows.single.athleteAgreementRequired, isTrue);
        expect(
          await ProgrammeAdaptationPermissionReader(
            client: stranger,
          ).loadThursdayTrial(
            assignmentId: assignmentId,
            versionId: versionId,
            slotKey: slotKey,
          ),
          isEmpty,
        );
        expect(await permissions(versionId), isEmpty);
        expect(
          await reader.loadThursdayTrial(
            assignmentId: assignmentId,
            versionId: 'b0290b33-2764-4e5b-ad78-3d4beafbb375',
            slotKey: slotKey,
          ),
          isEmpty,
        );
        expect(
          await reader.loadThursdayTrial(
            assignmentId: assignmentId,
            versionId: versionId,
            slotKey: 'LW10K-W01-D01',
          ),
          isEmpty,
        );
        debugPrint(
          'RLS PASS ordinary athlete receives one exact permission; eligibility only, wrong athlete, version and slot receive zero',
        );

        const assignments = ProgrammeAssignmentSupabaseStore();
        final assignment = (await assignments.getActiveAssignment(athleteId))!;
        expect(assignment.id, assignmentId);
        final row = await client
            .from('programme_schedule_occurrences')
            .select()
            .eq('assignment_id', assignmentId)
            .single();
        FixedProgrammeOccurrenceProjection occurrence({
          int? trainingSessionId,
        }) => FixedProgrammeOccurrenceProjection(
          assignmentId: assignmentId,
          occurrenceId: row['id'] as String,
          sessionSlotId: row['session_slot_id'] as String,
          programmeVersionId: versionId,
          protocolId: protocolId,
          programmedSessionKey: row['programmed_session_key'] as String,
          weekNumber: row['week_number'] as int,
          dayKey: row['day_key'] as String,
          sessionOrder: row['session_order'] as int,
          scheduledDate: row['scheduled_date'] as String,
          originalScheduledDate: row['original_scheduled_date'] as String,
          state: trainingSessionId == null
              ? FixedProgrammeOccurrenceState.today
              : FixedProgrammeOccurrenceState.inProgress,
          sessionTitle: 'Thursday selected strength',
          trainingSessionId: trainingSessionId,
        );

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
        final prepared = await prepare.prepareFixedOccurrence(
          assignment,
          occurrence(),
        );
        expect(
          prepared.isReady,
          isTrue,
          reason: '${prepared.code}: ${prepared.message}',
        );
        final original = prepared.package!;
        final context = prepared.executionContext!;
        expect(context.packageSlotKey, slotKey);
        final propose = ProgrammeAdaptationProposalService(
          loadAdaptationPermissions: reader.load,
        );
        const request = AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {M31ThursdayEquipmentTrial.dumbbell},
          confirmedMatchingDumbbellPairWithoutBarbell: true,
        );
        expect(
          (await propose.propose(
            package: original,
            request: request,
            slotKey: 'LW10K-W01-D01',
          )).isAcceptable,
          isFalse,
        );
        for (final rejected in const [
          AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment: {M31ThursdayEquipmentTrial.dumbbell},
          ),
          AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment: {
              M31ThursdayEquipmentTrial.dumbbell,
              M31ThursdayEquipmentTrial.barbell,
            },
            confirmedMatchingDumbbellPairWithoutBarbell: true,
          ),
        ]) {
          expect(
            (await propose.propose(
              package: original,
              request: rejected,
              slotKey: slotKey,
            )).isAcceptable,
            isFalse,
          );
        }
        final before = jsonEncode(kv.debugDump);
        final reviewed = await propose.propose(
          package: original,
          request: request,
          slotKey: slotKey,
        );
        expect(
          reviewed.isAcceptable,
          isTrue,
          reason: '${reviewed.noSafeReason} ${reviewed.athleteFacingMessage}',
        );
        expect(reviewed.exerciseChanges, hasLength(1));
        Future<void> verifyDecline() async {
          final declined = await prepareWith(
            kv,
          ).prepareFixedOccurrence(assignment, occurrence());
          expect(jsonEncode(kv.debugDump), before);
          expect(
            declined.package!.plan.blocks[1].linkedExercises.first.exerciseId,
            'EX-078',
          );
        }

        Future<TrainingSessionRecord> verifyAcceptance() async {
          final accept = ProgrammeAdaptationAcceptanceService(
            prepareService: prepare,
            loadAdaptationPermissions: reader.load,
          );
          final accepted = await accept.accept(
            athleteId: athleteId,
            currentPackage: original,
            proposal: reviewed,
            executionContext: context,
          );
          expect(
            accepted.success,
            isTrue,
            reason: '${accepted.errorCode}: ${accepted.message}',
          );
          final adapted = accepted.package!;
          const codec = SessionExecutionPlanCodec();
          final restoredBlocks =
              codec.encodePlan(adapted.plan)['blocks'] as List;
          final originalBlocks =
              codec.encodePlan(original.plan)['blocks'] as List;
          expect(restoredBlocks.first, originalBlocks.first);
          expect(restoredBlocks.last, originalBlocks.last);
          expect(
            restoredBlocks[1]['linkedExercises'].skip(1),
            originalBlocks[1]['linkedExercises'].skip(1),
          );
          final replacement = adapted.plan.blocks[1].linkedExercises.first;
          expect(replacement.exerciseId, 'EX-040');
          expect(
            replacement.prescription!.toJson(),
            M31ThursdayEquipmentTrial.prescription.toJson(),
          );
          debugPrint(
            'ACCEPTANCE PASS decline preserves bytes; exact single placement changes only after acceptance',
          );

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
          final capture =
              PerformanceCaptureController.initializeFromExecutionPlan(
                plan: adapted.plan,
                athleteId: athleteId,
                trainingSessionId: sessionId,
                programmeContext: context,
              );
          final movement = capture.draft.blockDrafts
              .expand((b) => b.exerciseResults)
              .singleWhere((e) => e.sourceExerciseId == 'EX-040');
          expect(movement.sets, hasLength(2));
          expect(movement.sets.every((s) => s.load == null), isTrue);
          for (final block in List.of(capture.draft.blockDrafts)) {
            for (final exercise in block.exerciseResults) {
              for (final set in exercise.sets) {
                capture.updateSet(
                  block.sourceBlockId,
                  exercise.sourceExerciseId,
                  set.setResultId,
                  (s) => s.copyWith(
                    reps: set.setNumber == 1 ? 5 : 6,
                    load: exercise.sourceExerciseId == 'EX-040' ? 16 : 10,
                    loadUnit: 'kg',
                    completed: true,
                  ),
                );
              }
            }
            capture.markBlockComplete(block.sourceBlockId);
          }
          final store = SupabasePerformanceRecordStore();
          final saved = await PerformanceRecordSaveCoordinator(
            store: store,
          ).saveDraft(controller: capture);
          final fresh = InMemoryKvStore();
          final persisted =
              jsonDecode(jsonEncode(kv.debugDump)) as Map<String, dynamic>;
          for (final entry in persisted.entries) {
            await fresh.writeString(entry.key, entry.value as String);
          }
          final reopened = await prepareWith(fresh).prepareFixedOccurrence(
            assignment,
            occurrence(trainingSessionId: sessionId),
          );
          expect(
            reopened.isReady,
            isTrue,
            reason: '${reopened.code}: ${reopened.message}',
          );
          expect(reopened.package!.hasAcceptedAdaptation, isTrue);
          expect(
            reopened.package!.plan.blocks[1].linkedExercises.first.prescription!
                .toJson(),
            M31ThursdayEquipmentTrial.prescription.toJson(),
          );
          final resumed = await launcher.createOrResumeLaunchResult(
            athleteId: athleteId,
            programmeContext: reopened.executionContext!,
            package: reopened.package!,
          );
          expect(resumed.trainingSession.id, sessionId);
          final readback = await store.getInProgressForTrainingSession(
            athleteId: athleteId,
            trainingSessionId: sessionId,
          );
          expect(readback!.recordId, saved.recordId);
          final rebuilt = PerformanceRecordSaveCoordinator(
            store: store,
          ).restoreControllerFromRecord(readback);
          final completion = AthleteProgrammeCompletionService(
            store: const AthleteProgrammeCompletionSupabaseStore(),
            performanceStore: store,
          );
          final result = await completion.submit(
            controller: rebuilt,
            programmeContext: reopened.executionContext!,
            trainingSessionId: sessionId,
            idempotencyKey: 'm31-local-${row['id']}',
          );
          expect(
            result.isSuccess,
            isTrue,
            reason: '${result.code}: ${result.message}',
          );
          final history = await store.listHistory(athleteId: athleteId);
          expect(history, hasLength(1));
          expect(history.single.recordId, saved.recordId);
          final retained = history.single.blockResults
              .expand((b) => b.exerciseResults)
              .singleWhere((e) => e.sourceExerciseId == 'EX-040');
          expect(retained.setResults.map((s) => [s.reps, s.load, s.loadUnit]), [
            [5, 16, 'kg'],
            [6, 16, 'kg'],
          ]);
          final projected = CompletedExerciseResultProjection.fromExercise(
            retained,
            current: history.single,
            athleteHistory: history,
          );
          expect(projected.coachCue, M31ThursdayEquipmentTrial.cue);
          expect(projected.sets.map((s) => s.loadLabel), [
            '16 kg per dumbbell',
            '16 kg per dumbbell',
          ]);
          debugPrint(
            'HISTORY PASS cold restore, same session/record, one completion, 5 and 6 reps at 16 kg per dumbbell, cue retained',
          );
          return history.single;
        }

        return (
          proposal: reviewed,
          verifyDecline: verifyDecline,
          verifyAcceptance: verifyAcceptance,
        );
      }))!;
      bool? reviewResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    reviewResult = await showProgrammeAdaptationProposalSheet(
                      context,
                      trial.proposal,
                    );
                  },
                  child: const Text('Open trial review'),
                );
              },
            ),
          ),
        ),
      );
      Future<void> reviewAndTap(String label) async {
        await tester.tap(find.text('Open trial review'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'Barbell Romanian deadlift → Dumbbell Romanian deadlift',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('kg per dumbbell'), findsOneWidget);
        final button = find.text(label);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await reviewAndTap('Keep Original Session');
      expect(reviewResult, isFalse);
      await tester.runAsync(trial.verifyDecline);
      await reviewAndTap('Accept Adaptation');
      expect(reviewResult, isTrue);
      final record = (await tester.runAsync(trial.verifyAcceptance))!;
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
      final title = find.text('Dumbbell Romanian deadlift');
      await tester.scrollUntilVisible(title, 200);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text(M31ThursdayEquipmentTrial.cue), findsOneWidget);
      expect(find.text('16 kg per dumbbell'), findsNWidgets(2));
      expect(find.text('Barbell Romanian deadlift'), findsNothing);
    },
    skip: configFile == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
