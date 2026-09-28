import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260927120000_plan_package_v2_authored_running.sql',
  ).readAsStringSync();
  final publisher = File(
    'tool/programmes/bin/publish_private_exact_version.dart',
  ).readAsStringSync();
  final databaseGate = File(
    'supabase/tests/sql/gate_bh_plan_package_v2_publication.sql',
  ).readAsStringSync();

  test(
    'v2 publication attests canonical bytes and persists the hashed slot doc',
    () {
      expect(migration, contains('authored_running_v1 JSONB'));
      expect(
        migration,
        contains("digest(convert_to(v_canonical_text, 'UTF8'), 'sha256')"),
      );
      expect(
        migration,
        contains("payload->'weeks' IS DISTINCT FROM v_canonical->'weeks'"),
      );
      expect(
        migration,
        contains(
          'persisted.authored_running_v1 IS DISTINCT FROM\n'
          '              (v_running_slots -> persisted.package_slot_key)',
        ),
      );
      expect(migration, contains('v_slot_keys JSONB'));
      expect(
        migration,
        contains('ELSE persisted.authored_running_v1 IS NOT NULL'),
      );
      expect(
        migration,
        contains("'cohort.plan_package_v2_running_slots'"),
      );
      expect(
        migration,
        contains(
          "RAISE EXCEPTION 'Plan Package v2 publication did not preserve",
        ),
      );
    },
  );

  test('v2 RPC is additive and service-role only', () {
    expect(
      migration,
      isNot(
        contains(
          'CREATE OR REPLACE FUNCTION public.publish_private_exact_programme_version(payload',
        ),
      ),
    );
    expect(
      migration,
      contains(
        'REVOKE ALL ON FUNCTION public.publish_private_exact_programme_version_v2(JSONB)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      migration,
      contains(
        'GRANT EXECUTE ON FUNCTION public.publish_private_exact_programme_version_v2(JSONB)\n'
        '  TO service_role;',
      ),
    );
  });

  test('private publisher selects v2 only from the compiled schema', () {
    expect(publisher, contains('compiled.manifest!.packageSchemaVersion'));
    expect(
      publisher,
      contains("? 'publish_private_exact_programme_version_v2'"),
    );
    expect(publisher, contains(": 'publish_private_exact_programme_version';"));
  });

  test('disposable gate covers canonical integrity and full rollback', () {
    for (final caseId in <String>[
      'valid_exact_canonical_publish',
      'published_slot_immutable',
      'changed_bytes_rejected',
      'changed_attachment_rejected',
      'malformed_steps_rejected',
      'persistence_failure_full_rollback',
      'v1_publication_unchanged',
      'anon_v2_publish_denied',
      'athlete_v2_publish_denied',
    ]) {
      expect(databaseGate, contains("'$caseId'"));
    }
  });
}
