import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260803140000_apply_programme_schedule_move_swap.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('programme schedule apply migration (1.7D)', () {
    test('file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('defines fingerprint helpers and apply RPC', () {
      expect(sql, contains('cohort_scheduling_canonical_json'));
      expect(sql, contains('cohort_scheduling_apply_fingerprint'));
      expect(sql, contains('apply_programme_schedule_operation'));
      expect(sql, contains('digest('));
    });

    test('grants apply to authenticated after Move/Swap implementation', () {
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM anon',
        ),
      );
    });

    test('rejects client-nominated projections and unsupported ops', () {
      expect(sql, contains('client_nominated_projection_forbidden'));
      expect(sql, contains("v_op IN ('push', 'skip', 'undo')"));
      expect(sql, contains('stale_preview_fingerprint'));
      expect(sql, contains('idempotency_key_conflict'));
    });

    test('updates scheduled dates only and advances both revision mirrors', () {
      expect(sql, contains('SET scheduled_date = v_target'));
      expect(sql, contains('SET schedule_revision = v_result_rev'));
      expect(sql, contains('UPDATE public.programme_assignments'));
      expect(sql.contains('SET disposition'), isFalse);
      expect(sql.contains('current_week_number ='), isFalse);
      expect(sql.contains('INSERT INTO public.programme_slot_outcomes'), isFalse);
    });
  });
}
