import 'package:cohort_platform/features/session_builder/services/protocol_draft_block_resolver.dart';
import 'package:cohort_platform/features/session_builder/services/session_block_validation.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validation = SessionBlockValidation();
  const resolver = ProtocolDraftBlockResolver();

  group('SessionBlockValidation', () {
    test('AMRAP requires duration', () {
      final messages = const TimerConfiguration().validateForFormat(
        WorkoutFormat.amrap,
      );

      expect(messages, contains('AMRAP requires a duration.'));
    });

    test('workout format transition clears incompatible timer fields', () {
      final normalized = TimerConfiguration.normalizedForFormat(
        WorkoutFormat.amrap,
        const TimerConfiguration(
          totalDurationSeconds: 600,
          intervalSeconds: 60,
          durationSeconds: 720,
        ),
      );

      expect(normalized.durationSeconds, 720);
      expect(normalized.totalDurationSeconds, isNull);
      expect(normalized.intervalSeconds, isNull);
    });

    test('block deep clone clears persisted ids', () {
      const block = SessionBlock(
        localId: 'block-1',
        persistedId: 'persisted-1',
        blockType: SessionBlockType.strength,
        title: 'Strength',
        content: '5 x 5 squat',
        workoutFormat: WorkoutFormat.none,
        position: 1,
      );

      final clone = block.deepClone(position: 2);

      expect(clone.persistedId, isNull);
      expect(clone.localId, isNot(block.localId));
      expect(clone.content, block.content);
    });
  });

  group('ProtocolDraftBlockResolver', () {
    test('resolveSteps projects blocks for execution compatibility', () {
      final draft = resolver.withSyncedStepsFromBlocks(
        const ProtocolDraft(
          protocolId: 'session-1',
          name: 'Test',
          sessionFormat: 'structured_strength',
          steps: const [],
          blocks: [
            SessionBlock(
              localId: 'block-1',
              blockType: SessionBlockType.strength,
              title: 'Strength',
              content: 'Back squat 5 x 5',
              workoutFormat: WorkoutFormat.none,
              position: 1,
            ),
          ],
        ),
      );

      expect(draft.steps, hasLength(1));
      expect(draft.steps.first.title, 'Strength');
      expect(draft.steps.first.notes, contains('Back squat 5 x 5'));
    });
  });
}
