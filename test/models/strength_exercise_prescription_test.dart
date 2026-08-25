import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/strength_prescription_formatter.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StrengthExercisePrescription', () {
    test('per-side dosage round-trips and formats explicitly', () {
      const prescription = StrengthExercisePrescription(
        sets: 2,
        reps: StrengthRepPrescription(
          type: StrengthRepType.exact,
          exactReps: 8,
        ),
        perSide: true,
      );

      final restored = StrengthExercisePrescription.fromJson(
        prescription.toJson(),
      );

      expect(restored.perSide, isTrue);
      expect(
        StrengthPrescriptionFormatter.formatSetsReps(restored),
        '2 × 8 / side',
      );
    });
    test('exact rep prescription round trip', () {
      const prescription = StrengthExercisePrescription(
        sets: 5,
        reps: StrengthRepPrescription(
          type: StrengthRepType.exact,
          exactReps: 5,
        ),
        load: StrengthLoadPrescription(type: StrengthLoadType.rpe, rpe: 8),
        restSeconds: 180,
        tempo: '31X1',
        coachCue: 'Drive through the floor',
      );

      final restored = StrengthExercisePrescription.fromJson(
        prescription.toJson(),
      );

      expect(restored.sets, 5);
      expect(restored.reps.type, StrengthRepType.exact);
      expect(restored.reps.exactReps, 5);
      expect(restored.load?.type, StrengthLoadType.rpe);
      expect(restored.load?.rpe, 8);
      expect(restored.restSeconds, 180);
      expect(restored.tempo, '31X1');
      expect(restored.coachCue, 'Drive through the floor');
    });

    test('rep range and RIR load round trip', () {
      const prescription = StrengthExercisePrescription(
        sets: 4,
        reps: StrengthRepPrescription(
          type: StrengthRepType.range,
          minReps: 8,
          maxReps: 10,
        ),
        load: StrengthLoadPrescription(type: StrengthLoadType.rir, rir: 2),
        restSeconds: 120,
      );

      final restored = StrengthExercisePrescription.fromJson(
        prescription.toJson(),
      );
      expect(restored.reps.minReps, 8);
      expect(restored.reps.maxReps, 10);
      expect(restored.load?.rir, 2);
    });

    test('decodes compact persisted programme prescription text', () {
      final restored = StrengthExercisePrescription.fromJson(const {
        'sets': 4,
        'reps': '5-6',
        'rir': '1-2',
        'rest_seconds': '150-180',
      });

      expect(restored.sets, 4);
      expect(restored.reps.type, StrengthRepType.freeText);
      expect(restored.reps.text, '5-6');
      expect(restored.restSeconds, isNull);
    });

    test(
      'accepts a JSON-encoded typed object but rejects malformed values',
      () {
        final restored = StrengthExercisePrescription.fromJson(const {
          'sets': 3,
          'reps': '{"type":"exact","exact_reps":8}',
        });
        expect(restored.reps.exactReps, 8);

        expect(
          () => StrengthExercisePrescription.fromJson(const {
            'sets': 3,
            'reps': '{"type":',
          }),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => StrengthExercisePrescription.fromJson(const {
            'sets': 3,
            'reps': '[1, 2]',
          }),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => StrengthExercisePrescription.fromJson(const {
            'sets': 3,
            'reps': true,
          }),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('null reps retains the existing empty structured contract', () {
      final restored = StrengthExercisePrescription.fromJson(const {
        'sets': 0,
        'reps': null,
      });

      expect(restored.reps.type, StrengthRepType.exact);
      expect(restored.reps.exactReps, isNull);
    });

    test('duplicate exercise link generates new identity', () {
      const link = SessionBlockExerciseLink(
        localId: 'link-1',
        exerciseId: 'ROW-001',
        position: 1,
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.exact,
            exactReps: 12,
          ),
        ),
      );

      final duplicate = link.duplicateWithNewIdentity();
      expect(duplicate.localId, isNot('link-1'));
      expect(duplicate.exerciseId, link.exerciseId);
      expect(duplicate.prescription?.sets, 3);
    });

    test('formatter renders compact athlete summary', () {
      const prescription = StrengthExercisePrescription(
        sets: 4,
        reps: StrengthRepPrescription(
          type: StrengthRepType.exact,
          exactReps: 8,
        ),
        load: StrengthLoadPrescription(
          type: StrengthLoadType.percent1rm,
          percent1rm: 70,
        ),
        restSeconds: 120,
      );

      expect(
        StrengthPrescriptionFormatter.summaryLine(prescription),
        '4 × 8 · 70% 1RM',
      );
      expect(
        StrengthPrescriptionFormatter.detailLine(prescription),
        'Rest 2 min',
      );
    });
  });
}
