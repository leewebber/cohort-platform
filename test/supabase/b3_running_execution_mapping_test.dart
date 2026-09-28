import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260928120000_b3_running_execution_mapping.sql',
  ).readAsStringSync();
  final gate = File(
    'supabase/tests/sql/gate_bl_b3_running_execution_mapping.sql',
  ).readAsStringSync();

  test('mapping is hash-attested and preserves unattached B2 documents', () {
    expect(migration, contains('cohort.running_execution_mapping.v1'));
    expect(
      migration,
      contains("digest(convert_to(v_canonical, 'UTF8'), 'sha256')"),
    );
    expect(
      migration,
      contains(
        'RETURN public.cohort_authored_running_v1_b2_is_valid(document);',
      ),
    );
    expect(migration, contains("document->'step_ids' = v_expected_steps"));
  });

  test('publication scope uses stable block identity and fails closed', () {
    expect(migration, contains('WHERE block.block_id = ('));
    expect(migration, contains('AND block.session_id = trim(p_protocol_id)'));
    expect(migration, isNot(contains('block.title')));
    expect(migration, isNot(contains('block.position')));
    expect(
      migration,
      contains('BEFORE INSERT OR UPDATE OF authored_running_v1, protocol_id'),
    );
    expect(
      migration,
      contains(
        'running execution mapping does not match exact B1 protocol block',
      ),
    );
  });

  test('mapping validators are not callable by athlete roles', () {
    expect(
      migration,
      contains(
        'REVOKE ALL ON FUNCTION public.cohort_running_execution_mapping_matches_protocol(JSONB, TEXT)\n'
        '  FROM PUBLIC, anon, authenticated, service_role;',
      ),
    );
    for (final caseId in <String>[
      'exact_block_mapping_published',
      'mapping_hash_tamper_rejected',
      'nonexistent_block_mapping_rolls_back',
      'anon_mapping_validator_denied',
      'athlete_mapping_validator_denied',
    ]) {
      expect(gate, contains("'$caseId'"));
    }
  });
}
