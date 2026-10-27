import 'dart:convert';
import 'dart:io';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/core/persistence/athlete_persistence.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/features/session/models/authored_timed_running_execution.dart';
import 'package:cohort_platform/features/session/services/running_target_admission_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/screens/running_target_review_screen.dart';
import 'package:cohort_platform/features/session/screens/structured_running_timer_screen.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';

const _owner = 'athlete-a';
const _ctx = ProgrammeExecutionContext(
  assignmentId: 'assignment',
  programmeVersionId: 'version',
  sessionSlotId: 'slot',
  weekNumber: 1,
  dayKey: 'day_1',
  sessionOrder: 1,
  plannedProtocolId: 'fixture',
  effectiveProtocolId: 'fixture',
  packageContentHash:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  occurrenceId: 'occurrence',
  programmedSessionKey: 'key',
  packageSchemaVersion: 1,
);
SessionExecutionPlan _plan() => SessionExecutionPlan(
  sessionId: 'fixture',
  sessionTitle: '[FIXTURE ONLY] Easy run',
  blocks: [
    SessionExecutionBlock(
      blockId: 'block',
      title: '[FIXTURE ONLY] Easy run',
      blockType: SessionBlockType.conditioning,
      content: 'Software fixture; not approved training content',
      workoutFormat: WorkoutFormat.steadyState,
      position: 1,
      timerConfiguration: TimerConfiguration(
        durationSeconds: 1500,
        runningWorkout: const RunningWorkoutCodec().decode(
          File(
            'test/session/fixtures/zone2_admission/easy_run.json',
          ).readAsStringSync(),
        ),
      ),
    ),
  ],
);
Map<String, dynamic> _document() => {
  'schema_version': 1,
  'athlete_id': _owner,
  'assignment_id': _ctx.assignmentId,
  'programme_version_id': _ctx.programmeVersionId,
  'package_hash': _ctx.packageContentHash,
  'protocol_id': 'fixture',
  'occurrence_id': _ctx.occurrenceId,
  'zone2': {
    'athlete_id': _owner,
    'revision': 'revision-a',
    'withdrawn': false,
    'confirmed_at': '2026-10-27T00:00:00Z',
    'lower_bpm': 120,
    'upper_bpm': 145,
  },
  'blocks': [
    {
      'block_id': 'block',
      'workout': _plan().blocks.single.timerConfiguration!
          .toJson()['running_workout'],
    },
  ],
};
Map<String, dynamic> _frozen() => {
  ..._document(),
  'training_session_id': 17,
  'review_hash': 'a' * 64,
  'accepted_at': '2026-10-27T01:00:00Z',
};
void _validate(Map<String, dynamic> d) => validateRunningTargetDocument(
  _plan(),
  d,
  athleteId: _owner,
  occurrenceId: _ctx.occurrenceId!,
  assignmentId: _ctx.assignmentId,
  versionId: _ctx.programmeVersionId,
  packageHash: _ctx.packageContentHash!,
);
void main() {
  tearDown(() {
    AthletePersistence.resetForTests();
    AthleteSessionMemoryStore.instance.clearAll();
  });
  test(
    'confirmed inputs are explicit numeric BPM windows; no universal formula',
    () {
      for (final pair in <List<int?>>[
        [null, 145],
        [120, null],
        [0, 145],
        [120, 251],
        [145, 120],
        [120, 120],
      ]) {
        expect(
          () => validateConfirmedZone2(pair[0], pair[1]),
          throwsFormatException,
        );
      }
      validateConfirmedZone2(120, 145);
      expect(requiresZone2Admission(_plan()), isTrue);
    },
  );
  for (final mismatch in [
    'athlete_id',
    'occurrence_id',
    'assignment_id',
    'programme_version_id',
    'package_hash',
    'protocol_id',
  ]) {
    test('review rejects wrong $mismatch', () {
      final d = _document();
      d[mismatch] = 'foreign';
      expect(() => _validate(d), throwsFormatException);
    });
  }
  test('withdrawn, malformed and changed exact source fail closed', () {
    for (final mode in ['withdrawn', 'window', 'duplicate', 'source']) {
      final d = _document();
      if (mode == 'withdrawn') d['zone2']['withdrawn'] = true;
      if (mode == 'window') d['zone2']['lower_bpm'] = '120';
      if (mode == 'duplicate') d['blocks'].add(d['blocks'].first);
      if (mode == 'source') {
        d['blocks'].first['workout']['steps'].first['label'] = 'Changed source';
      }
      expect(() => _validate(d), throwsFormatException);
    }
  });
  test(
    'source reference cannot run without frozen acceptance; pace fixtures use explicit units/order',
    () {
      expect(
        () => AuthoredTimedRunningExecution.fromBlock(_plan().blocks.single),
        throwsFormatException,
      );
      for (final target in [
        {'kind': 'pace_range', 'low': 300000, 'high': 280000},
        {'kind': 'pace_range', 'low': 0, 'high': 280000},
      ]) {
        final raw = const RunningWorkoutCodec().toJson(
          _plan().blocks.single.timerConfiguration!.runningWorkout!,
        );
        raw['steps'][1]['target'] = target;
        expect(
          const RunningWorkoutValidator()
              .validate(const RunningWorkoutCodec().decodeMap(raw))
              .isValid,
          isFalse,
        );
      }
      final raw = const RunningWorkoutCodec().toJson(
        _plan().blocks.single.timerConfiguration!.runningWorkout!,
      );
      raw['steps'][1]['target'] = {
        'kind': 'pace_range',
        'unit': 'mph',
        'low': 4,
        'high': 5,
      };
      expect(
        () => const RunningWorkoutCodec().decodeMap(raw),
        throwsA(isA<RunningWorkoutCodecException>()),
      );
    },
  );
  test(
    'exact frozen range resolves only main, survives serialization and forbids later replacement',
    () {
      final plan = applyRunningTargetAdmission(_plan(), _frozen());
      final encoded =
          jsonDecode(
                jsonEncode(const SessionExecutionPlanCodec().encodePlan(plan)),
              )
              as Map<String, dynamic>;
      final restored = const SessionExecutionPlanCodec().decodePlan(encoded);
      final run = AuthoredTimedRunningExecution.fromBlock(
        restored.blocks.single,
        admission: restored.runningTargetAdmissionSnapshot,
      );
      final steps = runningAtomicSteps(run.workout).toList();
      expect(steps.map((s) => s.target.kind), [
        RunningTargetKind.none,
        RunningTargetKind.heartRateRange,
        RunningTargetKind.none,
      ]);
      expect(
        steps[1].target,
        const RunningTarget.heartRateRange(low: 120, high: 145),
      );
      final changed = _frozen();
      changed['zone2']['lower_bpm'] = 125;
      expect(
        () => applyRunningTargetAdmission(restored, changed),
        throwsFormatException,
      );
      expect(
        () => restored.runningTargetAdmissionSnapshot!['zone2']['lower_bpm'] =
            125,
        throwsUnsupportedError,
      );
    },
  );
  test(
    'JSON key order cannot invalidate an otherwise identical frozen timer',
    () {
      final snapshot = _frozen();
      Object? reorder(Object? v) {
        if (v is Map) {
          final keys = v.keys.cast<String>().toList()
            ..sort((a, b) => b.compareTo(a));
          return {for (final key in keys) key: reorder(v[key])};
        }
        if (v is List) return v.map(reorder).toList();
        return v;
      }

      final first = AuthoredTimedRunningExecution.fromBlock(
        _plan().blocks.single,
        admission: snapshot,
      );
      final second = AuthoredTimedRunningExecution.fromBlock(
        _plan().blocks.single,
        admission: reorder(snapshot) as Map<String, dynamic>,
      );
      expect(second.executionMappingSha256, first.executionMappingSha256);
    },
  );

  testWidgets(
    'review requires explicit input confirmation and acceptance; edits cancel old preview',
    (tester) async {
      final store = _ReviewStore();
      String? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                accepted = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => RunningTargetReviewScreen(
                      athleteId: _owner,
                      plan: _plan(),
                      programmeContext: _ctx,
                      store: store,
                    ),
                  ),
                );
              },
              child: const Text('Review'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Accept targets and start'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('zone2-lower')), '145');
      await tester.enterText(find.byKey(const ValueKey('zone2-upper')), '120');
      await tester.tap(find.text('Confirm these Zone 2 limits'));
      await tester.pumpAndSettle();
      expect(store.confirmations, 0);
      await tester.enterText(find.byKey(const ValueKey('zone2-lower')), '120');
      await tester.enterText(find.byKey(const ValueKey('zone2-upper')), '145');
      await tester.tap(find.text('Confirm these Zone 2 limits'));
      await tester.pumpAndSettle();
      expect(store.confirmations, 1);
      expect(find.textContaining('Aerobic main: 120–145 bpm'), findsOneWidget);
      expect(accepted, isNull);
      await tester.enterText(find.byKey(const ValueKey('zone2-lower')), '121');
      await tester.pump();
      expect(find.text('Accept targets and start'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('zone2-lower')), '120');
      await tester.tap(find.text('Confirm these Zone 2 limits'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Accept targets and start'));
      await tester.tap(find.text('Accept targets and start'));
      await tester.pumpAndSettle();
      expect(accepted, 'a' * 64);
    },
  );
  testWidgets(
    'main step shows frozen BPM and restores paused without closed-time catch-up',
    (tester) async {
      final plan = applyRunningTargetAdmission(_plan(), _frozen());
      final execution = AuthoredTimedRunningExecution.fromBlock(
        plan.blocks.single,
        admission: plan.runningTargetAdmissionSnapshot,
      );
      final live = StructuredRunningController.fresh(
        execution: execution,
        elapsedTime: () => Duration.zero,
      );
      live.start();
      live.elapse(const Duration(seconds: 300));
      final cursor = live.cursor;
      live.dispose();
      await tester.pumpWidget(
        MaterialApp(
          home: StructuredRunningTimerScreen(
            execution: execution,
            initialCursor: cursor,
            onCheckpoint: (_) async => true,
            wallClock: () => DateTime.utc(2099),
          ),
        ),
      );
      expect(find.text('120–145 bpm'), findsOneWidget);
      expect(find.text('Aerobic main'), findsOneWidget);
      expect(find.text('900 s'), findsOneWidget);
      await tester.pump(const Duration(hours: 1));
      expect(find.text('900 s'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'canonical local restart keeps target acceptance, step, result snapshot and owner isolation',
    (tester) async {
      final kv = InMemoryKvStore();
      AthletePersistence.bindForTests(AthleteLocalRepository(kv));
      final plan = applyRunningTargetAdmission(_plan(), _frozen());
      var records = InMemoryPerformanceRecordStore();
      Widget app({String owner = _owner}) => MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                SessionExecutionLauncher(
                  saveCoordinator: PerformanceRecordSaveCoordinator(
                    store: records,
                  ),
                  restoreEnvelopeStore: ProductionRestoreEnvelopeStore(),
                ).launchActiveSessionWithPlan(
                  context: context,
                  plan: plan,
                  protocolId: 'fixture',
                  trainingSessionId: 17,
                  athleteId: owner,
                  programmeContext: _ctx,
                ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start timer'));
      await tester.tap(find.text('Start timer'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start / resume'));
      await tester.tap(find.text('Start / resume'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      final saved = await AthletePersistence.repository
          .readProductionRestoreEnvelope(
            athleteId: _owner,
            trainingSessionId: 17,
          );
      final record = (await records.getInProgressForTrainingSession(
        athleteId: _owner,
        trainingSessionId: 17,
      ))!;
      expect(record.sessionSnapshot.runningTargetAdmissionSnapshot, _frozen());
      await tester.pumpWidget(const SizedBox());
      records = InMemoryPerformanceRecordStore();
      await records.saveDraft(
        const PerformanceRecordMapper().toDraft(
          TrainingSessionRecord.fromCompletionTreeMap(
            jsonDecode(jsonEncode(record.toCompletionTreeMap()))
                as Map<String, dynamic>,
          ),
        ),
      );
      AthleteSessionMemoryStore.instance.clearAll();
      await tester.pumpWidget(app());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final after = await AthletePersistence.repository
          .readProductionRestoreEnvelope(
            athleteId: _owner,
            trainingSessionId: 17,
          );
      expect(
        after!['cursor']['authored_timed_runs']
            .single['remaining_milliseconds'],
        saved!['cursor']['authored_timed_runs']
            .single['remaining_milliseconds'],
      );
      expect(find.text('Start / resume'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _ReviewStore implements RunningTargetAdmissionStore {
  int confirmations = 0;
  bool withdrawn = false;
  @override
  Future<void> confirmZone(
    int? lower,
    int? upper, {
    bool withdraw = false,
  }) async {
    confirmations++;
    withdrawn = withdraw;
  }

  @override
  Future<Map<String, dynamic>> review(String _) async =>
      confirmations == 0 || withdrawn
      ? {
          'status': 'input_required',
          'reason': withdrawn ? 'withdrawn' : 'missing',
        }
      : {
          'status': 'review_required',
          'document': _document(),
          'review_hash': 'a' * 64,
        };
}
