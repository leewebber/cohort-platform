import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/athlete_persistence.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/authored_timed_running_execution.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/structured_running_execution.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/features/session/screens/structured_running_timer_screen.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:crypto/crypto.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _context = ProgrammeExecutionContext(
  assignmentId: 'assignment',
  programmeVersionId: 'version',
  sessionSlotId: 'slot',
  weekNumber: 1,
  dayKey: 'day',
  sessionOrder: 1,
  plannedProtocolId: 'test-protocol',
  effectiveProtocolId: 'test-protocol',
  packageContentHash:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  programmedSessionKey: 'key',
  occurrenceId: 'occurrence',
);
RunningWorkout _workout() => const RunningWorkoutCodec().decode(
  File('test/session/fixtures/authored_distance_run.json').readAsStringSync(),
);
SessionExecutionPlan _plan({RunningWorkout? workout}) {
  final config = TimerConfiguration(
    durationSeconds: 1980,
    runningWorkout: workout ?? _workout(),
  );
  final row = SessionBlock.fromRow({
    'block_id': 'test-run',
    'block_type': 'conditioning',
    'title': '[SOFTWARE FIXTURE ONLY] Phased run',
    'content': 'Not approved training content',
    'workout_format': 'steady_state',
    'position': 1,
    'timer_config': config.toJson(),
  });
  return SessionExecutionPlan(
    sessionId: 'test-protocol',
    sessionTitle: row.title,
    blocks: [
      SessionExecutionBlock.fromSessionBlock(row, exercisesById: const {}),
    ],
  );
}

Widget _app(
  InMemoryPerformanceRecordStore records, {
  SessionExecutionPlan? plan,
  String athlete = 'athlete-a',
  void Function(Object)? onError,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final launcher = SessionExecutionLauncher(
    saveCoordinator: PerformanceRecordSaveCoordinator(store: records),
    restoreEnvelopeStore: ProductionRestoreEnvelopeStore(),
  );
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => launcher
              .launchActiveSessionWithPlan(
                context: context,
                plan: plan ?? _plan(),
                protocolId: (plan ?? _plan()).sessionId,
                trainingSessionId: 17,
                athleteId: athlete,
                programmeContext: _context,
              )
              .catchError((Object error) {
                if (onError == null) throw error;
                onError(error);
              }),
          child: const Text('Open workout'),
        ),
      ),
    ),
  );
}

StructuredRunningController _atDistance({int seconds = 0}) {
  final c = StructuredRunningController.fresh(
    execution: AuthoredTimedRunningExecution.fromBlock(_plan().blocks.single),
    elapsedTime: () => Duration.zero,
  );
  c.start();
  c.elapse(const Duration(seconds: 1380));
  if (seconds > 0) {
    c.start();
    c.elapse(Duration(seconds: seconds));
  }
  return c;
}

void main() {
  late _Kv kv;
  setUp(() {
    kv = _Kv();
    AthletePersistence.bindForTests(AthleteLocalRepository(kv));
    AthleteSessionMemoryStore.instance.clearAll();
  });
  tearDown(() {
    AthletePersistence.resetForTests();
    CurrentUserSession.clear();
  });

  test(
    'exact representative 10K body preserves millimetres and 33 timed minutes',
    () {
      final block = _plan().blocks.single;
      expect(block.hasTimer, isTrue);
      expect(block.timerConfiguration!.hasDistanceStep, isTrue);
      expect(
        block.timerConfiguration!.summaryForFormat(WorkoutFormat.steadyState),
        contains('10,000 m + 1980s'),
      );
      final steps = _workout().steps.cast<RunningAtomicStep>();
      expect(
        steps
            .where((s) => s.duration.kind == RunningDurationKind.distance)
            .single
            .duration
            .millimetres,
        10000000,
      );
      expect(
        steps.fold<int>(0, (n, s) => n + (s.duration.milliseconds ?? 0)),
        1980000,
      );
    },
  );

  for (final version in [1, 2]) {
    test(
      'private v$version admits representative distance graph without B2 mapping',
      () {
        final compiled = const PlanPackageCompiler().compile(
          File(
            'test/session/fixtures/authored_timed_run_v$version.yaml',
          ).readAsStringSync(),
        );
        final graphs = jsonDecode(
          File(
            'test/session/fixtures/authored_timed_protocol_graph.json',
          ).readAsStringSync(),
        );
        graphs.single['blocks'].single['timer_config']['durationSeconds'] =
            1980;
        graphs.single['blocks'].single['timer_config']['running_workout'] =
            const RunningWorkoutCodec().toJson(_workout());
        final source = jsonEncode(graphs);
        final artifact = const ReviewedProtocolGraphArtifact().inspect(
          compileResult: compiled,
          source: source,
          expectedSha256: sha256.convert(utf8.encode(source)).toString(),
        );
        expect(artifact.runningProjections, isEmpty);
      },
    );
  }

  test(
    'preparation overshoot never starts test; elapsed cannot finish distance; confirmation pauses cooldown',
    () {
      final c = _atDistance();
      expect(c.isDistanceStep, isTrue);
      expect(c.cursor.isPaused, isTrue);
      expect(c.cursor.distanceElapsedMilliseconds, 0);
      expect(c.confirmDistanceStep, throwsStateError);
      c.elapse(const Duration(days: 1));
      expect(c.cursor.distanceElapsedMilliseconds, 0);
      c.start();
      c.elapse(const Duration(minutes: 50));
      expect(c.isDistanceStep, isTrue);
      expect(c.cursor.isFinished, isFalse);
      c.confirmDistanceStep();
      expect(c.cursor.distanceConfirmed, isTrue);
      expect(c.cursor.isPaused, isTrue);
      expect(c.cursor.distanceElapsedMilliseconds, 3000000);
      expect(c.cursor.authoredStepId, 'LW10K-W10-D07-P10');
      expect(c.confirmDistanceStep, throwsStateError);
      c.start();
      c.elapse(const Duration(minutes: 10));
      expect(c.cursor.isFinished, isTrue);
      expect(
        c.cursor.manualEvidenceState,
        StructuredRunningManualEvidenceState.notCaptured,
      );
      c.dispose();
      final overshoot = StructuredRunningController.fresh(
        execution: AuthoredTimedRunningExecution.fromBlock(
          _plan().blocks.single,
        ),
        elapsedTime: () => Duration.zero,
      );
      overshoot.start();
      overshoot.elapse(const Duration(hours: 3));
      expect(overshoot.isDistanceStep, isTrue);
      expect(overshoot.cursor.distanceElapsedMilliseconds, 0);
      overshoot.dispose();
    },
  );

  for (final confirmed in [false, true]) {
    test(
      'JSON restart during/after distance confirmed=$confirmed never counts closed time',
      () {
        final c = _atDistance(seconds: 123);
        if (confirmed) c.confirmDistanceStep();
        final cursor = StructuredRunningCursor.fromJson(
          jsonDecode(jsonEncode(c.cursor.toJson())),
        );
        final restored = StructuredRunningController.restore(
          execution: AuthoredTimedRunningExecution.fromBlock(
            _plan().blocks.single,
          ),
          cursor: cursor,
          wallClock: () => DateTime.utc(2099),
        );
        expect(restored.cursor.isPaused, isTrue);
        expect(restored.cursor.distanceElapsedMilliseconds, 123000);
        expect(restored.cursor.distanceConfirmed, confirmed);
        restored.elapse(const Duration(days: 1));
        expect(restored.cursor.distanceElapsedMilliseconds, 123000);
        restored.start();
        restored.elapse(const Duration(seconds: 2));
        expect(
          restored.cursor.distanceElapsedMilliseconds,
          confirmed ? 123000 : 125000,
        );
        restored.dispose();
        c.dispose();
      },
    );
  }

  test(
    'distance cursor rejects corrupt, stale and impossible boundary states',
    () {
      final c = _atDistance(seconds: 1);
      final raw = c.cursor.toJson();
      for (final patch in [
        {'distance_elapsed_milliseconds': -1},
        {'distance_confirmed': true},
        {'remaining_milliseconds': 1},
        {'repeat_ordinal': 2},
        {'execution_mapping_sha256': 'b' * 64},
        {'authored_step_id': 'foreign'},
        {'schema_version': 999},
        {'is_finished': true},
      ]) {
        expect(
          () {
            final v = StructuredRunningCursor.fromJson({...raw, ...patch});
            StructuredRunningController.restore(
              execution: AuthoredTimedRunningExecution.fromBlock(
                _plan().blocks.single,
              ),
              cursor: v,
            ).dispose();
          },
          throwsA(anything),
          reason: patch.toString(),
        );
      }
      c.dispose();
    },
  );

  test(
    'unsupported distance shapes/manual lap and conflicting timed total remain refused',
    () {
      final raw = _plan().blocks.single.timerConfiguration!.toJson();
      for (final kind in [
        'wrong_distance',
        'repeat',
        'two_distances',
        'wrong_role',
        'manual_lap',
        'total',
      ]) {
        final j = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
        final steps = j['running_workout']['steps'] as List;
        final distance = steps[8];
        switch (kind) {
          case 'wrong_distance':
            distance['duration']['millimetres'] = 5000000;
          case 'repeat':
            steps[8] = {
              'kind': 'repeat',
              'group_id': 'bad',
              'count': 1,
              'steps': [distance],
            };
          case 'two_distances':
            steps.add({...distance, 'step_id': 'another'});
          case 'wrong_role':
            distance['role'] = 'recovery';
          case 'manual_lap':
            distance['duration'] = {'kind': 'manual_lap'};
          case 'total':
            j['durationSeconds'] = 1981;
        }
        expect(
          () {
            final t = TimerConfiguration.fromJson(j);
            if (!t.isValidForFormat(WorkoutFormat.steadyState)) {
              throw const FormatException();
            }
          },
          throwsA(anything),
          reason: kind,
        );
      }
    },
  );

  test(
    'manual actuals only; incomplete/abandoned are never completed test results; correction preserves prescription',
    () {
      final c = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _plan(),
        athleteId: 'athlete-a',
        trainingSessionId: 17,
        programmeContext: _context,
      );
      expect(
        (c.draft.blockDrafts.single.resultData as EnduranceResultData).distance,
        isNull,
      );
      expect(
        c.resolveCompletionStatus(),
        TrainingSessionRecordStatus.partiallyCompleted,
      );
      final snapshot = c.draft.blockDrafts.single.blockSnapshot;
      expect(
        BlockPerformanceSnapshot.fromJson({
          ...snapshot.toJson(),
          'timedRunningWorkoutV1': {'steps': {}},
        }).hasDistanceStep,
        isFalse,
      );
      c.markBlockSkipped('test-run');
      expect(
        c.resolveCompletionStatus(),
        TrainingSessionRecordStatus.abandoned,
      );
      c.markBlockComplete('test-run');
      expect(c.validateForCompletion().isValid, isFalse);
      for (final actual in [
        const EnduranceResultData(
          distance: 9.9,
          distanceUnit: 'km',
          durationSeconds: 3000,
        ),
        const EnduranceResultData(
          distance: double.nan,
          distanceUnit: 'km',
          durationSeconds: 3000,
        ),
        const EnduranceResultData(
          distance: 10,
          distanceUnit: 'unknown',
          durationSeconds: 3000,
        ),
        const EnduranceResultData(distance: 10, distanceUnit: 'km'),
      ]) {
        c.updateBlockResultData('test-run', actual);
        expect(c.validateForCompletion().isValid, isFalse);
      }
      c.updateBlockResultData(
        'test-run',
        const EnduranceResultData(
          distance: 10,
          distanceUnit: 'km',
          durationSeconds: 3010,
          note: 'External elapsed including interruption',
        ),
      );
      expect(c.validateForCompletion().isValid, isTrue);
      final record = const PerformanceRecordMapper().fromDraft(
        c.buildPersistableDraft(status: TrainingSessionRecordStatus.completed),
      );
      final restored = TrainingSessionRecord.fromCompletionTreeMap(
        jsonDecode(jsonEncode(record.toCompletionTreeMap())),
      );
      final projection = CompletedSessionResultProjection.fromRecords(
        record: restored,
      );
      expect(projection.blocks.single.summary, contains('manual/external'));
      expect(
        projection.blocks.single.prescriptionContext,
        contains('10,000 m'),
      );
      final correction = PerformanceCorrectionDraft(restored);
      correction.blockResults = [
        correction.blockResults.single.copyWith(
          resultData: const EnduranceResultData(
            distance: 10,
            distanceUnit: 'km',
            durationSeconds: 3009,
          ),
        ),
      ];
      expect(
        correction.blockResults.single.blockSnapshot.timedRunningWorkout,
        const RunningWorkoutCodec().toJson(_workout()),
      );
    },
  );

  testWidgets(
    'distance requires explicit confirmation, cancellation holds, cooldown has no auto actuals',
    (tester) async {
      var records = _Records();
      await _openTimer(tester, records);
      final c = _atDistance(seconds: 10);
      records = await _inject(tester, records, kv, c.cursor);
      c.dispose();
      expect(find.text('Prescribed distance: 10,000 m'), findsOneWidget);
      expect(_clock(tester), 'Active time 0:00:10');
      final before = await _record(records);
      final writes = records.draftWrites;
      await tester.ensureVisible(find.text('Confirm distance step finished'));
      await tester.tap(find.text('Confirm distance step finished'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep paused'));
      await tester.pumpAndSettle();
      expect(_timer(await _saved())['distance_confirmed'], isFalse);
      await tester.tap(find.text('Confirm distance step finished'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I completed 10,000 m'));
      await tester.pumpAndSettle();
      expect(find.text('Easy cooldown jog'), findsOneWidget);
      expect(_clock(tester), '600 s');
      expect(_timer(await _saved())['distance_confirmed'], isTrue);
      expect(records.draftWrites, writes);
      expect(
        (await _record(records)).toCompletionTreeMap(),
        before.toCompletionTreeMap(),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed confirmation save retains progress for Retry and refuses exit; restart retains acknowledgement',
    (tester) async {
      var records = _Records();
      await _openTimer(tester, records);
      final c = _atDistance(seconds: 20);
      records = await _inject(tester, records, kv, c.cursor);
      c.dispose();
      // _inject rebinds a fresh repository; fail its native KV.
      final repoKv = _activeKv!;
      repoKv.fail = true;
      await tester.ensureVisible(find.text('Confirm distance step finished'));
      await tester.tap(find.text('Confirm distance step finished'));
      await tester.pumpAndSettle();
      // Pause checkpoint failure prevents accepting the dialog.
      await tester.tap(find.text('I completed 10,000 m'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving timer'), findsOneWidget);
      expect(_timer(await _saved())['distance_confirmed'], isFalse);
      await tester.tap(find.byTooltip('Exit timer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save the timer. Retry before exiting.'),
        findsOneWidget,
      );
      repoKv.fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry saving timer'));
      await tester.tap(find.text('Retry saving timer'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm distance step finished'));
      await tester.tap(find.text('Confirm distance step finished'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I completed 10,000 m'));
      await tester.pumpAndSettle();
      expect(_timer(await _saved())['distance_confirmed'], isTrue);
      await tester.pumpWidget(const SizedBox());
      final fresh = await _restart(records, repoKv);
      await _open(tester, fresh);
      expect(find.text('Easy cooldown jog'), findsOneWidget);
      expect(_clock(tester), '600 s');
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final corruption in [
    'step',
    'digest',
    'ordinal',
    'remaining',
    'future',
    'duplicate',
    'active',
  ]) {
    testWidgets(
      'damaged $corruption cursor fails closed without changing actuals',
      (tester) async {
        final records = _Records();
        await _openTimer(tester, records);
        final atDistance = _atDistance(seconds: 10);
        final saved = await _saved();
        saved['cursor']['authored_timed_runs'] = [atDistance.cursor.toJson()];
        atDistance.dispose();
        final cursor = _timer(saved);
        switch (corruption) {
          case 'step':
            cursor['authored_step_id'] = 'foreign';
          case 'digest':
            cursor['execution_mapping_sha256'] = 'b' * 64;
          case 'ordinal':
            cursor['repeat_ordinal'] = 99;
          case 'remaining':
            cursor['remaining_milliseconds'] = -1;
          case 'future':
            saved['cursor']['schema_version'] = 999;
          case 'duplicate':
            saved['cursor']['authored_timed_runs'].add(
              Map<String, dynamic>.from(cursor),
            );
          case 'active':
            saved['cursor']['active_block_id'] = 'foreign';
        }
        await AthletePersistence.repository.saveProductionRestoreEnvelope(
          athleteId: 'athlete-a',
          trainingSessionId: 17,
          payload: saved,
        );
        final before = await _record(records);
        await tester.pumpWidget(const SizedBox());
        final fresh = await _restart(records, kv);
        await _open(tester, fresh);
        expect(find.text('Draft cannot be safely restored'), findsOneWidget);
        expect(
          (await _record(fresh)).toCompletionTreeMap(),
          before.toCompletionTreeMap(),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'body changes cannot bypass snapshot pin by discarding the UI cursor',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      await tester.pumpWidget(const SizedBox());
      await AthletePersistence.repository.clearProductionRestoreEnvelope(
        athleteId: 'athlete-a',
        trainingSessionId: 17,
      );
      final raw = const RunningWorkoutCodec().toJson(_workout());
      (raw['steps'] as List).first['label'] = 'Changed instruction';
      Object? error;
      final fresh = await _restart(records, kv);
      await tester.pumpWidget(
        _app(
          fresh,
          plan: _plan(workout: const RunningWorkoutCodec().decodeMap(raw)),
          onError: (e) => error = e,
        ),
      );
      await tester.tap(find.text('Open workout'));
      await tester.pumpAndSettle();
      expect(error, isFormatException);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'another account receives a fresh workout and cannot hydrate this timer',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      final saved = await _saved();
      await tester.pumpWidget(const SizedBox());
      await _open(tester, await _restart(records, kv), athlete: 'athlete-b');
      expect(
        find.byKey(const ValueKey('structured-running-clock')),
        findsNothing,
      );
      expect(_timer(await _saved()), _timer(saved));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'pending distance checkpoint cannot resurrect signed-out envelope',
    (tester) async {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-a',
          displayName: 'A',
          isCoach: false,
          isAthlete: true,
        ),
      );
      var records = _Records();
      await _openTimer(tester, records);
      final c = _atDistance(seconds: 10);
      records = await _inject(tester, records, kv, c.cursor);
      c.dispose();
      final next = _activeKv!;
      next.gate = Completer<void>();
      await tester.ensureVisible(find.text('Start / resume'));
      await tester.tap(find.text('Start / resume'));
      await tester.pump();
      CurrentUserSession.clear();
      await AthletePersistence.repository.clearProductionRestoreEnvelope(
        athleteId: 'athlete-a',
        trainingSessionId: 17,
      );
      next.gate!.complete();
      next.gate = null;
      await tester.pumpAndSettle();
      expect(
        await AthletePersistence.repository.readProductionRestoreEnvelope(
          athleteId: 'athlete-a',
          trainingSessionId: 17,
        ),
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation write failure holds cooldown paused until retry; never restores an unsaved claim',
    (tester) async {
      final c = _atDistance(seconds: 40);
      final initial = c.cursor;
      c.dispose();
      StructuredRunningCursor saved = initial;
      bool fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StructuredRunningTimerScreen(
            execution: AuthoredTimedRunningExecution.fromBlock(
              _plan().blocks.single,
            ),
            initialCursor: initial,
            onCheckpoint: (cursor) async {
              if (cursor.distanceConfirmed && fail) return false;
              saved = cursor;
              return true;
            },
          ),
        ),
      );
      await tester.ensureVisible(find.text('Confirm distance step finished'));
      await tester.tap(find.text('Confirm distance step finished'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I completed 10,000 m'));
      await tester.pumpAndSettle();
      expect(saved.distanceConfirmed, isFalse);
      expect(find.text('Retry saving timer'), findsOneWidget);
      expect(_clock(tester), '600 s');
      await tester.pump(const Duration(minutes: 1));
      expect(_clock(tester), '600 s');
      fail = false;
      await tester.ensureVisible(find.text('Retry saving timer'));
      await tester.tap(find.text('Retry saving timer'));
      await tester.pumpAndSettle();
      expect(saved.distanceConfirmed, isTrue);
      expect(saved.isPaused, isTrue);
      expect(saved.distanceElapsedMilliseconds, 40000);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'distance interruption resumes paused and manual result survives fresh serialized dependencies',
    (tester) async {
      var records = _Records();
      await _openTimer(tester, records);
      final capture = PerformanceRecordSaveCoordinator(
        store: records,
      ).restoreControllerFromRecord(await _record(records));
      capture.updateBlockResultData(
        'test-run',
        const EnduranceResultData(
          distance: 9.2,
          distanceUnit: 'km',
          durationSeconds: 3120,
          note: 'Stopped early; external elapsed',
        ),
      );
      await PerformanceRecordSaveCoordinator(
        store: records,
      ).saveDraft(controller: capture);
      final c = _atDistance(seconds: 55);
      records = await _inject(tester, records, kv, c.cursor);
      c.dispose();
      expect(_clock(tester), 'Active time 0:00:55');
      await tester.ensureVisible(find.text('Start / resume'));
      await tester.tap(find.text('Start / resume'));
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      final clock = _clock(tester);
      await tester.pump(const Duration(hours: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_clock(tester), clock);
      await tester.pumpWidget(const SizedBox());
      final fresh = await _restart(records, _activeKv!);
      await _open(tester, fresh);
      expect(_clock(tester), clock);
      final result =
          (await _record(fresh)).blockResults.single.resultData
              as EnduranceResultData;
      expect(result.distance, 9.2);
      expect(result.durationSeconds, 3120);
      expect(result.note, 'Stopped early; external elapsed');
      expect(
        (await _record(fresh)).status,
        TrainingSessionRecordStatus.inProgress,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

_Kv? _activeKv;
Future<_Records> _inject(
  WidgetTester tester,
  _Records records,
  _Kv kv,
  StructuredRunningCursor cursor,
) async {
  final saved = await _saved();
  saved['cursor']['authored_timed_runs'] = [cursor.toJson()];
  await AthletePersistence.repository.saveProductionRestoreEnvelope(
    athleteId: 'athlete-a',
    trainingSessionId: 17,
    payload: saved,
  );
  await tester.pumpWidget(const SizedBox());
  final fresh = await _restart(records, kv);
  await _open(tester, fresh);
  return fresh;
}

class _Kv extends InMemoryKvStore {
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> writeString(String key, String value) async {
    if (fail) throw StateError('Test local write failure');
    final pending = gate;
    if (pending != null) await pending.future;
    await super.writeString(key, value);
  }
}

class _Records extends InMemoryPerformanceRecordStore {
  int draftWrites = 0;
  @override
  Future<TrainingSessionRecord> saveDraft(ActivePerformanceDraft draft) {
    draftWrites++;
    return super.saveDraft(draft);
  }
}

Future<TrainingSessionRecord> _record(
  InMemoryPerformanceRecordStore records,
) async => (await records.getInProgressForTrainingSession(
  athleteId: 'athlete-a',
  trainingSessionId: 17,
))!;
Future<Map<String, dynamic>> _saved() async =>
    (await AthletePersistence.repository.readProductionRestoreEnvelope(
      athleteId: 'athlete-a',
      trainingSessionId: 17,
    ))!;
Map _timer(Map saved) =>
    ((saved['cursor'] as Map)['authored_timed_runs'] as List).single as Map;
String _clock(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('structured-running-clock')))
    .data!;
Future<void> _open(
  WidgetTester tester,
  InMemoryPerformanceRecordStore records, {
  SessionExecutionPlan? plan,
  String athlete = 'athlete-a',
}) async {
  await tester.pumpWidget(_app(records, plan: plan, athlete: athlete));
  await tester.tap(find.text('Open workout'));
  await tester.pumpAndSettle();
}

Future<void> _openTimer(
  WidgetTester tester,
  InMemoryPerformanceRecordStore records, {
  SessionExecutionPlan? plan,
}) async {
  await _open(tester, records, plan: plan);
  await tester.ensureVisible(find.text('Start timer'));
  await tester.tap(find.text('Start timer'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Start / resume'));
  await tester.tap(find.text('Start / resume'));
  await tester.pump();
}

Future<_Records> _restart(
  InMemoryPerformanceRecordStore records,
  _Kv old,
) async {
  final record = await _record(records);
  final jsonRecord = TrainingSessionRecord.fromCompletionTreeMap(
    jsonDecode(jsonEncode(record.toCompletionTreeMap()))
        as Map<String, dynamic>,
  );
  final fresh = _Records();
  await fresh.saveDraft(const PerformanceRecordMapper().toDraft(jsonRecord));
  final next = _Kv();
  for (final entry in old.debugDump.entries) {
    await next.writeString(entry.key, entry.value);
  }
  AthletePersistence.resetForTests();
  AthleteSessionMemoryStore.instance.clearAll();
  AthletePersistence.bindForTests(AthleteLocalRepository(next));
  _activeKv = next;
  return fresh;
}
