import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260926160000_private_protocol_graph_publication.sql',
  ).readAsStringSync();

  test('repair and publish remain service-role only', () {
    expect(sql, contains('repair_incomplete_private_programme_graph'));
    expect(sql, contains('cohort_private_protocol_is_executable'));
    expect(sql, contains('protocol_graph_required'));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.repair_incomplete_private_programme_graph(JSONB)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(sql, isNot(contains('lee@')));
    expect(sql, isNot(contains('95ee6900')));
  });

  test('does not edit earlier private migrations', () {
    expect(
      File(
        'supabase/migrations/20260926140000_private_exact_version_publication.sql',
      ).readAsStringSync(),
      isNot(contains('repair_incomplete_private_programme_graph')),
    );
  });
}
