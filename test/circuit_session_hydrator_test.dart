import 'package:cohort_platform/features/session/services/circuit_session_hydrator.dart';
import 'package:cohort_platform/models/circuit_data_source.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_performance.dart';
import 'package:cohort_platform/models/circuit_performance_entry.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_execution_state.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hydrator = CircuitSessionHydrator();

  group('CircuitSessionHydrator', () {
    test('hydrates AMRAP score fields', () {
      final baseState = _baseState(_amrapPlan());
      final persisted = CircuitPerformance(
        id: 1,
        trainingSessionId: 42,
        protocolId: 'proto-1',
        circuitFormat: CircuitFormat.amrap,
        scoreType: CircuitScoreType.roundsAndReps,
        completedRounds: 6,
        additionalReps: 9,
        completed: false,
        timeCapped: false,
        skipped: false,
        dataSource: CircuitDataSource.manual,
      );

      final hydrated = hydrator.hydrate(
        plan: _amrapPlan(),
        baseState: baseState,
        persisted: persisted,
        preservePerformance: false,
      );

      expect(hydrated.performance.completedRounds, 6);
      expect(hydrated.performance.additionalReps, 9);
    });

    test('hydrates for-time elapsed duration', () {
      final baseState = _baseState(_forTimePlan());
      final persisted = CircuitPerformance(
        id: 1,
        trainingSessionId: 42,
        protocolId: 'proto-1',
        circuitFormat: CircuitFormat.forTime,
        scoreType: CircuitScoreType.elapsedTime,
        elapsedDurationSeconds: 872,
        completed: false,
        timeCapped: false,
        skipped: false,
        dataSource: CircuitDataSource.manual,
      );

      final hydrated = hydrator.hydrate(
        plan: _forTimePlan(),
        baseState: baseState,
        persisted: persisted,
        preservePerformance: false,
      );

      expect(
        hydrated.performance.elapsedDuration,
        const Duration(minutes: 14, seconds: 32),
      );
    });

    test('preserves local performance when flagged', () {
      final baseState = _baseState(_amrapPlan()).updatePerformance(
        const CircuitPerformanceEntry(
          localId: 'local-1',
          completedRounds: 2,
          additionalReps: 1,
        ),
      );
      final persisted = CircuitPerformance(
        id: 1,
        trainingSessionId: 42,
        protocolId: 'proto-1',
        circuitFormat: CircuitFormat.amrap,
        scoreType: CircuitScoreType.roundsAndReps,
        completedRounds: 6,
        additionalReps: 9,
        completed: false,
        timeCapped: false,
        skipped: false,
        dataSource: CircuitDataSource.manual,
      );

      final hydrated = hydrator.hydrate(
        plan: _amrapPlan(),
        baseState: baseState,
        persisted: persisted,
        preservePerformance: true,
      );

      expect(hydrated.performance.completedRounds, 2);
      expect(hydrated.performance.additionalReps, 1);
    });

    test('restores EMOM interval progress into current round', () {
      final baseState = _baseState(_emomPlan());
      final persisted = CircuitPerformance(
        id: 1,
        trainingSessionId: 42,
        protocolId: 'proto-1',
        circuitFormat: CircuitFormat.emom,
        scoreType: CircuitScoreType.roundsCompleted,
        completedIntervals: 2,
        completed: false,
        timeCapped: false,
        skipped: false,
        dataSource: CircuitDataSource.manual,
      );

      final hydrated = hydrator.hydrate(
        plan: _emomPlan(),
        baseState: baseState,
        persisted: persisted,
        preservePerformance: false,
      );

      expect(hydrated.performance.completedRounds, 2);
      expect(hydrated.currentRound, 3);
    });
  });
}

CircuitSessionExecutionState _baseState(CircuitSessionPlan plan) {
  return CircuitSessionExecutionState(
    plan: plan,
    performance: const CircuitPerformanceEntry(localId: 'local-1'),
    trainingSessionId: 42,
  );
}

CircuitSessionPlan _amrapPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'AMRAP',
    format: CircuitFormat.amrap,
    scoreType: CircuitScoreType.roundsAndReps,
    movements: [],
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
