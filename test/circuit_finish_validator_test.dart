import 'package:cohort_platform/features/session/models/circuit_timer_state.dart';
import 'package:cohort_platform/features/session/services/circuit_finish_validator.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_performance_entry.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_execution_state.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = CircuitFinishValidator();

  group('CircuitFinishValidator', () {
    test('accepts AMRAP rounds plus reps', () {
      const performance = CircuitPerformanceEntry(
        localId: 'perf-1',
        completedRounds: 5,
        additionalReps: 12,
      );

      expect(
        validator.hasValidScore(
          performance: performance,
          scoreType: CircuitScoreType.roundsAndReps,
        ),
        isTrue,
      );
    });

    test('rejects empty for-time score', () {
      const performance = CircuitPerformanceEntry(localId: 'perf-2');

      expect(
        validator.hasValidScore(
          performance: performance,
          scoreType: CircuitScoreType.elapsedTime,
        ),
        isFalse,
      );
    });

    test('detects work started after timer begins', () {
      final state = CircuitSessionExecutionState(
        plan: _plan(),
        performance: const CircuitPerformanceEntry(localId: 'perf-3'),
      );

      expect(
        validator.hasWorkStarted(
          state: state,
          timerState: const CircuitTimerState(
            mode: CircuitTimerMode.countUp,
            isStarted: true,
          ),
        ),
        isTrue,
      );
    });

    test('describes EMOM interval progress', () {
      final state = CircuitSessionExecutionState(
        plan: _emomPlan(),
        performance: const CircuitPerformanceEntry(
          localId: 'perf-4',
          completedRounds: 2,
        ),
      );

      expect(
        validator.progressSummary(state: state),
        '2 of 5 intervals complete',
      );
    });
  });
}

CircuitSessionPlan _plan() {
  return const CircuitSessionPlan(
    sessionTitle: 'Test',
    format: CircuitFormat.forTime,
    scoreType: CircuitScoreType.elapsedTime,
    movements: [],
  );
}

CircuitSessionPlan _emomPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'EMOM',
    format: CircuitFormat.emom,
    scoreType: CircuitScoreType.roundsCompleted,
    movements: [],
    intervalCount: 5,
  );
}
