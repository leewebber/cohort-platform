-- Empty future-only extension of the published canonical definition boundary.
-- NO catalogue backfill or usable producer membership. PostgreSQL 17 may retain
-- only its creator ADMIN link, with SET/INHERIT both false; this is not RPC access.
BEGIN;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher') THEN
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher'
      AND (rolcanlogin OR rolinherit OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls))
      OR EXISTS(SELECT 1 FROM pg_auth_members WHERE
        (roleid='cohort_exercise_version_publisher'::regrole AND
          (member<>current_user::regrole OR inherit_option OR set_option OR NOT admin_option))
        OR member='cohort_exercise_version_publisher'::regrole) THEN
      RAISE EXCEPTION 'unexpected exercise version publisher authority';
    END IF;
  ELSE
    CREATE ROLE cohort_exercise_version_publisher NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
  END IF;
END $$;
CREATE TABLE public.published_exercise_definition_versions (
  exercise_id text NOT NULL REFERENCES public.exercises_v2(exercise_id) ON DELETE RESTRICT,
  definition_version text NOT NULL CHECK (length(definition_version) BETWEEN 1 AND 128 AND btrim(definition_version)=definition_version),
  canonical_text text NOT NULL CHECK (octet_length(canonical_text) BETWEEN 2 AND 262144),
  content_digest text NOT NULL CHECK (content_digest=encode(extensions.digest(convert_to(canonical_text,'UTF8'),'sha256'),'hex')),
  publication jsonb NOT NULL,
  captured_by name NOT NULL DEFAULT session_user,
  captured_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  PRIMARY KEY(exercise_id,definition_version),
  UNIQUE(exercise_id,definition_version,content_digest)
);
CREATE UNIQUE INDEX published_exercise_version_event_unique ON public.published_exercise_definition_versions((publication->>'event_id'));
ALTER TABLE public.published_exercise_definition_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.published_exercise_definition_versions FROM PUBLIC,anon,authenticated,service_role,cohort_exercise_version_publisher;
CREATE TRIGGER published_exercise_definition_immutable BEFORE UPDATE OR DELETE ON public.published_exercise_definition_versions
FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();

CREATE FUNCTION public.retain_published_exercise_definition_v1(p_canonical_text text,p_publication jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE d jsonb; prior public.published_exercise_definition_versions%ROWTYPE; k text; ref text;
BEGIN
  -- Capability comes from the authenticated database producer role, not fields,
  -- hashes, catalogue existence, a founder-looking string or the service JWT.
  IF current_setting('role',true) IS DISTINCT FROM 'cohort_exercise_version_publisher' THEN
    RAISE EXCEPTION 'verified exercise publication producer required' USING ERRCODE='42501'; END IF;
  d:=p_canonical_text::jsonb;
  IF octet_length(p_canonical_text)>262144 OR p_canonical_text IS DISTINCT FROM public.cohort_tracking_canonical_text(d)
    OR jsonb_typeof(d) IS DISTINCT FROM 'object'
    OR NOT d ?& ARRAY['id','canonical_name','aliases','modality','movement_patterns','laterality','technical_complexity','impact_level',
      'valid_prescription_dimensions','valid_completed_performance_dimensions','equipment','environments','coaching_content_refs',
      'media_refs','movement_standard_refs','sport_standard_refs','transitional_alias_ids','lifecycle_status','version','owner','published_at']
    OR d-ARRAY['id','canonical_name','aliases','modality','family_id','movement_patterns','laterality','technical_complexity','impact_level',
      'valid_prescription_dimensions','valid_completed_performance_dimensions','equipment','environments','coaching_content_refs',
      'media_refs','movement_standard_refs','sport_standard_refs','transitional_alias_ids','lifecycle_status','version','owner','published_at'] <> '{}'
    OR jsonb_typeof(d->'id') IS DISTINCT FROM 'string' OR d->>'id' !~ '^EX-[0-9]+$' OR d->>'lifecycle_status' IS DISTINCT FROM 'published'
    OR coalesce(d->>'modality','') NOT IN ('strength','bodyweight','locomotion','erg','mobility','recovery','sport_specific','other')
    OR coalesce(d->>'laterality','') NOT IN ('bilateral','unilateral','either','not_applicable')
    OR coalesce(d->>'technical_complexity','') NOT IN ('beginner','intermediate','advanced','unknown')
    OR coalesce(d->>'impact_level','') NOT IN ('low','moderate','high','unknown')
    OR coalesce(d->>'published_at','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$'
    OR d->>'owner' IS DISTINCT FROM 'founder' OR jsonb_typeof(d->'version') IS DISTINCT FROM 'string'
    OR coalesce(length(d->>'version'),0) NOT BETWEEN 1 AND 128 OR btrim(d->>'version')<>d->>'version'
    OR coalesce(length(btrim(d->>'canonical_name')),0)=0 OR jsonb_typeof(d->'published_at') IS DISTINCT FROM 'string'
    OR NOT coalesce(public.cohort_running_5k_payload_is_valid(p_publication,ARRAY[
      'issuer','event_id','source_reference','published_at','approved_binding_kinds']),false)
    OR jsonb_typeof(p_publication->'event_id') IS DISTINCT FROM 'string'
    OR jsonb_typeof(p_publication->'source_reference') IS DISTINCT FROM 'string'
    OR jsonb_typeof(p_publication->'published_at') IS DISTINCT FROM 'string'
    OR p_publication->>'issuer' IS DISTINCT FROM 'founder_exercise_publication_v1'
    OR coalesce(length(btrim(p_publication->>'source_reference')),0) NOT BETWEEN 1 AND 1024
    OR jsonb_typeof(p_publication->'approved_binding_kinds') IS DISTINCT FROM 'array'
    OR (d->>'published_at')::timestamptz IS DISTINCT FROM (p_publication->>'published_at')::timestamptz THEN
    RAISE EXCEPTION 'unresolved published definition/provenance' USING ERRCODE='22023'; END IF;
  PERFORM (p_publication->>'event_id')::uuid;
  FOREACH k IN ARRAY ARRAY['aliases','movement_patterns','valid_prescription_dimensions','valid_completed_performance_dimensions',
    'coaching_content_refs','media_refs','movement_standard_refs','sport_standard_refs','transitional_alias_ids'] LOOP
    IF jsonb_typeof(d->k) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid definition collection' USING ERRCODE='22023'; END IF;
  END LOOP;
  IF jsonb_typeof(d->'equipment') IS DISTINCT FROM 'object' OR jsonb_typeof(d->'environments') IS DISTINCT FROM 'object'
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_publication->'approved_binding_kinds') x
      WHERE jsonb_typeof(x)<>'string' OR x#>>'{}' NOT IN ('runningIntervals','dedicatedRowIntervals','backSquat'))
    OR (SELECT count(*) FROM jsonb_array_elements(p_publication->'approved_binding_kinds'))<>
       (SELECT count(DISTINCT x) FROM jsonb_array_elements(p_publication->'approved_binding_kinds') x) THEN
    RAISE EXCEPTION 'invalid publication capability' USING ERRCODE='22023'; END IF;
  -- The current catalogue is an identity/lifecycle check only, never a version.
  PERFORM 1 FROM public.exercises_v2 WHERE exercise_id=d->>'id' AND published IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'published canonical identity unavailable' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('exercise-version:'||(d->>'id')||':'||(d->>'version'),0));
  SELECT * INTO prior FROM public.published_exercise_definition_versions WHERE exercise_id=d->>'id' AND definition_version=d->>'version';
  IF FOUND THEN
    IF prior.canonical_text<>p_canonical_text OR prior.publication<>p_publication THEN
      RAISE EXCEPTION 'immutable published definition conflict' USING ERRCODE='23505'; END IF;
    RETURN to_jsonb(prior);
  END IF;
  INSERT INTO public.published_exercise_definition_versions(exercise_id,definition_version,canonical_text,content_digest,publication)
    VALUES(d->>'id',d->>'version',p_canonical_text,encode(extensions.digest(convert_to(p_canonical_text,'UTF8'),'sha256'),'hex'),p_publication)
    RETURNING * INTO prior;
  RETURN to_jsonb(prior);
END $$;
REVOKE ALL ON FUNCTION public.retain_published_exercise_definition_v1(text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT USAGE ON SCHEMA public TO cohort_exercise_version_publisher;
GRANT EXECUTE ON FUNCTION public.retain_published_exercise_definition_v1(text,jsonb) TO cohort_exercise_version_publisher;

CREATE TABLE public.published_exercise_version_retirements (
 exercise_id text NOT NULL,
 definition_version text NOT NULL,
 event jsonb NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 PRIMARY KEY(exercise_id,definition_version),
 FOREIGN KEY(exercise_id,definition_version) REFERENCES public.published_exercise_definition_versions(exercise_id,definition_version) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX published_exercise_retirement_event_unique ON public.published_exercise_version_retirements((event->>'event_id'));
ALTER TABLE public.published_exercise_version_retirements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.published_exercise_version_retirements FROM PUBLIC,anon,authenticated,service_role,cohort_exercise_version_publisher;
CREATE TRIGGER published_exercise_retirement_immutable BEFORE UPDATE OR DELETE ON public.published_exercise_version_retirements
FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();
CREATE FUNCTION public.retire_published_exercise_version_v1(p_id text,p_version text,p_event jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v public.published_exercise_definition_versions%ROWTYPE; old public.published_exercise_version_retirements%ROWTYPE;
BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_exercise_version_publisher' THEN
   RAISE EXCEPTION 'verified publication producer required' USING ERRCODE='42501'; END IF;
 SELECT * INTO v FROM public.published_exercise_definition_versions WHERE exercise_id=p_id AND definition_version=p_version FOR UPDATE;
 IF NOT FOUND OR NOT coalesce(public.cohort_running_5k_payload_is_valid(p_event,ARRAY['issuer','event_id','publication_event_id','source_reference','retired_at']),false)
   OR p_event->>'issuer' IS DISTINCT FROM 'founder_exercise_publication_v1'
   OR p_event->>'publication_event_id' IS DISTINCT FROM v.publication->>'event_id'
   OR jsonb_typeof(p_event->'event_id') IS DISTINCT FROM 'string'
   OR jsonb_typeof(p_event->'source_reference') IS DISTINCT FROM 'string'
   OR coalesce(length(btrim(p_event->>'source_reference')),0) NOT BETWEEN 1 AND 1024
   OR coalesce(p_event->>'retired_at','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' THEN
   RAISE EXCEPTION 'unresolved exact version retirement authority' USING ERRCODE='22023'; END IF;
 PERFORM (p_event->>'event_id')::uuid;
 IF (p_event->>'retired_at')::timestamptz < (v.publication->>'published_at')::timestamptz THEN
   RAISE EXCEPTION 'retirement precedes publication' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM public.published_exercise_version_retirements WHERE exercise_id=p_id AND definition_version=p_version;
 IF FOUND THEN
   IF old.event<>p_event THEN RAISE EXCEPTION 'immutable retirement conflict' USING ERRCODE='23505'; END IF;
   RETURN to_jsonb(old);
 END IF;
 INSERT INTO public.published_exercise_version_retirements(exercise_id,definition_version,event) VALUES(p_id,p_version,p_event) RETURNING * INTO old;
 RETURN to_jsonb(old);
END $$;
REVOKE ALL ON FUNCTION public.retire_published_exercise_version_v1(text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.retire_published_exercise_version_v1(text,text,jsonb) TO cohort_exercise_version_publisher;

CREATE FUNCTION public.lookup_published_exercise_version(p_id text,p_version text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT to_jsonb(v)||jsonb_build_object('retirement',(SELECT to_jsonb(r) FROM public.published_exercise_version_retirements r WHERE r.exercise_id=v.exercise_id AND r.definition_version=v.definition_version)) FROM public.published_exercise_definition_versions v
 WHERE v.exercise_id=p_id AND v.definition_version=p_version;
$$;
REVOKE ALL ON FUNCTION public.lookup_published_exercise_version(text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.lookup_published_exercise_version(text,text) TO service_role;
COMMENT ON TABLE public.published_exercise_definition_versions IS
 'Exact published canonical versions retained only from the authorised publication producer. No inferred history. Publication approval kinds are explicit external authority, never exercise-name/modality inference. No usable producer membership is installed; a creator ADMIN-only link may exist.';

CREATE TABLE public.hyrox_prescription_dependencies (
  kind text PRIMARY KEY CHECK(kind IN ('runningIntervals','dedicatedRowIntervals','backSquat')),
  metric text NOT NULL UNIQUE,
  rule_document jsonb NOT NULL,
  benchmark_document jsonb NOT NULL
);
ALTER TABLE public.hyrox_prescription_dependencies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hyrox_prescription_dependencies FROM PUBLIC,anon,authenticated,service_role,cohort_exercise_version_publisher;
CREATE TRIGGER hyrox_dependency_immutable BEFORE UPDATE OR DELETE ON public.hyrox_prescription_dependencies
FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();
INSERT INTO public.hyrox_prescription_dependencies(kind,metric,rule_document,benchmark_document) VALUES ('runningIntervals','run10km',$doc${"approved_brief_sha256":"5ae2ebcc020883ce2f496b457296d349ee1793c513818501d616238341d32056","approved_rule":"hyrox-base-personalisation-v1","formula":"10km_ms/10 * pace_multiplier; 4-5min:100/100..105/100; 6-7min:102/100..107/100; 10min:103/100..108/100","id":"hyrox-base-runningIntervals","input_unit":"milliseconds","output_unit":"millisecondsPerKilometre","version":1,"weeks":[{"recovery_seconds":120,"repetitions":4,"week":1,"work_seconds":240},{"recovery_seconds":120,"repetitions":5,"week":2,"work_seconds":240},{"recovery_seconds":120,"repetitions":4,"week":3,"work_seconds":360},{"recovery_seconds":120,"repetitions":4,"week":4,"work_seconds":240},{"recovery_seconds":120,"repetitions":5,"week":5,"work_seconds":300},{"recovery_seconds":120,"repetitions":4,"week":6,"work_seconds":420},{"recovery_seconds":120,"repetitions":3,"week":7,"work_seconds":600},{"recovery_seconds":120,"repetitions":4,"week":8,"work_seconds":300}]}$doc$::jsonb,$doc${"freshness":"none","id":"hyrox-base-benchmark-run10km","metric":"run10km","source_policy":"declared known or recorded result; no test attestation; explicit programme consent required","test_date_required":true,"test_meaning":"10 km run elapsed completion time","unit":"milliseconds","version":1}$doc$::jsonb);
INSERT INTO public.hyrox_prescription_dependencies(kind,metric,rule_document,benchmark_document) VALUES ('dedicatedRowIntervals','row2km',$doc${"approved_brief_sha256":"5ae2ebcc020883ce2f496b457296d349ee1793c513818501d616238341d32056","approved_rule":"hyrox-base-personalisation-v1","formula":"2km_ms/4 + split_offset_ms; 2min:+10000..15000; 3min:+12000..18000; W4:+18000..23000; W8:+15000..20000; dedicated only","id":"hyrox-base-dedicatedRowIntervals","input_unit":"milliseconds","output_unit":"millisecondsPer500Metres","version":1,"weeks":[{"recovery_seconds":90,"repetitions":6,"week":1,"work_seconds":120},{"recovery_seconds":90,"repetitions":7,"week":2,"work_seconds":120},{"recovery_seconds":90,"repetitions":5,"week":3,"work_seconds":180},{"recovery_seconds":90,"repetitions":4,"week":4,"work_seconds":120},{"recovery_seconds":75,"repetitions":6,"week":5,"work_seconds":120},{"recovery_seconds":75,"repetitions":7,"week":6,"work_seconds":120},{"recovery_seconds":75,"repetitions":5,"week":7,"work_seconds":180},{"recovery_seconds":90,"repetitions":4,"week":8,"work_seconds":120}]}$doc$::jsonb,$doc${"freshness":"none","id":"hyrox-base-benchmark-row2km","metric":"row2km","source_policy":"declared known or recorded result; no test attestation; explicit programme consent required","test_date_required":true,"test_meaning":"2 km row elapsed completion time","unit":"milliseconds","version":1}$doc$::jsonb);
INSERT INTO public.hyrox_prescription_dependencies(kind,metric,rule_document,benchmark_document) VALUES ('backSquat','backSquat5rm',$doc${"approved_brief_sha256":"5ae2ebcc020883ce2f496b457296d349ee1793c513818501d616238341d32056","approved_rule":"hyrox-base-personalisation-v1","formula":"5rm_micrograms * authored_basis_points / 10000; nearest configured total gram increment; ties down; RIR governs adjustments","id":"hyrox-base-backSquat","input_unit":"microgramsTotalExternalLoad","output_unit":"gramsTotalExternalLoad","version":1,"weeks":[{"five_rm_basis_points":8000,"reps":8,"rir":"3","sets":3,"week":1},{"five_rm_basis_points":8250,"reps":8,"rir":"2–3","sets":3,"week":2},{"five_rm_basis_points":8750,"reps":6,"rir":"2","sets":4,"week":3},{"five_rm_basis_points":7000,"reps":6,"rir":"4","sets":2,"week":4},{"five_rm_basis_points":8750,"reps":6,"rir":"3","sets":4,"week":5},{"five_rm_basis_points":9000,"reps":5,"rir":"2–3","sets":4,"week":6},{"five_rm_basis_points":9500,"reps":4,"rir":"2","sets":4,"week":7},{"five_rm_basis_points":7500,"reps":5,"rir":"3–4","sets":2,"week":8}]}$doc$::jsonb,$doc${"freshness":"none","id":"hyrox-base-benchmark-backSquat5rm","metric":"backSquat5rm","source_policy":"declared known or recorded result; no test attestation; explicit programme consent required","test_date_required":true,"test_meaning":"back squat 5RM total external load","unit":"microgramsTotalExternalLoad","version":1}$doc$::jsonb);

COMMIT;
