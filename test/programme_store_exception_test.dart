import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgrammeStoreException', () {
    test('detects access denied from postgrest-style message', () {
      final error = ProgrammeStoreException.fromDynamic(
        Exception(
          'PostgrestException(message: permission denied for table programme_assignments, code: 42501)',
        ),
      );

      expect(error.isAccessDenied, isTrue);
      expect(error.code, '42501');
    });

    test('detects unique violation code', () {
      final error = ProgrammeStoreException(
        'duplicate key value violates unique constraint',
        code: '23505',
      );

      expect(error.isUniqueViolation, isTrue);
    });

    test('detects missing conflict target for upsert (42P10)', () {
      final error = ProgrammeStoreException.fromDynamic(
        Exception(
          'PostgrestException(message: there is no unique or exclusion constraint matching the ON CONFLICT specification, code: 42P10)',
        ),
        fallbackMessage: 'Failed to upsert athlete state projection',
        operation: 'upsertProjection',
        tableName: 'athlete_state',
        conflictTarget: 'athlete_id',
      );

      expect(error.isMissingConflictTarget, isTrue);
      expect(error.operation, 'upsertProjection');
      expect(error.tableName, 'athlete_state');
      expect(error.conflictTarget, 'athlete_id');
      expect(error.toString(), contains('[upsertProjection]'));
      expect(error.toString(), contains('onConflict: athlete_id'));
    });
  });
}
