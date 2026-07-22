import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final conversionMigration = File(
    'supabase/migrations/20260721155000_convert_programme_assignments_athlete_id_to_uuid.sql',
  );
  final normalizeMigration = File(
    'supabase/migrations/20260722140000_normalize_programme_assignment_uuid_rls.sql',
  );
  final adaptationMigration = File(
    'supabase/migrations/20260721160000_add_programme_adaptation_events.sql',
  );

  late String conversionSql;
  late String normalizeSql;
  late String adaptationSql;

  setUpAll(() {
    conversionSql = conversionMigration.readAsStringSync();
    normalizeSql = normalizeMigration.readAsStringSync();
    adaptationSql = adaptationMigration.readAsStringSync();
  });

  group('programme_assignments athlete_id UUID conversion', () {
    test('conversion migration runs before adaptation events migration', () {
      expect(conversionMigration.existsSync(), isTrue);
      expect(
        conversionMigration.uri.pathSegments.last.compareTo(
          '20260721160000_add_programme_adaptation_events.sql',
        ),
        lessThan(0),
      );
    });

    test('converts athlete_id column to UUID with profiles foreign key', () {
      expect(conversionSql, contains('ALTER COLUMN athlete_id TYPE UUID'));
      expect(conversionSql, contains('programme_assignments_athlete_id_fkey'));
      expect(conversionSql, contains('REFERENCES profiles (id)'));
    });

    test('removes legacy non-UUID dev athlete rows before conversion', () {
      expect(conversionSql, contains("legacy dev values such as lee"));
      expect(conversionSql, contains('DELETE FROM programme_assignments'));
    });

    test('adds UUID-native cohort_coach_has_active_athlete overload', () {
      expect(conversionSql, contains('cohort_coach_has_active_athlete(p_athlete_id UUID)'));
      expect(conversionSql, contains('cohort_coach_has_active_athlete(p_athlete_id TEXT)'));
    });

    test('adaptation events migration still joins relationships to assignments', () {
      expect(adaptationSql, contains('car.athlete_id = pa.athlete_id'));
    });
  });

  group('programme_assignments UUID RLS normalization', () {
    test('normalize migration uses auth.uid() without text casts in policy SQL', () {
      final sqlWithoutComments = normalizeSql
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('--'))
          .join('\n');

      expect(sqlWithoutComments, contains('athlete_id = auth.uid()'));
      expect(sqlWithoutComments, isNot(contains('auth.uid()::TEXT')));
    });

    test('recreates dual-role self-assignment insert policy', () {
      expect(normalizeSql, contains('programme_assignments_dual_role_self_insert'));
      expect(normalizeSql, contains('cohort_auth_is_dual_role_coach_athlete()'));
    });
  });
}
