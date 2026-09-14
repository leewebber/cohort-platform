-- Gate AV — parent training_sessions closes only from terminal records.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_open BIGINT;
  v_draft BIGINT;
  v_status TEXT;
  v_completed_at TIMESTAMPTZ;
BEGIN
  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-av-athlete', 'GATE-AV-OPEN', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_open;

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-av-athlete', 'GATE-AV-DRAFT', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_draft;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at
  ) VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'gate-av-athlete',
    v_draft,
    'in_progress',
    '{"sessionTitle":"Draft"}'::JSONB,
    NOW()
  );

  SELECT status INTO v_status FROM public.training_sessions WHERE id = v_draft;
  PERFORM sprint12_assert_eq(
    'AV', 'draft_record_leaves_parent_open', 'in_progress', v_status,
    'in-progress records are not completion evidence'
  );

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot,
    started_at, completed_at
  ) VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    'gate-av-athlete',
    v_open,
    'completed',
    '{"sessionTitle":"Closed"}'::JSONB,
    NOW() - INTERVAL '20 minutes',
    NOW()
  );

  SELECT status, completed_at
    INTO v_status, v_completed_at
  FROM public.training_sessions
  WHERE id = v_open;

  PERFORM sprint12_assert_eq(
    'AV', 'completed_record_closes_parent', 'completed', v_status,
    'terminal record must close the parent container'
  );
  PERFORM sprint12_record(
    'AV', 'completed_at_populated', 'not_null',
    CASE WHEN v_completed_at IS NULL THEN 'null' ELSE 'not_null' END,
    TRUE,
    v_completed_at IS NOT NULL,
    NULL
  );

  UPDATE public.training_session_records
  SET status = 'completed',
      completed_at = NOW()
  WHERE record_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';

  SELECT status INTO v_status FROM public.training_sessions WHERE id = v_draft;
  PERFORM sprint12_assert_eq(
    'AV', 'later_completion_closes_draft_parent', 'completed', v_status,
    'updating a draft record to completed closes the parent'
  );

  INSERT INTO public.training_sessions (athlete_id, protocol_id, status, started_at, created_at, updated_at)
  VALUES ('gate-av-athlete', 'GATE-AV-ABANDON', 'in_progress', NOW(), NOW(), NOW())
  RETURNING id INTO v_open;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, training_session_id, status, session_snapshot, started_at
  ) VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    'gate-av-athlete',
    v_open,
    'abandoned',
    '{"sessionTitle":"Abandoned"}'::JSONB,
    NOW()
  );

  SELECT status INTO v_status FROM public.training_sessions WHERE id = v_open;
  PERFORM sprint12_assert_eq(
    'AV', 'abandoned_does_not_complete_parent', 'in_progress', v_status,
    'abandonment is not valid completion evidence'
  );
END $$;

SELECT sprint12_fail_if_any_failed();
