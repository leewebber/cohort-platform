import 'dart:io';

import 'package:cohort_platform/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:cohort_platform/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

/// Week 1 founder programme labels mapped to catalogue slugs after Wave 1 library.
void main() {
  final migrationSql = File(
    'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql',
  ).readAsStringSync();

  Exercise ex(String id, String name, String slug) {
    return Exercise(exerciseId: id, name: name, slug: slug, published: true);
  }

  // Prior catalogue (72) represented minimally for reused slugs + running/mobility.
  final catalogue = <Exercise>[
    ex('EX-001', 'Easy Run', 'easy-run'),
    ex('EX-002', 'Threshold Run', 'threshold-run'),
    ex('EX-012', 'Push Up', 'push-up'),
    ex('EX-053', 'Pull Up', 'pull-up'),
    ex('EX-029', 'Bulgarian Split Squat', 'bulgarian-split-squat'),
    ex('EX-025', 'Walking Lunge', 'walking-lunge'),
    ex('EX-037', 'Dumbbell Strict Press', 'dumbbell-strict-press'),
    ex('EX-044', 'Lateral Raise', 'lateral-raise'),
    ex('EX-047', 'Reverse Fly', 'reverse-fly'),
    ex('EX-042', 'Hammer Curl', 'hammer-curl'),
    ex('EX-021', 'Plank', 'plank'),
    ex('EX-062', 'Full Body Mobility Flow', 'full-body-mobility-flow'),
  ];

  void addFromMigration(String slug, String name) {
    if (migrationSql.contains("'$slug'")) {
      catalogue.add(
        Exercise(
          exerciseId: 'EX-NEW-$slug',
          name: name,
          slug: slug,
          published: true,
        ),
      );
    }
  }

  for (final entry in _wave1NewSlugNames.entries) {
    addFromMigration(entry.key, entry.value);
  }

  final resolver = FounderProgrammeExerciseResolver.fromCatalogue(catalogue);

  group('Week 1 programme exercise resolution after Wave 1', () {
    for (final mapping in _week1Mappings) {
      test('resolves ${mapping.label} via ${mapping.slug}', () {
        final exercise = FounderProgrammeYamlExercise(
          exerciseSlug: mapping.slug,
          order: 1,
        );
        expect(resolver.validationError(exercise, mapping.label), isNull);
        expect(resolver.resolveExerciseId(exercise), isNotNull);
      });
    }

    test('stretching remains a catalogue gap (use session/day notes)', () {
      final exercise = FounderProgrammeYamlExercise(
        exerciseName: 'Stretching',
        order: 1,
      );
      expect(resolver.validationError(exercise, 'Stretching'), isNotNull);
    });
  });
}

const _wave1NewSlugNames = {
  'weighted-pull-up': 'Weighted Pull Up',
  'weighted-chin-up': 'Weighted Chin Up',
  'chin-up': 'Chin Up',
  'chest-supported-row': 'Chest Supported Row',
  'cable-row': 'Cable Row',
  'face-pull': 'Face Pull',
  'dead-hang': 'Dead Hang',
  'incline-dumbbell-press': 'Incline Dumbbell Press',
  'weighted-dip': 'Weighted Dip',
  'dip': 'Dip',
  'romanian-deadlift': 'Romanian Deadlift',
  'rope-triceps-pushdown': 'Rope Triceps Pushdown',
  'incline-dumbbell-curl': 'Incline Dumbbell Curl',
  'standing-calf-raise': 'Standing Calf Raise',
  'tibialis-raise': 'Tibialis Raise',
  'farmer-carry': 'Farmer Carry',
  'suitcase-carry': 'Suitcase Carry',
  'hanging-leg-raise': 'Hanging Leg Raise',
  'hanging-knee-raise': 'Hanging Knee Raise',
  'copenhagen-plank': 'Copenhagen Plank',
  'hollow-hold': 'Hollow Hold',
  'side-plank': 'Side Plank',
  'ab-wheel-rollout': 'Ab Wheel Rollout',
};

class _Week1Mapping {
  const _Week1Mapping(this.label, this.slug);

  final String label;
  final String slug;
}

const _week1Mappings = [
  _Week1Mapping('Pull-up', 'pull-up'),
  _Week1Mapping('Push-up', 'push-up'),
  _Week1Mapping('Weighted Pull-up', 'weighted-pull-up'),
  _Week1Mapping('Weighted Chin-up', 'weighted-chin-up'),
  _Week1Mapping('Chest-Supported Row', 'chest-supported-row'),
  _Week1Mapping('Cable Row', 'cable-row'),
  _Week1Mapping('Face Pull', 'face-pull'),
  _Week1Mapping('Rear Delt Fly', 'reverse-fly'),
  _Week1Mapping('Dead Hang', 'dead-hang'),
  _Week1Mapping('Incline Dumbbell Press', 'incline-dumbbell-press'),
  _Week1Mapping('Weighted Dip', 'weighted-dip'),
  _Week1Mapping('Dip', 'dip'),
  _Week1Mapping('Dumbbell Shoulder Press', 'dumbbell-strict-press'),
  _Week1Mapping('Rope Triceps Pushdown', 'rope-triceps-pushdown'),
  _Week1Mapping('Dumbbell Lateral Raise', 'lateral-raise'),
  _Week1Mapping('Hammer Curl', 'hammer-curl'),
  _Week1Mapping('Incline Dumbbell Curl', 'incline-dumbbell-curl'),
  _Week1Mapping('Romanian Deadlift', 'romanian-deadlift'),
  _Week1Mapping('Bulgarian Split Squat', 'bulgarian-split-squat'),
  _Week1Mapping('Walking Lunge', 'walking-lunge'),
  _Week1Mapping('Standing Calf Raise', 'standing-calf-raise'),
  _Week1Mapping('Tibialis Raise', 'tibialis-raise'),
  _Week1Mapping('Farmer Carry', 'farmer-carry'),
  _Week1Mapping('Suitcase Carry', 'suitcase-carry'),
  _Week1Mapping('Hanging Leg Raise', 'hanging-leg-raise'),
  _Week1Mapping('Front Plank', 'plank'),
  _Week1Mapping('Copenhagen Plank', 'copenhagen-plank'),
  _Week1Mapping('Hollow Hold', 'hollow-hold'),
  _Week1Mapping('Side Plank', 'side-plank'),
  _Week1Mapping('Ab Wheel Rollout', 'ab-wheel-rollout'),
  _Week1Mapping('Hanging Knee Raise', 'hanging-knee-raise'),
  _Week1Mapping('General Mobility', 'full-body-mobility-flow'),
];
