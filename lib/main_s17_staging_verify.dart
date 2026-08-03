import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/adaptation/programme_adaptation_acceptance_service.dart';
import 'application/adaptation/programme_adaptation_proposal_service.dart';
import 'core/persistence/athlete_local_repository.dart';
import 'core/persistence/local_kv_store.dart';
import 'data/repositories/programme_assignment_supabase_store.dart';
import 'data/repositories/programme_version_supabase_store.dart';
import 'data/repositories/training_session_repository.dart';
import 'domain/programme_scheduling/programme_scheduling_domain.dart';
import 'domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'features/adaptation/services/adaptation_policy_gate.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/current_user_session.dart';
import 'features/performance/controllers/performance_capture_controller.dart';
import 'features/programme/services/athlete_catalogue_enrolment_service.dart';
import 'features/programme/services/athlete_catalogue_enrolment_supabase_store.dart';
import 'features/programme/services/athlete_plan_materialisation_service.dart';
import 'features/programme/services/athlete_plan_materialisation_supabase_store.dart';
import 'features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'features/programme/services/athlete_programme_completion_service.dart';
import 'features/programme/services/athlete_programme_session_prepare_service.dart';
import 'features/programme/services/athlete_programme_switch_catalog_service.dart';
import 'features/programme/services/programme_catalog_service_impl.dart';
import 'features/programme/services/programme_schedule_apply_service.dart';
import 'features/programme/services/programme_schedule_apply_supabase_store.dart';
import 'features/programme/services/programme_schedule_operations_supabase_store.dart';
import 'features/programme/services/programme_schedule_projection_supabase_store.dart';
import 'features/programme/services/programme_schedule_restore_service.dart';
import 'features/session/services/session_execution_loader.dart';
import 'features/workout_player/models/previous_performance_snapshot.dart';
import 'models/adaptation_request.dart';
import 'models/adaptation_reason.dart';
import 'models/training_session_status.dart';
import 'staging/s17_adaptation_harness.dart';
import 'staging/s17_completion_harness.dart';
import 'staging/s17_isolation_prereq.dart';
import 'staging/s17_occurrence_baseline.dart';
import 'staging/s17_preparation_adapters.dart';
import 'staging/s17_previous_performance_harness.dart';
import 'staging/s17_resume_mode.dart';
import 'staging/s17_schedule_preparation.dart';
import 'staging/s17_staging_journey_matrix.dart';
import 'staging/s17_staging_runtime_config.dart';

/// Cohort Staging Athlete D verification for Phase 1.6 / Sprint 1.7.
///
/// Runtime config arrives only via `--dart-define-from-file` (private temp JSON).
/// Does not read shared `.env` or tracked staging secret stubs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var config = S17StagingRuntimeConfig.fromEnvironment();
  final results = S17StagingJourneyMatrix.allNotRun();
  final details = <String, String>{
    for (final code in S17StagingJourneyMatrix.codes)
      code: 'Harness loaded; journey not started',
  };
  final prerequisites = <String, Map<String, String>>{};
  List<String> selected = S17StagingJourneyMatrix.codes;
  try {
    if (config.resumeMode) {
      selected = S17ResumeMode.parseSelectedJourneys(
        config.selectedJourneysRaw,
      );
      for (final code in S17StagingJourneyMatrix.codes) {
        if (!selected.contains(code)) {
          results[code] = S17JourneyResult.notRun;
          details[code] =
              'Skipped in resume mode (already passed or not selected)';
        }
      }
    }
  } catch (e) {
    prerequisites['PREREQ_IDENTITY'] = {
      'result': 'FAIL',
      'detail': 'Invalid resume journey selection',
    };
  }

  Future<void> emit() async {
    final selectedSet = selected.toSet();
    final releaseOk =
        selectedSet.isNotEmpty &&
        selectedSet.every((c) => results[c] == S17JourneyResult.pass);
    final report = S17JourneyReport(results: results, details: details);
    final encoded = jsonEncode({
      ...report.toJson(),
      'ok': releaseOk,
      'resume_mode': config.resumeMode,
      'selected': selected,
      'prerequisites': prerequisites,
      'identity': config.enabled
          ? config.redactedIdentity()
          : const <String, String>{},
      'matrix': S17StagingJourneyMatrix.codes,
    });
    debugPrint('S17_FLUTTER_JOURNEY_JSON $encoded');
    // ignore: avoid_print
    print('S17_FLUTTER_JOURNEY_JSON $encoded');
    final exitCode = releaseOk ? 0 : 1;
    // ignore: avoid_print
    print('S17_FLUTTER_COMPLETE exit=$exitCode');
    debugPrint('S17_FLUTTER_COMPLETE exit=$exitCode');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  releaseOk
                      ? 'S17 Athlete D journeys PASSED'
                      : 'S17 Athlete D journeys incomplete / failed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: releaseOk
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                ...S17StagingJourneyMatrix.journeys.map((j) {
                  final result = results[j.code]!;
                  return Text(
                    '${result.label} ${j.code}. ${j.title}'
                    '${details[j.code] != null ? ' | ${details[j.code]}' : ''}',
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!kIsWeb) {
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  void setResult(String code, S17JourneyResult result, [String? detail]) {
    results[code] = result;
    if (detail != null) details[code] = detail;
  }

  void setPrereq(String code, S17JourneyResult result, String detail) {
    prerequisites[code] = {'result': result.label, 'detail': detail};
  }

  final configError = config.validationError();
  if (configError != null) {
    for (final code in S17StagingJourneyMatrix.codes) {
      setResult(code, S17JourneyResult.notRun, configError);
    }
    await emit();
    return;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
  } catch (e) {
    for (final code in S17StagingJourneyMatrix.codes) {
      setResult(code, S17JourneyResult.blocked, 'Supabase init failed');
    }
    await emit();
    return;
  }

  final client = Supabase.instance.client;
  final url = client.rest.url.toString();
  if (!url.contains(S17StagingRuntimeConfig.stagingHostMarker) ||
      url.contains(S17StagingRuntimeConfig.productionRefPrefix)) {
    for (final code in S17StagingJourneyMatrix.codes) {
      setResult(
        code,
        S17JourneyResult.fail,
        'Client did not target Cohort Staging',
      );
    }
    await emit();
    return;
  }

  try {
    final auth = await client.auth.signInWithPassword(
      email: config.athleteEmail,
      password: config.athletePassword,
    );
    if (auth.session == null || auth.user?.id != config.athleteId) {
      setResult('A', S17JourneyResult.fail, 'Athlete D authentication failed');
      for (final code in S17StagingJourneyMatrix.codes.skip(1)) {
        setResult(code, S17JourneyResult.notRun, 'Blocked by auth failure');
      }
      await emit();
      return;
    }

    final profileRow = await client
        .from('profiles')
        .select()
        .eq('id', config.athleteId)
        .single();
    final profile = UserProfile.fromMap(
      Map<String, dynamic>.from(profileRow as Map),
    );
    CurrentUserSession.bind(profile);

    final assignmentStore = const ProgrammeAssignmentSupabaseStore();
    final assignment = await assignmentStore.getActiveAssignment(
      config.athleteId,
    );
    bool? foreignProbe;
    try {
      final foreign = await client
          .from('programme_assignments')
          .select('id')
          .neq('athlete_id', config.athleteId)
          .limit(1);
      foreignProbe = (foreign as List).isNotEmpty;
      // Do not inspect or log foreign ids — presence alone is the signal.
    } catch (_) {
      foreignProbe = null;
    }

    final isolation = S17IsolationPrereq.assess(
      authenticated: true,
      isAthlete: profile.isAthlete,
      isCoach: profile.isCoach,
      ownAssignmentFound: assignment != null,
      ownAssignmentOwned:
          assignment != null && assignment.athleteId == config.athleteId,
      foreignProbe: foreignProbe,
    );
    setPrereq('PREREQ_A', isolation.overallResult, isolation.reportDetail);
    setPrereq(
      'PREREQ_IDENTITY',
      isolation.overallResult,
      isolation.reportDetail,
    );
    if (isolation.isolationBreachProven) {
      for (final code in selected) {
        if (['C', 'D', 'F', 'G', 'H', 'I', 'J', 'K'].contains(code)) {
          setResult(
            code,
            S17JourneyResult.fail,
            'Stopped: isolation breach suspected (FOREIGN=FAIL)',
          );
        }
      }
      await emit();
      return;
    }
    if (!config.resumeMode) {
      setResult('A', isolation.overallResult, isolation.reportDetail);
    }

    final versionStore = const ProgrammeVersionSupabaseStore();
    final prepare = AthleteProgrammeSessionPrepareService(
      assignmentStore: assignmentStore,
      slotResolver: const AthleteProgrammeAuthoredSlotResolver(
        versionStore: ProgrammeVersionSupabaseStore(),
      ),
      sessionLoader: SessionExecutionLoader(),
      localRepository: AthleteLocalRepository(InMemoryKvStore()),
    );
    final prepared1 = await prepare.prepareForAthlete(config.athleteId);
    final prepared2 = await prepare.prepareForAthlete(config.athleteId);
    final version = await versionStore.getVersionById(config.versionId);
    final preparedOk =
        prepared1.isReady &&
        prepared2.isReady &&
        version != null &&
        assignment?.programmeVersionId == config.versionId &&
        prepared1.package?.programmedSessionKey ==
            prepared2.package?.programmedSessionKey;
    setPrereq(
      'PREREQ_B',
      preparedOk ? S17JourneyResult.pass : S17JourneyResult.fail,
      preparedOk
          ? 'Prepared execution stable for assigned version'
          : 'Prepared execution mismatch',
    );
    if (!config.resumeMode) {
      setResult(
        'B',
        preparedOk ? S17JourneyResult.pass : S17JourneyResult.fail,
        preparedOk
            ? 'Prepared execution stable for assigned version'
            : 'Prepared execution mismatch',
      );
    }

    final local = AthleteLocalRepository(InMemoryKvStore());
    final restore = ProgrammeScheduleRestoreService(
      store: const ProgrammeScheduleProjectionSupabaseStore(),
      localRepository: local,
    );
    final apply = ProgrammeScheduleApplyService(
      applyStore: const ProgrammeScheduleApplySupabaseStore(),
      restoreService: restore,
      localRepository: local,
      prepareService: prepare,
    );
    final ops = const ProgrammeScheduleOperationsSupabaseStore();

    final restored1 = await restore.ensureAndRestore(
      athleteId: config.athleteId,
      programmeAssignmentId: config.assignmentId,
    );
    final restored2 = await restore.ensureAndRestore(
      athleteId: config.athleteId,
      programmeAssignmentId: config.assignmentId,
    );
    final projectionOk =
        restored1.isSuccess &&
        restored2.isSuccess &&
        restored1.projection != null &&
        restored2.projection != null &&
        restored1.projection!.scheduleRevision ==
            restored2.projection!.scheduleRevision &&
        restored1.projection!.occurrences.length ==
            restored2.projection!.occurrences.length;
    setPrereq(
      'PREREQ_E',
      projectionOk ? S17JourneyResult.pass : S17JourneyResult.fail,
      projectionOk
          ? 'Projection deterministic across restore'
          : 'Projection unstable or missing',
    );
    // Resume mode must never record journey E as PASS — A/B/E are PREREQ only.
    if (!config.resumeMode) {
      setResult(
        'E',
        projectionOk ? S17JourneyResult.pass : S17JourneyResult.fail,
        projectionOk
            ? 'Projection deterministic across restore'
            : 'Projection unstable or missing',
      );
    }

    var selectedJourneysUnlocked = false;
    if (!projectionOk || restored1.projection == null) {
      setPrereq(
        'PREREQ_PREP',
        S17JourneyResult.fail,
        'PREP_FAIL stage=projectionRestore Projection unavailable',
      );
      setPrereq(
        'PREREQ_BASELINE',
        S17JourneyResult.fail,
        'BASELINE_FAIL projection unavailable',
      );
      for (final code in selected) {
        if (['C', 'D', 'F', 'G', 'H', 'I', 'J', 'K'].contains(code)) {
          setResult(
            code,
            S17JourneyResult.fail,
            'Blocked: projection unavailable',
          );
        }
      }
    } else {
      final today = SessionOccurrenceDate.fromDateTime(DateTime.now().toUtc());
      var snapshot = restore.snapshotForPreview(
        projection: restored1.projection!,
        today: today,
      );
      var scheduled = snapshot.projection.occurrences
          .where((o) => o.isUncompleted)
          .toList();
      final baselineSnap = S17OccurrenceBaselineSnapshot(
        authoredExecutableSlotCount:
            config.lineageCode == S17OccurrenceBaseline.oneSlotCatalogueLineage
            ? 1
            : scheduled.length,
        projectedOccurrenceCount: snapshot.projection.occurrences.length,
        uncompletedOccurrenceCount: scheduled.length,
        completedOrSkippedCount:
            snapshot.projection.occurrences.length - scheduled.length,
        lineageCode: config.lineageCode,
        schedulingHorizonEnd: snapshot.schedulingHorizonEnd?.toString(),
      );

      final enrolService = AthleteCatalogueEnrolmentService(
        enrolmentStore: const AthleteCatalogueEnrolmentSupabaseStore(),
        assignmentStore: assignmentStore,
      );
      final matService = AthletePlanMaterialisationService(
        materialisationStore: const AthletePlanMaterialisationSupabaseStore(),
        assignmentStore: assignmentStore,
        legacyHasActivePlan: () => false,
      );
      final catalog = AthleteProgrammeSwitchCatalogService(
        catalogService: ProgrammeCatalogServiceImpl(
          versionStore: versionStore,
          coachId: CurrentUserSession.maybeInstance?.coachId ?? '',
        ),
      );
      final prepOrchestrator = S17SchedulePreparation(
        catalogue: S17AthleteCatalogueLookupAdapter(
          catalog: catalog,
          versionStore: versionStore,
        ),
        enrolment: S17AthleteEnrolmentAdapter(enrolment: enrolService),
        materialise: S17PlanMaterialiseAdapter(materialise: matService),
        projection: S17ProjectionBaselineAdapter(restore: restore),
        activeAssignment: S17ActiveAssignmentAdapter(store: assignmentStore),
        packageSelection: S17PackageSelectionAdapter(
          assignmentStore: assignmentStore,
          versionStore: versionStore,
        ),
        preparedExecution: S17PreparedExecutionAdapter(prepare: prepare),
      );
      final prepResult = await prepOrchestrator.ensureScheduleOpsBaseline(
        S17SchedulePreparationRequest(
          athleteId: config.athleteId,
          currentLineageCode: config.lineageCode,
          currentVersionId: config.versionId,
          currentAssignmentId: config.assignmentId,
          targetSchedulingLineage: config.schedulingLineageCode,
        ),
        current: baselineSnap,
      );
      setPrereq(
        'PREREQ_PREP',
        prepResult.ok ? S17JourneyResult.pass : S17JourneyResult.fail,
        prepResult.ok
            ? 'stage=${prepResult.stage.name} ${prepResult.detail}'
            : prepResult.classifiedDetail,
      );
      if (prepResult.ok &&
          prepResult.assignmentId != null &&
          prepResult.versionId != null &&
          prepResult.lineageCode != null) {
        config = config.copyWith(
          assignmentId: prepResult.assignmentId!,
          versionId: prepResult.versionId!,
          lineageCode: prepResult.lineageCode!,
          packageHash: prepResult.packageHash ?? config.packageHash,
        );
        final restoredPrep = await restore.ensureAndRestore(
          athleteId: config.athleteId,
          programmeAssignmentId: config.assignmentId,
        );
        if (restoredPrep.isSuccess && restoredPrep.projection != null) {
          snapshot = restore.snapshotForPreview(
            projection: restoredPrep.projection!,
            today: today,
          );
          scheduled = snapshot.projection.occurrences
              .where((o) => o.isUncompleted)
              .toList();
        }
      }

      final baselineAfter = S17OccurrenceBaselineSnapshot(
        authoredExecutableSlotCount: prepResult.ok
            ? (prepResult.uncompletedOccurrences >= 2
                  ? prepResult.uncompletedOccurrences
                  : scheduled.length)
            : baselineSnap.authoredExecutableSlotCount,
        projectedOccurrenceCount: snapshot.projection.occurrences.length,
        uncompletedOccurrenceCount: scheduled.length,
        completedOrSkippedCount:
            snapshot.projection.occurrences.length - scheduled.length,
        lineageCode: config.lineageCode,
        schedulingHorizonEnd: snapshot.schedulingHorizonEnd?.toString(),
      );
      final diagnosis = S17OccurrenceBaseline.diagnose(baselineAfter);
      final baselineFail = prepResult.ok
          ? S17OccurrenceBaseline.failClosedReason(baselineAfter)
          : prepResult.classifiedDetail;
      setPrereq(
        'PREREQ_BASELINE',
        baselineFail == null ? S17JourneyResult.pass : S17JourneyResult.fail,
        baselineFail ??
            'Baseline ready uncompleted=${baselineAfter.uncompletedOccurrenceCount}',
      );
      if (baselineFail != null) {
        for (final code in ['C', 'D', 'F', 'G', 'H', 'I', 'J', 'K']) {
          if (!config.resumeMode || selected.contains(code)) {
            setResult(
              code,
              S17JourneyResult.fail,
              prepResult.ok
                  ? 'BASELINE_FAIL cause=${diagnosis.cause.name} ${diagnosis.detail}'
                  : prepResult.classifiedDetail,
            );
          }
        }
      } else {
        selectedJourneysUnlocked = true;
        Future<ProgrammeSchedulingSnapshot?> reloadSnapshot() async {
          final r = await restore.ensureAndRestore(
            athleteId: config.athleteId,
            programmeAssignmentId: config.assignmentId,
          );
          if (!r.isSuccess || r.projection == null) return null;
          return restore.snapshotForPreview(
            projection: r.projection!,
            today: today,
          );
        }

        // F Move
        final beforeMoveRev = snapshot.projection.scheduleRevision;
        final beforeCount = snapshot.projection.occurrences.length;
        final moveSlot = scheduled.first.identity.sessionSlotId;
        final moveDate = scheduled.first.scheduledDate;
        final target = SessionOccurrenceDate(
          year: moveDate.year,
          month: moveDate.month,
          day: moveDate.day + 1,
        );
        final movePreview = apply.previewMove(
          snapshot: snapshot,
          sessionSlotId: moveSlot,
          targetDate: target,
        );
        var moveOk = false;
        if (movePreview.isReady && movePreview.preview != null) {
          final cmd = apply.moveCommandFromPreview(
            snapshot: snapshot,
            request: ProgrammeSchedulingMoveRequest(
              sessionSlotId: moveSlot,
              targetDate: target,
            ),
            preview: movePreview.preview!,
          );
          if (cmd != null) {
            final applied = await apply.confirmApply(
              athleteId: config.athleteId,
              command: cmd,
            );
            final after = await reloadSnapshot();
            moveOk =
                applied.isSuccess &&
                after != null &&
                after.projection.occurrences.length == beforeCount &&
                after.projection.scheduleRevision != beforeMoveRev;
            if (after != null) snapshot = after;
          }
        }
        final invalidMove = apply.previewMove(
          snapshot: snapshot,
          sessionSlotId: moveSlot,
          targetDate: const SessionOccurrenceDate(year: 1970, month: 1, day: 1),
        );
        setResult(
          'F',
          moveOk && !invalidMove.isReady
              ? S17JourneyResult.pass
              : S17JourneyResult.fail,
          'valid_move=$moveOk; invalid_rejected=${!invalidMove.isReady}',
        );

        // G Swap
        snapshot = (await reloadSnapshot()) ?? snapshot;
        final swapables = snapshot.projection.occurrences
            .where((o) => o.isUncompleted)
            .toList();
        var swapOk = false;
        var swapInvalidRejected = false;
        if (swapables.length >= 2) {
          final a = swapables[0].identity.sessionSlotId;
          final b = swapables[1].identity.sessionSlotId;
          final before = snapshot.projection.occurrences.length;
          final swapPreview = apply.previewSwap(
            snapshot: snapshot,
            sessionSlotIdA: a,
            sessionSlotIdB: b,
          );
          if (swapPreview.isReady && swapPreview.preview != null) {
            final cmd = apply.swapCommandFromPreview(
              snapshot: snapshot,
              request: ProgrammeSchedulingSwapRequest(
                sessionSlotIdA: a,
                sessionSlotIdB: b,
              ),
              preview: swapPreview.preview!,
            );
            if (cmd != null) {
              final applied = await apply.confirmApply(
                athleteId: config.athleteId,
                command: cmd,
              );
              final after = await reloadSnapshot();
              swapOk =
                  applied.isSuccess &&
                  after != null &&
                  after.projection.occurrences.length == before;
              if (after != null) snapshot = after;
            }
          }
          final invalid = apply.previewSwap(
            snapshot: snapshot,
            sessionSlotIdA: a,
            sessionSlotIdB: a,
          );
          swapInvalidRejected = !invalid.isReady;
        }
        setResult(
          'G',
          swapOk && swapInvalidRejected
              ? S17JourneyResult.pass
              : (swapables.length < 2
                    ? S17JourneyResult.blocked
                    : S17JourneyResult.fail),
          'valid_swap=$swapOk; invalid_rejected=$swapInvalidRejected',
        );

        // H Push
        snapshot = (await reloadSnapshot()) ?? snapshot;
        final pushables = snapshot.projection.occurrences
            .where((o) => o.isUncompleted)
            .toList();
        var pushOk = false;
        var pushInvalidRejected = false;
        if (pushables.isNotEmpty) {
          final from = pushables.first.identity.sessionSlotId;
          final before = snapshot.projection.occurrences.length;
          final pushPreview = apply.previewPush(
            snapshot: snapshot,
            fromSessionSlotId: from,
            dayDelta: 1,
          );
          if (pushPreview.isReady && pushPreview.preview != null) {
            final cmd = apply.pushCommandFromPreview(
              snapshot: snapshot,
              request: ProgrammeSchedulingPushRequest(
                fromSessionSlotId: from,
                dayDelta: 1,
              ),
              preview: pushPreview.preview!,
            );
            if (cmd != null) {
              final applied = await apply.confirmApply(
                athleteId: config.athleteId,
                command: cmd,
              );
              final after = await reloadSnapshot();
              pushOk =
                  applied.isSuccess &&
                  after != null &&
                  after.projection.occurrences.length == before;
              if (after != null) snapshot = after;
            }
          }
          final invalid = apply.previewPush(
            snapshot: snapshot,
            fromSessionSlotId: from,
            dayDelta: 10000,
          );
          pushInvalidRejected = !invalid.isReady;
        }
        setResult(
          'H',
          pushOk && pushInvalidRejected
              ? S17JourneyResult.pass
              : (pushables.isEmpty
                    ? S17JourneyResult.blocked
                    : S17JourneyResult.fail),
          'valid_push=$pushOk; invalid_rejected=$pushInvalidRejected',
        );

        // I Skip
        snapshot = (await reloadSnapshot()) ?? snapshot;
        final skipables = snapshot.projection.occurrences
            .where((o) => o.isUncompleted)
            .toList();
        var skipOk = false;
        var beforeSkipRev = snapshot.projection.scheduleRevision;
        if (skipables.isNotEmpty) {
          final slot = skipables.first.identity.sessionSlotId;
          beforeSkipRev = snapshot.projection.scheduleRevision;
          final skipPreview = apply.previewSkip(
            snapshot: snapshot,
            sessionSlotId: slot,
          );
          if (skipPreview.isReady && skipPreview.preview != null) {
            final cmd = apply.skipCommandFromPreview(
              snapshot: snapshot,
              request: ProgrammeSchedulingSkipRequest(sessionSlotId: slot),
              preview: skipPreview.preview!,
            );
            if (cmd != null) {
              final applied = await apply.confirmApply(
                athleteId: config.athleteId,
                command: cmd,
              );
              final after = await reloadSnapshot();
              skipOk =
                  applied.isSuccess &&
                  after != null &&
                  after.projection.scheduleRevision != beforeSkipRev;
              if (after != null) snapshot = after;
            }
          }
        }
        setResult(
          'I',
          skipOk
              ? S17JourneyResult.pass
              : (skipables.isEmpty
                    ? S17JourneyResult.blocked
                    : S17JourneyResult.fail),
          skipOk ? 'Skip applied' : 'Skip failed or unavailable',
        );

        // J Undo
        final undoable = await ops.latestUndoableOperation(
          assignmentId: config.assignmentId,
        );
        var undoOk = false;
        if (undoable != null) {
          final undoPreview = apply.previewUndo(
            snapshot: snapshot,
            operation: undoable,
          );
          if (undoPreview.isReady && undoPreview.preview != null) {
            final cmd = apply.undoCommandFromPreview(
              snapshot: snapshot,
              operation: undoable,
              preview: undoPreview.preview!,
            );
            if (cmd != null) {
              final applied = await apply.confirmApply(
                athleteId: config.athleteId,
                command: cmd,
              );
              final after = await reloadSnapshot();
              undoOk =
                  applied.isSuccess &&
                  after != null &&
                  after.projection.scheduleRevision == beforeSkipRev;
            }
          }
        }
        setResult(
          'J',
          undoOk
              ? S17JourneyResult.pass
              : (undoable == null
                    ? S17JourneyResult.blocked
                    : S17JourneyResult.fail),
          undoOk
              ? 'Undo restored prior revision'
              : 'Undo unavailable or incomplete',
        );
      }
    }

    // K → C dependency; D independent after prepare.
    // Never enter selected journeys when preparation/baseline postconditions fail.
    if (selectedJourneysUnlocked &&
        (!config.resumeMode ||
            selected.contains('K') ||
            selected.contains('C'))) {
      final preparedK = await prepare.prepareForAthlete(config.athleteId);
      if (!preparedK.isReady ||
          preparedK.package == null ||
          preparedK.executionContext == null) {
        if (!config.resumeMode || selected.contains('K')) {
          setResult(
            'K',
            S17JourneyResult.fail,
            'Prepare failed for completion',
          );
        }
        if (!config.resumeMode || selected.contains('C')) {
          setResult(
            'C',
            S17JourneyResult.fail,
            'No prior athlete-entered result',
          );
        }
      } else {
        final package = preparedK.package!;
        final ctx = preparedK.executionContext!;
        final prescriptionFp =
            '${package.programmeVersionId}|${package.programmedSessionKey}|${package.packageContentHash}';
        final completion = AthleteProgrammeCompletionService(
          assignmentStore: assignmentStore,
        );
        final trainingSessions = const TrainingSessionRepository();
        final trainingSession = await trainingSessions.createSession(
          athleteId: config.athleteId,
          protocolId: package.protocolId ?? 'unknown',
          status: TrainingSessionStatus.inProgress,
          programmeId: package.programmeVersionId,
          weekNumber: ctx.weekNumber,
        );
        var controller =
            PerformanceCaptureController.initializeFromExecutionPlan(
              plan: package.plan,
              athleteId: config.athleteId,
              trainingSessionId: trainingSession.id,
              programmeContext: ctx,
            );
        String? priorExerciseId;
        if (controller.draft.blockDrafts.isNotEmpty &&
            controller.draft.blockDrafts.first.exerciseResults.isNotEmpty) {
          final block = controller.draft.blockDrafts.first;
          final ex = block.exerciseResults.first;
          priorExerciseId = ex.sourceExerciseId;
          controller = controller.addSet(
            block.sourceBlockId,
            ex.sourceExerciseId,
          );
          final setId = controller
              .draft
              .blockDrafts
              .first
              .exerciseResults
              .first
              .sets
              .first
              .setResultId;
          controller = controller.updateSet(
            block.sourceBlockId,
            ex.sourceExerciseId,
            setId,
            (s) => s.copyWith(reps: 5, load: 40, completed: true),
          );
          controller = controller.markBlockComplete(block.sourceBlockId);
        }
        final logical = completion.buildLogicalCompletionKey(ctx);
        final idem = completion.buildIdempotencyKey(
          logicalCompletionKey: logical,
          requestNonce: 's17-b4c-primary',
        );
        final primary = await completion.submit(
          controller: controller,
          programmeContext: ctx,
          trainingSessionId: trainingSession.id,
          idempotencyKey: idem,
          frozenLogicalKey: logical,
        );
        final dup = await completion.submit(
          controller: controller,
          programmeContext: ctx,
          trainingSessionId: trainingSession.id,
          idempotencyKey: idem,
          frozenLogicalKey: logical,
        );
        final afterAssign = await assignmentStore.getActiveAssignment(
          config.athleteId,
        );
        if (!config.resumeMode || selected.contains('K')) {
          final assignmentId = package.assignmentId ?? config.assignmentId;
          final versionId = package.programmeVersionId ?? config.versionId;
          final sessionKey = package.programmedSessionKey.value;
          final packageHash = package.packageContentHash ?? config.packageHash;
          final evaluated = const S17CompletionHarness().evaluate(
            expectedAssignmentId: assignmentId,
            expectedVersionId: versionId,
            expectedSessionKey: sessionKey,
            expectedPackageHash: packageHash,
            primary: S17CompletionAttempt(
              assignmentId: assignmentId,
              versionId: versionId,
              programmedSessionKey: sessionKey,
              packageContentHash: packageHash,
              athleteEntered: priorExerciseId != null,
              succeeded: primary.isSuccess,
              advancedToSessionOrder: afterAssign?.currentSessionOrder,
            ),
            duplicate: S17CompletionAttempt(
              assignmentId: assignmentId,
              versionId: versionId,
              programmedSessionKey: sessionKey,
              packageContentHash: packageHash,
              athleteEntered: true,
              succeeded: dup.isSuccess,
              advancedToSessionOrder: afterAssign?.currentSessionOrder,
              duplicateOfPrior: true,
              createdDuplicateHistory: false,
            ),
            expectedNextSessionOrder: ctx.sessionOrder + 1,
          );
          setResult('K', evaluated.result, evaluated.detail);
        }
        if (!config.resumeMode || selected.contains('C')) {
          final records = <PreviousPerformanceSnapshot>[
            if (priorExerciseId != null)
              PreviousPerformanceSnapshot(
                exerciseId: priorExerciseId,
                sessionType: PreviousPerformanceSessionType.strength,
                performedAt: DateTime.now().toUtc(),
                repSummary: '5',
                loadSummary: '40',
              ),
            PreviousPerformanceSnapshot(
              exerciseId: 'unlike-exercise-id',
              sessionType: PreviousPerformanceSessionType.strength,
              performedAt: DateTime.now().toUtc(),
              repSummary: '99',
            ),
          ];
          final harness = const S17PreviousPerformanceHarness();
          final exerciseId = priorExerciseId ?? 'missing';
          final matching = harness.resolver.resolveLatest(
            exerciseId: exerciseId,
            records: records,
          );
          final unlike = harness.resolver.resolveLatest(
            exerciseId: 'no-such-exercise',
            records: records,
          );
          final result = harness.run(
            exerciseId: exerciseId,
            athleteEnteredRecords: records,
            authoredPrescriptionFingerprintBefore: prescriptionFp,
            authoredPrescriptionFingerprintAfter: prescriptionFp,
            progressionRewritten: false,
          );
          setResult(
            'C',
            priorExerciseId == null ? S17JourneyResult.fail : result,
            harness.detail(
              result: result,
              matchingSurfaced: matching != null,
              unlikeAbsent: unlike == null,
              prescriptionUnchanged: true,
              noProgression: true,
            ),
          );
        }
      }
    }

    if (selectedJourneysUnlocked &&
        (!config.resumeMode || selected.contains('D'))) {
      final preparedD = await prepare.prepareForAthlete(config.athleteId);
      final fpBefore = preparedD.package == null
          ? 'none'
          : '${preparedD.package!.programmedSessionKey}|${preparedD.package!.acceptedAdaptation}';
      if (!preparedD.isReady || preparedD.package == null) {
        setResult(
          'D',
          S17JourneyResult.fail,
          'No prepared package for adaptation',
        );
      } else {
        final proposalService = ProgrammeAdaptationProposalService();
        final proposal = await proposalService.propose(
          package: preparedD.package!,
          request: const AdaptationRequest(reason: AdaptationReason.equipment),
        );
        final afterSuggest = await prepare.prepareForAthlete(config.athleteId);
        final fpSuggest = afterSuggest.package == null
            ? 'none'
            : '${afterSuggest.package!.programmedSessionKey}|${afterSuggest.package!.acceptedAdaptation}';
        final adapt = const S17AdaptationHarness();
        if (!proposal.isAcceptable) {
          final eval = adapt.evaluate(
            proposal: null,
            action: S17AdaptationAthleteAction.reject,
            fingerprintBefore: fpBefore,
            fingerprintAfterSuggestionOnly: fpSuggest,
            fingerprintAfterAction: fpSuggest,
            acceptInvokedExplicitly: false,
            autoApplied: false,
          );
          setResult('D', eval.result, eval.detail);
        } else {
          final view = S17AdaptationProposalView(
            proposalId: proposal.proposalId,
            changeKinds: AdaptationPolicyGate.allowed.toList(),
            packageFingerprint: fpBefore,
          );
          final rejectEval = adapt.evaluate(
            proposal: view,
            action: S17AdaptationAthleteAction.reject,
            fingerprintBefore: fpBefore,
            fingerprintAfterSuggestionOnly: fpSuggest,
            fingerprintAfterAction: fpBefore,
            acceptInvokedExplicitly: false,
            autoApplied: false,
          );
          if (rejectEval.result != S17JourneyResult.pass) {
            setResult('D', rejectEval.result, rejectEval.detail);
          } else {
            final acceptance = ProgrammeAdaptationAcceptanceService(
              prepareService: prepare,
            );
            final acceptRes = await acceptance.accept(
              athleteId: config.athleteId,
              currentPackage: preparedD.package!,
              proposal: proposal,
              executionContext: preparedD.executionContext!,
            );
            final afterAccept = await prepare.prepareForAthlete(
              config.athleteId,
            );
            final fpAccept = afterAccept.package == null
                ? 'none'
                : '${afterAccept.package!.programmedSessionKey}|${afterAccept.package!.acceptedAdaptation}';
            final acceptEval = adapt.evaluate(
              proposal: view,
              action: S17AdaptationAthleteAction.accept,
              fingerprintBefore: fpBefore,
              fingerprintAfterSuggestionOnly: fpSuggest,
              fingerprintAfterAction: fpAccept,
              acceptInvokedExplicitly: acceptRes.success,
              autoApplied: false,
            );
            setResult('D', acceptEval.result, acceptEval.detail);
          }
        }
      }
    }
  } catch (e) {
    for (final code in S17StagingJourneyMatrix.codes) {
      if (results[code] == S17JourneyResult.notRun) {
        setResult(
          code,
          S17JourneyResult.fail,
          'Unhandled error: ${e.runtimeType}',
        );
      }
    }
  }

  await emit();
}
