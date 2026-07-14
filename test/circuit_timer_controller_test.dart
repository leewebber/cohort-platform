import 'package:cohort_platform/features/session/services/circuit_timer_controller.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:cohort_platform/features/session/models/circuit_timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitTimerController', () {
    test('counts up for for-time sessions', () {
      final plan = _forTimePlan();
      CircuitTimerState? latest;
      final controller = CircuitTimerController(
        plan: plan,
        onStateChanged: (state) => latest = state,
      );

      controller.start();
      expect(latest?.mode, CircuitTimerMode.countUp);
      expect(latest?.elapsedSeconds, 0);

      controller.finish();
      expect(latest?.finished, isTrue);
      expect(latest?.elapsedSeconds, 0);
    });

    test('starts countdown for AMRAP sessions', () {
      final plan = _amrapPlan();
      CircuitTimerState? latest;
      var finished = false;

      final controller = CircuitTimerController(
        plan: plan,
        onStateChanged: (state) => latest = state,
        onFinished: (_) => finished = true,
      );

      controller.start();
      expect(latest?.mode, CircuitTimerMode.countDown);
      expect(latest?.primarySeconds, 120);

      controller.finish();
      expect(finished, isTrue);
      expect(latest?.finished, isTrue);
    });

    test('shows interval phase for EMOM sessions', () {
      final plan = _emomPlan();
      CircuitTimerState? latest;
      final controller = CircuitTimerController(
        plan: plan,
        onStateChanged: (state) => latest = state,
      );

      expect(
        CircuitTimerController.resolveMode(plan),
        CircuitTimerMode.intervalPhase,
      );

      controller.start();
      expect(latest?.currentInterval, 1);
      expect(latest?.totalIntervals, 3);
      expect(latest?.primarySeconds, 60);
    });
  });
}

CircuitSessionPlan _amrapPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'AMRAP Test',
    format: CircuitFormat.amrap,
    scoreType: CircuitScoreType.roundsAndReps,
    movements: [],
    timeCap: Duration(minutes: 2),
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
    movements: [],
    workInterval: Duration(seconds: 60),
    intervalCount: 3,
  );
}
