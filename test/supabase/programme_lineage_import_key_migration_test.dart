import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260724120000_add_programme_lineage_import_key.sql',
  );

  test('programme lineage import_key migration exists', () {
    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();
    expect(sql, contains('import_key'));
    expect(sql, contains('programme_lineages_import_key_unique'));
  });
}
