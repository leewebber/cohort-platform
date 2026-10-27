import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/athlete_persistence.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
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
  File('test/session/fixtures/authored_timed_run.json').readAsStringSync(),
);
SessionExecutionPlan _plan({RunningWorkout? workout}) {
  final config = TimerConfiguration(
    durationSeconds: 1740,
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

  for (final version in [1, 2]) {
    test(
      'private v$version graph admits exact whole-body timed source and rejects drift',
      () {
        final compiled = const PlanPackageCompiler().compile(
          File(
            'test/session/fixtures/authored_timed_run_v$version.yaml',
          ).readAsStringSync(),
        );
        expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
        final source = File(
          'test/session/fixtures/authored_timed_protocol_graph.json',
        ).readAsStringSync();
        final graph = const ReviewedProtocolGraphArtifact().inspect(
          compileResult: compiled,
          source: source,
          expectedSha256: sha256.convert(utf8.encode(source)).toString(),
        );
        final block = (graph.graphs.single['blocks'] as List).single as Map;
        final config = TimerConfiguration.fromJson(
          Map<String, dynamic>.from(block['timer_config']),
        );
        expect(config.runningWorkout, _workout());
        expect(
          graph.runningProjections,
          isEmpty,
        ); // no fabricated B2 advisory authority
        final corrupt = jsonDecode(source) as List;
        corrupt.single['blocks'].single['timer_config']['durationSeconds'] =
            1741;
        final changed = jsonEncode(corrupt);
        expect(
          () => const ReviewedProtocolGraphArtifact().inspect(
            compileResult: compiled,
            source: changed,
            expectedSha256: sha256.convert(utf8.encode(changed)).toString(),
          ),
          throwsA(isA<ReviewedProtocolGraphArtifactException>()),
        );
      },
    );
  }

  test(
    'each repeated boundary restores exactly, paused, and finished never restarts',
    () {
      final execution = AuthoredTimedRunningExecution.fromBlock(
        _plan().blocks.single,
      );
      final live = StructuredRunningController.fresh(
        execution: execution,
        elapsedTime: () => Duration.zero,
      );
      live.start();
      for (var i = 0; i < 9; i++) {
        final cursor = StructuredRunningCursor.fromJson(live.cursor.toJson());
        final restored = StructuredRunningController.restore(
          execution: execution,
          cursor: cursor,
          wallClock: () => DateTime.utc(2099),
        );
        expect(restored.cursor.authoredStepId, cursor.authoredStepId);
        expect(restored.cursor.repeatOrdinal, cursor.repeatOrdinal);
        expect(
          restored.cursor.remainingMilliseconds,
          cursor.remainingMilliseconds,
        );
        expect(restored.cursor.isPaused, isTrue);
        restored.elapse(const Duration(days: 1));
        expect(
          restored.cursor.remainingMilliseconds,
          cursor.remainingMilliseconds,
        );
        restored.dispose();
        live.elapse(Duration(milliseconds: live.cursor.remainingMilliseconds));
      }
      final finished = StructuredRunningController.restore(
        execution: execution,
        cursor: live.cursor,
      );
      finished.start();
      expect(finished.cursor.isFinished, isTrue);
      expect(finished.cursor.remainingMilliseconds, 0);
      finished.dispose();
      live.dispose();
    },
  );

  for (final seconds in [300, 900, 1020, 1740]) {
    testWidgets(
      'canonical cold restore at $seconds seconds retains manual results',
      (tester) async {
        final records = _Records();
        await _openTimer(tester, records);
        final original = await _record(records);
        final capture = PerformanceRecordSaveCoordinator(
          store: records,
        ).restoreControllerFromRecord(original);
        capture.updateBlockResultData(
          'test-run',
          const EnduranceResultData(
            durationSeconds: 99,
            distance: 1.5,
            distanceUnit: 'km',
            note: 'Entered actuals',
          ),
        );
        await PerformanceRecordSaveCoordinator(
          store: records,
        ).saveDraft(controller: capture);
        final controller = StructuredRunningController.fresh(
          execution: AuthoredTimedRunningExecution.fromBlock(
            _plan().blocks.single,
          ),
          elapsedTime: () => Duration.zero,
        );
        controller.start();
        controller.elapse(Duration(seconds: seconds));
        final saved = await _saved();
        saved['cursor']['authored_timed_runs'] = [controller.cursor.toJson()];
        controller.dispose();
        await AthletePersistence.repository.saveProductionRestoreEnvelope(
          athleteId: 'athlete-a',
          trainingSessionId: 17,
          payload: saved,
        );
        await tester.pumpWidget(const SizedBox());
        final fresh = await _restart(records, kv);
        await _open(tester, fresh);
        if (seconds == 1740) {
          expect(find.text('Timer finished'), findsOneWidget);
        } else if (seconds == 300) {
          expect(find.text('Aerobic main'), findsOneWidget);
          expect(
            find.textContaining('Heart-rate zone: fixture-zone-2'),
            findsOneWidget,
          );
          expect(_clock(tester), '600 s');
        } else if (seconds == 900) {
          expect(find.text('Controlled effort'), findsOneWidget);
          expect(find.text('4:40.250–4:55.750 /km'), findsOneWidget);
          expect(_clock(tester), '120 s');
        } else {
          expect(find.text('Easy recovery'), findsOneWidget);
          expect(find.text('RPE 2/10'), findsOneWidget);
          expect(_clock(tester), '60 s');
        }
        final record = await _record(fresh);
        final result =
            record.blockResults.single.resultData as EnduranceResultData;
        expect(result.durationSeconds, 99);
        expect(result.distance, 1.5);
        expect(result.note, 'Entered actuals');
        expect(record.status.name, 'inProgress');
        expect(record.blockResults.single.status.name, isNot('completed'));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'account switch stops old running checkpoints; sign-out route disposal is safe',
    (tester) async {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-a',
          displayName: 'A',
          isCoach: false,
          isAthlete: true,
        ),
      );
      final records = _Records();
      await _openTimer(tester, records);
      final before = await _saved();
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-b',
          displayName: 'B',
          isCoach: false,
          isAthlete: true,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving timer'), findsOneWidget);
      expect(_timer(await _saved()), _timer(before));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'completed record round-trip and actual correction retain exact authored workout',
    () {
      final controller =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: _plan(),
            athleteId: 'athlete-a',
            trainingSessionId: 17,
            programmeContext: _context,
          );
      controller.updateBlockResultData(
        'test-run',
        const EnduranceResultData(
          durationSeconds: 1700,
          distance: 5,
          distanceUnit: 'km',
          note: 'Entered actuals',
        ),
      );
      controller.markBlockComplete('test-run');
      expect(controller.validateForCompletion().isValid, isTrue);
      final completed = const PerformanceRecordMapper().fromDraft(
        controller.buildPersistableDraft(
          status: TrainingSessionRecordStatus.completed,
        ),
      );
      final hydrated = TrainingSessionRecord.fromCompletionTreeMap(
        jsonDecode(jsonEncode(completed.toCompletionTreeMap()))
            as Map<String, dynamic>,
      );
      expect(
        hydrated.sessionSnapshot.blocks.single.timedRunningWorkout,
        const RunningWorkoutCodec().toJson(_workout()),
      );
      final correction = PerformanceCorrectionDraft(hydrated);
      correction.blockResults = [
        correction.blockResults.single.copyWith(
          resultData: const EnduranceResultData(
            durationSeconds: 1699,
            distance: 5,
            distanceUnit: 'km',
            note: 'Corrected actual time',
          ),
        ),
      ];
      final corrected = const PerformanceCorrectionService().applyLocally(
        correction,
      );
      expect(
        corrected.blockResults.single.blockSnapshot.timedRunningWorkout,
        hydrated.blockResults.single.blockSnapshot.timedRunningWorkout,
      );
      expect(
        corrected.sessionSnapshot.toJson(),
        hydrated.sessionSnapshot.toJson(),
      );
      expect(
        (corrected.blockResults.single.resultData as EnduranceResultData)
            .durationSeconds,
        1699,
      );
      expect(corrected.recordId, hydrated.recordId);
      expect(corrected.status, hydrated.status);
    },
  );

  test(
    'exact body projects without flattening source, and snapshot retains it',
    () {
      final block = _plan().blocks.single;
      final projected = const RunningWorkoutProjector().project(
        format: block.workoutFormat,
        configuration: block.timerConfiguration!,
      );
      expect(projected.isSupported, isTrue);
      expect(projected.workout, _workout());
      expect(block.hasTimer, isTrue);
      final capture = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _plan(),
        athleteId: 'athlete-a',
        trainingSessionId: 17,
        programmeContext: _context,
      );
      expect(
        capture.draft.sessionSnapshot.blocks.single.timedRunningWorkout,
        const RunningWorkoutCodec().toJson(_workout()),
      );
      expect(
        () =>
            capture
                    .draft
                    .sessionSnapshot
                    .blocks
                    .single
                    .timedRunningWorkout!['steps'] =
                [],
        throwsUnsupportedError,
      );
    },
  );

  test(
    'every phase and repeat executes in exact authored order without actuals',
    () {
      final execution = AuthoredTimedRunningExecution.fromBlock(
        _plan().blocks.single,
      );
      final controller = StructuredRunningController.fresh(
        execution: execution,
        elapsedTime: () => Duration.zero,
      );
      expect(controller.totalSteps, 9);
      final ids = <String>[];
      final ordinals = <int>[];
      controller.start();
      for (var i = 0; i < 9; i++) {
        ids.add(controller.cursor.authoredStepId);
        ordinals.add(controller.cursor.repeatOrdinal);
        controller.elapse(
          Duration(milliseconds: controller.cursor.remainingMilliseconds),
        );
      }
      expect(ids, [
        'warm',
        'main',
        'effort',
        'recover',
        'effort',
        'recover',
        'effort',
        'recover',
        'cool',
      ]);
      expect(ordinals, [1, 1, 1, 1, 2, 2, 3, 3, 1]);
      expect(controller.cursor.isFinished, isTrue);
      expect(controller.cursor.manualEvidenceState.name, 'notCaptured');
      controller.dispose();
    },
  );

  test(
    'reject inconsistent totals, distance endings and conflicting scalar settings',
    () {
      final raw = TimerConfiguration(
        durationSeconds: 1740,
        runningWorkout: _workout(),
      ).toJson();
      for (final patch in [
        {'durationSeconds': 1741},
        {'workSeconds': 120},
        {'rounds': 3},
        {
          'durationRangeSeconds': [1000, 2000],
        },
      ]) {
        final config = TimerConfiguration.fromJson({...raw, ...patch});
        expect(config.isValidForFormat(WorkoutFormat.steadyState), isFalse);
      }
      final fractional = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      // Same exact whole-workout total, but the one-second UI cannot faithfully
      // present half-second boundaries. Reject rather than round or skip them.
      final phases = fractional['running_workout']['steps'] as List;
      phases[0]['duration']['milliseconds'] = 300500;
      phases[1]['duration']['milliseconds'] = 599500;
      expect(
        TimerConfiguration.fromJson(
          fractional,
        ).isValidForFormat(WorkoutFormat.steadyState),
        isFalse,
      );
      final changed = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      ((changed['running_workout']['steps'] as List).first as Map)['duration'] =
          {'kind': 'distance', 'millimetres': 1000000};
      expect(
        TimerConfiguration.fromJson(
          changed,
        ).isValidForFormat(WorkoutFormat.steadyState),
        isFalse,
      );
    },
  );

  testWidgets(
    'checkpoint is local only, cold restart restores active step paused and results intact',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      final before = await _record(records);
      final writes = records.draftWrites;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      final clock = _clock(tester);
      final cursor = _timer(await _saved());
      expect(cursor['is_paused'], isFalse);
      expect(records.draftWrites, writes);
      expect(
        (await _record(records)).toCompletionTreeMap(),
        before.toCompletionTreeMap(),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(hours: 2));
      final fresh = await _restart(records, kv);
      await _open(tester, fresh);
      expect(_clock(tester), clock);
      expect(find.text('Start / resume'), findsOneWidget);
      expect(find.text('Gradual warm-up'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(_clock(tester), clock);
      await tester.tap(find.text('Start / resume'));
      await tester.pump(const Duration(seconds: 1));
      expect(_clock(tester), isNot(clock));
      expect((await _record(fresh)).recordId, before.recordId);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'background and pause persist, resume is explicit; failed save blocks countdown and exit',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      final clock = _clock(tester);
      await tester.pump(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_clock(tester), clock);
      await tester.tap(find.text('Start / resume'));
      kv.fail = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Retry saving timer'), findsOneWidget);
      final failedClock = _clock(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(_clock(tester), failedClock);
      await tester.tap(find.byTooltip('Exit timer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save the timer. Retry before exiting.'),
        findsOneWidget,
      );
      kv.fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry saving timer'));
      await tester.tap(find.text('Retry saving timer'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving timer'), findsNothing);
      await tester.tap(find.byTooltip('Exit timer'));
      await tester.pumpAndSettle();
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
        final saved = await _saved();
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
            saved['cursor']['authored_timed_runs'].add(Map.from(cursor));
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
  return fresh;
}
