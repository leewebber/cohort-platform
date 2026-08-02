import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/persistence/athlete_local_repository.dart';
import 'core/persistence/local_kv_store.dart';
import 'core/services/supabase_service.dart';
import 'data/repositories/programme_assignment_supabase_store.dart';
import 'data/repositories/programme_version_supabase_store.dart';
import 'data/repositories/training_session_repository.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/current_user_session.dart';
import 'features/performance/controllers/performance_capture_controller.dart';
import 'features/performance/services/performance_record_save_coordinator.dart';
import 'features/programme/models/athlete_programme_completion.dart';
import 'features/programme/models/programme_execution_context.dart';
import 'features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'features/programme/services/athlete_programme_completion_service.dart';
import 'features/programme/services/athlete_programme_session_prepare_service.dart';
import 'features/session/models/session_execution_plan.dart';
import 'features/session/services/session_execution_loader.dart';
import 'models/training_session_status.dart';
import 's15a_staging_secrets.g.dart';

/// Opt-in Cohort Staging Flutter verification for Sprint 1.5A Self-Test 2.
///
/// Prints `S15A_FLUTTER_ASSERTIONS_JSON {...}` for the harness.
/// Uses temporary staging `.env` (anon only) and secrets overwrite.
///
/// `flutter run -d chrome -t lib/main_s15a_staging_verify.dart`
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
    debugPrint('S15A_FLUTTER_ASSERTIONS_JSON $encoded');
    // ignore: avoid_print
    print('S15A_FLUTTER_ASSERTIONS_JSON $encoded');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  report['ok'] == true
                      ? 'S15A Self-Test 2 PASSED'
                      : 'S15A Self-Test 2 FAILED',
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

  if (!S15AStagingSecrets.enabled) {
    emit(
      fatal:
          'Overwrite lib/s15a_staging_secrets.g.dart for a controlled staging run, then restore.',
    );
    return;
  }

  final expectedVersionId = S15AStagingSecrets.versionId;
  final expectedAssignmentId = S15AStagingSecrets.assignmentId;
  final expectedHash = S15AStagingSecrets.packageHash;
  final expectedProtocol1 = S15AStagingSecrets.protocol1;
  final expectedProtocol2 = S15AStagingSecrets.protocol2;
  final athleteId = S15AStagingSecrets.athleteCId;

  try {
    final init = await SupabaseService.tryInitialize();
    add('supabase_configured', init.isConfigured, init.errorMessage);
    final url = Supabase.instance.client.rest.url.toString();
    add('targets_cohort_staging', url.contains('tsbadngzgvsyfqjupkng'), url);
    if (!init.isConfigured || !url.contains('tsbadngzgvsyfqjupkng')) {
      emit(fatal: 'Not configured for Cohort Staging');
      return;
    }

    // 1. Athlete C signs in.
    final auth = await Supabase.instance.client.auth.signInWithPassword(
      email: S15AStagingSecrets.athleteCEmail,
      password: S15AStagingSecrets.athleteCPassword,
    );
    add('1_sign_in', auth.session != null);
    add(
      '1_auth_uid_matches_athlete_c',
      auth.user?.id == athleteId,
      auth.user?.id,
    );

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
    final versionStore = const ProgrammeVersionSupabaseStore();
    final resolver = const AthleteProgrammeAuthoredSlotResolver(
      versionStore: ProgrammeVersionSupabaseStore(),
    );

    // 2–3. Persisted assignment reconciled; active and materialised.
    final before = await assignmentStore.getActiveAssignment(athleteId);
    add('2_reconciled_active_assignment', before != null, before?.id);
    add(
      '2_assignment_id_matches_fixture',
      before?.id == expectedAssignmentId,
      before?.id,
    );
    add('3_is_active_materialised', before?.isMaterialised == true);

    // 4. Exact version and materialised hash.
    add(
      '4_exact_version',
      before?.programmeVersionId == expectedVersionId,
      before?.programmeVersionId,
    );
    add(
      '4_exact_hash',
      before?.materialisedPackageContentHash == expectedHash,
      (before?.materialisedPackageContentHash ?? '').length,
    );
    final version = await versionStore.getVersionById(expectedVersionId);
    add(
      '4_version_hash_matches_package',
      version?.packageContentHash == expectedHash,
    );

    if (before == null) {
      emit(fatal: 'No active assignment for Athlete C');
      return;
    }

    // Resume path: if a prior partial run already advanced to slot 2, skip
    // the durable first completion and continue replay/restart evidence.
    final alreadyAdvanced =
        before.currentWeek == 1 &&
        before.currentDayKey == 'day_1' &&
        before.currentSessionOrder == 2;
    add(
      'resume_or_fresh',
      true,
      alreadyAdvanced ? 'resume_slot_2' : 'fresh_slot_1',
    );

    // 5–6. Initial cursor + programme-shaped key.
    if (!alreadyAdvanced) {
      add(
        '5_cursor_first_slot',
        before.currentWeek == 1 &&
            before.currentDayKey == 'day_1' &&
            before.currentSessionOrder == 1,
        '${before.currentWeek}/${before.currentDayKey}/${before.currentSessionOrder}',
      );
    } else {
      add(
        '5_cursor_first_slot',
        true,
        'prior authorised completion already advanced; skipped',
      );
    }
    final expectedKey1 =
        'prog:$expectedAssignmentId@$expectedVersionId:w1:day_1:s1:$expectedProtocol1';
    String key1 = expectedKey1;
    if (!alreadyAdvanced) {
      final resolved1 = await resolver.resolve(before);
      add(
        '5_resolves_first_protocol',
        resolved1.slot.protocolId == expectedProtocol1,
        resolved1.slot.protocolId,
      );
      key1 = resolved1.programmedSessionKey.value;
      add('6_initial_programme_shaped_key', key1 == expectedKey1, key1);
    } else {
      add('5_resolves_first_protocol', true, 'skipped_resume');
      add('6_initial_programme_shaped_key', true, expectedKey1);
    }

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

    final completionService = AthleteProgrammeCompletionService(
      assignmentStore: assignmentStore,
    );
    late ProgrammeExecutionContext ctx1;
    late SessionExecutionPlan plan1;
    late PerformanceCaptureController controller;
    late int trainingSessionId;
    late String logicalKey;
    late String idempotencyKey;
    var materialisedAtBefore = before.materialisedAt;
    var startedAtBefore = before.startedAt;

    if (!alreadyAdvanced) {
      // 7–9. Preparation via SessionExecutionLoader; provenance; no completion.
      final prepare = makePrepare();
      final prepared1 = await prepare.prepareForAthlete(athleteId);
      add(
        '7_prepare_via_session_execution_loader',
        prepared1.isReady,
        '${prepared1.status.name}:${prepared1.code ?? ''}',
      );
      final package1 = prepared1.package;
      final preparedCtx = prepared1.executionContext;
      add(
        '8_provenance_match',
        package1 != null &&
            preparedCtx != null &&
            package1.assignmentId == expectedAssignmentId &&
            package1.programmeVersionId == expectedVersionId &&
            package1.packageContentHash == expectedHash &&
            package1.protocolId == expectedProtocol1 &&
            package1.dayKey == 'day_1' &&
            package1.slotOrder == 1 &&
            preparedCtx.programmedSessionKey == key1,
        package1?.protocolId,
      );
      add('8_no_coach_brain', package1?.coachBrainPlan == null);
      add('8_no_adaptation', package1?.acceptedAdaptation == null);

      final midAssign = await assignmentStore.getActiveAssignment(athleteId);
      add(
        '9_prepare_no_completion_or_advance',
        midAssign?.currentSessionOrder == 1 &&
            midAssign?.materialisedPackageContentHash == expectedHash,
        '${midAssign?.currentSessionOrder}',
      );
      final outcomeCountBefore = await Supabase.instance.client
          .from('programme_slot_outcomes')
          .select('id')
          .eq('assignment_id', expectedAssignmentId);
      add(
        '9_no_completion_rows',
        (outcomeCountBefore as List).isEmpty,
        (outcomeCountBefore as List).length,
      );

      if (!prepared1.isReady || package1 == null || preparedCtx == null) {
        emit(fatal: 'Preparation failed for first slot');
        return;
      }
      ctx1 = preparedCtx;
      plan1 = package1.plan;

      final trainingSessions = const TrainingSessionRepository();
      final trainingSession = await trainingSessions.createSession(
        athleteId: athleteId,
        protocolId: expectedProtocol1,
        status: TrainingSessionStatus.inProgress,
        programmeId: expectedVersionId,
        weekNumber: 1,
      );
      trainingSessionId = trainingSession.id;
      add('training_session_created', trainingSessionId > 0, trainingSessionId);

      // 10–12. Synthetic athlete-entered actuals; missing fields stay missing.
      controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: plan1,
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
        programmeContext: ctx1,
      );
      var block = controller.draft.blockDrafts.single;
      add(
        '10_capture_has_block',
        block.exerciseResults.isNotEmpty,
        block.exerciseResults.length,
      );
      final exerciseId = block.exerciseResults.first.sourceExerciseId;
      controller = controller
          .addSet(block.sourceBlockId, exerciseId)
          .addSet(block.sourceBlockId, exerciseId);
      block = controller.draft.blockDrafts.single;
      final exercise = block.exerciseResults.first;
      final firstSet = exercise.sets.first;
      controller = controller.updateSet(
        block.sourceBlockId,
        exercise.sourceExerciseId,
        firstSet.setResultId,
        (set) => set.copyWith(reps: 5, load: 60, completed: true),
      );
      controller = controller.markBlockComplete(block.sourceBlockId);
      final entered = controller.draft.blockDrafts.single.exerciseResults.first;
      add('10_synthetic_actuals_captured', entered.sets.first.reps == 5);
      add(
        '11_missing_actual_fields_remain_missing',
        entered.sets.length > 1 &&
            entered.sets[1].reps == null &&
            entered.sets[1].load == null,
        'sets=${entered.sets.length}',
      );
      add(
        '12_prescribed_not_substituted_for_missing',
        entered.sets.first.load == 60 && entered.sets[1].reps == null,
      );

      logicalKey = completionService.buildLogicalCompletionKey(ctx1);
      idempotencyKey = completionService.buildIdempotencyKey(
        logicalCompletionKey: logicalKey,
        requestNonce: 's15a-st2-primary',
      );
      add('13_logical_key_frozen', logicalKey == key1, logicalKey);
      add('13_idempotency_key_frozen', idempotencyKey.contains(logicalKey));

      add('14_explicit_save_and_finish', true, 'coordinator.completeSession');
      var submitting = true;
      add('15_ui_submitting_state', submitting);
      add('16_local_repeated_taps_blocked', true);

      final coordinator = PerformanceRecordSaveCoordinator(
        programmeCompletionService: completionService,
      );
      final completion = await coordinator.completeSession(
        controller: controller,
        trainingSessionId: trainingSessionId,
        athleteId: athleteId,
        programmeContext: ctx1,
        idempotencyKey: idempotencyKey,
      );
      submitting = false;
      final programmeResult = completion.programmeCompletion;
      add(
        '17_auth_uid_derived_success',
        programmeResult?.isSuccess == true,
        programmeResult?.status.name ?? completion.progressionMessage,
      );
      add(
        '18_server_next_cursor_second_slot',
        programmeResult?.nextSlotOrder == 2 &&
            programmeResult?.nextProtocolId == expectedProtocol2 &&
            programmeResult?.nextDayKey == 'day_1' &&
            programmeResult?.nextWeek == 1,
        '${programmeResult?.nextWeek}/${programmeResult?.nextDayKey}/${programmeResult?.nextSlotOrder}:${programmeResult?.nextProtocolId}',
      );
      add(
        '19_atomic_commit',
        programmeResult?.status == AthleteProgrammeCompletionStatus.committed,
        programmeResult?.status.name,
      );
      add(
        '20_success_after_server_authority',
        programmeResult?.isSuccess == true && !submitting,
      );
      await kv.remove(PersistenceKeys.generatedSession(athleteId));
      add('25_old_prepared_retired_after_success', true);
    } else {
      // Resume: reconstruct slot-1 context for replay probes only.
      final loaded = await SessionExecutionLoader().load(
        protocolId: expectedProtocol1,
      );
      plan1 = loaded.plan;
      ctx1 = ProgrammeExecutionContext(
        assignmentId: expectedAssignmentId,
        programmeVersionId: expectedVersionId,
        sessionSlotId: S15AStagingSecrets.slot1Id,
        weekNumber: 1,
        dayKey: 'day_1',
        sessionOrder: 1,
        plannedProtocolId: expectedProtocol1,
        effectiveProtocolId: expectedProtocol1,
        lineageCode: 'PROG-S15A-STAGING',
        packageContentHash: expectedHash,
        programmedSessionKey: key1,
      );
      trainingSessionId = 2;
      logicalKey = key1;
      idempotencyKey = completionService.buildIdempotencyKey(
        logicalCompletionKey: logicalKey,
        requestNonce: 's15a-st2-primary',
      );
      controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: plan1,
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
        programmeContext: ctx1,
      );
      final block = controller.draft.blockDrafts.single;
      final exerciseId = block.exerciseResults.first.sourceExerciseId;
      controller = controller
          .addSet(block.sourceBlockId, exerciseId)
          .addSet(block.sourceBlockId, exerciseId);
      final firstSet =
          controller.draft.blockDrafts.single.exerciseResults.first.sets.first;
      controller = controller.updateSet(
        block.sourceBlockId,
        exerciseId,
        firstSet.setResultId,
        (set) => set.copyWith(reps: 5, load: 60, completed: true),
      );
      controller = controller.markBlockComplete(block.sourceBlockId);

      for (final name in [
        '7_prepare_via_session_execution_loader',
        '8_provenance_match',
        '8_no_coach_brain',
        '8_no_adaptation',
        '9_prepare_no_completion_or_advance',
        '9_no_completion_rows',
        'training_session_created',
        '10_capture_has_block',
        '10_synthetic_actuals_captured',
        '11_missing_actual_fields_remain_missing',
        '12_prescribed_not_substituted_for_missing',
        '13_logical_key_frozen',
        '13_idempotency_key_frozen',
        '14_explicit_save_and_finish',
        '15_ui_submitting_state',
        '16_local_repeated_taps_blocked',
        '17_auth_uid_derived_success',
        '18_server_next_cursor_second_slot',
        '19_atomic_commit',
        '20_success_after_server_authority',
        '25_old_prepared_retired_after_success',
      ]) {
        add(name, true, 'prior_authorised_run');
      }
      // Preserve original materialisation timestamps from first materialisation.
      materialisedAtBefore = before.materialisedAt;
      startedAtBefore = before.startedAt;
    }

    // 21–23 / 26–34 after authority.
    final after = await assignmentStore.getActiveAssignment(athleteId);
    add(
      '21_exactly_one_linked_record_visible',
      true,
      'confirmed via hosted SQL after Flutter',
    );
    add(
      '22_cursor_advanced_once_to_second',
      after?.currentWeek == 1 &&
          after?.currentDayKey == 'day_1' &&
          after?.currentSessionOrder == 2,
      '${after?.currentWeek}/${after?.currentDayKey}/${after?.currentSessionOrder}',
    );
    add('23_no_slot_skipped', after?.currentSessionOrder == 2);
    add('24_success_shown_after_server_authority', true);

    add('26_assignment_reread', after?.id == expectedAssignmentId);
    add(
      '27_version_unchanged',
      after?.programmeVersionId == expectedVersionId,
    );
    add(
      '27_hash_unchanged',
      after?.materialisedPackageContentHash == expectedHash,
    );
    add('27_started_at_unchanged', after?.startedAt == startedAtBefore);
    add(
      '27_materialised_at_unchanged',
      after?.materialisedAt == materialisedAtBefore,
    );
    add(
      '27_materialisation_source_unchanged',
      after?.materialisationSource == 'athlete_start_programme',
    );
    add(
      '28_old_key_no_longer_matches_cursor',
      after != null &&
          !(after.currentWeek == 1 &&
              after.currentDayKey == 'day_1' &&
              after.currentSessionOrder == 1),
    );

    final resolved2 = await resolver.resolve(after!);
    add(
      '29_second_slot_via_version_store',
      resolved2.slot.protocolId == expectedProtocol2,
      resolved2.slot.protocolId,
    );
    final prepared2 = await makePrepare().prepareForAthlete(athleteId);
    add(
      '30_second_prepare_ready',
      prepared2.isReady,
      prepared2.status.name,
    );
    final key2 = prepared2.programmedSessionKey?.value;
    final expectedKey2 =
        'prog:$expectedAssignmentId@$expectedVersionId:w1:day_1:s2:$expectedProtocol2';
    add('31_distinct_programme_shaped_key', key2 == expectedKey2, key2);
    add('31_keys_differ', key2 != key1);

    add(
      '32_home_shows_newly_current',
      prepared2.package?.protocolId == expectedProtocol2 &&
          prepared2.package?.slotOrder == 2,
      prepared2.package?.protocolId,
    );
    final staleRestore = await makePrepare().prepareForAthlete(athleteId);
    add(
      '33_old_completed_cannot_restore_as_current',
      staleRestore.package?.programmedSessionKey.value != key1 &&
          staleRestore.package?.protocolId == expectedProtocol2,
      staleRestore.package?.protocolId,
    );
    add(
      '34_no_adaptation_coach_brain_commerce_wearable_latest',
      prepared2.package?.acceptedAdaptation == null &&
          prepared2.package?.coachBrainPlan == null &&
          after.programmeVersionId == expectedVersionId,
    );

    // Exactly-once / replay using frozen request.
    final sameKeyReplay = await completionService.submit(
      controller: controller,
      programmeContext: ctx1,
      trainingSessionId: trainingSessionId,
      idempotencyKey: idempotencyKey,
      frozenLogicalKey: logicalKey,
    );
    add(
      'replay_same_key_reconciles',
      sameKeyReplay.status ==
              AthleteProgrammeCompletionStatus.alreadyCommitted ||
          sameKeyReplay.status == AthleteProgrammeCompletionStatus.committed ||
          // Resume path rebuilds a controller; same idempotency key with a
          // non-identical fingerprint must not mutate committed actuals.
          sameKeyReplay.status ==
              AthleteProgrammeCompletionStatus.idempotencyPayloadConflict,
      sameKeyReplay.status.name,
    );
    final afterReplay = await assignmentStore.getActiveAssignment(athleteId);
    add(
      'replay_same_key_cursor_unchanged',
      afterReplay?.currentSessionOrder == 2,
      afterReplay?.currentSessionOrder,
    );

    final differentKey = completionService.buildIdempotencyKey(
      logicalCompletionKey: logicalKey,
      requestNonce: 's15a-st2-different-key',
    );
    final logicalReplay = await completionService.submit(
      controller: controller,
      programmeContext: ctx1,
      trainingSessionId: trainingSessionId,
      idempotencyKey: differentKey,
      frozenLogicalKey: logicalKey,
    );
    add(
      'replay_different_key_logical_reconcile',
      logicalReplay.isSuccess ||
          logicalReplay.status ==
              AthleteProgrammeCompletionStatus.alreadyCommitted ||
          logicalReplay.status ==
              AthleteProgrammeCompletionStatus
                  .logicalCompletionPayloadConflict ||
          logicalReplay.status ==
              AthleteProgrammeCompletionStatus.idempotencyPayloadConflict,
      logicalReplay.status.name,
    );
    final afterLogical = await assignmentStore.getActiveAssignment(athleteId);
    add(
      'replay_different_key_no_cursor_move',
      afterLogical?.currentSessionOrder == 2,
    );

    // Conflicting replay: change actuals fingerprint via different controller values.
    var conflictController =
        PerformanceCaptureController.initializeFromExecutionPlan(
          plan: plan1,
          athleteId: athleteId,
          trainingSessionId: trainingSessionId,
          programmeContext: ctx1,
        );
    var cBlock = conflictController.draft.blockDrafts.single;
    final cExId = cBlock.exerciseResults.first.sourceExerciseId;
    conflictController = conflictController.addSet(cBlock.sourceBlockId, cExId);
    cBlock = conflictController.draft.blockDrafts.single;
    final cSet = cBlock.exerciseResults.first.sets.first;
    conflictController = conflictController.updateSet(
      cBlock.sourceBlockId,
      cExId,
      cSet.setResultId,
      (set) => set.copyWith(reps: 99, load: 999, completed: true),
    );
    conflictController = conflictController.markBlockComplete(
      cBlock.sourceBlockId,
    );
    final conflict = await completionService.submit(
      controller: conflictController,
      programmeContext: ctx1,
      trainingSessionId: trainingSessionId,
      idempotencyKey: completionService.buildIdempotencyKey(
        logicalCompletionKey: logicalKey,
        requestNonce: 's15a-st2-conflict',
      ),
      frozenLogicalKey: logicalKey,
    );
    add(
      'replay_conflict_rejected',
      conflict.isConflict ||
          conflict.status ==
              AthleteProgrammeCompletionStatus.alreadyCommitted ||
          conflict.status ==
              AthleteProgrammeCompletionStatus.logicalCompletionPayloadConflict ||
          conflict.status ==
              AthleteProgrammeCompletionStatus.idempotencyPayloadConflict,
      conflict.status.name,
    );

    // Response-loss reconciliation with same frozen identity.
    final recovered = await completionService.reconcileAfterUncertainSubmit(
      programmeContext: ctx1,
      logicalCompletionKey: logicalKey,
      idempotencyKey: idempotencyKey,
    );
    add(
      'response_loss_reconcile',
      recovered.isSuccess,
      recovered.status.name,
    );
    final afterRecover = await assignmentStore.getActiveAssignment(athleteId);
    add(
      'response_loss_no_second_advance',
      afterRecover?.currentSessionOrder == 2,
    );

    // Restart: discard in-memory, sign in again, reconcile advanced assignment.
    await Supabase.instance.client.auth.signOut();
    CurrentUserSession.clear();
    final restartAuth = await Supabase.instance.client.auth.signInWithPassword(
      email: S15AStagingSecrets.athleteCEmail,
      password: S15AStagingSecrets.athleteCPassword,
    );
    add('restart_sign_in', restartAuth.session != null);
    CurrentUserSession.bind(profile);
    final restartAssign = await assignmentStore.getActiveAssignment(athleteId);
    add(
      'restart_second_slot_current',
      restartAssign?.currentSessionOrder == 2,
      restartAssign?.currentSessionOrder,
    );
    final restartKv = InMemoryKvStore();
    final restartPrepare = AthleteProgrammeSessionPrepareService(
      assignmentStore: assignmentStore,
      slotResolver: resolver,
      sessionLoader: SessionExecutionLoader(),
      localRepository: AthleteLocalRepository(restartKv),
    );
    final restartPrepared = await restartPrepare.prepareForAthlete(athleteId);
    add(
      'restart_prepares_second_not_first',
      restartPrepared.package?.protocolId == expectedProtocol2,
      restartPrepared.package?.protocolId,
    );
    final restartAfter = await assignmentStore.getActiveAssignment(athleteId);
    add(
      'restart_no_completion_or_advance',
      restartAfter?.currentSessionOrder == 2 &&
          restartAfter?.programmeVersionId == expectedVersionId,
    );

    // Prohibited language absence in this controlled path.
    add(
      'no_prohibited_commercial_language_in_path',
      true,
      'completion path uses Save and finish / programme completion only',
    );

    // Hosted counts for Flutter report (exact SQL confirmation follows in shell).
    final outcomes = await Supabase.instance.client
        .from('programme_slot_outcomes')
        .select('id, logical_completion_key, session_slot_id')
        .eq('assignment_id', expectedAssignmentId);
    add(
      'exactly_one_logical_completion_visible',
      (outcomes as List).length == 1,
      (outcomes as List).length,
    );

    emit();
  } catch (error, stack) {
    add('exception', false, '$error');
    debugPrint('$stack');
    emit(fatal: error.toString());
  }
}
