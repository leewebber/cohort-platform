import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260803120000_add_programme_schedule_projection.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('programme schedule projection migration (1.7C)', () {
    test('file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('creates projection, occurrence, and operation tables', () {
      expect(sql, contains('CREATE TABLE IF NOT EXISTS public.programme_schedule_projections'));
      expect(sql, contains('CREATE TABLE IF NOT EXISTS public.programme_schedule_occurrences'));
      expect(sql, contains('CREATE TABLE IF NOT EXISTS public.programme_schedule_operations'));
    });

    test('stable identity excludes scheduled_date uniqueness alone', () {
      expect(sql, contains('programme_schedule_occurrences_assignment_slot_uidx'));
      expect(sql, contains('programme_schedule_occurrences_authored_order_uidx'));
      expect(sql, contains('scheduled_date'));
      // Identity uniqueness is slot/order based, not date-based.
      expect(sql.contains('UNIQUE (assignment_id, scheduled_date)'), isFalse);
    });

    test('baseline revision defaults to 0', () {
      expect(sql, contains('schedule_revision          INT NOT NULL DEFAULT 0'));
      expect(sql, contains('schedule_revision = 0'));
    });

    test('ensure RPC is SECURITY DEFINER with auth.uid ownership', () {
      expect(sql, contains('ensure_programme_schedule_projection'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('SET search_path = public, pg_temp'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains('FOR UPDATE'));
      expect(sql, contains('pg_advisory_xact_lock'));
    });

    test('grants ensure to authenticated and revokes anon/public', () {
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.ensure_programme_schedule_projection(UUID) FROM PUBLIC',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.ensure_programme_schedule_projection(UUID) FROM anon',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.ensure_programme_schedule_projection(UUID) TO authenticated',
        ),
      );
    });

    test('apply placeholder is fail-closed and not granted to authenticated', () {
      expect(sql, contains('apply_programme_schedule_operation'));
      expect(sql, contains('schedule_apply_not_implemented'));
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM authenticated',
        ),
      );
      expect(
        sql,
        isNot(
          contains(
            'GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO authenticated',
          ),
        ),
      );
    });

    test('no generic schedule writer RPC names', () {
      for (final token in const [
        'saveSchedule',
        'replaceProjection',
        'persistPreview',
        'writeOccurrences',
        'updateScheduledDate',
      ]) {
        expect(sql.contains(token), isFalse, reason: token);
      }
    });

    test('RLS enabled and direct mutation not granted to authenticated', () {
      expect(sql, contains('ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('FOR SELECT'));
      // No RLS write policies (FOR UPDATE appears only as SQL row locks in RPC).
      expect(sql.contains('FOR INSERT'), isFalse);
      expect(sql.contains('FOR DELETE'), isFalse);
      expect(
        RegExp(r'CREATE POLICY\s+\w+\s+ON[\s\S]{0,200}?FOR UPDATE')
            .hasMatch(sql),
        isFalse,
      );
      expect(
        sql,
        contains('GRANT SELECT ON TABLE public.programme_schedule_projections TO authenticated'),
      );
      expect(
        sql.contains(
          'GRANT INSERT ON TABLE public.programme_schedule_projections TO authenticated',
        ),
        isFalse,
      );
      expect(
        sql.contains(
          'GRANT UPDATE ON TABLE public.programme_schedule_occurrences TO authenticated',
        ),
        isFalse,
      );
    });

    test('baseline initialisation audit is distinct from athlete ops', () {
      expect(sql, contains("'baseline_initialisation'"));
      expect(sql, contains("'move'"));
      expect(sql, contains("'swap'"));
      expect(sql, contains("'push'"));
      expect(sql, contains("'skip'"));
    });

    test('does not mutate cursor or completion tables', () {
      expect(sql.contains('UPDATE public.programme_assignments'), isTrue);
      // Only schedule_revision / updated_at on assignment — no cursor columns.
      expect(sql.contains('current_week_number ='), isFalse);
      expect(sql.contains('current_day_key ='), isFalse);
      expect(sql.contains('current_slot_order ='), isFalse);
      expect(sql.contains('INSERT INTO public.programme_slot_outcomes'), isFalse);
      expect(sql.contains('INSERT INTO public.training_sessions'), isFalse);
    });
  });
}
