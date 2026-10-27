import 'dart:async';
import 'dart:convert';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/athlete_persistence.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/session/models/production_session_ui_cursor.dart';
import 'package:cohort_platform/features/session/models/steady_state_timer_cursor.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
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
const _plan = SessionExecutionPlan(
  sessionId: 'test-protocol',
  sessionTitle: 'Test workout',
  blocks: [
    SessionExecutionBlock(
      blockId: 'test-run',
      title: 'Test countdown',
      blockType: SessionBlockType.conditioning,
      content: 'Software fixture only',
      workoutFormat: WorkoutFormat.steadyState,
      timerConfiguration: TimerConfiguration(durationSeconds: 12),
      position: 1,
    ),
  ],
);

Widget _app(
  InMemoryPerformanceRecordStore records, {
  SessionExecutionPlan plan = _plan,
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
                plan: plan,
                protocolId: plan.sessionId,
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

  test(
    'strict cursor decoding rejects damaged/future state and keeps old envelopes readable',
    () {
      const timer = SteadyStateTimerCursor(
        blockId: 'test-run',
        durationSeconds: 12,
        remainingSeconds: 9,
        state: SteadyStateTimerStatus.paused,
      );
      final raw = timer.toJson();
      for (final patch in <Map<String, dynamic>>[
        {'schema_version': 2},
        {'remaining_seconds': -1},
        {'remaining_seconds': 13},
        {'remaining_seconds': 0},
        {'state': 'finished'},
        {'state': 'unknown'},
        {'duration_seconds': 0},
        {'extra': true},
        {'remaining_seconds': '9'},
      ]) {
        expect(
          () => SteadyStateTimerCursor.fromJson({...raw, ...patch}),
          throwsFormatException,
        );
      }
      const old = ProductionSessionUiCursor(
        schemaVersion: 2,
        athleteId: 'a',
        assignmentId: 'x',
        trainingSessionId: 17,
      );
      expect(
        ProductionSessionUiCursor.fromJson(old.toJson()).steadyStateTimers,
        isEmpty,
      );
      final encoded = {
        ...old.toJson(),
        'schema_version': 3,
        'active_block_id': 'test-run',
        'steady_state_timers': [raw],
      };
      expect(
        ProductionSessionUiCursor.fromJson(
          encoded,
        ).steadyStateTimers['test-run']!.remainingSeconds,
        9,
      );
      expect(
        () => ProductionSessionUiCursor.fromJson({
          ...encoded,
          'schema_version': 4,
        }),
        throwsFormatException,
      );
      expect(
        () => ProductionSessionUiCursor.fromJson({
          ...encoded,
          'steady_state_timers': [raw, raw],
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'active crash/restart resumes paused without counting closed time or changing actuals',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      final writes = records.draftWrites;
      final before = await _record(records);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      final clock = _clock(tester);
      final saved = await _saved();
      expect(_timer(saved)['state'], 'running');
      expect(
        records.draftWrites,
        writes,
      ); // ticking is local UI persistence only
      expect(
        (await _record(records)).toCompletionTreeMap(),
        before.toCompletionTreeMap(),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(hours: 2));
      final fresh = await _restart(records, kv);
      await _open(tester, fresh);
      expect(_clock(tester), clock);
      expect(find.text('Resume'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(_clock(tester), clock);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(seconds: 1));
      expect(_clock(tester), isNot(clock));
      expect((await _record(fresh)).recordId, before.recordId);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'background and explicit pause stay paused after same-process return and cold restart',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      final clock = _clock(tester);
      expect(_timer(await _saved())['state'], 'paused');
      await tester.pump(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_clock(tester), clock);
      expect(find.text('Resume'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Pause'));
      await tester.pump();
      final pausedClock = _clock(tester);
      await tester.pumpWidget(const SizedBox());
      await _open(tester, await _restart(records, kv));
      expect(_clock(tester), pausedClock);
      expect(find.text('Resume'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'finished timer restores finished without completing or advancing the workout',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      expect(_clock(tester), '00:00');
      expect(
        find.text('Timer finished. Review and record your result.'),
        findsOneWidget,
      );
      final raw = await _saved();
      expect(_timer(raw)['state'], 'finished');
      final before = await _record(records);
      expect(before.status, TrainingSessionRecordStatus.inProgress);
      expect(before.blockResults.single.status.name, isNot('completed'));
      expect(await records.listHistory(athleteId: 'athlete-a'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      final fresh = await _restart(records, kv);
      await _open(tester, fresh);
      expect(_clock(tester), '00:00');
      expect(find.text('Resume'), findsNothing);
      expect(
        (await _record(fresh)).status,
        TrainingSessionRecordStatus.inProgress,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'save failure pauses, blocks exit and permits retry without resetting',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      await tester.pump(const Duration(seconds: 2));
      kv.fail = true;
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      final clock = _clock(tester);
      expect(find.byKey(const ValueKey('timer-save-failed')), findsOneWidget);
      await tester.tap(find.text('Back to block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('block-timer-clock')), findsOneWidget);
      kv.fail = false;
      await tester.tap(find.text('Retry saving timer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timer-save-failed')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _open(tester, await _restart(records, kv));
      expect(_clock(tester), clock);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'serialized local writer cannot overwrite pause with an older running checkpoint',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      kv.gate = Completer<void>();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Pause'));
      await tester.pump();
      final clock = _clock(tester);
      kv.gate!.complete();
      kv.gate = null;
      await tester.pumpAndSettle();
      expect(_timer(await _saved())['state'], 'paused');
      await tester.pumpWidget(const SizedBox());
      await _open(tester, await _restart(records, kv));
      expect(_clock(tester), clock);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('prior step timer never auto-starts the next untouched block', (
    tester,
  ) async {
    final records = _Records();
    final plan = _twoBlocks();
    await _openTimer(tester, records, plan: plan);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Back to block'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next >'));
    await tester.tap(find.text('Next >'));
    await tester.pumpAndSettle();
    expect((await _saved())['cursor']['active_block_id'], 'second-run');
    await tester.pumpWidget(const SizedBox());
    await _open(tester, await _restart(records, kv), plan: plan);
    expect(find.byKey(const ValueKey('block-timer-clock')), findsNothing);
    expect(find.text('Second test step'), findsOneWidget);
    await tester.ensureVisible(find.text('< Previous'));
    await tester.tap(find.text('< Previous'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start timer'));
    await tester.tap(find.text('Start timer'));
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    expect(_clock(tester), isNot('00:12'));
    await tester.pumpWidget(const SizedBox());
  });

  for (final corruption in [
    'duration',
    'block',
    'active',
    'future',
    'malformed',
  ]) {
    testWidgets(
      'stale $corruption timer is blocked with recovery and retains results',
      (tester) async {
        final records = _Records();
        await _openTimer(tester, records);
        await tester.pump(const Duration(seconds: 2));
        final saved = await _saved();
        final cursor = saved['cursor'] as Map;
        if (corruption == 'active') {
          cursor['active_block_id'] = 'missing-step';
        } else if (corruption == 'future') {
          cursor['schema_version'] = 4;
        } else {
          final timer = (cursor['steady_state_timers'] as List).single as Map;
          if (corruption == 'duration') timer['duration_seconds'] = 13;
          if (corruption == 'block') timer['block_id'] = 'foreign-block';
          if (corruption == 'malformed') timer['remaining_seconds'] = -1;
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
        expect(find.text('Return to Home'), findsOneWidget);
        expect(find.byKey(const ValueKey('block-timer-clock')), findsNothing);
        expect(
          (await _record(fresh)).toCompletionTreeMap(),
          before.toCompletionTreeMap(),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'confirmed recovery clears only UI envelope and keeps the same result record',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      final saved = await _saved();
      _timer(saved)['duration_seconds'] = 13;
      await AthletePersistence.repository.saveProductionRestoreEnvelope(
        athleteId: 'athlete-a',
        trainingSessionId: 17,
        payload: saved,
      );
      final before = await _record(records);
      await tester.pumpWidget(const SizedBox());
      final fresh = await _restart(records, kv);
      await _open(tester, fresh);
      await tester.tap(find.byKey(const ValueKey('restore-discard-draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('restore-discard-cancel')));
      await tester.pumpAndSettle();
      expect(await _saved(), isNotNull);
      await tester.tap(find.byKey(const ValueKey('restore-discard-draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('restore-discard-confirm')));
      await tester.pumpAndSettle();
      expect(
        await AthletePersistence.repository.readProductionRestoreEnvelope(
          athleteId: 'athlete-a',
          trainingSessionId: 17,
        ),
        isNull,
      );
      expect(
        (await _record(fresh)).toCompletionTreeMap(),
        before.toCompletionTreeMap(),
      );
      await tester.tap(find.text('Open workout'));
      await tester.pumpAndSettle();
      expect(find.text('Start timer'), findsOneWidget);
      expect((await _record(fresh)).recordId, before.recordId);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('old endurance actuals do not masquerade as a timer cursor', (
    tester,
  ) async {
    final records = _Records();
    await _openTimer(tester, records);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    final controller = PerformanceCaptureController(
      draft: const PerformanceRecordMapper().toDraft(await _record(records)),
    );
    controller.updateBlockResultData(
      'test-run',
      const EnduranceResultData(
        distance: 1.5,
        durationSeconds: 99,
        averageHeartRate: 145,
        note: 'Retained manual result',
      ),
    );
    await records.saveDraft(controller.draft);
    final saved = await _saved();
    (saved['cursor'] as Map)
      ..remove('steady_state_timers')
      ..['schema_version'] = 2;
    await AthletePersistence.repository.saveProductionRestoreEnvelope(
      athleteId: 'athlete-a',
      trainingSessionId: 17,
      payload: saved,
    );
    await tester.pumpWidget(const SizedBox());
    final fresh = await _restart(records, kv);
    await _open(tester, fresh);
    expect(find.byKey(const ValueKey('block-timer-clock')), findsNothing);
    final result =
        (await _record(fresh)).blockResults.single.resultData
            as EnduranceResultData;
    expect(result.durationSeconds, 99);
    expect(result.distance, 1.5);
    expect(result.note, 'Retained manual result');
    await tester.ensureVisible(find.text('Start timer'));
    await tester.tap(find.text('Start timer'));
    await tester.pumpAndSettle();
    expect(_clock(tester), '00:12');
    expect(
      ((await _record(fresh)).blockResults.single.resultData
              as EnduranceResultData)
          .durationSeconds,
      99,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'account switch stops further checkpoints from the old timer route',
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
      expect(find.byKey(const ValueKey('timer-save-failed')), findsOneWidget);
      expect(_timer(await _saved()), _timer(before));
      expect(
        await AthletePersistence.repository.readProductionRestoreEnvelope(
          athleteId: 'athlete-b',
          trainingSessionId: 17,
        ),
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('sign-out route removal safely disposes an open countdown', (
    tester,
  ) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'athlete-a',
        displayName: 'A',
        isCoach: false,
        isAthlete: true,
      ),
    );
    final records = _Records();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(records, navigatorKey: navigator));
    await tester.tap(find.text('Open workout'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start timer'));
    await tester.tap(find.text('Start timer'));
    await tester.pumpAndSettle();
    CurrentUserSession.clear();
    unawaited(
      navigator.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Signed out')),
        ),
        (_) => false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signed out'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'pending local write cannot resurrect the signed-out athlete envelope',
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
      kv.gate = Completer<void>();
      await tester.pump(const Duration(seconds: 1));
      CurrentUserSession.clear();
      await kv.clearPrefix(PersistenceKeys.athleteRoot('athlete-a'));
      kv.gate!.complete();
      kv.gate = null;
      await tester.pumpAndSettle();
      expect(
        await AthletePersistence.repository.readProductionRestoreEnvelope(
          athleteId: 'athlete-a',
          trainingSessionId: 17,
        ),
        isNull,
      );
      expect(find.byKey(const ValueKey('timer-save-failed')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'authoritative completion wins even when the old timer envelope is corrupt',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      final before = await _record(records);
      final saved = await _saved();
      _timer(saved)['remaining_seconds'] = -1;
      await AthletePersistence.repository.saveProductionRestoreEnvelope(
        athleteId: 'athlete-a',
        trainingSessionId: 17,
        payload: saved,
      );
      await records.completeRecord(
        const PerformanceRecordMapper()
            .toDraft(before)
            .copyWith(status: TrainingSessionRecordStatus.completed),
      );
      await tester.pumpWidget(const SizedBox());
      AthleteSessionMemoryStore.instance.clearAll();
      final errors = <Object>[];
      await tester.pumpWidget(_app(records, onError: errors.add));
      await tester.tap(find.text('Open workout'));
      await tester.pumpAndSettle();
      expect(errors.single.toString(), contains('Session already completed'));
      expect(find.byKey(const ValueKey('block-timer-clock')), findsNothing);
      expect(
        await records.getInProgressForTrainingSession(
          athleteId: 'athlete-a',
          trainingSessionId: 17,
        ),
        isNull,
      );
      expect(
        (await records.getTerminalForTrainingSession(
          athleteId: 'athlete-a',
          trainingSessionId: 17,
        ))!.recordId,
        before.recordId,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'explicit timer reset persists without changing recorded results',
    (tester) async {
      final records = _Records();
      await _openTimer(tester, records);
      final before = await _record(records);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset').last);
      await tester.pumpAndSettle();
      expect(_clock(tester), '00:12');
      await tester.pumpWidget(const SizedBox());
      final fresh = await _restart(records, kv);
      await _open(tester, fresh);
      expect(_clock(tester), '00:12');
      expect(find.text('Resume'), findsOneWidget);
      expect(
        (await _record(fresh)).toCompletionTreeMap(),
        before.toCompletionTreeMap(),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('finishing the first countdown never skips into the next step', (
    tester,
  ) async {
    final records = _Records();
    await _openTimer(tester, records, plan: _twoBlocks());
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect((await _saved())['cursor']['active_block_id'], 'test-run');
    expect(_timer(await _saved())['state'], 'finished');
    expect(
      (await _record(
        records,
      )).blockResults.every((block) => block.status.name != 'completed'),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await _open(tester, await _restart(records, kv), plan: _twoBlocks());
    expect(_clock(tester), '00:00');
    expect(find.text('Test countdown'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another account cannot hydrate the first athlete timer', (
    tester,
  ) async {
    final records = _Records();
    await _openTimer(tester, records);
    await tester.pump(const Duration(seconds: 2));
    final own = await _saved();
    await tester.pumpWidget(const SizedBox());
    await _open(tester, await _restart(records, kv), athlete: 'athlete-b');
    expect(find.byKey(const ValueKey('block-timer-clock')), findsNothing);
    expect(find.text('Start timer'), findsOneWidget);
    expect(_timer(await _saved()), _timer(own));
    expect(
      await AthletePersistence.repository.readProductionRestoreEnvelope(
        athleteId: 'athlete-b',
        trainingSessionId: 17,
      ),
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'steady countdown checkpoint is durable through production route',
    (tester) async {
      final records = InMemoryPerformanceRecordStore();
      await tester.pumpWidget(_app(records));
      await tester.tap(find.text('Open workout'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start timer'));
      await tester.tap(find.text('Start timer'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      final saved = await AthletePersistence.repository
          .readProductionRestoreEnvelope(
            athleteId: 'athlete-a',
            trainingSessionId: 17,
          );
      expect((saved!['cursor'] as Map)['steady_state_timers'], isNotEmpty);
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
    ((saved['cursor'] as Map)['steady_state_timers'] as List).single as Map;
String _clock(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('block-timer-clock'))).data!;
Future<void> _open(
  WidgetTester tester,
  InMemoryPerformanceRecordStore records, {
  SessionExecutionPlan plan = _plan,
  String athlete = 'athlete-a',
}) async {
  await tester.pumpWidget(_app(records, plan: plan, athlete: athlete));
  await tester.tap(find.text('Open workout'));
  await tester.pumpAndSettle();
}

Future<void> _openTimer(
  WidgetTester tester,
  InMemoryPerformanceRecordStore records, {
  SessionExecutionPlan plan = _plan,
}) async {
  await _open(tester, records, plan: plan);
  await tester.ensureVisible(find.text('Start timer'));
  await tester.tap(find.text('Start timer'));
  await tester.pumpAndSettle();
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

SessionExecutionPlan _twoBlocks() => SessionExecutionPlan(
  sessionId: _plan.sessionId,
  sessionTitle: _plan.sessionTitle,
  blocks: [
    ..._plan.blocks,
    const SessionExecutionBlock(
      blockId: 'second-run',
      title: 'Second test step',
      blockType: SessionBlockType.conditioning,
      content: 'Software fixture only',
      workoutFormat: WorkoutFormat.steadyState,
      timerConfiguration: TimerConfiguration(durationSeconds: 20),
      position: 2,
    ),
  ],
);
