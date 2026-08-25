import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/strength_prescription_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Apollo Monday warm-up PostgREST rows decode through production models',
    () {
      final rows = <Map<String, dynamic>>[
        {
          'id': '15000000-0000-4000-8000-000000000001',
          'block_id': 'b1100001-0000-4000-8000-000000000001',
          'exercise_id': 'EX-150',
          'position': 1,
          'display_label_override': 'Thoracic extension over foam roller',
          'prescription': {
            'sets': 1,
            'reps': {'type': 'exact', 'exact_reps': 5},
            'tempo': 'slow',
            'coach_cue': 'Use 2–3 positions.',
          },
        },
        {
          'id': '15000000-0000-4000-8000-000000000002',
          'block_id': 'b1100001-0000-4000-8000-000000000001',
          'exercise_id': 'EX-151',
          'position': 2,
          'display_label_override': 'Open-book rotation',
          'prescription': {
            'sets': 1,
            'reps': {'type': 'exact', 'exact_reps': 6},
            'per_side': true,
            'coach_cue': 'Complete each side.',
          },
        },
        {
          'id': '15000000-0000-4000-8000-000000000003',
          'block_id': 'b1100001-0000-4000-8000-000000000001',
          'exercise_id': 'EX-152',
          'position': 3,
          'display_label_override': 'Serratus wall slide + reach',
          'prescription': {
            'sets': 2,
            'reps': {'type': 'exact', 'exact_reps': 8},
          },
        },
        {
          'id': '15000000-0000-4000-8000-000000000004',
          'block_id': 'b1100001-0000-4000-8000-000000000001',
          'exercise_id': 'EX-153',
          'position': 4,
          'display_label_override': 'Wall Y/lower-trap raise',
          'prescription': {
            'sets': 2,
            'reps': {'type': 'range', 'min_reps': 8, 'max_reps': 10},
            'load': {'type': 'freeText', 'text': 'Very light'},
          },
        },
        {
          'id': '15000000-0000-4000-8000-000000000005',
          'block_id': 'b1100001-0000-4000-8000-000000000001',
          'exercise_id': 'EX-154',
          'position': 5,
          'display_label_override': 'Single-arm cable/band row with reach',
          'prescription': {
            'sets': 2,
            'reps': {'type': 'exact', 'exact_reps': 10},
            'per_side': true,
            'coach_cue': 'Complete each side.',
          },
        },
      ];

      final links = rows
          .map(SessionBlockExerciseLink.fromRow)
          .toList(growable: false);

      expect(links.map((link) => link.exerciseId), [
        'EX-150',
        'EX-151',
        'EX-152',
        'EX-153',
        'EX-154',
      ]);
      expect(links.map((link) => link.position), [1, 2, 3, 4, 5]);
      expect(links.map((link) => link.prescription?.sets), [1, 1, 2, 2, 2]);

      expect(links[0].prescription?.reps.exactReps, 5);
      expect(links[0].prescription?.tempo, 'slow');
      expect(links[0].prescription?.coachCue, 'Use 2–3 positions.');
      expect(rows[1]['prescription'], containsPair('per_side', true));
      expect(links[1].prescription?.reps.exactReps, 6);
      expect(links[1].prescription?.coachCue, 'Complete each side.');
      expect(links[2].prescription?.reps.exactReps, 8);
      expect(links[3].prescription?.reps.type, StrengthRepType.range);
      expect(links[3].prescription?.reps.minReps, 8);
      expect(links[3].prescription?.reps.maxReps, 10);
      expect(links[3].prescription?.load?.type, StrengthLoadType.freeText);
      expect(links[3].prescription?.load?.text, 'Very light');
      expect(rows[4]['prescription'], containsPair('per_side', true));
      expect(links[4].prescription?.reps.exactReps, 10);
      expect(links[4].prescription?.coachCue, 'Complete each side.');

      expect(
        links.map((link) {
          return StrengthPrescriptionFormatter.summaryLine(link.prescription!);
        }),
        [
          '1 × 5',
          '1 × 6 / side',
          '2 × 8',
          '2 × 8–10 · Very light',
          '2 × 10 / side',
        ],
      );
    },
  );

  test('descriptive prose in compact reps remains rejected', () {
    expect(
      () => SessionBlockExerciseLink.fromRow({
        'id': '15000000-0000-4000-8000-000000000001',
        'exercise_id': 'EX-150',
        'position': 1,
        'prescription': const {
          'sets': 1,
          'reps': '5 slow reps at 2-3 positions',
        },
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Invalid compact reps text: 5 slow reps at 2-3 positions',
        ),
      ),
    );
  });
}
