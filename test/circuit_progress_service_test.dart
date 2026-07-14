import 'package:cohort_platform/features/session/services/circuit_progress_service.dart';
import 'package:cohort_platform/models/circuit_data_source.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_performance_entry.dart';
import 'package:cohort_platform/models/circuit_progress_result.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/circuit_session_plan.dart';
import 'package:cohort_platform/models/previous_circuit_performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CircuitProgressService();

  group('CircuitProgressService', () {
    test('detects first performance when no prior session exists', () {
      final result = service.evaluate(
        previousPerformance: null,
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 5,
          additionalReps: 3,
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.firstPerformance);
      expect(result.headline, 'First recorded circuit performance.');
    });

    test('detects more AMRAP rounds', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 7,
          additionalReps: 4,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 8,
          additionalReps: 2,
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.moreRoundsOrReps);
      expect(result.headline, 'More rounds or reps completed.');
    });

    test('detects same rounds with more reps', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 7,
          additionalReps: 4,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 7,
          additionalReps: 12,
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.moreRoundsOrReps);
    });

    test('detects faster for-time completion', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.elapsedTime,
          elapsedDuration: const Duration(minutes: 18, seconds: 42),
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          elapsedDuration: Duration(minutes: 17, seconds: 58),
        ),
        plan: _forTimePlan(),
      );

      expect(result.progressType, CircuitProgressType.fasterCompletion);
      expect(result.headline, 'Faster completion.');
    });

    test('detects more total reps', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.totalReps,
          totalReps: 120,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          totalReps: 135,
        ),
        plan: _fixedDurationPlan(),
      );

      expect(result.progressType, CircuitProgressType.moreWorkCompleted);
    });

    test('detects more intervals completed', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.roundsCompleted,
          circuitFormat: CircuitFormat.emom,
          completedIntervals: 16,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 18,
        ),
        plan: _emomPlan(),
      );

      expect(result.progressType, CircuitProgressType.moreWorkCompleted);
      expect(result.headline, 'More work completed.');
    });

    test('detects heavier load with equal score', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 6,
          additionalReps: 0,
          actualLoad: '40 kg',
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 6,
          additionalReps: 0,
          actualLoad: '43 kg',
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.heavierLoad);
    });

    test('detects lower RPE at same score', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 6,
          additionalReps: 3,
          averageRpe: 8,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 6,
          additionalReps: 3,
          rpe: 6,
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.effortImproved);
      expect(result.headline, 'Same work at lower effort.');
    });

    test('detects matched performance', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 6,
          additionalReps: 3,
          averageRpe: 7,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 6,
          additionalReps: 3,
          rpe: 7,
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.matchedPerformance);
    });

    test('detects mixed result when score declines', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.roundsAndReps,
          completedRounds: 8,
          additionalReps: 4,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 6,
          additionalReps: 10,
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.mixedResult);
    });

    test('returns insufficient data for incompatible time-capped comparison', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.elapsedTime,
          elapsedDuration: const Duration(minutes: 18, seconds: 42),
          timeCapped: true,
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          elapsedDuration: Duration(minutes: 17, seconds: 30),
        ),
        plan: _forTimePlan(),
      );

      expect(result.progressType, CircuitProgressType.insufficientData);
    });

    test('returns insufficient data for incompatible score types', () {
      final result = service.evaluate(
        previousPerformance: _previous(
          scoreType: CircuitScoreType.elapsedTime,
          elapsedDuration: const Duration(minutes: 18, seconds: 42),
        ),
        todayPerformance: const CircuitPerformanceEntry(
          localId: 'today',
          completedRounds: 6,
        ),
        plan: _amrapPlan(),
      );

      expect(result.progressType, CircuitProgressType.insufficientData);
    });
  });
}

PreviousCircuitPerformance _previous({
  CircuitFormat circuitFormat = CircuitFormat.amrap,
  required CircuitScoreType scoreType,
  Duration? elapsedDuration,
  int? completedRounds,
  int? additionalReps,
  int? totalReps,
  int? completedIntervals,
  int? completedMovements,
  String? actualLoad,
  int? averageRpe,
  bool timeCapped = false,
}) {
  return PreviousCircuitPerformance(
    circuitFormat: circuitFormat,
    scoreType: scoreType,
    displaySummary: 'Previous score',
    todayOpportunities: PreviousCircuitPerformance.defaultTodayOpportunities,
    elapsedDuration: elapsedDuration,
    completedRounds: completedRounds,
    additionalReps: additionalReps,
    totalReps: totalReps,
    completedIntervals: completedIntervals,
    completedMovements: completedMovements,
    actualLoad: actualLoad,
    averageRpe: averageRpe,
    timeCapped: timeCapped,
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

CircuitSessionPlan _fixedDurationPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'Fixed Duration',
    format: CircuitFormat.fixedDuration,
    scoreType: CircuitScoreType.totalReps,
    movements: [],
  );
}

CircuitSessionPlan _emomPlan() {
  return const CircuitSessionPlan(
    sessionTitle: 'EMOM',
    format: CircuitFormat.emom,
    scoreType: CircuitScoreType.roundsCompleted,
    intervalCount: 20,
    movements: [],
  );
}
