import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Apollo local preview seed uses the canonical fixed-calendar identity',
    () {
      final seed = File(
        'supabase/tests/sql/seed_apollo_calendar_preview.sql',
      ).readAsStringSync();
      final gate = File(
        'supabase/tests/sql/gate_af_apollo_import_replacement_materialisation.sql',
      ).readAsStringSync();

      expect(seed, contains("'apollo-local-athlete@example.invalid'"));
      expect(seed, isNot(contains('apollo-calendar-athlete@example.invalid')));
      expect(seed, contains('start_fixed_programme_from_enrolment'));
      expect(seed, contains('expected 84 occurrences'));
      expect(seed, contains('expected 84 materialised links'));
      expect(seed, contains('duplicate occurrence identities'));
      expect(seed, contains('terminal performances'));
      expect(gate, contains('apollo-gate-af-athlete@example.invalid'));
      expect(gate, isNot(contains('apollo-local-athlete@example.invalid')));
    },
  );
}
