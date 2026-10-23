import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/application/hyrox_base/programme_prescription_repository.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/domain/hyrox_base/programme_prescription.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/screens/programme_prescription_review_screen.dart';
import 'package:cohort_platform/features/session/models/bound_programme_execution.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/screens/block_timer_screen.dart';
import 'package:cohort_platform/features/session/services/block_timer_controller.dart';
import 'package:cohort_platform/features/session/services/circuit_block_timer_bridge.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';

const scope = ProgrammeExecutionContext(
  assignmentId: 'assignment',
  programmeVersionId: 'version',
  sessionSlotId: 'slot',
  weekNumber: 1,
  dayKey: 'day_1',
  sessionOrder: 1,
  plannedProtocolId: 'source',
  effectiveProtocolId: 'source',
  programmeName: 'Assigned programme',
  programmeVersionNumber: 2,
  packageSchemaVersion: 3,
  packageSlotKey: 'slot-key',
  packageContentHash: 'hash',
);
const timer = TimerConfiguration(workSeconds: 2, restSeconds: 1, rounds: 2);
const plan = SessionExecutionPlan(
  sessionId: 'source',
  sessionTitle: 'Session',
  blocks: [
    SessionExecutionBlock(
      blockId: 'block',
      title: 'Running',
      blockType: SessionBlockType.conditioning,
      content: '',
      workoutFormat: WorkoutFormat.intervals,
      position: 1,
      timerConfiguration: timer,
      linkedExercises: [
        SessionExecutionExerciseSummary(exerciseId: 'EX-1', displayName: 'Run'),
      ],
    ),
  ],
);
Map<String, dynamic> packet() {
  final calc = {
    'status': 'calculated',
    'unit': 'milliseconds_per_kilometre',
    'faster': {'numerator': 300000, 'denominator': 1},
    'slower': {'numerator': 315000, 'denominator': 1},
  };
  return {
    'schema_version': 1,
    'athlete_id': 'athlete',
    'assignment_id': 'assignment',
    'programme_version_id': 'version',
    'package_hash': 'hash',
    'prescriptions': [
      {
        'binding': {
          'kind': 'runningIntervals',
          'identity_namespace': 'canonical_exercise',
          'block_id': 'block',
          'slot_key': 'slot-key',
          'protocol_id': 'source',
          'week_number': 1,
          'step_ids': ['work-1', 'work-2'],
          'exercise': {'id': 'EX-1'},
        },
        'authored': {
          'repetitions': 2,
          'work_seconds': 2,
          'recovery_seconds': 1,
        },
        'calculated': calc,
        'steps': [
          {
            'step_id': 'work-1',
            'kind': 'work',
            'duration_seconds': 2,
            'target': calc,
          },
          {
            'step_id': 'recovery-1',
            'kind': 'recovery',
            'duration_seconds': 1,
            'target': null,
          },
          {
            'step_id': 'work-2',
            'kind': 'work',
            'duration_seconds': 2,
            'target': calc,
          },
        ],
        'authored_effort': 'approximate RPE 7 / repeatable',
        'actual': null,
      },
    ],
  };
}

void main() {
  test(
    'strict runner refuses different timers, IDs and recovery targets; preserves structured frozen data through codec',
    () {
      final p = ProgrammePrescription(packet());
      final bound = bindProgrammePrescription(
        plan: plan,
        prescription: p,
        protocolId: 'source',
        slotKey: 'slot-key',
      );
      expect(bound.blocks.single.boundTarget!.targetLabel, '5:00.0–5:15.0 /km');
      final restored = const SessionExecutionPlanCodec().decodePlan(
        const SessionExecutionPlanCodec().encodePlan(bound),
      );
      expect(restored.boundPrescriptionSnapshot, p.json);
      expect(restored.blocks.single.boundTarget!.json, p.targets.single.json);
      final invalidCursor = CircuitBlockTimerBridge.cursorFrom(
        const BlockTimerState(
          format: WorkoutFormat.intervals,
          phase: BlockTimerPhase.stopwatch,
          isRunning: false,
          isPaused: true,
          isFinished: false,
          primarySeconds: 1,
          currentRound: 1,
          totalRounds: 2,
        ),
      );
      expect(
        () => CircuitBlockTimerBridge.restoredState(
          block: bound.blocks.single,
          result: IntervalResultData(
            workSeconds: 2,
            totalIntervals: 2,
            timerCursor: invalidCursor,
          ),
        ),
        throwsFormatException,
      );

      for (final mutate in <void Function(Map<String, dynamic>)>[
        (p) => p['prescriptions'][0]['steps'][1]['target'] = {
          'status': 'calculated',
        },
        (p) => p['prescriptions'][0]['binding']['exercise']['id'] = 'other',
        (p) => p['prescriptions'][0]['authored']['work_seconds'] = 10,
        (p) => p['prescriptions'][0]['binding']['step_ids'] = ['guessed'],
      ]) {
        final bad = packet();
        mutate(bad);
        expect(
          () => bindProgrammePrescription(
            plan: plan,
            prescription: ProgrammePrescription(bad),
            protocolId: 'source',
            slotKey: 'slot-key',
          ),
          throwsFormatException,
        );
      }
      expect(
        () => p.targets.single.json['calculated']['status'] = 'override',
        throwsUnsupportedError,
      );
      expect(
        samePrescription(
          {
            'a': 1,
            'b': [2],
          },
          {
            'b': [2],
            'a': 1,
          },
        ),
        true,
      );
    },
  );
  testWidgets(
    'timer renders frozen pace on work only, recovery between repetitions and no final recovery; resume cursor preserves work dose',
    (tester) async {
      final target = ProgrammePrescription(packet()).targets.single;
      await tester.pumpWidget(
        MaterialApp(
          home: BlockTimerScreen(
            blockTitle: 'Running',
            format: WorkoutFormat.intervals,
            configuration: timer,
            boundTarget: target,
          ),
        ),
      );
      expect(find.text('Prescribed · 5:00.0–5:15.0 /km'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Recovery · no pace target'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Prescribed · 5:00.0–5:15.0 /km'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Recovery · no pace target'), findsNothing);
      final cursor = CircuitBlockTimerBridge.cursorFrom(
        const BlockTimerState(
          format: WorkoutFormat.intervals,
          phase: BlockTimerPhase.rest,
          isRunning: true,
          isPaused: false,
          isFinished: false,
          primarySeconds: 1,
          currentRound: 1,
          totalRounds: 2,
        ),
      );
      final result = IntervalResultData.fromJson(
        IntervalResultData(
          workSeconds: 2,
          totalIntervals: 2,
          timerCursor: cursor,
        ).toJson(),
      );
      final restored = CircuitBlockTimerBridge.restoredState(
        block: plan.blocks.single,
        result: result,
      )!;
      expect(restored.phase, BlockTimerPhase.rest);
      expect(restored.isPaused, true);
      expect(result.workSeconds, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'review is explicit, readable, invalidated by edits; refused/stale consent cannot launch',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var consents = 0;
      final repository = ProgrammePrescriptionRepository(
        rpc: (name, params) async {
          if (name == 'read_hyrox_programme_prescription_state') {
            return {'status': 'read', 'consent': null, 'benchmarks': []};
          }
          if (name == 'review_hyrox_programme_prescription') {
            return {
              'status': 'review',
              'review_id': 'review',
              'expected_consent_id': null,
              'document': packet(),
            };
          }
          consents++;
          return {'status': 'refused', 'reason': 'stale_review'};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProgrammePrescriptionReviewScreen(
            athleteId: 'athlete',
            executionContext: scope,
            plan: plan,
            repository: repository,
            forLaunch: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assigned programme'), findsOneWidget);
      expect(find.text('Version 2 · Week 1'), findsOneWidget);
      expect(find.text('Accept and begin session'), findsNothing);
      await tester.ensureVisible(find.text('Review calculated targets'));
      await tester.tap(find.text('Review calculated targets'));
      await tester.pumpAndSettle();
      expect(find.text('5:00.0–5:15.0 /km'), findsOneWidget);
      await tester.ensureVisible(find.text('Accept and begin session'));
      await tester.tap(find.text('Accept and begin session'));
      await tester.pumpAndSettle();
      expect(consents, 1);
      expect(find.text('Accept and begin session'), findsNothing);
      expect(
        find.byKey(const ValueKey('programme-target-error')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Review calculated targets'));
      await tester.tap(find.text('Review calculated targets'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '2.5');
      await tester.pumpAndSettle();
      expect(find.text('Accept and begin session'), findsNothing);
    },
  );
  testWidgets('backend unavailable never offers consent or synthetic target', (
    tester,
  ) async {
    final repository = ProgrammePrescriptionRepository(
      rpc: (_, _) async => throw StateError('unavailable'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProgrammePrescriptionReviewScreen(
          athleteId: 'athlete',
          executionContext: scope,
          plan: plan,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('programme-target-error')),
      findsOneWidget,
    );
    expect(find.text('Accept programme targets'), findsNothing);
    expect(find.text('Review calculated targets'), findsNothing);
  });
}
