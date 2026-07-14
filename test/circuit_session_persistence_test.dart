import 'package:cohort_platform/data/repositories/training_session_circuit_repository.dart';
import 'package:cohort_platform/features/session/widgets/circuit_session_view.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_movement_prescription.dart';
import 'package:cohort_platform/models/circuit_performance.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:cohort_platform/features/session/services/circuit_session_leave_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CircuitSessionView persistence', () {
    testWidgets('save and hydrate AMRAP score', (tester) async {
      final repository = InMemoryCircuitRepository();

      await _pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'AMRAP Test',
          plan: _amrapPlan(),
          trainingSessionId: 42,
          protocolId: 'proto-1',
          circuitRepository: repository,
          onFinishSession: (_) async {},
        ),
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('circuit-completed-rounds')),
          matching: find.byType(TextField),
        ),
        '5',
      );
      await tester.pump();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('circuit-additional-reps')),
          matching: find.byType(TextField),
        ),
        '12',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('circuit-save-progress')));
      await _pumpFrames(tester);

      expect(repository.upsertCount, 1);
      expect(repository.stored?.completedRounds, 5);
      expect(repository.stored?.additionalReps, 12);
      expect(repository.stored?.completed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await _pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'AMRAP Test',
          plan: _amrapPlan(),
          trainingSessionId: 42,
          protocolId: 'proto-1',
          circuitRepository: repository,
          onFinishSession: (_) async {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('circuit-completed-rounds')),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
      final roundsField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('circuit-completed-rounds')),
          matching: find.byType(TextField),
        ),
      );
      expect(roundsField.controller?.text, '5');
    });

    testWidgets('save and hydrate for-time elapsed duration', (tester) async {
      final repository = InMemoryCircuitRepository();

      await _pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'For Time Test',
          plan: _forTimePlan(),
          trainingSessionId: 42,
          protocolId: 'proto-1',
          circuitRepository: repository,
          onFinishSession: (_) async {},
        ),
      );

      await tester.tap(find.text('Enter result after training'));
      await _pumpFrames(tester);

      final elapsedFields = find.byKey(const ValueKey('circuit-elapsed-time'));
      await tester.enterText(
        find.descendant(of: elapsedFields, matching: find.byType(TextField)).first,
        '14',
      );
      await tester.pump();
      await tester.enterText(
        find.descendant(of: elapsedFields, matching: find.byType(TextField)).last,
        '32',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('circuit-save-progress')));
      await _pumpFrames(tester);

      expect(repository.stored?.elapsedDurationSeconds, 872);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await _pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'For Time Test',
          plan: _forTimePlan(),
          trainingSessionId: 42,
          protocolId: 'proto-1',
          circuitRepository: repository,
          onFinishSession: (_) async {},
        ),
      );

      await tester.tap(find.text('Enter result after training'));
      await _pumpFrames(tester);

      final minutesField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('circuit-elapsed-time')),
          matching: find.byType(TextField),
        ).first,
      );
      final secondsField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('circuit-elapsed-time')),
          matching: find.byType(TextField),
        ).last,
      );
      expect(minutesField.controller?.text, '14');
      expect(secondsField.controller?.text, '32');
    });

    testWidgets('resume later persists progress and pops', (tester) async {
      final repository = InMemoryCircuitRepository();
      CircuitSessionLeaveCoordinator? coordinator;

      await _pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Live AMRAP',
          plan: _amrapPlan(),
          trainingSessionId: 42,
          protocolId: 'proto-1',
          circuitRepository: repository,
          onFinishSession: (_) async {},
          onLeaveCoordinatorReady: (value) => coordinator = value,
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(coordinator, isNotNull);
      final leaveFuture =
          coordinator!.confirmLeave(tester.element(find.byType(Scaffold)));
      await _pumpFrames(tester);

      await tester.tap(find.text('Resume later'));
      await _pumpFrames(tester);
      await leaveFuture;

      expect(repository.upsertCount, greaterThanOrEqualTo(1));
      expect(repository.stored?.completed, isFalse);
    });

    testWidgets('end early persists completed result', (tester) async {
      final repository = InMemoryCircuitRepository();
      var finished = false;

      await _pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Live AMRAP',
          plan: _amrapPlan(),
          trainingSessionId: 42,
          protocolId: 'proto-1',
          circuitRepository: repository,
          onFinishSession: (_) async {
            finished = true;
          },
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.tap(find.text('End Session Early'));
      await _pumpFrames(tester);
      await tester.tap(find.text('End session'));
      await _pumpFrames(tester);

      expect(finished, isTrue);
      expect(repository.stored?.completed, isTrue);
    });

    testWidgets('preview remains non-persistent', (tester) async {
      final repository = InMemoryCircuitRepository();

      await _pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Preview WOD',
          plan: _amrapPlan(),
          previewMode: true,
          circuitRepository: repository,
          onFinishSession: (_) async {},
        ),
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('circuit-completed-rounds')),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('circuit-save-progress')), findsNothing);

      await tester.tap(find.text('Finish Session'));
      await _pumpFrames(tester);

      expect(repository.upsertCount, 0);
    });
  });
}

Future<void> _pumpCircuitView(
  WidgetTester tester,
  Widget child,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 3}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class InMemoryCircuitRepository implements TrainingSessionCircuitStore {
  CircuitPerformance? stored;
  int upsertCount = 0;

  @override
  Future<CircuitPerformance> upsertCircuitPerformance(
    CircuitPerformance performance,
  ) async {
    upsertCount++;
    stored = CircuitPerformance(
      id: 1,
      trainingSessionId: performance.trainingSessionId,
      protocolId: performance.protocolId,
      circuitFormat: performance.circuitFormat,
      scoreType: performance.scoreType,
      elapsedDurationSeconds: performance.elapsedDurationSeconds,
      completedRounds: performance.completedRounds,
      additionalReps: performance.additionalReps,
      totalReps: performance.totalReps,
      completedIntervals: performance.completedIntervals,
      completedMovements: performance.completedMovements,
      prescribedLoad: performance.prescribedLoad,
      actualLoad: performance.actualLoad,
      rpe: performance.rpe,
      completed: performance.completed,
      timeCapped: performance.timeCapped,
      skipped: performance.skipped,
      dataSource: performance.dataSource,
      athleteNote: performance.athleteNote,
    );
    return stored!;
  }

  @override
  Future<CircuitPerformance?> getPerformanceForTrainingSession(
    int trainingSessionId,
  ) async {
    if (stored?.trainingSessionId == trainingSessionId) {
      return stored;
    }

    return null;
  }
}

CircuitSessionPlan _amrapPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'AMRAP Test',
    format: CircuitFormat.amrap,
    scoreType: CircuitScoreType.roundsAndReps,
    movements: [
      CircuitMovementPrescription(
        localId: 'm-1',
        orderIndex: 1,
        title: 'Burpees',
        reps: '10',
      ),
    ],
  );
}

CircuitSessionPlan _forTimePlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'For Time Test',
    format: CircuitFormat.forTime,
    scoreType: CircuitScoreType.elapsedTime,
    movements: [],
  );
}
