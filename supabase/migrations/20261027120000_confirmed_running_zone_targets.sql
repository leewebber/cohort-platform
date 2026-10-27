BEGIN;
-- Explicit athlete input, never an age/formula-derived physiological zone.
CREATE TABLE public.athlete_running_zone2_inputs (
 athlete_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
 revision uuid NOT NULL DEFAULT gen_random_uuid(),
 lower_bpm integer, upper_bpm integer, confirmed_at timestamptz NOT NULL,
 withdrawn boolean NOT NULL,
 CHECK ((withdrawn AND lower_bpm IS NULL AND upper_bpm IS NULL) OR
        (NOT withdrawn AND lower_bpm IS NOT NULL AND upper_bpm IS NOT NULL AND lower_bpm BETWEEN 1 AND 250 AND upper_bpm BETWEEN 1 AND 250 AND lower_bpm<upper_bpm))
);
CREATE TABLE public.programme_occurrence_zone2_targets (
 occurrence_id uuid PRIMARY KEY REFERENCES public.programme_schedule_occurrences(id) ON DELETE RESTRICT,
 athlete_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 training_session_id bigint NOT NULL UNIQUE REFERENCES public.training_sessions(id) ON DELETE RESTRICT,
 snapshot jsonb NOT NULL
);
ALTER TABLE public.athlete_running_zone2_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programme_occurrence_zone2_targets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.athlete_running_zone2_inputs,public.programme_occurrence_zone2_targets FROM PUBLIC,anon,authenticated,service_role;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher') THEN
 REVOKE ALL ON public.athlete_running_zone2_inputs,public.programme_occurrence_zone2_targets FROM cohort_exercise_version_publisher;
 END IF; END $$;
GRANT SELECT ON public.athlete_running_zone2_inputs,public.programme_occurrence_zone2_targets TO authenticated;
CREATE POLICY zone2_input_owner ON public.athlete_running_zone2_inputs FOR SELECT TO authenticated USING(athlete_id=(SELECT auth.uid()) AND public.cohort_auth_is_athlete());
CREATE POLICY zone2_snapshot_owner ON public.programme_occurrence_zone2_targets FOR SELECT TO authenticated USING(athlete_id=(SELECT auth.uid()) AND public.cohort_auth_is_athlete());
CREATE TRIGGER zone2_snapshot_immutable BEFORE UPDATE OR DELETE ON public.programme_occurrence_zone2_targets FOR EACH ROW EXECUTE FUNCTION public.cohort_reject_running_target_snapshot_mutation();

CREATE FUNCTION public.confirm_running_zone2(p_expected_athlete_id uuid,p_lower_bpm integer,p_upper_bpm integer,p_withdraw boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); row public.athlete_running_zone2_inputs%ROWTYPE;
BEGIN
 IF actor IS NULL OR NOT coalesce(public.cohort_auth_is_athlete(),false) OR actor IS DISTINCT FROM p_expected_athlete_id THEN RAISE EXCEPTION 'zone2_owner_mismatch'; END IF;
 PERFORM pg_advisory_xact_lock(84202701,hashtext(actor::text));
 IF p_withdraw IS NULL OR (p_withdraw AND (p_lower_bpm IS NOT NULL OR p_upper_bpm IS NOT NULL)) OR
   (NOT p_withdraw AND (p_lower_bpm IS NULL OR p_upper_bpm IS NULL OR p_lower_bpm<1 OR p_upper_bpm>250 OR p_lower_bpm>=p_upper_bpm)) THEN
   RAISE EXCEPTION 'invalid_zone2_bpm_range'; END IF;
 INSERT INTO public.athlete_running_zone2_inputs VALUES(actor,gen_random_uuid(),p_lower_bpm,p_upper_bpm,transaction_timestamp(),p_withdraw)
 ON CONFLICT(athlete_id) DO UPDATE SET revision=excluded.revision,lower_bpm=excluded.lower_bpm,upper_bpm=excluded.upper_bpm,confirmed_at=excluded.confirmed_at,withdrawn=excluded.withdrawn
 RETURNING * INTO row;
 RETURN to_jsonb(row);
END $$;

-- Only this explicit source reference opts into confirmed Zone 2 admission.
-- Review includes exact source bytes and input revision; time alone never expires
-- a confirmed zone. Supersession/withdrawal invalidates an unstarted review.
CREATE FUNCTION public.review_running_zone2_targets(p_occurrence_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); o public.programme_schedule_occurrences%ROWTYPE;
 a public.programme_assignments%ROWTYPE; z public.athlete_running_zone2_inputs%ROWTYPE;
 bodies jsonb; packet jsonb; frozen public.programme_occurrence_zone2_targets%ROWTYPE;
BEGIN
 IF actor IS NULL OR NOT coalesce(public.cohort_auth_is_athlete(),false) THEN RAISE EXCEPTION 'athlete_authentication_required'; END IF;
 SELECT * INTO o FROM public.programme_schedule_occurrences WHERE id=p_occurrence_id;
 SELECT * INTO a FROM public.programme_assignments WHERE id=o.assignment_id AND athlete_id=actor;
 IF a.id IS NULL THEN RAISE EXCEPTION 'unavailable_occurrence'; END IF;
 SELECT * INTO frozen FROM public.programme_occurrence_zone2_targets WHERE occurrence_id=o.id AND athlete_id=actor;
 IF FOUND THEN RETURN jsonb_build_object('status','frozen','snapshot',frozen.snapshot); END IF;
 SELECT jsonb_agg(jsonb_build_object('block_id',b.block_id,'workout',b.timer_config->'running_workout') ORDER BY b.position,b.block_id)
 INTO bodies FROM public.session_blocks b WHERE b.session_id=o.protocol_id AND b.timer_config ? 'running_workout';
 IF bodies IS NULL OR NOT jsonb_path_exists(bodies,'$[*].workout.steps.**.target ? (@.kind == "heart_rate_zone_ref" && @.zone_ref == "athlete_confirmed_zone_2")') THEN
   RETURN jsonb_build_object('status','not_required'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.programme_versions v WHERE v.id=a.programme_version_id AND v.package_schema_version IN (1,2))
   OR a.schedule_mode<>'fixed_schedule' THEN RAISE EXCEPTION 'unsupported_zone2_source'; END IF;
 SELECT * INTO z FROM public.athlete_running_zone2_inputs WHERE athlete_id=actor;
 IF z.athlete_id IS NULL OR z.withdrawn THEN RETURN jsonb_build_object('status','input_required','reason',CASE WHEN z.withdrawn THEN 'withdrawn' ELSE 'missing' END); END IF;
 packet:=jsonb_build_object('schema_version',1,'athlete_id',actor,'occurrence_id',o.id,'assignment_id',a.id,
 'programme_version_id',a.programme_version_id,'package_hash',a.materialised_package_content_hash,'protocol_id',o.protocol_id,
 'zone2',to_jsonb(z),'blocks',bodies);
 RETURN jsonb_build_object('status','review_required','document',packet,'review_hash',encode(extensions.digest(convert_to(packet::text,'UTF8'),'sha256'),'hex'));
END $$;

-- Preserve the established function OID and delegate its entire validation/start
-- transaction. All existing fixed-start callers encounter admission, including
-- recovery/swap entrypoints. Unattached v1/v2 and v3 behavior stays delegated.
DO $$ BEGIN
 EXECUTE replace(pg_get_functiondef('public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamptz)'::regprocedure),
 'FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(', 'FUNCTION public.cohort_fixed_before_zone2(');
END $$;
CREATE FUNCTION public.cohort_fixed_with_zone2(p_occurrence_id uuid,p_now timestamptz,p_review_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); review jsonb; response jsonb; packet jsonb; old public.programme_occurrence_zone2_targets%ROWTYPE;
BEGIN
 -- Delegate unrelated/invalid starts unchanged, preserving the old status and
 -- authorization vocabulary. Only an owned opted-in source enters admission.
 IF NOT coalesce(public.cohort_auth_is_athlete(),false) OR NOT EXISTS(
   SELECT 1 FROM public.programme_schedule_occurrences o JOIN public.programme_assignments a ON a.id=o.assignment_id
   WHERE o.id=p_occurrence_id AND a.athlete_id=actor AND (
     EXISTS(SELECT 1 FROM public.programme_occurrence_zone2_targets f WHERE f.occurrence_id=o.id AND f.athlete_id=actor) OR
     EXISTS(SELECT 1 FROM public.session_blocks b WHERE b.session_id=o.protocol_id AND jsonb_path_exists(b.timer_config,'$.running_workout.steps.**.target ? (@.kind == "heart_rate_zone_ref" && @.zone_ref == "athlete_confirmed_zone_2")')))) THEN
   RETURN public.cohort_fixed_before_zone2(p_occurrence_id,p_now);
 END IF;
 -- One lock order: athlete input -> occurrence -> existing assignment locks.
 PERFORM pg_advisory_xact_lock(84202701,hashtext(actor::text));
 PERFORM pg_advisory_xact_lock(84202702,hashtext(p_occurrence_id::text));
 review:=public.review_running_zone2_targets(p_occurrence_id);
 IF review->>'status'='input_required' THEN RETURN jsonb_build_object('status','refused','code','running_target_review_required','reason',review->>'reason'); END IF;
 IF review->>'status'='review_required' AND (p_review_hash IS NULL OR p_review_hash IS DISTINCT FROM review->>'review_hash') THEN
   RETURN jsonb_build_object('status','refused','code','running_target_review_required','reason','missing_or_stale_review'); END IF;
 -- A pre-admission session cannot be retroactively prescribed. No orphan freeze.
 IF review->>'status'='review_required' AND EXISTS(SELECT 1 FROM public.programme_slot_outcomes s JOIN public.programme_schedule_occurrences o ON o.assignment_id=s.assignment_id AND o.session_slot_id=s.session_slot_id WHERE o.id=p_occurrence_id AND s.training_session_id IS NOT NULL) THEN
   RAISE EXCEPTION 'started_zone2_snapshot_missing'; END IF;
 response:=public.cohort_fixed_before_zone2(p_occurrence_id,p_now);
 IF review->>'status'='frozen' THEN
   SELECT * INTO STRICT old FROM public.programme_occurrence_zone2_targets WHERE occurrence_id=p_occurrence_id AND athlete_id=actor;
   IF response#>>'{training_session,id}' IS NOT NULL AND response#>>'{training_session,id}'<>old.training_session_id::text THEN RAISE EXCEPTION 'zone2_session_link_mismatch'; END IF;
   RETURN response||jsonb_build_object('running_target_admission_snapshot',old.snapshot);
 END IF;
 IF review->>'status'='review_required' AND response->>'status' IN ('created','resumed') THEN
   IF response->>'status'<>'created' OR response#>>'{training_session,athlete_id}'<>actor::text THEN RAISE EXCEPTION 'zone2_start_scope_mismatch'; END IF;
   packet:=review->'document'||jsonb_build_object('review_hash',review->>'review_hash','training_session_id',(response#>>'{training_session,id}')::bigint,'accepted_at',transaction_timestamp());
   INSERT INTO public.programme_occurrence_zone2_targets VALUES(p_occurrence_id,actor,(response#>>'{training_session,id}')::bigint,packet);
   RETURN response||jsonb_build_object('running_target_admission_snapshot',packet);
 END IF;
 RETURN response;
EXCEPTION WHEN raise_exception OR integrity_constraint_violation THEN
 -- Any failure rolls back delegated session creation as well as this snapshot.
 RETURN jsonb_build_object('status','refused','code','running_target_unavailable','reason',SQLERRM);
END $$;
CREATE OR REPLACE FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(p_occurrence_id uuid,p_now timestamptz) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$ SELECT public.cohort_fixed_with_zone2(p_occurrence_id,p_now,NULL); $$;
CREATE FUNCTION public.create_or_resume_fixed_programme_occurrence_session(p_occurrence_id uuid,p_target_review_hash text) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$ SELECT public.cohort_fixed_with_zone2(p_occurrence_id,transaction_timestamp(),p_target_review_hash); $$;

-- Generic non-occurrence start cannot bypass the opted-in fixed-start review.
DO $$ BEGIN
 EXECUTE replace(pg_get_functiondef('public.create_or_resume_programme_training_session(jsonb)'::regprocedure),
 'FUNCTION public.create_or_resume_programme_training_session(', 'FUNCTION public.cohort_generic_before_zone2(');
END $$;
CREATE OR REPLACE FUNCTION public.create_or_resume_programme_training_session(payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.programme_assignments a JOIN public.programme_version_weeks w ON w.version_id=a.programme_version_id
 JOIN public.programme_version_days d ON d.week_id=w.id JOIN public.programme_version_session_slots s ON s.day_id=d.id
 JOIN public.session_blocks b ON b.session_id=s.protocol_id WHERE a.id::text=payload->>'assignment_id' AND a.athlete_id=auth.uid()
 AND jsonb_path_exists(b.timer_config,'$.running_workout.steps.**.target ? (@.kind == "heart_rate_zone_ref" && @.zone_ref == "athlete_confirmed_zone_2")')) THEN
 RETURN jsonb_build_object('status','refused','code','running_target_requires_fixed_occurrence'); END IF;
 RETURN public.cohort_generic_before_zone2(payload);
END $$;

CREATE FUNCTION public.cohort_zone2_record_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f public.programme_occurrence_zone2_targets%ROWTYPE; b jsonb;
BEGIN
 SELECT * INTO f FROM public.programme_occurrence_zone2_targets WHERE training_session_id=NEW.training_session_id;
 IF FOUND THEN
   IF f.athlete_id::text IS DISTINCT FROM NEW.athlete_id OR f.snapshot IS DISTINCT FROM NEW.session_snapshot->'runningTargetAdmissionV1' THEN RAISE EXCEPTION 'frozen_zone2_prescription_required'; END IF;
   FOR b IN SELECT value FROM jsonb_array_elements(f.snapshot->'blocks') LOOP
     IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.session_snapshot->'blocks') x WHERE x->>'sourceBlockId'=b->>'block_id' AND x->'timedRunningWorkoutV1'=b->'workout') THEN RAISE EXCEPTION 'frozen_zone2_source_required'; END IF;
   END LOOP;
 ELSIF NEW.session_snapshot ? 'runningTargetAdmissionV1' THEN RAISE EXCEPTION 'unexpected_zone2_prescription'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_zone2_record BEFORE INSERT OR UPDATE ON public.training_session_records FOR EACH ROW EXECUTE FUNCTION public.cohort_zone2_record_guard();
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('confirm_running_zone2','review_running_zone2_targets','cohort_fixed_before_zone2','cohort_fixed_with_zone2','cohort_generic_before_zone2','cohort_zone2_record_guard','create_or_resume_fixed_programme_occurrence_session','cohort_create_or_resume_fixed_occurrence_at') LOOP
 -- Only revoke newly exposed helpers and the new overload; preserve existing v3 public signatures.
 IF f.sig::text IN ('create_or_resume_fixed_programme_occurrence_session(uuid)','create_or_resume_fixed_programme_occurrence_session(uuid,uuid)','create_or_resume_fixed_programme_occurrence_session(uuid,uuid,jsonb)') THEN CONTINUE; END IF;
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.sig);
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher') THEN
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM cohort_exercise_version_publisher',f.sig); END IF;
 END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION public.confirm_running_zone2(uuid,integer,integer,boolean),public.review_running_zone2_targets(uuid),public.create_or_resume_fixed_programme_occurrence_session(uuid,text) TO authenticated;
COMMIT;
