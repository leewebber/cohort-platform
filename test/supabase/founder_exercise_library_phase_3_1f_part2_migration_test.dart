import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/'
    '20260809160000_founder_exercise_library_phase_3_1f_part2.sql',
  );
  final wave1File = File(
    'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql',
  );

  late String sql;
  late String wave1;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
    wave1 = wave1File.readAsStringSync();
  });

  group('Phase 3.1F Part 2 catalogue migration', () {
    test('migration file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('allocates preferred EX-128 through EX-132 only', () {
      for (final id in [
        'EX-128',
        'EX-129',
        'EX-130',
        'EX-131',
        'EX-132',
      ]) {
        expect(sql, contains("'$id'"));
      }
      expect(sql, isNot(contains("'EX-133'")));
    });

    test('does not collide with Wave 1 ids', () {
      for (final id in [
        'EX-128',
        'EX-129',
        'EX-130',
        'EX-131',
        'EX-132',
      ]) {
        expect(wave1, isNot(contains("'$id'")));
      }
    });

    test('names and slugs match founder allocation', () {
      expect(sql, contains("'Lat Pulldown'"));
      expect(sql, contains("'lat-pulldown'"));
      expect(sql, contains("'Running'"));
      expect(sql, contains("'running'"));
      expect(sql, contains("'Burpee Broad Jump'"));
      expect(sql, contains("'burpee-broad-jump'"));
      expect(sql, contains("'Sled Push'"));
      expect(sql, contains("'sled-push'"));
      expect(sql, contains("'Sled Pull'"));
      expect(sql, contains("'sled-pull'"));
    });

    test('Running is generic not intensity-labelled', () {
      expect(sql, contains('generic Running'));
      expect(sql.toLowerCase(), isNot(contains('easy run')));
      expect(sql.toLowerCase(), isNot(contains('threshold run')));
    });

    test('keeps sled push and pull distinct', () {
      expect(sql, contains('Distinct from Sled Pull'));
      expect(sql, contains('Distinct from Sled Push'));
    });

    test('keeps burpee broad jump distinct from components', () {
      expect(sql, contains('EX-009'));
      expect(sql, contains('EX-024'));
    });

    test('fail-closed: no silent conflict skip or overwrite in executable SQL', () {
      final executable = _stripSqlComments(sql).toUpperCase();
      expect(executable, isNot(contains('ON CONFLICT')));
      expect(executable, isNot(contains('DO NOTHING')));
      expect(executable, isNot(contains('DO UPDATE')));
      expect(sql, contains('RAISE EXCEPTION'));
      expect(sql, contains('Fail closed'));
      expect(sql, contains('DO \$\$'));
    });

    test('is catalogue seed only — no DDL schema objects', () {
      final executable = _stripSqlComments(sql).toUpperCase();
      expect(executable, isNot(contains('CREATE TABLE')));
      expect(executable, isNot(contains('ALTER TABLE')));
      expect(executable, isNot(contains('CREATE FUNCTION')));
      expect(executable, isNot(contains('CREATE POLICY')));
      expect(executable, isNot(contains('DROP TABLE')));
      expect(sql, contains('INSERT INTO public.exercises_v2'));
    });

    test('documents hosted apply exclusion', () {
      expect(sql, contains('Hosted apply is NOT authorised'));
    });
  });
}

String _stripSqlComments(String sql) {
  return sql
      .split('\n')
      .map((line) {
        final idx = line.indexOf('--');
        return idx < 0 ? line : line.substring(0, idx);
      })
      .join('\n');
}
