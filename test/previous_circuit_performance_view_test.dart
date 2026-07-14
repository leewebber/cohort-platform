import 'package:cohort_platform/features/session/services/previous_circuit_performance_service.dart';
import 'package:cohort_platform/features/session/widgets/circuit_session_view.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_movement_prescription.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:cohort_platform/models/previous_circuit_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpView(
    WidgetTester tester,
    CircuitSessionView child,
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
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('CircuitSessionView previous performance', () {
    testWidgets('shows first performance message when no history', (tester) async {
      await pumpView(
        tester,
        CircuitSessionView(
          sessionTitle: 'AMRAP Test',
          plan: _amrapPlan(),
          athleteId: 'athlete-1',
          protocolId: 'WOD-001',
          trainingSessionId: 42,
          previousPerformanceService: _FakePreviousService(null),
          onFinishSession: (_) async {},
        ),
      );

      expect(
        find.text('This is your first recorded circuit performance.'),
        findsOneWidget,
      );
      expect(find.text('LAST PERFORMANCE'), findsNothing);
    });

    testWidgets('shows AMRAP last performance summary', (tester) async {
      await pumpView(
        tester,
        CircuitSessionView(
          sessionTitle: 'AMRAP Test',
          plan: _amrapPlan(),
          athleteId: 'athlete-1',
          protocolId: 'WOD-001',
          trainingSessionId: 42,
          previousPerformanceService: _FakePreviousService(
            const PreviousCircuitPerformance(
              circuitFormat: CircuitFormat.amrap,
              scoreType: CircuitScoreType.roundsAndReps,
              displaySummary: '8 rounds + 12 reps',
              averageRpe: 8,
              todayOpportunities:
                  PreviousCircuitPerformance.defaultTodayOpportunities,
            ),
          ),
          onFinishSession: (_) async {},
        ),
      );

      expect(find.text('LAST PERFORMANCE'), findsOneWidget);
      expect(find.text('8 rounds + 12 reps'), findsOneWidget);
      expect(find.text('RPE 8'), findsOneWidget);
      expect(find.text("TODAY'S OPPORTUNITY"), findsOneWidget);
    });

    testWidgets('hides previous performance in preview mode', (tester) async {
      await pumpView(
        tester,
        CircuitSessionView(
          sessionTitle: 'Preview WOD',
          plan: _amrapPlan(),
          previewMode: true,
          athleteId: 'athlete-1',
          protocolId: 'WOD-001',
          previousPerformanceService: _FakePreviousService(
            const PreviousCircuitPerformance(
              circuitFormat: CircuitFormat.amrap,
              scoreType: CircuitScoreType.roundsAndReps,
              displaySummary: '8 rounds + 12 reps',
              todayOpportunities:
                  PreviousCircuitPerformance.defaultTodayOpportunities,
            ),
          ),
          onFinishSession: (_) async {},
        ),
      );

      expect(find.text('LAST PERFORMANCE'), findsNothing);
      expect(
        find.text('This is your first recorded circuit performance.'),
        findsNothing,
      );
    });
  });
}

class _FakePreviousService extends PreviousCircuitPerformanceService {
  _FakePreviousService(this._result);

  final PreviousCircuitPerformance? _result;

  @override
  Future<PreviousCircuitPerformance?> load({
    required String athleteId,
    required String protocolId,
    int? excludeTrainingSessionId,
    int? prescribedIntervalCount,
  }) async {
    return _result;
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
