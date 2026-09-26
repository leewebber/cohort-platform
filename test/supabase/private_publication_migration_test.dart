import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260926140000_private_exact_version_publication.sql',
  ).readAsStringSync();

  test('private publication is service-role only', () {
    expect(sql, contains('publish_private_exact_programme_version'));
    expect(sql, contains("publication_kind"));
    expect(sql, contains('private_exact_version'));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.publish_private_exact_programme_version(JSONB)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.publish_private_exact_programme_version(JSONB)\n'
        '  TO service_role;',
      ),
    );
    expect(sql, isNot(contains('approve_cohort_global_programme_version')));
    expect(sql, isNot(contains('lee')));
  });

  test('discovery and explicit-date enrol are separate from catalogue', () {
    expect(sql, contains('list_my_private_programme_versions()'));
    expect(
      sql,
      contains(
        'enrol_athlete_in_private_programme_version(\n'
        '  p_programme_version_id UUID,\n'
        '  p_timezone TEXT,\n'
        '  p_started_at DATE,\n'
        '  p_replace_active BOOLEAN\n'
        ')',
      ),
    );
    expect(sql, isNot(contains('CREATE OR REPLACE FUNCTION public.enrol_athlete_in_catalogue_programme_version')));
    expect(
      sql,
      isNot(
        contains(
          'CREATE OR REPLACE FUNCTION public.enrol_athlete_in_private_programme_version(\n'
          '  p_programme_version_id UUID,\n'
          '  p_timezone TEXT DEFAULT NULL,\n'
          '  p_replace_active BOOLEAN DEFAULT FALSE\n'
          ')',
        ),
      ),
    );
  });
}
