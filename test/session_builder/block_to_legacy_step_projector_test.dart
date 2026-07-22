import 'package:cohort_platform/features/session_builder/services/block_to_legacy_step_projector.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projector = BlockToLegacyStepProjector();

  group('BlockToLegacyStepProjector structured strength', () {
    test('projects each structured exercise to a legacy step with metadata', () {
      final block = SessionBlock(
        localId: 'block-1',
        blockType: SessionBlockType.strength,
        title: 'Main Strength',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'link-1',
            exerciseId: 'SQ-001',
            position: 1,
            prescription: StrengthExercisePrescription(
              sets: 5,
              reps: StrengthRepPrescription.exact(5),
              load: const StrengthLoadPrescription(
                type: StrengthLoadType.rpe,
                rpe: 8,
              ),
              restSeconds: 180,
              tempo: '31X1',
              coachCue: 'Drive through the floor',
            ),
          ),
        ],
      );

      final steps = projector.projectBlocksToSteps([block]);

      expect(steps, hasLength(1));
      expect(steps.first.exerciseId, 'SQ-001');
      expect(steps.first.sets, '5');
      expect(steps.first.reps, '5');
      expect(steps.first.load, 'RPE 8');
      expect(steps.first.rest, '180s');
      expect(steps.first.tempo, '31X1');
      expect(steps.first.notes, 'Drive through the floor');
    });

    test('legacy free-text strength block still projects to a single step', () {
      final block = SessionBlock(
        localId: 'block-legacy',
        blockType: SessionBlockType.strength,
        title: 'Strength',
        content: 'Back squat and bench press',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: const [
          SessionBlockExerciseLink(
            localId: 'link-1',
            exerciseId: 'SQ-001',
            position: 1,
          ),
        ],
      );

      final steps = projector.projectBlocksToSteps([block]);
      expect(steps, hasLength(1));
      expect(steps.first.notes, contains('Back squat'));
      expect(steps.first.sets, isNull);
    });
  });
}
