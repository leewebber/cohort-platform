import 'package:cohort_platform/features/session/services/interval_session_plan_builder.dart';
import 'package:cohort_platform/models/interval_block.dart';
import 'package:cohort_platform/models/interval_modality.dart';
import 'package:cohort_platform/models/interval_phase_type.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = IntervalSessionPlanBuilder();

  group('IntervalSessionPlanBuilder', () {
    test('compiles RN-006 Classic Threshold structure', () {
      final plan = builder.build(
        protocol: _rn006Protocol,
        steps: _rn006Steps,
      );

      expect(plan.protocolId, 'RN-006');
      expect(plan.modality, IntervalModality.running);
      expect(plan.blocks.length, 3);
      expect(plan.totalPhases, 7);
      expect(plan.totalWorkPhases, 3);

      expect(plan.blocks[0].blockType, IntervalBlockType.warmUp);
      expect(plan.blocks[1].blockType, IntervalBlockType.repeated);
      expect(plan.blocks[2].blockType, IntervalBlockType.coolDown);

      final timeline = plan.timelineEntries;
      expect(timeline[0].phaseType, IntervalPhaseType.warmUp);
      expect(timeline[1].phaseType, IntervalPhaseType.work);
      expect(timeline[1].targetDuration, '10 min');
      expect(timeline[1].targetIntensity, 'Threshold');
      expect(timeline[2].phaseType, IntervalPhaseType.recovery);
      expect(timeline[2].targetDuration, '2 min');
      expect(timeline[3].phaseType, IntervalPhaseType.work);
      expect(timeline[3].repNumber, 2);
      expect(timeline[4].phaseType, IntervalPhaseType.recovery);
      expect(timeline[5].phaseType, IntervalPhaseType.work);
      expect(timeline[5].repNumber, 3);
      expect(timeline[6].phaseType, IntervalPhaseType.coolDown);

      expect(timeline.where((entry) => entry.isRecoveryPhase).length, 2);
      expect(timeline.last.targetDuration, '5 min');
    });

    test('throws when no work phases are present', () {
      expect(
        () => builder.build(
          protocol: const Protocol(
            protocolId: 'EMPTY-001',
            name: 'Instruction only',
            sessionType: 'running',
          ),
          steps: [
            ProtocolStep(
              id: 1,
              protocolId: 'EMPTY-001',
              stepOrder: 1,
              section: 'Main Set',
              stepType: 'Instruction',
              displayStyle: 'instruction',
              title: 'Stay tall',
              metadata: const {},
            ),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('no executable work phases'),
          ),
        ),
      );
    });

    test('throws when steps list is empty', () {
      expect(
        () => builder.build(
          protocol: const Protocol(
            protocolId: 'EMPTY-002',
            name: 'No steps',
          ),
          steps: const [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('derives rowing modality from equipment metadata', () {
      final plan = builder.build(
        protocol: const Protocol(
          protocolId: 'ROW-001',
          name: 'Row intervals',
          sessionType: 'intervals',
          requiredEquipment: 'Concept2 erg',
        ),
        steps: [
          ProtocolStep(
            id: 10,
            protocolId: 'ROW-001',
            stepOrder: 1,
            section: 'Main Set',
            stepType: 'Run',
            displayStyle: 'run',
            title: '500 m repeats',
            metadata: const {
              'distance': '500 m',
              'sets': '4',
              'rest': '1:30',
            },
          ),
        ],
      );

      expect(plan.modality, IntervalModality.rowing);
      expect(plan.totalWorkPhases, 4);
    });
  });
}

final _rn006Protocol = Protocol(
  protocolId: 'RN-006',
  name: 'Classic Threshold',
  sessionType: 'running',
  runningRequired: true,
);

final _rn006Steps = [
  ProtocolStep(
    id: 101,
    protocolId: 'RN-006',
    stepOrder: 1,
    section: 'Warm Up',
    stepType: 'Run',
    displayStyle: 'run',
    title: 'Easy jog',
    metadata: const {
      'duration': '10 min',
    },
  ),
  ProtocolStep(
    id: 102,
    protocolId: 'RN-006',
    stepOrder: 2,
    section: 'Main Set',
    stepType: 'Run',
    displayStyle: 'run',
    title: 'Threshold intervals',
    metadata: const {
      'duration': '10 min',
      'sets': '3',
      'rest': '2 min',
      'load': 'Threshold',
    },
  ),
  ProtocolStep(
    id: 103,
    protocolId: 'RN-006',
    stepOrder: 3,
    section: 'Cool Down',
    stepType: 'Run',
    displayStyle: 'run',
    title: 'Easy jog',
    metadata: const {
      'duration': '5 min',
    },
  ),
];
