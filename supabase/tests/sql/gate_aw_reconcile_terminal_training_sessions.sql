-- Gate AW — historical parent close from exactly one terminal record.
-- Disable the future-path trigger while seeding historical orphan shapes.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_parent BIGINT;
  v_conflict BIGINT;
  v_draft BIGINT;
  v_orphan BIGINT;
  v_abandoned BIGINT;
  v_partial BIGINT;
  v_future BIGINT;
  v_status TEXT;
  v_completed_at TIMESTAMPTZ;
  v_ended BOOLEAN;
  v_count INT;
  v_blocks INT;
  v_occ INT;
  v_ops INT;
BEGIN
  ALTER TABLE public.training_session_records
    DISABLE TRIGGER trg_sync_training_session_from_terminal_record;

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-athlete', 'GATE-AW-COMPLETE', 'in_progress', NOW() - INTERVAL '1 day', NOW(), NOW())
  RETURNING id INTO v_parent;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at, completed_at
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'gate-aw-athlete',
    v_parent,
    'completed',
    '{"sessionTitle":"Closed"}'::JSONB,
    NOW() - INTERVAL '2 hours',
    TIMESTAMPTZ '2026-09-01 18:00:00+00'
  );

  INSERT INTO public.training_block_results (
    block_result_id, session_record_id, source_block_id, block_snapshot, status, result_type, position
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'b1', '{}'::JSONB, 'completed', 'strength', 1
  );

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-athlete', 'GATE-AW-PARTIAL', 'in_progress', NOW() - INTERVAL '1 day', NOW(), NOW())
  RETURNING id INTO v_partial;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at, completed_at
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3',
    'gate-aw-athlete',
    v_partial,
    'partially_completed',
    '{"sessionTitle":"Partial"}'::JSONB,
    NOW() - INTERVAL '3 hours',
    TIMESTAMPTZ '2026-09-02 19:00:00+00'
  );

  INSERT INTO public.training_block_results (
    block_result_id, session_record_id, source_block_id, block_snapshot, status, result_type, position
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3',
    'b1', '{}'::JSONB, 'completed', 'strength', 1
  );

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-athlete', 'GATE-AW-DRAFT', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_draft;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb5',
    'gate-aw-athlete',
    v_draft,
    'in_progress',
    '{"sessionTitle":"Draft"}'::JSONB,
    NOW()
  );

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-athlete', 'GATE-AW-ORPHAN', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_orphan;

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-athlete', 'GATE-AW-ABANDON', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_abandoned;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6',
    'gate-aw-athlete',
    v_abandoned,
    'abandoned',
    '{"sessionTitle":"Abandoned"}'::JSONB,
    NOW()
  );

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-other', 'GATE-AW-MISMATCH', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_conflict;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at, completed_at
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7',
    'gate-aw-athlete',
    v_conflict,
    'completed',
    '{"sessionTitle":"Mismatch"}'::JSONB,
    NOW() - INTERVAL '1 hour',
    NOW()
  );

  INSERT INTO public.training_block_results (
    block_result_id, session_record_id, source_block_id, block_snapshot, status, result_type, position
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb7',
    'b1', '{}'::JSONB, 'completed', 'strength', 1
  );

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-athlete', 'GATE-AW-MULTI', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_conflict;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at, completed_at
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb9',
    'gate-aw-athlete',
    v_conflict,
    'completed',
    '{"sessionTitle":"First"}'::JSONB,
    NOW() - INTERVAL '2 hours',
    NOW() - INTERVAL '1 hour'
  ), (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbba',
    'gate-aw-athlete',
    v_conflict,
    'completed',
    '{"sessionTitle":"Second"}'::JSONB,
    NOW() - INTERVAL '90 minutes',
    NOW() - INTERVAL '30 minutes'
  );

  INSERT INTO public.training_block_results (
    block_result_id, session_record_id, source_block_id, block_snapshot, status, result_type, position
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb0',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb9',
    'b1', '{}'::JSONB, 'completed', 'strength', 1
  );

  SELECT COUNT(*) INTO v_blocks FROM public.training_block_results
  WHERE session_record_id IN (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3'
  );
  SELECT COUNT(*) INTO v_occ FROM public.programme_schedule_occurrences;
  SELECT COUNT(*) INTO v_ops FROM public.programme_schedule_operations;

  PERFORM public.cohort_reconcile_terminal_training_sessions_from_records();

  SELECT status, completed_at, ended_early
    INTO v_status, v_completed_at, v_ended
  FROM public.training_sessions
  WHERE protocol_id = 'GATE-AW-COMPLETE';
  PERFORM sprint12_assert_eq('AW', 'completed_record_closes_parent', 'completed', v_status, NULL);
  PERFORM sprint12_record(
    'AW', 'uses_record_completed_at', 'match',
    CASE
      WHEN v_completed_at = TIMESTAMPTZ '2026-09-01 18:00:00+00' THEN 'match'
      ELSE COALESCE(v_completed_at::TEXT, 'null')
    END,
    TRUE,
    v_completed_at = TIMESTAMPTZ '2026-09-01 18:00:00+00',
    NULL
  );

  SELECT status, ended_early INTO v_status, v_ended
  FROM public.training_sessions WHERE protocol_id = 'GATE-AW-PARTIAL';
  PERFORM sprint12_assert_eq('AW', 'partial_record_closes_parent', 'completed', v_status, NULL);
  PERFORM sprint12_record(
    'AW', 'partial_sets_ended_early', 'true', v_ended::TEXT, TRUE, v_ended IS TRUE, NULL
  );

  SELECT status INTO v_status FROM public.training_sessions WHERE protocol_id = 'GATE-AW-DRAFT';
  PERFORM sprint12_assert_eq('AW', 'in_progress_record_unchanged', 'in_progress', v_status, NULL);

  SELECT status INTO v_status FROM public.training_sessions WHERE protocol_id = 'GATE-AW-ORPHAN';
  PERFORM sprint12_assert_eq('AW', 'no_record_unchanged', 'in_progress', v_status, NULL);

  SELECT status INTO v_status FROM public.training_sessions WHERE protocol_id = 'GATE-AW-ABANDON';
  PERFORM sprint12_assert_eq('AW', 'abandoned_unchanged', 'in_progress', v_status, NULL);

  SELECT status INTO v_status FROM public.training_sessions WHERE protocol_id = 'GATE-AW-MISMATCH';
  PERFORM sprint12_assert_eq('AW', 'athlete_mismatch_unchanged', 'in_progress', v_status, NULL);

  SELECT status INTO v_status FROM public.training_sessions WHERE protocol_id = 'GATE-AW-MULTI';
  PERFORM sprint12_assert_eq('AW', 'conflicting_records_unchanged', 'in_progress', v_status, NULL);

  SELECT COUNT(*) INTO v_count
  FROM public.cohort_reconcile_terminal_training_sessions_from_records();
  PERFORM sprint12_assert_eq('AW', 'second_apply_zero_rows', '0', v_count::TEXT, NULL);

  PERFORM sprint12_assert_eq(
    'AW', 'block_results_unchanged', v_blocks::TEXT,
    (SELECT COUNT(*)::TEXT FROM public.training_block_results
     WHERE session_record_id IN (
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3'
     )),
    NULL
  );
  PERFORM sprint12_assert_eq(
    'AW', 'occurrences_unchanged', v_occ::TEXT,
    (SELECT COUNT(*)::TEXT FROM public.programme_schedule_occurrences),
    NULL
  );
  PERFORM sprint12_assert_eq(
    'AW', 'schedule_ops_unchanged', v_ops::TEXT,
    (SELECT COUNT(*)::TEXT FROM public.programme_schedule_operations),
    NULL
  );

  ALTER TABLE public.training_session_records
    ENABLE TRIGGER trg_sync_training_session_from_terminal_record;

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-aw-athlete', 'GATE-AW-FUTURE', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_future;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at, completed_at
  ) VALUES (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbf',
    'gate-aw-athlete',
    v_future,
    'completed',
    '{"sessionTitle":"Future"}'::JSONB,
    NOW() - INTERVAL '10 minutes',
    NOW()
  );

  SELECT status INTO v_status FROM public.training_sessions WHERE id = v_future;
  PERFORM sprint12_assert_eq('AW', 'future_trigger_closes_parent', 'completed', v_status, NULL);
END $$;

SELECT sprint12_fail_if_any_failed();
