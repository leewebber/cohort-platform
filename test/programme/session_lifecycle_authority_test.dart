import 'dart:io';

import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'athlete-facing Incomplete is a display label over overdue wire state',
    () {
      expect(FixedProgrammeOccurrenceState.overdue.wireValue, 'OVERDUE');
      expect(FixedProgrammeOccurrenceState.overdue.displayLabel, 'Incomplete');
      expect(
        FixedProgrammeOccurrenceState.inProgressOverdue.displayLabel,
        'Incomplete',
      );
    },
  );

  test(
    'calendar, not assignment cursor, is the Home import for fixed schedule',
    () {
      final home = File(
        'lib/features/home/home_screen.dart',
      ).readAsStringSync();
      expect(home, contains('FixedProgrammeOccurrenceProjectionStore'));
      expect(home, contains('athlete_home_today_presentation.dart'));
      expect(home, isNot(contains('TodaySessionServiceImpl')));
    },
  );

  test('programme completion RPC does not itself close training_sessions', () {
    final sql = File(
      'supabase/migrations/20260801160000_complete_programme_session_and_advance.sql',
    ).readAsStringSync();
    expect(sql, contains('INSERT INTO public.training_session_records'));
    expect(sql, contains('INSERT INTO public.programme_slot_outcomes'));
    expect(sql, isNot(contains('UPDATE public.training_sessions')));
  });

  test('backfill persistence does not advance the assignment cursor', () {
    final sql = File(
      'supabase/migrations/20260913120000_backfill_fixed_programme_session_results.sql',
    ).readAsStringSync();
    expect(sql, contains('Does not advance the assignment cursor.'));
  });

  test('terminal record trigger is the parent-session reconciliation rule', () {
    final sql = File(
      'supabase/migrations/20260914120000_terminalize_training_session_from_completed_record.sql',
    ).readAsStringSync();
    expect(sql, contains('cohort_sync_training_session_from_terminal_record'));
    expect(
      sql,
      contains("NEW.status NOT IN ('completed', 'partially_completed')"),
    );
    expect(sql, contains("AND status IS DISTINCT FROM 'completed'"));
    expect(sql, contains('No migration-time row writes'));
    expect(sql, isNot(contains('79853f15')));
  });

  test('legacy set history still keys off parent session status', () {
    final dart = File(
      'lib/data/repositories/training_session_set_repository.dart',
    ).readAsStringSync();
    expect(dart, contains(".eq('training_sessions.status', 'completed')"));
  });

  test(
    'swap eligibility requires an open slot outcome, not an orphan parent',
    () {
      final sql = File(
        'supabase/migrations/20260906140000_ignore_completed_sessions_in_train_today_swap.sql',
      ).readAsStringSync();
      expect(sql, contains("o.outcome_status = 'in_progress'"));
      expect(sql, contains("ts.status = 'in_progress'"));
    },
  );
}
