import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseId', () {
    test('parses canonical EX-* ids', () {
      expect(ExerciseId.parse('EX-073').value, 'EX-073');
      expect(ExerciseId.parse(' EX-9001 ').value, 'EX-9001');
      expect(ExerciseId.isCanonical('EX-127'), isTrue);
    });

    test('rejects blank and malformed ids', () {
      expect(() => ExerciseId.parse(''), throwsFormatException);
      expect(() => ExerciseId.parse('back-squat'), throwsFormatException);
      expect(() => ExerciseId.parse('EX-'), throwsFormatException);
      expect(() => ExerciseId.parse('EX-ABC'), throwsFormatException);
    });

    test('rejects transitional cohort.exercise.* as canonical', () {
      expect(
        () => ExerciseId.parse('cohort.exercise.back_squat'),
        throwsFormatException,
      );
      expect(
        ExerciseId.isTransitionalKnowledgeId('cohort.exercise.goblet_squat'),
        isTrue,
      );
      expect(ExerciseId.tryParse('cohort.exercise.back_squat'), isNull);
    });

    test('serializes deterministically', () {
      final id = ExerciseId.parse('EX-073');
      expect(id.toJson(), 'EX-073');
      expect(ExerciseId.fromJson(id.toJson()), id);
      expect(id.toString(), 'EX-073');
    });
  });
}
