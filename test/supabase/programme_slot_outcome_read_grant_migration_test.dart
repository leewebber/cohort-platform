import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated outcome reads are granted without mutation or anon access', () {
    final sql = File(
      'supabase/migrations/20260902120000_allow_authenticated_programme_slot_outcome_reads.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains(
        'GRANT SELECT ON TABLE public.programme_slot_outcomes TO authenticated',
      ),
    );
    expect(
      sql,
      contains('REVOKE ALL ON TABLE public.programme_slot_outcomes FROM anon'),
    );
    expect(
      sql,
      contains(
        'REVOKE INSERT, UPDATE, DELETE ON TABLE public.programme_slot_outcomes',
      ),
    );
    expect(
      RegExp(
        r'GRANT\s+(?:ALL|INSERT|UPDATE|DELETE)',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
    );
  });
}
