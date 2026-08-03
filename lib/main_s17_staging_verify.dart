import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/persistence/athlete_local_repository.dart';
import 'core/persistence/local_kv_store.dart';
import 'data/repositories/programme_assignment_supabase_store.dart';
import 'data/repositories/programme_version_supabase_store.dart';
import 'domain/programme_scheduling/programme_scheduling_domain.dart';
import 'domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/current_user_session.dart';
import 'features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'features/programme/services/athlete_programme_session_prepare_service.dart';
import 'features/programme/services/programme_schedule_apply_service.dart';
import 'features/programme/services/programme_schedule_apply_supabase_store.dart';
import 'features/programme/services/programme_schedule_operations_supabase_store.dart';
import 'features/programme/services/programme_schedule_projection_supabase_store.dart';
import 'features/programme/services/programme_schedule_restore_service.dart';
import 'features/session/services/session_execution_loader.dart';
import 'staging/s17_staging_journey_matrix.dart';
import 'staging/s17_staging_runtime_config.dart';

/// Cohort Staging Athlete D verification for Phase 1.6 / Sprint 1.7.
///
/// Runtime config arrives only via `--dart-define-from-file` (private temp JSON).
/// Does not read shared `.env` or tracked staging secret stubs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = S17StagingRuntimeConfig.fromEnvironment();
  final results = S17StagingJourneyMatrix.allNotRun();
  final details = <String, String>{
    for (final code in S17StagingJourneyMatrix.codes)
      code: 'Harness loaded; journey not started',
  };

  void emit() {
    final report = S17JourneyReport(results: results, details: details);
    final encoded = jsonEncode({
      ...report.toJson(),
      'identity': config.enabled
          ? config.redactedIdentity()
          : const <String, String>{},
      'matrix': S17StagingJourneyMatrix.codes,
    });
    debugPrint('S17_FLUTTER_JOURNEY_JSON $encoded');
    // ignore: avoid_print
    print('S17_FLUTTER_JOURNEY_JSON $encoded');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  report.allPass
                      ? 'S17 Athlete D journeys PASSED'
                      : 'S17 Athlete D journeys incomplete / failed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: report.allPass
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
  }

  void setResult(String code, S17JourneyResult result, [String? detail]) {
    results[code] = result;
    if (detail != null) details[code] = detail;
  }

  final configError = config.validationError();
  if (configError != null) {
    for (final code in S17StagingJourneyMatrix.codes) {
      setResult(code, S17JourneyResult.notRun, configError);
    }
    emit();
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
    emit();
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
    emit();
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
      emit();
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
    final owns =
        assignment != null &&
        assignment.id == config.assignmentId &&
        assignment.athleteId == config.athleteId &&
        profile.isAthlete &&
        !profile.isCoach;

    final foreign = await client
        .from('programme_assignments')
        .select('id')
        .neq('athlete_id', config.athleteId)
        .limit(1);
    final foreignEmpty = (foreign as List).isEmpty;

    setResult(
      'A',
      owns && foreignEmpty ? S17JourneyResult.pass : S17JourneyResult.fail,
      owns && foreignEmpty
          ? 'Authenticated; own assignment only'
          : 'Isolation/auth scope failed',
    );

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
    setResult(
      'B',
      preparedOk ? S17JourneyResult.pass : S17JourneyResult.fail,
      preparedOk
          ? 'Prepared execution stable for assigned version'
          : 'Prepared execution mismatch',
    );

    setResult(
      'C',
      S17JourneyResult.blocked,
      'Interactive performance-capture path not automated in headless harness',
    );

    setResult(
      'D',
      prepared1.isReady ? S17JourneyResult.blocked : S17JourneyResult.fail,
      prepared1.isReady
          ? 'Adapt require explicit UI accept/reject; proposal path available when constraint present'
          : 'No prepared package for adaptation',
    );

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
    setResult(
      'E',
      projectionOk ? S17JourneyResult.pass : S17JourneyResult.fail,
      projectionOk
          ? 'Projection deterministic across restore'
          : 'Projection unstable or missing',
    );

    if (!projectionOk || restored1.projection == null) {
      for (final code in ['F', 'G', 'H', 'I', 'J']) {
        setResult(code, S17JourneyResult.blocked, 'Projection unavailable');
      }
    } else {
      final today = SessionOccurrenceDate.fromDateTime(DateTime.now().toUtc());
      var snapshot = restore.snapshotForPreview(
        projection: restored1.projection!,
        today: today,
      );
      final scheduled = snapshot.projection.occurrences
          .where((o) => o.isUncompleted)
          .toList();
      if (scheduled.length < 2) {
        for (final code in ['F', 'G', 'H', 'I', 'J']) {
          setResult(
            code,
            S17JourneyResult.blocked,
            'Need ≥2 scheduled occurrences',
          );
        }
      } else {
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

    setResult(
      'K',
      S17JourneyResult.blocked,
      'Completion/advancement remains operator-confirmed against Self-Test 2 contract',
    );
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

  emit();
}
