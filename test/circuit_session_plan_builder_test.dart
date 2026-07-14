import 'package:cohort_platform/features/session/services/circuit_session_plan_builder.dart';
import 'package:cohort_platform/models/circuit_format.dart';
import 'package:cohort_platform/models/circuit_score_type.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = CircuitSessionPlanBuilder();

  group('CircuitSessionPlanBuilder', () {
    test('compiles AMRAP structure with time cap and rounds+reps score', () {
      final plan = builder.build(
        protocol: _amrapProtocol,
        steps: _amrapSteps,
      );

      expect(plan.protocolId, 'AMRAP-001');
      expect(plan.format, CircuitFormat.amrap);
      expect(plan.scoreType, CircuitScoreType.roundsAndReps);
      expect(plan.timeCap, const Duration(minutes: 12));
      expect(plan.movementCount, 3);
      expect(plan.movements.first.title, 'Burpees');
      expect(plan.movements.first.reps, '10');
      expect(plan.movements.last.load, '24 kg');
    });

    test('compiles rounds for time with prescribed rounds', () {
      final plan = builder.build(
        protocol: _roundsForTimeProtocol,
        steps: _roundsForTimeSteps,
      );

      expect(plan.format, CircuitFormat.roundsForTime);
      expect(plan.scoreType, CircuitScoreType.elapsedTime);
      expect(plan.prescribedRounds, 5);
      expect(plan.movementCount, 4);
      expect(plan.movements.map((movement) => movement.orderIndex), [1, 2, 3, 4]);
    });

    test('compiles chipper with elapsed-time score', () {
      final plan = builder.build(
        protocol: _chipperProtocol,
        steps: _chipperSteps,
      );

      expect(plan.format, CircuitFormat.chipper);
      expect(plan.scoreType, CircuitScoreType.elapsedTime);
      expect(plan.movementCount, 5);
      expect(plan.movements.first.orderIndex, 1);
      expect(plan.movements.last.title, 'Row 500 m');
    });

    test('compiles EMOM with work interval and interval count', () {
      final plan = builder.build(
        protocol: _emomProtocol,
        steps: _emomSteps,
      );

      expect(plan.format, CircuitFormat.emom);
      expect(plan.scoreType, CircuitScoreType.roundsCompleted);
      expect(plan.workInterval, const Duration(seconds: 60));
      expect(plan.intervalCount, 10);
      expect(plan.prescribedRounds, 10);
      expect(plan.movementCount, 3);
    });

    test('preserves movement ordering after unsorted input', () {
      final plan = builder.build(
        protocol: _roundsForTimeProtocol,
        steps: _roundsForTimeSteps.reversed.toList(),
      );

      expect(
        plan.movements.map((movement) => movement.title).toList(),
        ['Burpees', 'KB Swings', 'Run 200 m', 'Pull-ups'],
      );
      expect(
        plan.movements.map((movement) => movement.protocolStepId).toList(),
        [202, 203, 204, 205],
      );
    });

    test('throws when no executable movements are present', () {
      expect(
        () => builder.build(
          protocol: const Protocol(
            protocolId: 'EMPTY-001',
            name: 'Instruction only',
            sessionType: 'circuit',
          ),
          steps: [
            ProtocolStep(
              id: 1,
              protocolId: 'EMPTY-001',
              stepOrder: 1,
              section: 'Overview',
              stepType: 'Instruction',
              displayStyle: 'instruction',
              title: 'AMRAP 12:00',
              metadata: const {
                'format': 'amrap',
                'time_cap': '12:00',
              },
            ),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('EMPTY-001'),
              contains('no executable movements'),
            ),
          ),
        ),
      );
    });

    test('throws when score type is incompatible with format', () {
      expect(
        () => builder.build(
          protocol: const Protocol(
            protocolId: 'BAD-001',
            name: 'Bad score mapping',
            sessionType: 'amrap',
          ),
          steps: [
            ProtocolStep(
              id: 1,
              protocolId: 'BAD-001',
              stepOrder: 1,
              section: 'Overview',
              stepType: 'Instruction',
              displayStyle: 'instruction',
              title: 'AMRAP 10:00',
              metadata: const {
                'format': 'amrap',
                'score_type': 'elapsed_time',
              },
            ),
            ProtocolStep(
              id: 2,
              protocolId: 'BAD-001',
              stepOrder: 2,
              section: 'Main Set',
              stepType: 'Exercise',
              displayStyle: 'exercise',
              title: 'Burpees',
              metadata: const {'reps': '10'},
            ),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('BAD-001'),
              contains('not compatible'),
            ),
          ),
        ),
      );
    });
  });
}

final _amrapProtocol = Protocol(
  protocolId: 'AMRAP-001',
  name: 'Bodyweight Grinder',
  sessionType: 'amrap',
);

final _amrapSteps = [
  ProtocolStep(
    id: 101,
    protocolId: 'AMRAP-001',
    stepOrder: 1,
    section: 'Overview',
    stepType: 'Instruction',
    displayStyle: 'instruction',
    title: 'AMRAP 12:00',
    metadata: const {
      'format': 'amrap',
      'time_cap': '12:00',
      'score_type': 'rounds_plus_reps',
    },
  ),
  ProtocolStep(
    id: 102,
    protocolId: 'AMRAP-001',
    stepOrder: 2,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'Burpees',
    exerciseId: 'EX-BURPEE',
    metadata: const {'reps': '10'},
  ),
  ProtocolStep(
    id: 103,
    protocolId: 'AMRAP-001',
    stepOrder: 3,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'Air Squats',
    exerciseId: 'EX-SQUAT',
    metadata: const {'reps': '15'},
  ),
  ProtocolStep(
    id: 104,
    protocolId: 'AMRAP-001',
    stepOrder: 4,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'KB Swings',
    exerciseId: 'EX-KBS',
    metadata: const {
      'reps': '20',
      'load': '24 kg',
    },
  ),
];

final _roundsForTimeProtocol = Protocol(
  protocolId: 'RFT-001',
  name: 'Five-round burner',
  sessionType: 'circuit',
);

final _roundsForTimeSteps = [
  ProtocolStep(
    id: 201,
    protocolId: 'RFT-001',
    stepOrder: 1,
    section: 'Overview',
    stepType: 'Instruction',
    displayStyle: 'instruction',
    title: '5 rounds for time',
    metadata: const {
      'format': 'rounds_for_time',
      'rounds': '5',
    },
  ),
  ProtocolStep(
    id: 202,
    protocolId: 'RFT-001',
    stepOrder: 2,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'Burpees',
    metadata: const {'reps': '10'},
  ),
  ProtocolStep(
    id: 203,
    protocolId: 'RFT-001',
    stepOrder: 3,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'KB Swings',
    metadata: const {'reps': '15', 'load': '24 kg'},
  ),
  ProtocolStep(
    id: 204,
    protocolId: 'RFT-001',
    stepOrder: 4,
    section: 'Main Set',
    stepType: 'Run',
    displayStyle: 'run',
    title: 'Run 200 m',
    metadata: const {'distance': '200 m'},
  ),
  ProtocolStep(
    id: 205,
    protocolId: 'RFT-001',
    stepOrder: 5,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'Pull-ups',
    metadata: const {'reps': '8'},
  ),
];

final _chipperProtocol = Protocol(
  protocolId: 'CHIP-001',
  name: 'Full Gym Chipper',
  sessionType: 'chipper',
);

final _chipperSteps = [
  ProtocolStep(
    id: 301,
    protocolId: 'CHIP-001',
    stepOrder: 1,
    section: 'Overview',
    stepType: 'Instruction',
    displayStyle: 'instruction',
    title: 'Complete for time',
    metadata: const {'format': 'chipper'},
  ),
  ProtocolStep(
    id: 302,
    protocolId: 'CHIP-001',
    stepOrder: 2,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: '50 Wall Balls',
    metadata: const {'reps': '50', 'load': '9 kg'},
  ),
  ProtocolStep(
    id: 303,
    protocolId: 'CHIP-001',
    stepOrder: 3,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: '40 Box Jumps',
    metadata: const {'reps': '40'},
  ),
  ProtocolStep(
    id: 304,
    protocolId: 'CHIP-001',
    stepOrder: 4,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: '30 KB Swings',
    metadata: const {'reps': '30', 'load': '24 kg'},
  ),
  ProtocolStep(
    id: 305,
    protocolId: 'CHIP-001',
    stepOrder: 5,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: '20 Burpees',
    metadata: const {'reps': '20'},
  ),
  ProtocolStep(
    id: 306,
    protocolId: 'CHIP-001',
    stepOrder: 6,
    section: 'Main Set',
    stepType: 'Run',
    displayStyle: 'run',
    title: 'Row 500 m',
    metadata: const {'distance': '500 m'},
  ),
];

final _emomProtocol = Protocol(
  protocolId: 'EMOM-001',
  name: 'Bike Burner',
  sessionType: 'emom',
);

final _emomSteps = [
  ProtocolStep(
    id: 401,
    protocolId: 'EMOM-001',
    stepOrder: 1,
    section: 'Overview',
    stepType: 'Instruction',
    displayStyle: 'instruction',
    title: 'EMOM 10',
    metadata: const {
      'format': 'emom',
      'work': '60 sec',
      'intervals': '10',
      'rounds': '10',
    },
  ),
  ProtocolStep(
    id: 402,
    protocolId: 'EMOM-001',
    stepOrder: 2,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'Assault Bike Calories',
    metadata: const {'reps': '12'},
  ),
  ProtocolStep(
    id: 403,
    protocolId: 'EMOM-001',
    stepOrder: 3,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'Push-ups',
    metadata: const {'reps': '10'},
  ),
  ProtocolStep(
    id: 404,
    protocolId: 'EMOM-001',
    stepOrder: 4,
    section: 'Main Set',
    stepType: 'Exercise',
    displayStyle: 'exercise',
    title: 'Goblet Squats',
    metadata: const {'reps': '8', 'load': '2×22.5 kg'},
  ),
];
