-- Review fix: prevent elevated child-tree collisions and mutable result identity edges.
BEGIN;
-- Exact result identities across direct writes and elevated completion trees.
-- Direct draft checks inherit the real caller privilege context. Elevated
-- completion/correction may write terminal children; ordinary clients may not.
CREATE OR REPLACE FUNCTION public.cohort_guard_direct_result_write_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE root_id uuid; r public.training_session_records%ROWTYPE;
BEGIN
 IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;
 CASE TG_TABLE_NAME
  WHEN 'training_block_results' THEN root_id:=NEW.session_record_id;
  WHEN 'training_exercise_results' THEN
   SELECT session_record_id INTO root_id FROM public.training_block_results WHERE block_result_id=NEW.block_result_id;
  WHEN 'training_set_results' THEN
   SELECT b.session_record_id INTO root_id FROM public.training_exercise_results e
    JOIN public.training_block_results b ON b.block_result_id=e.block_result_id WHERE e.exercise_result_id=NEW.exercise_result_id;
  ELSE RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
 END CASE;
 SELECT * INTO r FROM public.training_session_records WHERE record_id=root_id FOR SHARE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.athlete_id IS DISTINCT FROM auth.uid()::text OR r.status<>'in_progress' THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_guard_direct_result_write_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.cohort_guard_result_identity_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE n jsonb:=to_jsonb(NEW); old_row jsonb; id_column text; edge_column text;
 node_id uuid; edge_id uuid; existing_edge uuid; root_id uuid; block_id uuid;
 r public.training_session_records%ROWTYPE; a public.programme_assignments%ROWTYPE;
BEGIN
 CASE TG_TABLE_NAME
  WHEN 'training_block_results' THEN id_column:='block_result_id'; edge_column:='session_record_id';
  WHEN 'training_exercise_results' THEN id_column:='exercise_result_id'; edge_column:='block_result_id';
  WHEN 'training_set_results' THEN id_column:='set_result_id'; edge_column:='exercise_result_id';
  ELSE RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
 END CASE;
 node_id:=(n->>id_column)::uuid; edge_id:=(n->>edge_column)::uuid;
 IF node_id IS NULL OR edge_id IS NULL THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' THEN
  old_row:=to_jsonb(OLD);
  IF old_row->>id_column IS DISTINCT FROM n->>id_column OR old_row->>edge_column IS DISTINCT FROM n->>edge_column THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 ELSE
  -- Check before ON CONFLICT can silently accept an identity in another tree.
  EXECUTE format('SELECT %I FROM public.%I WHERE %I=$1',edge_column,TG_TABLE_NAME,id_column) INTO existing_edge USING node_id;
  IF existing_edge IS NOT NULL AND existing_edge IS DISTINCT FROM edge_id THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 END IF;
 IF TG_TABLE_NAME='training_block_results' THEN root_id:=edge_id;
 ELSIF TG_TABLE_NAME='training_exercise_results' THEN
  block_id:=edge_id; SELECT session_record_id INTO root_id FROM public.training_block_results WHERE block_result_id=block_id;
 ELSE
  SELECT e.block_result_id,b.session_record_id INTO block_id,root_id FROM public.training_exercise_results e
   JOIN public.training_block_results b ON b.block_result_id=e.block_result_id WHERE e.exercise_result_id=edge_id;
 END IF;
 -- Root first, then retained programme and physical links. This privileged
 -- trigger checks the claims-derived owner explicitly; RLS is not its authority.
 SELECT * INTO r FROM public.training_session_records WHERE record_id=root_id FOR SHARE;
 IF NOT FOUND OR (current_setting('role',true) IN ('authenticated','anon') AND
  (auth.uid() IS NULL OR r.athlete_id IS DISTINCT FROM auth.uid()::text OR NOT public.cohort_auth_is_athlete())) THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 -- Existing assignment hints without retained outcomes remain legacy context,
 -- not reconstructed programme authority. Lock any extant checked owner.
 IF r.assignment_id IS NOT NULL THEN
  SELECT * INTO a FROM public.programme_assignments WHERE id=r.assignment_id FOR SHARE;
  IF FOUND AND a.athlete_id::text IS DISTINCT FROM r.athlete_id THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 END IF;
 PERFORM public.cohort_assert_record_parent_v1(r);
 IF block_id IS NOT NULL THEN
  PERFORM 1 FROM public.training_block_results WHERE block_result_id=block_id AND session_record_id=root_id FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 END IF;
 IF TG_TABLE_NAME='training_set_results' THEN
  PERFORM 1 FROM public.training_exercise_results WHERE exercise_result_id=edge_id AND block_result_id=block_id FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_guard_result_identity_v1() FROM PUBLIC,anon,authenticated,service_role;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['training_block_results','training_exercise_results','training_set_results'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS guard_direct_result_write_v1 ON public.%I',t);
  EXECUTE format('CREATE TRIGGER guard_direct_result_write_v1 BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.cohort_guard_direct_result_write_v1()',t);
  EXECUTE format('DROP TRIGGER IF EXISTS guard_result_identity_v1 ON public.%I',t);
  EXECUTE format('CREATE TRIGGER guard_result_identity_v1 BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.cohort_guard_result_identity_v1()',t);
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.cohort_guard_completion_record_identity_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE a public.programme_assignments%ROWTYPE; slot_version uuid; slot_week int; slot_protocol text;
 parent public.training_sessions%ROWTYPE; existing public.training_session_records%ROWTYPE;
BEGIN
 IF current_setting('role',true) IN ('authenticated','anon') AND
  (auth.uid() IS NULL OR NEW.athlete_id IS DISTINCT FROM auth.uid()::text OR NOT public.cohort_auth_is_athlete()) THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
 END IF;
 IF TG_OP='UPDATE' AND OLD.record_id IS DISTINCT FROM NEW.record_id THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' THEN existing:=OLD;
 ELSE SELECT * INTO existing FROM public.training_session_records WHERE record_id=NEW.record_id; END IF;
 IF existing.record_id IS NOT NULL AND
  (existing.athlete_id IS DISTINCT FROM NEW.athlete_id
   OR existing.training_session_id IS DISTINCT FROM NEW.training_session_id
   OR (existing.programme_id IS NOT NULL AND existing.programme_id IS DISTINCT FROM NEW.programme_id)
   OR (existing.assignment_id IS NOT NULL AND existing.assignment_id IS DISTINCT FROM NEW.assignment_id)
   OR (existing.programme_session_id IS NOT NULL AND existing.programme_session_id IS DISTINCT FROM NEW.programme_session_id)
   OR (existing.source_protocol_id IS NOT NULL AND existing.source_protocol_id IS DISTINCT FROM NEW.source_protocol_id)) THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
 END IF;
 PERFORM public.cohort_assert_record_parent_v1(NEW);
 IF current_setting('role',true) IN ('authenticated','anon') AND NEW.assignment_id IS NOT NULL THEN
  SELECT * INTO a FROM public.programme_assignments WHERE id=NEW.assignment_id AND athlete_id=auth.uid();
  SELECT w.version_id,w.week_number,s.protocol_id INTO slot_version,slot_week,slot_protocol FROM public.programme_version_session_slots s
   JOIN public.programme_version_days d ON d.id=s.day_id JOIN public.programme_version_weeks w ON w.id=d.week_id
   WHERE s.id=NEW.programme_session_id;
  IF a.id IS NULL OR (NEW.programme_session_id IS NOT NULL AND slot_version IS DISTINCT FROM a.programme_version_id) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
  END IF;
  -- Backfill creates its parent before its outcome. Require the exact owned
  -- assignment/slot and physical parent metadata during that interval too.
  IF NEW.training_session_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.programme_slot_outcomes WHERE training_session_id=NEW.training_session_id) THEN
   SELECT * INTO parent FROM public.training_sessions WHERE id=NEW.training_session_id;
   IF NEW.programme_session_id IS NULL OR parent.programme_id IS NULL
    OR parent.programme_id NOT IN (a.lineage_code,a.programme_version_id::text)
    OR parent.week_number IS DISTINCT FROM slot_week OR parent.protocol_id IS DISTINCT FROM slot_protocol THEN
    RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  END IF;
 END IF;
 IF current_setting('role',true) IN ('authenticated','anon') AND NEW.assignment_id IS NULL AND NEW.programme_session_id IS NOT NULL THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_guard_completion_record_identity_v1() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS guard_completion_record_identity_v1 ON public.training_session_records;
CREATE TRIGGER guard_completion_record_identity_v1 BEFORE INSERT OR UPDATE OF record_id,athlete_id,training_session_id,programme_id,
 assignment_id,programme_session_id,source_protocol_id,status ON public.training_session_records
 FOR EACH ROW EXECUTE FUNCTION public.cohort_guard_completion_record_identity_v1();

CREATE OR REPLACE FUNCTION public.cohort_insert_training_session_result_tree(
  p_record_id UUID,
  p_blocks JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_block JSONB;
  v_exercise JSONB;
  v_set JSONB;
  v_block_id UUID;
  v_exercise_id UUID;
  v_set_id UUID;
  v_position INT := 0;
BEGIN
  IF p_blocks IS NULL OR jsonb_typeof(p_blocks) <> 'array' OR jsonb_array_length(p_blocks) < 1 THEN
    RAISE EXCEPTION 'empty_result_tree' USING ERRCODE = 'P0001';
  END IF;

  FOR v_block IN
    SELECT value FROM jsonb_array_elements(p_blocks)
  LOOP
    v_position := v_position + 1;
    BEGIN
      v_block_id := NULLIF(v_block->>'block_result_id', '')::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
    END;
    IF v_block_id IS NULL THEN
      RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.training_block_results (
      block_result_id,
      session_record_id,
      source_block_id,
      block_snapshot,
      status,
      result_type,
      result_data,
      athlete_note,
      started_at,
      completed_at,
      duration_seconds,
      position
    ) VALUES (
      v_block_id,
      p_record_id,
      NULLIF(v_block->>'source_block_id', ''),
      COALESCE(v_block->'block_snapshot', '{}'::jsonb),
      COALESCE(NULLIF(v_block->>'status', ''), 'completed'),
      COALESCE(NULLIF(v_block->>'result_type', ''), 'completion'),
      v_block->'result_data',
      NULLIF(v_block->>'athlete_note', ''),
      NULLIF(v_block->>'started_at', '')::timestamptz,
      NULLIF(v_block->>'completed_at', '')::timestamptz,
      NULLIF(v_block->>'duration_seconds', '')::integer,
      COALESCE(NULLIF(v_block->>'position', '')::integer, v_position)
    )
    ON CONFLICT (block_result_id) DO NOTHING;
    -- Reconcile after the conflict wait too; a concurrent UUID winner must
    -- belong to this exact tree edge, never another record or athlete.
    PERFORM 1 FROM public.training_block_results WHERE block_result_id=v_block_id AND session_record_id=p_record_id FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;

    IF jsonb_typeof(v_block->'exercise_results') = 'array' THEN
      FOR v_exercise IN
        SELECT value FROM jsonb_array_elements(v_block->'exercise_results')
      LOOP
        BEGIN
          v_exercise_id := NULLIF(v_exercise->>'exercise_result_id', '')::UUID;
        EXCEPTION WHEN invalid_text_representation THEN
          RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
        END;
        IF v_exercise_id IS NULL THEN
          RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
        END IF;
        INSERT INTO public.training_exercise_results (
          exercise_result_id,
          block_result_id,
          source_exercise_id,
          exercise_snapshot,
          athlete_note,
          position
        ) VALUES (
          v_exercise_id,
          v_block_id,
          NULLIF(v_exercise->>'source_exercise_id', ''),
          COALESCE(v_exercise->'exercise_snapshot', '{}'::jsonb),
          NULLIF(v_exercise->>'athlete_note', ''),
          COALESCE(NULLIF(v_exercise->>'position', '')::integer, 0)
        )
        ON CONFLICT (exercise_result_id) DO NOTHING;
    -- Reconcile after the conflict wait too; a concurrent UUID winner must
    -- belong to this exact tree edge, never another record or athlete.
    PERFORM 1 FROM public.training_exercise_results WHERE exercise_result_id=v_exercise_id AND block_result_id=v_block_id FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;

        IF jsonb_typeof(v_exercise->'set_results') = 'array' THEN
          FOR v_set IN
            SELECT value FROM jsonb_array_elements(v_exercise->'set_results')
          LOOP
            BEGIN
              v_set_id := NULLIF(v_set->>'set_result_id', '')::UUID;
            EXCEPTION WHEN invalid_text_representation THEN
              RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
            END;
            IF v_set_id IS NULL THEN
              RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
            END IF;
            INSERT INTO public.training_set_results (
              set_result_id,
              exercise_result_id,
              set_number,
              reps,
              load,
              load_unit,
              distance,
              distance_unit,
              duration_seconds,
              completed,
              rpe,
              note,
              position
            ) VALUES (
              v_set_id,
              v_exercise_id,
              COALESCE(NULLIF(v_set->>'set_number', '')::integer, 0),
              NULLIF(v_set->>'reps', '')::numeric,
              NULLIF(v_set->>'load', '')::numeric,
              NULLIF(v_set->>'load_unit', ''),
              NULLIF(v_set->>'distance', '')::numeric,
              NULLIF(v_set->>'distance_unit', ''),
              NULLIF(v_set->>'duration_seconds', '')::integer,
              COALESCE((v_set->>'completed')::boolean, FALSE),
              NULLIF(v_set->>'rpe', '')::numeric,
              NULLIF(v_set->>'note', ''),
              COALESCE(NULLIF(v_set->>'position', '')::integer, 0)
            )
            ON CONFLICT (set_result_id) DO NOTHING;
    -- Reconcile after the conflict wait too; a concurrent UUID winner must
    -- belong to this exact tree edge, never another record or athlete.
    PERFORM 1 FROM public.training_set_results WHERE set_result_id=v_set_id AND exercise_result_id=v_exercise_id FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
          END LOOP;
        END IF;
      END LOOP;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_insert_training_session_result_tree(UUID, JSONB)
  FROM PUBLIC, anon, authenticated, service_role;

COMMIT;
