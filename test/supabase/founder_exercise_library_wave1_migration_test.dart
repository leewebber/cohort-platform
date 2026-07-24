import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  const existingSlugs = [
    'goblet-squat',
    'dumbbell-floor-press',
    'push-up',
    'pull-up',
    'bulgarian-split-squat',
    'walking-lunge',
    'reverse-fly',
    'lateral-raise',
    'dumbbell-strict-press',
    'barbell-push-press',
    'hammer-curl',
    'plank',
    'dead-bug',
    'sandbag-carry',
    'easy-run',
    'threshold-run',
  ];

  const newSlugs = [
    'romanian-deadlift',
    'incline-dumbbell-press',
    'weighted-dip',
    'dip',
    'chest-supported-row',
    'cable-row',
    'face-pull',
    'weighted-pull-up',
    'weighted-chin-up',
    'chin-up',
    'dead-hang',
    'farmer-carry',
    'suitcase-carry',
    'hanging-leg-raise',
    'hanging-knee-raise',
    'copenhagen-plank',
    'side-plank',
    'hollow-hold',
    'ab-wheel-rollout',
    'incline-dumbbell-curl',
    'rope-triceps-pushdown',
    'standing-calf-raise',
    'tibialis-raise',
  ];

  group('founder exercise library wave 1 migration', () {
    test('migration file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test(
      'inserts wave 1 slugs without duplicating existing catalogue slugs',
      () {
        for (final slug in existingSlugs) {
          expect(sql, isNot(contains("'$slug'")));
        }
        for (final slug in newSlugs) {
          expect(sql, contains("'$slug'"));
        }
      },
    );

    test('uses idempotent insert on exercise_id', () {
      expect(sql, contains('ON CONFLICT (exercise_id) DO NOTHING'));
    });

    test('assigns contiguous EX-073 through EX-127 ids', () {
      expect(sql, contains("'EX-073'"));
      expect(sql, contains("'EX-127'"));
      expect(sql, isNot(contains("'EX-128'")));
    });
  });
}
