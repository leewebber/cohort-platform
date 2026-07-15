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
  });
}
