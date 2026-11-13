// Opt-in against a positively identified disposable local Supabase stack.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/performance/repositories/supabase_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_completion.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_store.dart';
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

import 'm31_thursday_trial_fixture.dart';
import 'm31_trial_candidate_test.dart'
    show m31Candidate, gobletCandidate, gobletVersion;
import 'm32_trial_candidate_test.dart' show m32Candidate, m32Version;

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  final configFile = Platform.environment['M31_LOCAL_CONFIG'];
  for (final fixture in [
    (
      forTime: false,
      finishEarly: false,
      directory: m31Candidate,
      version: M31ThursdayEquipmentTrial.versionId,
      sourceLabel: 'Barbell Romanian deadlift',
      replacementLabel: 'Dumbbell Romanian Deadlift',
    ),
    (
      forTime: false,
      finishEarly: false,
      directory: gobletCandidate,
      version: gobletVersion,
      sourceLabel: 'Back Squat',
      replacementLabel: 'Goblet Squat',
    ),
    (
      forTime: true,
      finishEarly: false,
      directory: m32Candidate,
      version: m32Version,
      sourceLabel: 'Dumbbell lateral raise',
      replacementLabel: 'Barbell bench press',
    ),
    (
      forTime: true,
      finishEarly: true,
      directory: m32Candidate,
      version: m32Version,
      sourceLabel: 'Dumbbell lateral raise',
      replacementLabel: 'Barbell bench press',
    ),
  ]) {
    testWidgets(
      'ordinary athlete reviews, restarts and ${fixture.finishEarly ? 'finishes early' : 'completes'} ${fixture.directory}',
      (tester) async {
        final forTime = fixture.forTime;
        final approvalFile = forTime
            ? 'time-approval.json'
            : 'equipment-approval.json';
        final approvalData =
            jsonDecode(
                  File('${fixture.directory}/$approvalFile').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final sourceId = forTime
            ? 'EX-044'
            : approvalData['source_exercise_id'] as String;
        final replacementId = forTime
            ? 'EX-083'
            : approvalData['replacement_exercise_id'] as String;
        final requiredEquipment = approvalData['required_equipment'] as String?;
        final missingEquipment = approvalData['missing_equipment'] as String?;
        final needsPair = approvalData['matching_dumbbell_pair'] == true;
        final originalGraph = forTime
            ? (jsonDecode(
                            File(
                              '${fixture.directory}/protocol-graphs.json',
                            ).readAsStringSync(),
                          )
                          as List)
                      .single
                  as Map
            : null;
        final expectedPrescription = StrengthExercisePrescription.fromJson(
          (forTime
                  ? originalGraph!['blocks'][1]['exercises'][0]['prescription']
                  : approvalData['prescription'])
              as Map<String, dynamic>,
        );
        final loggedLabel = needsPair ? '16 kg per dumbbell' : '16 kg';
        final actualReps = forTime
            ? List.filled(4, 8)
            : [
                expectedPrescription.reps.minReps!,
                expectedPrescription.reps.maxReps!,
              ];
        if (needsPair) {
          expect(
            expectedPrescription.toJson(),
            M31ThursdayEquipmentTrial.prescription.toJson(),
          );
        }
        tester.view.physicalSize = const Size(900, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final trial = (await tester.runAsync(() async {
          final config =
              jsonDecode(File(configFile!).readAsStringSync()) as Map;
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
              email: 'adapt-local-$suffix@example.com',
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
          final strangerId = await register(stranger);
          final versionId = fixture.version;
          final slotKey = approvalData['slot_key'] as String;
          final protocolId = approvalData['protocol_id'] as String;
          const reader = ProgrammeAdaptationPermissionReader();
          ProgrammeExecutionContext query({
            required String assignmentId,
            required String occurrenceId,
            String? version,
            String? slot,
          }) => ProgrammeExecutionContext(
            assignmentId: assignmentId,
            programmeVersionId: version ?? versionId,
            sessionSlotId: '',
            weekNumber: 1,
            dayKey: 'day_4',
            sessionOrder: 1,
            plannedProtocolId: protocolId,
            effectiveProtocolId: protocolId,
            packageSlotKey: slot ?? slotKey,
            occurrenceId: occurrenceId,
          );
          Future<bool> canRead(
            ProgrammeAdaptationPermissionReader actor,
            ProgrammeExecutionContext scope,
          ) async {
            if (forTime) {
              final option = await actor.loadApprovedTime(scope);
              if (option == null) return false;
              expect(option.slotKey, slotKey);
              expect(option.protocolId, protocolId);
              expect(
                [
                  option.fullMinutes,
                  option.shortMinutes,
                  option.omittedPosition,
                ],
                [45, 30, 3],
              );
              expect(option.permission.athleteAgreementRequired, isTrue);
            } else {
              final approval = await actor.loadApprovedEquipment(scope);
              if (approval == null) return false;
              expect(approval.replacementId, replacementId);
              expect(approval.slotKey, slotKey);
              expect(approval.permission.athleteAgreementRequired, isTrue);
            }
            return true;
          }

          final absent = query(
            assignmentId: versionId,
            occurrenceId: versionId,
          );
          expect(await canRead(reader, absent), isFalse);
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
            await canRead(reader, absent),
            isFalse,
            reason: 'Eligibility alone grants no approval',
          );
          final today = await sql(
            "SELECT (now() AT TIME ZONE 'Asia/Makassar')::date",
          );
          final anchor = DateTime.parse(
            today,
          ).subtract(Duration(days: forTime ? 0 : 3));
          final assignmentId = await acquisition.acquire(versionId, anchor);
          const assignments = ProgrammeAssignmentSupabaseStore();
          final assignment = (await assignments.getActiveAssignment(
            athleteId,
          ))!;
          expect(assignment.id, assignmentId);
          final row = await client
              .from('programme_schedule_occurrences')
              .select()
              .eq('assignment_id', assignmentId)
              .single();
          final occurrenceId = row['id'] as String;
          final scope = query(
            assignmentId: assignmentId,
            occurrenceId: occurrenceId,
          );
          expect(await canRead(reader, scope), isTrue);
          final otherReader = ProgrammeAdaptationPermissionReader(
            client: stranger,
          );
          expect(await canRead(otherReader, scope), isFalse);
          for (final wrong in [
            query(assignmentId: versionId, occurrenceId: occurrenceId),
            query(assignmentId: assignmentId, occurrenceId: versionId),
            query(
              assignmentId: assignmentId,
              occurrenceId: occurrenceId,
              version: 'b0290b33-2764-4e5b-ad78-3d4beafbb375',
            ),
            query(
              assignmentId: assignmentId,
              occurrenceId: occurrenceId,
              slot: 'LW10K-W01-D01',
            ),
          ]) {
            expect(await canRead(reader, wrong), isFalse);
          }
          final otherAcquisition = SupabaseAcquisitionStore(
            athleteId: strangerId,
            client: stranger,
          );
          await otherAcquisition.saveSetup('Asia/Makassar', complete: true);
          await sql(
            "INSERT INTO public.private_programme_alpha_eligibility"
            "(athlete_id,programme_version_id) VALUES('$strangerId','$versionId')",
          );
          final otherAssignment = await otherAcquisition.acquire(
            versionId,
            anchor,
          );
          final otherRow = await stranger
              .from('programme_schedule_occurrences')
              .select('id')
              .eq('assignment_id', otherAssignment)
              .single();
          final otherScope = query(
            assignmentId: otherAssignment,
            occurrenceId: otherRow['id'] as String,
          );
          expect(await canRead(otherReader, otherScope), isTrue);
          expect(await canRead(reader, otherScope), isFalse);
          await otherAcquisition.endProgramme(
            assignmentId: otherAssignment,
            programmeVersionId: versionId,
          );
          expect(await canRead(otherReader, otherScope), isFalse);
          debugPrint(
            'OWNER PASS exact active assignment/version/occurrence/slot and removal after End programme for ${fixture.directory}',
          );
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
            sessionTitle: forTime
                ? 'Upper-body strength time trial'
                : 'Thursday selected strength',
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
            loadEquipmentApproval: reader.loadApprovedEquipment,
            loadTimeApproval: reader.loadApprovedTime,
          );
          final request = forTime
              ? const AdaptationRequest(
                  reason: AdaptationReason.time,
                  availableMinutes: 30,
                )
              : AdaptationRequest(
                  reason: AdaptationReason.equipment,
                  availableEquipment: {requiredEquipment!},
                  confirmedMatchingDumbbellPair: true,
                );
          if (!forTime) {
            expect(
              (await propose.propose(
                package: original,
                request: request,
                executionContext: context,
                slotKey: 'LW10K-W01-D01',
              )).isAcceptable,
              isFalse,
            );
          }
          for (final rejected in [
            if (forTime)
              const AdaptationRequest(
                reason: AdaptationReason.time,
                availableMinutes: 15,
              )
            else ...[
              if (needsPair)
                AdaptationRequest(
                  reason: AdaptationReason.equipment,
                  availableEquipment: {requiredEquipment!},
                ),
              AdaptationRequest(
                reason: AdaptationReason.equipment,
                availableEquipment: {requiredEquipment!, missingEquipment!},
                confirmedMatchingDumbbellPair: true,
              ),
            ],
          ]) {
            expect(
              (await propose.propose(
                package: original,
                request: rejected,
                executionContext: context,
              )).isAcceptable,
              isFalse,
            );
          }
          final before = jsonEncode(kv.debugDump);
          final reviewed = await propose.propose(
            package: original,
            request: request,
            executionContext: context,
          );
          expect(
            reviewed.isAcceptable,
            isTrue,
            reason: '${reviewed.noSafeReason} ${reviewed.athleteFacingMessage}',
          );
          expect(reviewed.exerciseChanges, hasLength(forTime ? 0 : 1));
          Future<void> verifyDecline() async {
            final declined = await prepareWith(
              kv,
            ).prepareFixedOccurrence(assignment, occurrence());
            expect(jsonEncode(kv.debugDump), before);
            expect(
              declined
                  .package!
                  .plan
                  .blocks[forTime ? 2 : 1]
                  .linkedExercises
                  .first
                  .exerciseId,
              sourceId,
            );
          }

          Future<TrainingSessionRecord> verifyAcceptance() async {
            final accept = ProgrammeAdaptationAcceptanceService(
              prepareService: prepare,
              loadEquipmentApproval: reader.loadApprovedEquipment,
              loadTimeApproval: reader.loadApprovedTime,
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
            if (forTime) {
              expect(restoredBlocks, originalBlocks.take(2).toList());
              expect(adapted.plan.durationMin, 30);
            } else {
              expect(restoredBlocks.first, originalBlocks.first);
              expect(restoredBlocks.last, originalBlocks.last);
              expect(
                restoredBlocks[1]['linkedExercises'].skip(1),
                originalBlocks[1]['linkedExercises'].skip(1),
              );
            }
            final replacement = adapted.plan.blocks[1].linkedExercises.first;
            expect(replacement.exerciseId, replacementId);
            expect(
              replacement.prescription!.toJson(),
              expectedPrescription.toJson(),
            );
            debugPrint(
              'ACCEPTANCE PASS decline preserves bytes; '
              '${forTime ? 'only the optional block is omitted' : 'only one exercise is replaced'} after acceptance',
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
                .singleWhere((e) => e.sourceExerciseId == replacementId);
            expect(movement.sets, hasLength(actualReps.length));
            expect(movement.sets.every((s) => s.load == null), isTrue);
            for (final block in List.of(capture.draft.blockDrafts)) {
              for (final exercise in block.exerciseResults) {
                if (forTime && exercise.sourceExerciseId != replacementId) {
                  continue;
                }
                for (final set
                    in fixture.finishEarly
                        ? exercise.sets.take(1)
                        : exercise.sets) {
                  capture.updateSet(
                    block.sourceBlockId,
                    exercise.sourceExerciseId,
                    set.setResultId,
                    (s) => s.copyWith(
                      reps: exercise.sourceExerciseId == replacementId
                          ? actualReps[set.setNumber - 1]
                          : set.setNumber == 1
                          ? 5
                          : 6,
                      load: exercise.sourceExerciseId == replacementId
                          ? 16
                          : 10,
                      loadUnit: 'kg',
                      completed: true,
                    ),
                  );
                }
              }
              if (!fixture.finishEarly || block.position == 1) {
                capture.markBlockComplete(block.sourceBlockId);
              }
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
            if (forTime) {
              expect(reopened.package!.plan.durationMin, 30);
              expect(
                codec.encodePlan(reopened.package!.plan)['blocks'],
                restoredBlocks,
              );
            }
            expect(
              reopened
                  .package!
                  .plan
                  .blocks[1]
                  .linkedExercises
                  .first
                  .prescription!
                  .toJson(),
              expectedPrescription.toJson(),
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
            final completionKey = 'm31-local-${row['id']}';
            if (fixture.finishEarly) {
              final completionStore = _DropFirstCompletionReply();
              final result =
                  await PerformanceRecordSaveCoordinator(
                    store: store,
                    programmeCompletionService:
                        AthleteProgrammeCompletionService(
                          store: completionStore,
                          performanceStore: store,
                        ),
                  ).completeSession(
                    controller: rebuilt,
                    programmeContext: reopened.executionContext!,
                    trainingSessionId: sessionId,
                    athleteId: athleteId,
                    idempotencyKey: completionKey,
                    finishEarly: true,
                  );
              expect(
                result.progressionFailed,
                isFalse,
                reason: result.progressionMessage,
              );
              expect(
                result.programmeCompletion?.status,
                AthleteProgrammeCompletionStatus.alreadyCommitted,
              );
              expect(completionStore.replies, [
                'committed',
                'already_committed',
              ]);
              expect(completionStore.requests, hasLength(2));
              expect(
                completionStore.requests.last,
                completionStore.requests.first,
              );
              expect(result.record.recordId, saved.recordId);
              expect(
                result.record.status,
                TrainingSessionRecordStatus.partiallyCompleted,
              );
              final outcome = await sql("""
                SELECT outcome_status || ':' || (completion_request_sha256 IS NOT NULL)::text
                  FROM public.programme_slot_outcomes
                  WHERE training_session_id = $sessionId;
              """);
              expect(outcome, 'completed_partial:true');
            } else {
              final completion = AthleteProgrammeCompletionService(
                store: const AthleteProgrammeCompletionSupabaseStore(),
                performanceStore: store,
              );
              final result = await completion.submit(
                controller: rebuilt,
                programmeContext: reopened.executionContext!,
                trainingSessionId: sessionId,
                idempotencyKey: completionKey,
              );
              expect(
                result.isSuccess,
                isTrue,
                reason: '${result.code}: ${result.message}',
              );
            }
            final history = await store.listHistory(athleteId: athleteId);
            expect(history, hasLength(1));
            expect(history.single.recordId, saved.recordId);
            if (fixture.finishEarly) {
              expect(
                history.single.status,
                TrainingSessionRecordStatus.partiallyCompleted,
              );
              expect(history.single.blockResults.map((b) => b.status), [
                TrainingBlockResultStatus.completed,
                TrainingBlockResultStatus.notStarted,
              ]);
            }

            if (forTime) {
              expect(history.single.blockResults.map((b) => b.position), [
                1,
                2,
              ]);
              expect(await canRead(reader, scope), isFalse);
            }
            final retained = history.single.blockResults
                .expand((b) => b.exerciseResults)
                .singleWhere((e) => e.sourceExerciseId == replacementId);
            expect(
              retained.setResults
                  .where((s) => s.completed)
                  .map((s) => [s.reps, s.load, s.loadUnit]),
              [
                for (final reps
                    in fixture.finishEarly ? actualReps.take(1) : actualReps)
                  [reps, 16, 'kg'],
              ],
            );
            final projected = CompletedExerciseResultProjection.fromExercise(
              retained,
              current: history.single,
              athleteHistory: history,
            );
            if (needsPair) {
              expect(projected.coachCue, expectedPrescription.coachCue);
            }
            expect(
              projected.sets.where((s) => s.loadLabel == loggedLabel),
              hasLength(fixture.finishEarly ? 1 : actualReps.length),
            );
            debugPrint(
              'HISTORY PASS $replacementId after cold restore and completion at $loggedLabel',
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
              forTime
                  ? 'Estimated session duration 45m → 30m'
                  : '${fixture.sourceLabel} → ${fixture.replacementLabel}',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              forTime
                  ? 'Omit Optional upper-body accessories. All remaining sets, reps and rests stay as prescribed.'
                  : needsPair
                  ? 'kg per dumbbell'
                  : 'log the load in kg',
            ),
            findsOneWidget,
          );
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
        final title = find.text(fixture.replacementLabel);
        await tester.scrollUntilVisible(title, 200);
        await tester.tap(title);
        await tester.pumpAndSettle();
        if (needsPair) {
          expect(find.text(expectedPrescription.coachCue!), findsOneWidget);
        }
        expect(find.text(loggedLabel), findsWidgets);
        expect(find.text(fixture.sourceLabel), findsNothing);
      },
      skip: configFile == null,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

/// Lose the acknowledgement after the real loopback RPC commits.
class _DropFirstCompletionReply implements AthleteProgrammeCompletionStore {
  final requests = <String>[];
  final replies = <Object?>[];

  @override
  Future<Map<String, dynamic>> completeAndAdvance(
    Map<String, dynamic> payload,
  ) async {
    requests.add(jsonEncode(payload));
    final reply = await const AthleteProgrammeCompletionSupabaseStore()
        .completeAndAdvance(payload);
    replies.add(reply['status']);
    if (requests.length == 1) {
      throw TimeoutException('Simulated lost completion acknowledgement');
    }
    return reply;
  }
}
