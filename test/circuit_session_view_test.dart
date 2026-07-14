import 'package:cohort_platform/features/session/models/circuit_session_finish_summary.dart';
import 'package:cohort_platform/features/session/widgets/circuit_session_view.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_movement_prescription.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCircuitView(
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
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CircuitSessionView', () {
    testWidgets('shows AMRAP score fields and enables finish after entry',
        (tester) async {
      CircuitSessionFinishSummary? summary;

      await pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Bodyweight Grinder',
          plan: _amrapPlan(),
          previewMode: true,
          onFinishSession: (value) async {
            summary = value;
          },
        ),
      );

      expect(find.text('AMRAP'), findsOneWidget);
      expect(find.text('Completed rounds'), findsOneWidget);
      expect(find.text('Finish Session'), findsNothing);

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

      expect(find.text('Finish Session'), findsOneWidget);

      await tester.tap(find.text('Finish Session'));
      await tester.pumpAndSettle();

      expect(summary, isNotNull);
      final finished = summary!;
      expect(finished.format, CircuitFormat.amrap);
      expect(finished.performance.completedRounds, 5);
      expect(finished.performance.additionalReps, 12);
      expect(finished.endedEarly, isFalse);
    });

    testWidgets('shows EMOM interval clock after start', (tester) async {
      await pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Bike Burner',
          plan: _emomPlan(),
          previewMode: true,
          onFinishSession: (_) async {},
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('Interval 1 of 3'), findsOneWidget);
      expect(find.text('Interval clock'), findsOneWidget);
      expect(find.text('Skip interval'), findsOneWidget);
      expect(find.text('+15 sec'), findsOneWidget);
    });

    testWidgets('preview finish returns summary through callback',
        (tester) async {
      CircuitSessionFinishSummary? summary;

      await pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Preview WOD',
          plan: _forTimePlan(),
          previewMode: true,
          onFinishSession: (value) async {
            summary = value;
          },
        ),
      );

      await tester.tap(find.text('Enter result after training'));
      await tester.pumpAndSettle();

      final elapsedFields = find.byKey(const ValueKey('circuit-elapsed-time'));
      await tester.enterText(
        find.descendant(
          of: elapsedFields,
          matching: find.byType(TextField),
        ).first,
        '14',
      );
      await tester.pump();
      await tester.enterText(
        find.descendant(
          of: elapsedFields,
          matching: find.byType(TextField),
        ).last,
        '32',
      );
      await tester.pump();

      await tester.tap(find.text('Finish Session'));
      await tester.pumpAndSettle();

      expect(
        summary?.performance.elapsedDuration,
        const Duration(minutes: 14, seconds: 32),
      );
    });

    testWidgets('shows end session early after work starts', (tester) async {
      await pumpCircuitView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Live AMRAP',
          plan: _amrapPlan(),
          trainingSessionId: 42,
          onFinishSession: (_) async {},
        ),
      );

      expect(find.text('End Session Early'), findsNothing);

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('End Session Early'), findsOneWidget);
    });
  });
}

CircuitSessionPlan _amrapPlan() {
  return CircuitSessionPlan(
    sessionTitle: 'AMRAP Test',
    format: CircuitFormat.amrap,
    scoreType: CircuitScoreType.roundsAndReps,
    timeCap: const Duration(minutes: 12),
    movements: const [
      CircuitMovementPrescription(
        localId: 'm-1',
        orderIndex: 1,
        title: 'Burpees',
        reps: '10',
      ),
      CircuitMovementPrescription(
        localId: 'm-2',
        orderIndex: 2,
        title: 'Air Squats',
        reps: '15',
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

CircuitSessionPlan _emomPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'EMOM Test',
    format: CircuitFormat.emom,
    scoreType: CircuitScoreType.roundsCompleted,
    workInterval: Duration(seconds: 60),
    intervalCount: 3,
    movements: [
      CircuitMovementPrescription(
        localId: 'm-1',
        orderIndex: 1,
        title: 'Calories',
        reps: '12',
      ),
    ],
  );
}
