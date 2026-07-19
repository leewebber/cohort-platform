import 'package:cohort_platform/features/session_builder/services/legacy_step_to_block_converter.dart';
import 'package:cohort_platform/models/protocol_step_draft.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const converter = LegacyStepToBlockConverter();

  group('LegacyStepToBlockConverter', () {
    test('creates one custom Session block from legacy steps', () {
      final blocks = converter.convertStepsToBlocks(const [
        ProtocolStepDraft(
          localId: 'step-1',
          stepOrder: 1,
          title: 'Warm-up',
          notes: 'Easy row',
          sets: '1',
          duration: '10 min',
          exerciseId: 'row',
        ),
        ProtocolStepDraft(
          localId: 'step-2',
          stepOrder: 2,
          title: 'Back Squat',
          reps: '5',
          load: '100 kg',
          exerciseId: 'back-squat',
        ),
      ]);

      expect(blocks, hasLength(1));
      expect(blocks.first.blockType, SessionBlockType.custom);
      expect(blocks.first.title, 'Session');
      expect(blocks.first.workoutFormat, WorkoutFormat.none);
      expect(blocks.first.content, contains('Warm-up'));
      expect(blocks.first.content, contains('Back Squat'));
      expect(blocks.first.content, contains('Sets: 1'));
      expect(blocks.first.linkedExercises, hasLength(2));
    });

    test('returns empty list for no steps', () {
      expect(converter.convertStepsToBlocks(const []), isEmpty);
    });

    test('conversion is deterministic for same input', () {
      const steps = [
        ProtocolStepDraft(
          localId: 'step-1',
          stepOrder: 1,
          title: 'A',
        ),
      ];

      final first = converter.convertStepsToBlocks(steps);
      final second = converter.convertStepsToBlocks(steps);

      expect(first.first.title, second.first.title);
      expect(first.first.content, second.first.content);
      expect(first.first.linkedExercises.length, second.first.linkedExercises.length);
    });
  });
}
