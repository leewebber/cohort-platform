import 'package:cohort_platform/features/session/services/circuit_performance_mapper.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_movement_prescription.dart';
import 'package:cohort_platform/models/circuit_performance_entry.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = CircuitPerformanceMapper();

  group('CircuitPerformanceMapper', () {
    test('maps AMRAP rounds plus reps', () {
      final performance = mapper.fromEntry(
        trainingSessionId: 12,
        protocolId: 'proto-1',
        plan: _amrapPlan(),
        entry: const CircuitPerformanceEntry(
          localId: 'local-1',
          completedRounds: 7,
          additionalReps: 4,
          timeCapped: true,
        ),
        completed: false,
      );

      expect(performance.completedRounds, 7);
      expect(performance.additionalReps, 4);
      expect(performance.completedIntervals, isNull);
      expect(performance.timeCapped, isTrue);
      expect(performance.completed, isFalse);
    });

    test('maps for-time elapsed duration', () {
      final performance = mapper.fromEntry(
        trainingSessionId: 12,
        protocolId: 'proto-1',
        plan: _forTimePlan(),
        entry: const CircuitPerformanceEntry(
          localId: 'local-1',
          elapsedDuration: Duration(minutes: 14, seconds: 32),
        ),
        completed: true,
      );

      expect(performance.elapsedDurationSeconds, 872);
      expect(performance.circuitFormat, CircuitFormat.forTime);
      expect(performance.scoreType, CircuitScoreType.elapsedTime);
      expect(performance.completed, isTrue);
    });

    test('maps EMOM intervals to completed_intervals', () {
      final performance = mapper.fromEntry(
        trainingSessionId: 12,
        protocolId: 'proto-1',
        plan: _emomPlan(),
        entry: const CircuitPerformanceEntry(
          localId: 'local-1',
          completedRounds: 3,
        ),
        completed: false,
      );

      expect(performance.completedIntervals, 3);
      expect(performance.completedRounds, isNull);
    });
  });
}

CircuitSessionPlan _amrapPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'AMRAP',
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
    sessionTitle: 'For Time',
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
    intervalCount: 5,
    movements: [],
  );
}
