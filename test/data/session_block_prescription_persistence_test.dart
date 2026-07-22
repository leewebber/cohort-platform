import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import '../support/in_memory_session_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save and reload preserves structured strength prescription', () async {
    final repository = InMemorySessionBlockRepository();
    const sessionId = 'session-strength-1';

    final block = SessionBlock(
      localId: 'block-1',
      blockType: SessionBlockType.strength,
      title: 'Main Strength',
      content: 'Brace hard before each set.',
      workoutFormat: WorkoutFormat.none,
      position: 1,
      linkedExercises: [
        SessionBlockExerciseLink(
          localId: 'link-1',
          exerciseId: 'PULL-001',
          position: 1,
          prescription: const StrengthExercisePrescription(
            sets: 5,
            reps: StrengthRepPrescription(type: StrengthRepType.exact, exactReps: 5),
            load: StrengthLoadPrescription(type: StrengthLoadType.rpe, rpe: 8),
            restSeconds: 180,
            tempo: '21X1',
            coachCue: 'Start from a dead hang',
          ),
        ),
        SessionBlockExerciseLink(
          localId: 'link-2',
          exerciseId: 'BP-001',
          position: 2,
          prescription: const StrengthExercisePrescription(
            sets: 4,
            reps: StrengthRepPrescription(
              type: StrengthRepType.range,
              minReps: 8,
              maxReps: 10,
            ),
            load: StrengthLoadPrescription(type: StrengthLoadType.rir, rir: 2),
            restSeconds: 120,
          ),
        ),
      ],
    );

    await repository.replaceSessionBlocks(sessionId: sessionId, blocks: [block]);
    final reloaded = await repository.getSessionBlocks(sessionId);

    expect(reloaded, hasLength(1));
    expect(reloaded.first.content, 'Brace hard before each set.');
    expect(reloaded.first.linkedExercises, hasLength(2));
    expect(reloaded.first.linkedExercises.first.prescription?.sets, 5);
    expect(reloaded.first.linkedExercises.first.prescription?.tempo, '21X1');
    expect(reloaded.first.linkedExercises.last.prescription?.reps.maxReps, 10);

    final rows = repository.exerciseRowsForSession(sessionId);
    expect(rows.first['prescription'], isA<Map>());
  });
}
