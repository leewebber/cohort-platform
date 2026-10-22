-- Independent Base declared-result storage. No programme eligibility/start authority.
-- No new production v3 import, canonical ExerciseDefinition registry or hosted change.
BEGIN;

CREATE FUNCTION public.cohort_base_actor() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  -- A service JWT carrying a forged sub is not athlete approval.
  IF current_setting('role', true) IS DISTINCT FROM 'authenticated'
     OR auth.uid() IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RAISE EXCEPTION 'authenticated athlete required' USING ERRCODE = '42501';
  END IF;
  RETURN auth.uid();
END $$;

CREATE FUNCTION public.cohort_base_canonical_value(p_metric text, p_value text, p_unit text)
RETURNS bigint LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE v numeric; factor numeric; maximum numeric;
BEGIN
  IF p_metric IS NULL OR p_unit IS NULL OR p_value IS NULL
     OR p_value !~ '^[0-9]{1,10}(\.[0-9]{1,6})?$' THEN
    RAISE EXCEPTION 'invalid decimal/metric/unit' USING ERRCODE = '22023';
  END IF;
  IF p_metric IN ('run10km','row2km') AND p_unit IN ('seconds','minutes','milliseconds') THEN
    factor := CASE p_unit WHEN 'seconds' THEN 1000 WHEN 'minutes' THEN 60000 ELSE 1 END;
    maximum := 1000000000;
  ELSIF p_metric IN ('backSquat5rm','strictPress5rm') AND p_unit IN ('kilograms','pounds') THEN
    factor := CASE p_unit WHEN 'kilograms' THEN 1000000000 ELSE 453592370 END;
    maximum := 1000000000000000;
  ELSIF p_metric = 'strictPullUps' AND p_unit = 'count' THEN
    factor := 1; maximum := 1000000000;
  ELSE
    RAISE EXCEPTION 'incompatible metric/unit' USING ERRCODE = '22023';
  END IF;
  v := p_value::numeric * factor;
  IF trunc(v) <> v OR v > maximum OR (v = 0 AND p_metric <> 'strictPullUps') THEN
    RAISE EXCEPTION 'invalid precision/range' USING ERRCODE = '22023';
  END IF;
  RETURN v::bigint;
END $$;

CREATE TABLE public.hyrox_base_benchmark_revisions (
  revision_id uuid PRIMARY KEY,
  athlete_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  evidence_id uuid NOT NULL REFERENCES public.hyrox_base_benchmark_revisions(revision_id) ON DELETE RESTRICT,
  metric text NOT NULL CHECK (metric IN ('run10km','row2km','backSquat5rm','strictPress5rm','strictPullUps')),
  evidence_contract text NOT NULL DEFAULT 'hyrox-base-declared-evidence-v1'
    CHECK (evidence_contract = 'hyrox-base-declared-evidence-v1'),
  revision_number integer NOT NULL CHECK (revision_number > 0),
  previous_revision_id uuid,
  command_id uuid NOT NULL UNIQUE,
  request jsonb NOT NULL CHECK (jsonb_typeof(request) = 'object'),
  raw_value text NOT NULL,
  input_unit text NOT NULL,
  canonical_value bigint NOT NULL,
  test_date date NOT NULL CHECK (test_date BETWEEN DATE '0001-01-01' AND DATE '9999-12-31'),
  source_type text NOT NULL CHECK (source_type IN ('knownResult','recordedResult')),
  source_reference text NOT NULL CHECK (length(btrim(source_reference)) BETWEEN 1 AND 512),
  correction_reason text,
  retained_digest text NOT NULL CHECK (retained_digest ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (revision_id, athlete_id, metric),
  UNIQUE (revision_id, athlete_id, metric, evidence_id, source_reference),
  UNIQUE (athlete_id, metric, source_reference, revision_number),
  UNIQUE (previous_revision_id),
  FOREIGN KEY (previous_revision_id, athlete_id, metric, evidence_id, source_reference)
    REFERENCES public.hyrox_base_benchmark_revisions(revision_id, athlete_id, metric, evidence_id, source_reference) ON DELETE RESTRICT,
  CHECK (canonical_value = public.cohort_base_canonical_value(metric, raw_value, input_unit)),
  CHECK ((revision_number = 1 AND evidence_id = revision_id AND previous_revision_id IS NULL AND correction_reason IS NULL)
    OR (revision_number > 1 AND previous_revision_id IS NOT NULL AND previous_revision_id <> revision_id
      AND correction_reason IS NOT NULL AND length(btrim(correction_reason)) BETWEEN 1 AND 500))
);

CREATE TABLE public.hyrox_base_benchmark_selections (
  selection_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  metric text NOT NULL CHECK (metric IN ('run10km','row2km','backSquat5rm','strictPress5rm','strictPullUps')),
  selected_revision_id uuid,
  previous_selection_id uuid,
  generation bigint NOT NULL CHECK (generation > 0),
  command_id uuid NOT NULL UNIQUE,
  request jsonb NOT NULL CHECK (jsonb_typeof(request) = 'object'),
  accepted_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  consent_scope text NOT NULL DEFAULT 'declared_benchmark_future_preview_only_v1'
    CHECK (consent_scope = 'declared_benchmark_future_preview_only_v1'),
  UNIQUE (selection_id, athlete_id, metric),
  UNIQUE (athlete_id, metric, generation),
  UNIQUE (previous_selection_id),
  FOREIGN KEY (previous_selection_id, athlete_id, metric)
    REFERENCES public.hyrox_base_benchmark_selections(selection_id, athlete_id, metric) ON DELETE RESTRICT,
  FOREIGN KEY (selected_revision_id, athlete_id, metric)
    REFERENCES public.hyrox_base_benchmark_revisions(revision_id, athlete_id, metric) ON DELETE RESTRICT,
  CHECK ((generation = 1 AND previous_selection_id IS NULL)
    OR (generation > 1 AND previous_selection_id IS NOT NULL AND previous_selection_id <> selection_id))
);

COMMENT ON TABLE public.hyrox_base_benchmark_revisions IS
  'Owner-scoped declared results, not test attestation, canonical definition publication or programme eligibility. Immutable corrections retain prior revisions.';
COMMENT ON TABLE public.hyrox_base_benchmark_selections IS
  'Explicit benchmark use/withdrawal for future previews only. Not programme/assignment/binding/rule/target consent. Never authorises session start.';

CREATE FUNCTION public.cohort_base_reject_mutation() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  RAISE EXCEPTION 'Base evidence/selection is append-only' USING ERRCODE = '23000';
END $$;
CREATE TRIGGER hyrox_base_evidence_immutable BEFORE UPDATE OR DELETE ON public.hyrox_base_benchmark_revisions
FOR EACH ROW EXECUTE FUNCTION public.cohort_base_reject_mutation();
CREATE TRIGGER hyrox_base_selection_immutable BEFORE UPDATE OR DELETE ON public.hyrox_base_benchmark_selections
FOR EACH ROW EXECUTE FUNCTION public.cohort_base_reject_mutation();

CREATE FUNCTION public.record_hyrox_base_benchmark(payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  actor uuid := public.cohort_base_actor(); command uuid; predecessor uuid; rid uuid := gen_random_uuid();
  prior public.hyrox_base_benchmark_revisions%ROWTYPE; replay public.hyrox_base_benchmark_revisions%ROWTYPE;
  val bigint; performed date; retained text; identity_id uuid; revision integer;
BEGIN
  IF NOT coalesce(public.cohort_running_5k_payload_is_valid(payload, ARRAY[
    'command_id','metric','value','unit','test_date','source_type','source_reference','previous_revision_id','correction_reason']), false)
    OR EXISTS (SELECT 1 FROM jsonb_each(payload) e WHERE
      e.key NOT IN ('previous_revision_id','correction_reason') AND jsonb_typeof(e.value) <> 'string')
    OR jsonb_typeof(payload->'previous_revision_id') NOT IN ('null','string')
    OR jsonb_typeof(payload->'correction_reason') NOT IN ('null','string') THEN
    RAISE EXCEPTION 'invalid benchmark payload' USING ERRCODE = '22023';
  END IF;
  command := (payload->>'command_id')::uuid;
  predecessor := (payload->>'previous_revision_id')::uuid;
  val := public.cohort_base_canonical_value(payload->>'metric', payload->>'value', payload->>'unit');
  IF payload->>'test_date' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    RAISE EXCEPTION 'invalid date' USING ERRCODE = '22023';
  END IF;
  performed := (payload->>'test_date')::date;
  IF to_char(performed, 'YYYY-MM-DD') <> payload->>'test_date'
    OR performed < DATE '0001-01-01' OR performed > DATE '9999-12-31'
    OR payload->>'source_type' NOT IN ('knownResult','recordedResult')
    OR length(btrim(payload->>'source_reference')) NOT BETWEEN 1 AND 512 THEN
    RAISE EXCEPTION 'invalid date/source' USING ERRCODE = '22023';
  END IF;
  -- Common actor/metric lock serialises evidence correction and selection.
  PERFORM pg_advisory_xact_lock(84202610, hashtext(actor::text || ':' || (payload->>'metric')));
  SELECT * INTO replay FROM public.hyrox_base_benchmark_revisions WHERE command_id = command;
  IF FOUND THEN
    IF replay.athlete_id <> actor OR replay.request <> payload THEN
      RETURN jsonb_build_object('status','refused','code','command_conflict');
    END IF;
    RETURN jsonb_build_object('status','replayed','revision_id',replay.revision_id,'retained_digest',replay.retained_digest);
  END IF;
  SELECT * INTO prior FROM public.hyrox_base_benchmark_revisions
    WHERE athlete_id = actor AND metric = payload->>'metric' AND source_reference = payload->>'source_reference'
    ORDER BY revision_number DESC LIMIT 1;
  IF FOUND THEN
    IF predecessor IS DISTINCT FROM prior.revision_id THEN
      RETURN jsonb_build_object('status','refused','code','stale_evidence_revision');
    END IF;
    IF length(btrim(coalesce(payload->>'correction_reason',''))) NOT BETWEEN 1 AND 500 THEN
      RAISE EXCEPTION 'correction reason required' USING ERRCODE = '22023';
    END IF;
    identity_id := prior.evidence_id; revision := prior.revision_number + 1;
  ELSE
    IF predecessor IS NOT NULL OR payload->>'correction_reason' IS NOT NULL THEN
      RETURN jsonb_build_object('status','refused','code','unresolved_evidence_identity');
    END IF;
    identity_id := rid; revision := 1;
  END IF;
  retained := encode(extensions.digest(convert_to(public.cohort_tracking_canonical_text(
    jsonb_build_object('contract','hyrox-base-declared-evidence-v1','athlete_id',actor,
      'revision_id',rid,'evidence_id',identity_id,'revision_number',revision,
      'canonical_value',val,'request',payload)), 'UTF8'), 'sha256'), 'hex');
  INSERT INTO public.hyrox_base_benchmark_revisions
    (revision_id,athlete_id,evidence_id,metric,revision_number,previous_revision_id,command_id,request,
     raw_value,input_unit,canonical_value,test_date,source_type,source_reference,correction_reason,retained_digest)
    VALUES (rid,actor,identity_id,payload->>'metric',revision,predecessor,command,payload,
      payload->>'value',payload->>'unit',val,performed,payload->>'source_type',payload->>'source_reference',
      payload->>'correction_reason',retained);
  RETURN jsonb_build_object('status','recorded','revision_id',rid,'retained_digest',retained);
EXCEPTION WHEN invalid_parameter_value OR invalid_text_representation OR datetime_field_overflow OR invalid_datetime_format OR check_violation THEN
  RETURN jsonb_build_object('status','validation_failure','code','invalid_base_benchmark');
WHEN unique_violation THEN
  RETURN jsonb_build_object('status','refused','code','command_conflict');
END $$;

CREATE FUNCTION public.select_hyrox_base_benchmark(payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE actor uuid := public.cohort_base_actor(); command uuid; chosen uuid; previous uuid;
  head public.hyrox_base_benchmark_selections%ROWTYPE; replay public.hyrox_base_benchmark_selections%ROWTYPE;
  result public.hyrox_base_benchmark_selections%ROWTYPE; benchmark public.hyrox_base_benchmark_revisions%ROWTYPE;
BEGIN
  IF NOT coalesce(public.cohort_running_5k_payload_is_valid(payload, ARRAY[
      'command_id','metric','selected_revision_id','expected_selection_id','consent']), false)
    OR jsonb_typeof(payload->'command_id') <> 'string' OR jsonb_typeof(payload->'metric') <> 'string'
    OR jsonb_typeof(payload->'selected_revision_id') NOT IN ('null','string')
    OR jsonb_typeof(payload->'expected_selection_id') NOT IN ('null','string')
    OR payload->'consent' IS DISTINCT FROM '"use_declared_benchmark_for_future_previews_only"'::jsonb
    OR payload->>'metric' NOT IN ('run10km','row2km','backSquat5rm','strictPress5rm','strictPullUps') THEN
    RAISE EXCEPTION 'invalid explicit selection' USING ERRCODE = '22023';
  END IF;
  command := (payload->>'command_id')::uuid; chosen := (payload->>'selected_revision_id')::uuid;
  previous := (payload->>'expected_selection_id')::uuid;
  PERFORM pg_advisory_xact_lock(84202610, hashtext(actor::text || ':' || (payload->>'metric')));
  SELECT * INTO replay FROM public.hyrox_base_benchmark_selections WHERE command_id = command;
  IF FOUND THEN
    IF replay.athlete_id <> actor OR replay.request <> payload THEN
      RETURN jsonb_build_object('status','refused','code','command_conflict');
    END IF;
    RETURN jsonb_build_object('status','replayed','selection_id',replay.selection_id,'generation',replay.generation);
  END IF;
  SELECT * INTO head FROM public.hyrox_base_benchmark_selections
    WHERE athlete_id = actor AND metric = payload->>'metric' ORDER BY generation DESC LIMIT 1;
  IF head.selection_id IS DISTINCT FROM previous THEN
    RETURN jsonb_build_object('status','refused','code','stale_selection');
  END IF;
  IF chosen IS NOT NULL THEN
    SELECT * INTO benchmark FROM public.hyrox_base_benchmark_revisions
      WHERE revision_id = chosen AND athlete_id = actor AND metric = payload->>'metric';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('status','refused','code','unresolved_owned_benchmark');
    END IF;
    IF EXISTS (SELECT 1 FROM public.hyrox_base_benchmark_revisions WHERE previous_revision_id = chosen) THEN
      RETURN jsonb_build_object('status','refused','code','superseded_benchmark');
    END IF;
  END IF;
  INSERT INTO public.hyrox_base_benchmark_selections
    (athlete_id,metric,selected_revision_id,previous_selection_id,generation,command_id,request)
    VALUES (actor,payload->>'metric',chosen,previous,coalesce(head.generation,0)+1,command,payload)
    RETURNING * INTO result;
  RETURN jsonb_build_object('status','accepted','selection_id',result.selection_id,'generation',result.generation);
EXCEPTION WHEN invalid_parameter_value OR invalid_text_representation THEN
  RETURN jsonb_build_object('status','validation_failure','code','invalid_base_selection');
WHEN unique_violation THEN
  RETURN jsonb_build_object('status','refused','code','command_conflict');
END $$;

CREATE FUNCTION public.read_hyrox_base_selections() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE actor uuid := public.cohort_base_actor(); result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(to_jsonb(h) || jsonb_build_object(
    'benchmark', CASE WHEN b.revision_id IS NULL THEN NULL ELSE to_jsonb(b) END,
    'preview_state', CASE WHEN b.revision_id IS NULL THEN 'unavailable_withdrawn'
      WHEN EXISTS (SELECT 1 FROM public.hyrox_base_benchmark_revisions newer WHERE newer.previous_revision_id = b.revision_id)
        THEN 'unavailable_stale_selection' ELSE 'selected_declared_result' END) ORDER BY h.metric), '[]'::jsonb)
  INTO result FROM (
    SELECT DISTINCT ON (metric) * FROM public.hyrox_base_benchmark_selections
    WHERE athlete_id = actor ORDER BY metric, generation DESC
  ) h LEFT JOIN public.hyrox_base_benchmark_revisions b
    ON b.revision_id = h.selected_revision_id AND b.athlete_id = actor AND b.metric = h.metric;
  RETURN jsonb_build_object('status','read','scope','declared_benchmark_future_preview_only_v1','selections',result);
END $$;

-- Private, non-admitting calculation kernel. SQL NUMERIC gives the same exact integer
-- intermediates as Dart BigInt, including nearest increment with ties down.
CREATE FUNCTION public.cohort_base_calculate_v1(p_kind text, p_rule_version integer,
  p_week integer, p_value bigint, p_increment_grams bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE fast integer; slow integer; basis integer; numerator numeric; denominator numeric; grams bigint;
BEGIN
  IF p_rule_version IS DISTINCT FROM 1 OR p_week IS NULL OR p_week NOT BETWEEN 1 AND 8
    OR p_kind IS NULL OR p_kind NOT IN ('runningIntervals','dedicatedRowIntervals','backSquat') THEN
    RETURN jsonb_build_object('status','unavailable','code','unsupported_rule');
  END IF;
  IF p_value IS NULL THEN RETURN jsonb_build_object('status','unavailable','code','missing_benchmark'); END IF;
  IF p_value <= 0 OR p_value > (CASE WHEN p_kind = 'backSquat' THEN 1000000000000000 ELSE 1000000000 END) THEN
    RETURN jsonb_build_object('status','unavailable','code','invalid_benchmark');
  END IF;
  IF p_kind = 'runningIntervals' THEN
    fast := (ARRAY[100,100,102,100,100,102,103,100])[p_week]; slow := fast + 5;
    RETURN jsonb_build_object('status','calculated','unit','milliseconds_per_kilometre',
      'faster',jsonb_build_object('numerator',p_value*fast,'denominator',1000),
      'slower',jsonb_build_object('numerator',p_value*slow,'denominator',1000));
  ELSIF p_kind = 'dedicatedRowIntervals' THEN
    fast := (ARRAY[10,10,12,18,10,10,12,15])[p_week];
    slow := (ARRAY[15,15,18,23,15,15,18,20])[p_week];
    RETURN jsonb_build_object('status','calculated','unit','milliseconds_per_500_metres',
      'faster',jsonb_build_object('numerator',p_value+fast*4000,'denominator',4),
      'slower',jsonb_build_object('numerator',p_value+slow*4000,'denominator',4));
  END IF;
  IF p_increment_grams IS NULL OR p_increment_grams NOT BETWEEN 1 AND 1000000000 THEN
    RETURN jsonb_build_object('status','unavailable','code','missing_or_invalid_increment');
  END IF;
  basis := (ARRAY[8000,8250,8750,7000,8750,9000,9500,7500])[p_week];
  numerator := p_value::numeric*basis; denominator := 10000::numeric*p_increment_grams*1000000;
  grams := (div(numerator,denominator) + CASE WHEN mod(numerator,denominator)*2 > denominator THEN 1 ELSE 0 END)*p_increment_grams;
  IF grams = 0 THEN RETURN jsonb_build_object('status','unavailable','code','rounded_load_not_positive_use_authored_rir'); END IF;
  RETURN jsonb_build_object('status','calculated','unit','grams_total_external_load','grams',grams);
END $$;
COMMENT ON FUNCTION public.cohort_base_calculate_v1(text,integer,integer,bigint,bigint) IS
  'Private arithmetic prerequisite only; caller must first resolve canonical source, rule, exact metric/unit, dedicated block, ownership and consent. Never admission by hash.';

ALTER TABLE public.hyrox_base_benchmark_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hyrox_base_benchmark_selections ENABLE ROW LEVEL SECURITY;
CREATE POLICY hyrox_base_evidence_owner_read ON public.hyrox_base_benchmark_revisions FOR SELECT TO authenticated
  USING (athlete_id = (SELECT auth.uid()) AND public.cohort_auth_is_athlete());
CREATE POLICY hyrox_base_selection_owner_read ON public.hyrox_base_benchmark_selections FOR SELECT TO authenticated
  USING (athlete_id = (SELECT auth.uid()) AND public.cohort_auth_is_athlete());
REVOKE ALL ON TABLE public.hyrox_base_benchmark_revisions, public.hyrox_base_benchmark_selections FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.hyrox_base_benchmark_revisions, public.hyrox_base_benchmark_selections TO authenticated;
REVOKE ALL ON FUNCTION public.cohort_base_actor(), public.cohort_base_canonical_value(text,text,text),
  public.cohort_base_reject_mutation(), public.cohort_base_calculate_v1(text,integer,integer,bigint,bigint),
  public.record_hyrox_base_benchmark(jsonb), public.select_hyrox_base_benchmark(jsonb), public.read_hyrox_base_selections()
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_hyrox_base_benchmark(jsonb), public.select_hyrox_base_benchmark(jsonb), public.read_hyrox_base_selections() TO authenticated;
COMMIT;
