BEGIN;
CREATE FUNCTION public.read_hyrox_programme_prescription_state(p_assignment_id uuid,p_programme_version_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=public.cohort_base_actor(); head public.programme_v3_prescription_consents%ROWTYPE; doc jsonb; benchmarks jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.programme_assignments WHERE id=p_assignment_id AND athlete_id=actor AND programme_version_id=p_programme_version_id) THEN
  RAISE EXCEPTION 'wrong_owned_programme' USING ERRCODE='42501'; END IF;
 SELECT * INTO head FROM public.programme_v3_prescription_consents WHERE assignment_id=p_assignment_id ORDER BY generation DESC LIMIT 1;
 SELECT document INTO doc FROM public.programme_v3_prescription_reviews WHERE review_id=head.review_id AND athlete_id=actor;
 SELECT coalesce(jsonb_agg(to_jsonb(b) ORDER BY b.metric,b.test_date DESC,b.revision_id),'[]') INTO benchmarks
 FROM public.hyrox_base_benchmark_revisions b WHERE b.athlete_id=actor AND b.metric IN ('run10km','row2km','backSquat5rm')
 AND NOT EXISTS(SELECT 1 FROM public.hyrox_base_benchmark_revisions n WHERE n.previous_revision_id=b.revision_id);
 RETURN jsonb_build_object('status','read','consent',CASE WHEN head.consent_id IS NULL THEN NULL ELSE to_jsonb(head) END,
   'accepted_document',doc,'benchmarks',benchmarks);
END $$;
REVOKE ALL ON FUNCTION public.read_hyrox_programme_prescription_state(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.read_hyrox_programme_prescription_state(uuid,uuid) TO authenticated;

-- The retained canonical snapshot, rather than a client-supplied copy, owns targets
-- through ordinary draft, completion and subsequent actual-result corrections.
CREATE FUNCTION public.cohort_v3_record_prescription_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE frozen public.programme_occurrence_v3_prescription_snapshots%ROWTYPE;
BEGIN
 SELECT * INTO frozen FROM public.programme_occurrence_v3_prescription_snapshots WHERE training_session_id=NEW.training_session_id;
 IF FOUND THEN
  IF frozen.athlete_id::text<>NEW.athlete_id::text OR frozen.assignment_id::text IS DISTINCT FROM NEW.assignment_id::text
    OR frozen.programme_version_id::text IS DISTINCT FROM NEW.programme_id OR
    frozen.snapshot IS DISTINCT FROM NEW.session_snapshot->'boundPrescriptionV1' THEN
    RAISE EXCEPTION 'authoritative_prescription_snapshot_required' USING ERRCODE='23514'; END IF;
 ELSIF NEW.session_snapshot ? 'boundPrescriptionV1' THEN
  RAISE EXCEPTION 'unexpected_bound_prescription_snapshot' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_v3_record_prescription_guard() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_v3_record_prescription BEFORE INSERT OR UPDATE ON public.training_session_records
FOR EACH ROW EXECUTE FUNCTION public.cohort_v3_record_prescription_guard();

CREATE OR REPLACE FUNCTION public.cohort_canonicalize_interval_result_data(
  p_result JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total INT;
  v_unit TEXT;
  v_row JSONB;
  v_ordinal INT;
  v_pace NUMERIC;
  v_state TEXT;
  v_recorded INT := 0;
  v_seen INT[] := ARRAY[]::INT[];
BEGIN
  IF p_result IS NULL OR jsonb_typeof(p_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'invalid_result_data' USING ERRCODE = '22023';
  END IF;

  v_total := NULLIF(p_result->>'totalIntervals', '')::INT;
  v_unit := COALESCE(NULLIF(p_result->>'paceUnit', ''), 'sec_per_km');
  IF v_unit NOT IN ('sec_per_km', 's/km', 'sec/km', 'sec_per_500m') THEN
    RAISE EXCEPTION 'invalid_pace_unit' USING ERRCODE = '22023';
  END IF;

  IF p_result ? 'intervals'
     AND jsonb_typeof(p_result->'intervals') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'invalid_result_data' USING ERRCODE = '22023';
  END IF;

  IF v_total IS NOT NULL AND (v_total < 1 OR v_total > 100) THEN
    RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
  END IF;

  IF p_result ? 'intervals' THEN
    IF v_total IS NOT NULL
       AND jsonb_array_length(p_result->'intervals') > v_total THEN
      RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
    END IF;
    FOR v_row IN SELECT value FROM jsonb_array_elements(p_result->'intervals')
    LOOP
      v_ordinal := NULLIF(v_row->>'ordinal', '')::INT;
      v_state := COALESCE(v_row->>'state', 'pending');
      v_pace := NULLIF(v_row->>'paceSecondsPerKm', '')::NUMERIC;
      IF v_ordinal IS NULL OR v_ordinal < 1 THEN
        RAISE EXCEPTION 'invalid_interval_ordinal' USING ERRCODE = '22023';
      END IF;
      IF v_total IS NOT NULL AND v_ordinal > v_total THEN
        RAISE EXCEPTION 'invalid_interval_ordinal' USING ERRCODE = '22023';
      END IF;
      IF v_ordinal = ANY (v_seen) THEN
        RAISE EXCEPTION 'duplicate_interval_ordinal' USING ERRCODE = '22023';
      END IF;
      v_seen := array_append(v_seen, v_ordinal);
      IF v_state NOT IN ('pending', 'completed', 'skipped', 'pace_unavailable') THEN
        RAISE EXCEPTION 'invalid_interval_state' USING ERRCODE = '22023';
      END IF;
      IF v_pace IS NOT NULL AND v_pace <= 0 THEN
        RAISE EXCEPTION 'invalid_pace' USING ERRCODE = '22023';
      END IF;
      IF v_state = 'completed' AND (v_pace IS NULL OR v_pace <= 0) THEN
        RAISE EXCEPTION 'invalid_pace' USING ERRCODE = '22023';
      END IF;
      IF v_state IN ('completed', 'pace_unavailable') THEN
        v_recorded := v_recorded + 1;
      END IF;
    END LOOP;
    p_result := jsonb_set(p_result, '{intervalsCompleted}', to_jsonb(v_recorded));
  ELSIF p_result ? 'intervalsCompleted' THEN
    v_recorded := NULLIF(p_result->>'intervalsCompleted', '')::INT;
    IF v_recorded IS NULL OR v_recorded < 0 OR v_recorded > 1000 THEN
      RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
    END IF;
    IF v_total IS NOT NULL AND v_recorded > v_total THEN
      RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
    END IF;
  END IF;

  RETURN p_result;
END;
$$;

-- Bound block doses and dimensional units are checked against retained server
-- prescriptions for drafts, completion and later actual-result corrections.
CREATE FUNCTION public.cohort_v3_block_actuals_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE packet jsonb; t jsonb; row_value jsonb; expected_unit text; reps int; work_seconds int;
BEGIN
 SELECT s.snapshot INTO packet FROM public.training_session_records r
 JOIN public.programme_occurrence_v3_prescription_snapshots s ON s.training_session_id=r.training_session_id
 WHERE r.record_id=NEW.session_record_id;
 IF packet IS NULL THEN RETURN NEW; END IF;
 SELECT x INTO t FROM jsonb_array_elements(packet->'prescriptions') x WHERE x#>>'{binding,block_id}'=NEW.source_block_id;
 IF t IS NULL OR t#>>'{binding,kind}'='backSquat' THEN RETURN NEW; END IF;
 expected_unit:=CASE t#>>'{binding,kind}' WHEN 'runningIntervals' THEN 'sec_per_km' ELSE 'sec_per_500m' END;
 reps:=(t#>>'{authored,repetitions}')::int; work_seconds:=(t#>>'{authored,work_seconds}')::int;
 IF NEW.result_type<>'interval' OR NEW.result_data->>'paceUnit' IS DISTINCT FROM expected_unit
   OR (NEW.result_data->>'totalIntervals')::int IS DISTINCT FROM reps
   OR (NEW.result_data->>'workSeconds')::int IS DISTINCT FROM work_seconds
   OR jsonb_typeof(NEW.result_data->'intervals') IS DISTINCT FROM 'array'
   OR jsonb_array_length(NEW.result_data->'intervals')<>reps THEN
   RAISE EXCEPTION 'bound_interval_shape_mismatch' USING ERRCODE='23514'; END IF;
 NEW.result_data:=public.cohort_canonicalize_interval_result_data(NEW.result_data);
 FOR row_value IN SELECT value FROM jsonb_array_elements(NEW.result_data->'intervals') LOOP
  IF row_value->>'paceUnit' IS DISTINCT FROM expected_unit OR (row_value->>'workSeconds')::int IS DISTINCT FROM work_seconds THEN
   RAISE EXCEPTION 'bound_interval_unit_or_duration_mismatch' USING ERRCODE='23514'; END IF;
 END LOOP;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_v3_block_actuals_guard() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_v3_block_actuals BEFORE INSERT OR UPDATE ON public.training_block_results
FOR EACH ROW EXECUTE FUNCTION public.cohort_v3_block_actuals_guard();

COMMIT;
