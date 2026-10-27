BEGIN;
-- Representative sustained 5K evidence is not silently reclassified as the
-- legacy B2 completed-test evidence. Manual threshold remains explicit entry.
CREATE TABLE public.athlete_running_quality_inputs (
 athlete_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
 revision uuid NOT NULL DEFAULT gen_random_uuid(), confirmed_at timestamptz NOT NULL,
 five_k_seconds integer CHECK(five_k_seconds BETWEEN 1 AND 86400), five_k_date date,
 five_k_timezone text, sustained boolean, five_k_withdrawn boolean NOT NULL DEFAULT true,
 manual_seconds_per_km integer CHECK(manual_seconds_per_km BETWEEN 1 AND 86400),
 manual_origin text CHECK(manual_origin IN ('manual_entry','garmin_read_manually')),
 manual_withdrawn boolean NOT NULL DEFAULT true,
 CHECK(five_k_withdrawn OR (five_k_seconds IS NOT NULL AND five_k_date IS NOT NULL AND five_k_timezone IS NOT NULL AND sustained IS TRUE)),
 CHECK(manual_withdrawn OR (manual_seconds_per_km IS NOT NULL AND manual_origin IS NOT NULL))
);
ALTER TABLE public.athlete_running_quality_inputs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.athlete_running_quality_inputs FROM PUBLIC,anon,authenticated,service_role;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher') THEN REVOKE ALL ON public.athlete_running_quality_inputs FROM cohort_exercise_version_publisher; END IF; END $$;
GRANT SELECT ON public.athlete_running_quality_inputs TO authenticated;
CREATE POLICY quality_input_owner ON public.athlete_running_quality_inputs FOR SELECT TO authenticated USING(athlete_id=(SELECT auth.uid()) AND public.cohort_auth_is_athlete());

CREATE FUNCTION public.confirm_running_quality_input(p_expected_athlete_id uuid,p_input_kind text,p_seconds integer,p_result_date date,p_sustained boolean,p_withdraw boolean DEFAULT false,p_manual_origin text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); tz text; row public.athlete_running_quality_inputs%ROWTYPE;
BEGIN
 IF actor IS NULL OR NOT coalesce(public.cohort_auth_is_athlete(),false) OR actor IS DISTINCT FROM p_expected_athlete_id THEN RAISE EXCEPTION 'quality_owner_mismatch'; END IF;
 -- Same actor lock as confirmed Zone 2/start: review acceptance cannot race input replacement.
 PERFORM pg_advisory_xact_lock(84202701,hashtext(actor::text));
 IF p_withdraw IS NULL OR p_input_kind IS NULL OR p_input_kind NOT IN ('five_k','manual_threshold') THEN RAISE EXCEPTION 'invalid_quality_input_kind'; END IF;
 SELECT timezone INTO tz FROM public.athlete_training_setup WHERE athlete_id=actor AND completed_at IS NOT NULL;
 IF tz IS NULL OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=tz) THEN RAISE EXCEPTION 'confirmed_training_timezone_required'; END IF;
 IF NOT p_withdraw THEN
   IF p_seconds IS NULL OR p_seconds NOT BETWEEN 1 AND 86400 THEN RAISE EXCEPTION 'invalid_quality_seconds'; END IF;
   IF p_input_kind='five_k' AND (p_result_date IS NULL OR p_result_date>(transaction_timestamp() AT TIME ZONE tz)::date OR p_sustained IS DISTINCT FROM true OR p_manual_origin IS NOT NULL) THEN RAISE EXCEPTION 'dated_representative_sustained_5k_required'; END IF;
   IF p_input_kind='manual_threshold' AND (p_manual_origin IS NULL OR p_manual_origin NOT IN ('manual_entry','garmin_read_manually') OR p_result_date IS NOT NULL OR p_sustained IS NOT NULL) THEN RAISE EXCEPTION 'invalid_manual_threshold_input'; END IF;
 ELSE
   IF p_seconds IS NOT NULL OR p_result_date IS NOT NULL OR p_sustained IS NOT NULL OR p_manual_origin IS NOT NULL THEN RAISE EXCEPTION 'withdrawal_requires_empty_input'; END IF;
 END IF;
 INSERT INTO public.athlete_running_quality_inputs(athlete_id,confirmed_at) VALUES(actor,transaction_timestamp()) ON CONFLICT DO NOTHING;
 IF p_input_kind='five_k' THEN
   UPDATE public.athlete_running_quality_inputs SET revision=gen_random_uuid(),confirmed_at=transaction_timestamp(),five_k_seconds=p_seconds,five_k_date=p_result_date,five_k_timezone=CASE WHEN p_withdraw THEN NULL ELSE tz END,sustained=p_sustained,five_k_withdrawn=p_withdraw WHERE athlete_id=actor RETURNING * INTO row;
 ELSE
   UPDATE public.athlete_running_quality_inputs SET revision=gen_random_uuid(),confirmed_at=transaction_timestamp(),manual_seconds_per_km=p_seconds,manual_origin=p_manual_origin,manual_withdrawn=p_withdraw WHERE athlete_id=actor RETURNING * INTO row;
 END IF;
 RETURN to_jsonb(row);
END $$;

-- Versioned positive-second arithmetic. numeric power avoids binary display
-- rounding; floor(x+0.5) is nearest-second, exact halves toward +infinity.
CREATE FUNCTION public.cohort_alpha_quality_window_v1(p_seconds integer,p_category text,p_source text) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE p5 numeric:=p_seconds::numeric/5; estimated numeric:=p_seconds::numeric*power(2::numeric,1.06::numeric); p10 numeric:=estimated/10; lo numeric; hi numeric; l integer; h integer;
BEGIN
 IF p_seconds IS NULL OR p_seconds NOT BETWEEN 1 AND 86400 OR p_category IS NULL OR p_category NOT IN ('threshold','10k_specific','short_5k') OR p_source IS NULL OR p_source NOT IN ('five_k','manual_threshold') THEN RAISE EXCEPTION 'invalid_alpha_pace_input'; END IF;
 IF p_source='manual_threshold' THEN
   IF p_category<>'threshold' THEN RAISE EXCEPTION 'manual_threshold_only_for_threshold'; END IF;
   lo:=p_seconds::numeric*0.98;hi:=p_seconds::numeric*1.02;
 ELSIF p_category='threshold' THEN lo:=p10*1.02;hi:=p10*1.06;
 ELSIF p_category='10k_specific' THEN lo:=p10*0.99;hi:=p10*1.02;
 ELSE lo:=p5;hi:=p5*1.03; END IF;
 l:=floor(lo+0.5);h:=floor(hi+0.5);
 IF l<1 OR l>=h THEN RAISE EXCEPTION 'unsupported_rounded_pace_window'; END IF;
 RETURN jsonb_build_object('unit','seconds_per_kilometre','lower',l,'upper',h);
END $$;

CREATE FUNCTION public.cohort_alpha_5k_date_eligible_v1(p_date date,p_input_timezone text,p_assignment_timezone text,p_now timestamptz) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF p_date IS NULL OR p_now IS NULL OR p_input_timezone IS DISTINCT FROM p_assignment_timezone OR p_assignment_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_assignment_timezone) THEN RETURN false; END IF;
 RETURN (p_now AT TIME ZONE p_assignment_timezone)::date-p_date BETWEEN 0 AND 56;
END $$;

CREATE FUNCTION public.review_running_quality_targets(p_occurrence_id uuid,p_target_source text DEFAULT 'five_k') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); o public.programme_schedule_occurrences%ROWTYPE; a public.programme_assignments%ROWTYPE;
 q public.athlete_running_quality_inputs%ROWTYPE; bodies jsonb; base jsonb; packet jsonb; b jsonb; n jsonb; st jsonb; t jsonb;
 targets jsonb:='[]'; quality jsonb; resolved_target jsonb; today date; reason text; fallback_ok boolean:=true; found_quality boolean:=false;
 rule text; age integer;
BEGIN
 IF actor IS NULL OR NOT coalesce(public.cohort_auth_is_athlete(),false) THEN RAISE EXCEPTION 'athlete_authentication_required'; END IF;
 SELECT * INTO o FROM public.programme_schedule_occurrences WHERE id=p_occurrence_id;
 SELECT * INTO a FROM public.programme_assignments WHERE id=o.assignment_id AND athlete_id=actor;
 IF a.id IS NULL THEN RAISE EXCEPTION 'unavailable_occurrence'; END IF;
 -- Existing immutable snapshot always wins over current input/source requests.
 base:=public.review_running_zone2_targets(p_occurrence_id);
 IF base->>'status'='frozen' THEN RETURN base; END IF;
 SELECT jsonb_agg(jsonb_build_object('block_id',b.block_id,'workout',b.timer_config->'running_workout') ORDER BY b.position,b.block_id) INTO bodies FROM public.session_blocks b WHERE b.session_id=o.protocol_id AND b.timer_config ? 'running_workout';
 IF bodies IS NULL OR NOT jsonb_path_exists(bodies,'$[*].workout.steps.**.target ? (@.kind == "alpha_quality_pace_v1")') THEN RETURN base; END IF;
 IF a.schedule_mode<>'fixed_schedule' OR NOT EXISTS(SELECT 1 FROM public.programme_versions v WHERE v.id=a.programme_version_id AND v.package_schema_version IN (1,2)) THEN RAISE EXCEPTION 'unsupported_quality_source'; END IF;
 IF p_target_source IS NULL OR p_target_source NOT IN ('five_k','manual_threshold','authored_rpe') THEN RAISE EXCEPTION 'invalid_quality_source_selection'; END IF;
 IF base->>'status'='input_required' THEN RETURN base; END IF;
 SELECT * INTO q FROM public.athlete_running_quality_inputs WHERE athlete_id=actor;
 IF NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=a.timezone) THEN RAISE EXCEPTION 'invalid_assignment_timezone'; END IF;
 today:=(transaction_timestamp() AT TIME ZONE a.timezone)::date;
 IF p_target_source='five_k' THEN
   rule:='alpha_5k_8w_riegel_1_06_v1';
   IF q.athlete_id IS NULL OR q.five_k_withdrawn THEN reason:=CASE WHEN q.athlete_id IS NULL THEN 'missing_5k' ELSE 'withdrawn_5k' END;
   ELSIF q.sustained IS DISTINCT FROM true OR q.five_k_date IS NULL OR q.five_k_seconds IS NULL THEN reason:='invalid_5k';
   ELSIF q.five_k_timezone IS DISTINCT FROM a.timezone THEN reason:='benchmark_timezone_mismatch';
   ELSIF q.five_k_date>today THEN reason:='future_5k';
   ELSIF NOT public.cohort_alpha_5k_date_eligible_v1(q.five_k_date,q.five_k_timezone,a.timezone,transaction_timestamp()) THEN reason:='stale_5k'; END IF;
 ELSIF p_target_source='manual_threshold' THEN
   rule:='alpha_manual_threshold_pm2_v1';
   IF q.athlete_id IS NULL OR q.manual_withdrawn OR q.manual_seconds_per_km IS NULL THEN reason:='missing_or_withdrawn_manual_threshold'; END IF;
 ELSE rule:='authored_rpe_v1'; END IF;
 FOR b IN SELECT value FROM jsonb_array_elements(bodies) LOOP
   FOR n IN SELECT value FROM jsonb_array_elements(b#>'{workout,steps}') LOOP
     FOR st IN SELECT value FROM jsonb_array_elements(CASE WHEN n->>'kind'='repeat' THEN n->'steps' ELSE jsonb_build_array(n) END) LOOP
       t:=st->'target'; IF t->>'kind'<>'alpha_quality_pace_v1' THEN CONTINUE; END IF;
       found_quality:=true; IF st->>'role' IS DISTINCT FROM 'work' THEN RAISE EXCEPTION 'invalid_quality_step_role'; END IF;
       IF t->>'category' IS NULL OR t->>'category' NOT IN ('threshold','10k_specific','short_5k') THEN RAISE EXCEPTION 'invalid_quality_category'; END IF;
       IF t->'fallback_rpe' IS NULL OR jsonb_typeof(t->'fallback_rpe')<>'number' OR t->>'fallback_rpe' !~ '^[0-9]+$' OR (t->>'fallback_rpe')::int NOT BETWEEN 1 AND 10 THEN fallback_ok:=false; END IF;
       IF p_target_source='manual_threshold' AND t->>'category'<>'threshold' THEN reason:='manual_threshold_only_for_threshold'; END IF;
       IF reason IS NOT NULL THEN CONTINUE; END IF;
       IF p_target_source='authored_rpe' THEN
         IF NOT fallback_ok THEN RAISE EXCEPTION 'authored_rpe_fallback_unavailable'; END IF;
         resolved_target:=jsonb_build_object('unit','rpe_cr10','value',t->'fallback_rpe');
       ELSE
         resolved_target:=public.cohort_alpha_quality_window_v1(CASE WHEN p_target_source='five_k' THEN q.five_k_seconds ELSE q.manual_seconds_per_km END,t->>'category',p_target_source);
       END IF;
       targets:=targets||jsonb_build_array(jsonb_build_object('block_id',b->>'block_id','step_id',st->>'step_id','category',t->>'category','source',p_target_source,'rule_id',rule,'target',resolved_target));
     END LOOP;
   END LOOP;
 END LOOP;
 IF NOT found_quality THEN RAISE EXCEPTION 'quality_scope_missing'; END IF;
 IF reason IS NOT NULL THEN RETURN jsonb_build_object('status','input_required','reason',reason,'authored_rpe_available',fallback_ok,'input',CASE WHEN q.athlete_id IS NULL THEN NULL ELSE to_jsonb(q) END,'evaluation_local_date',today,'evaluation_timezone',a.timezone); END IF;
 packet:=CASE WHEN base->>'status'='review_required' THEN base->'document' ELSE jsonb_build_object('schema_version',1,'athlete_id',actor,'occurrence_id',o.id,'assignment_id',a.id,'programme_version_id',a.programme_version_id,'package_hash',a.materialised_package_content_hash,'protocol_id',o.protocol_id,'blocks',bodies) END;
 quality:=jsonb_build_object('rule_id',rule,'selected_source',p_target_source,'input',CASE WHEN p_target_source='authored_rpe' THEN NULL ELSE to_jsonb(q) END,
 'evaluation_local_date',today,'evaluation_timezone',a.timezone,'rounding','nearest_second_half_up','freshness_days',CASE WHEN p_target_source='five_k' THEN 56 END,'cutoff_inclusive',CASE WHEN p_target_source='five_k' THEN true END,
 'formula',CASE p_target_source WHEN 'five_k' THEN 'P5=T5/5; estimatedT10=T5*2^1.06; P10=estimatedT10/10' WHEN 'manual_threshold' THEN 'lower=manualPace*0.98; upper=manualPace*1.02' ELSE 'exact_authored_rpe' END,'bands',jsonb_build_object('threshold',jsonb_build_array(1.02,1.06),'10k_specific',jsonb_build_array(0.99,1.02),'short_5k',jsonb_build_array(1.00,1.03),'manual_threshold',jsonb_build_array(0.98,1.02)));
 IF p_target_source='five_k' THEN quality:=quality||jsonb_build_object('p5_seconds_per_km',(q.five_k_seconds::numeric/5)::text,'estimated_10k_seconds',(q.five_k_seconds::numeric*power(2::numeric,1.06::numeric))::text,'p10_seconds_per_km',(q.five_k_seconds::numeric*power(2::numeric,1.06::numeric)/10)::text); END IF;
 packet:=packet||jsonb_build_object('quality',quality,'quality_targets',targets);
 RETURN jsonb_build_object('status','review_required','document',packet,'review_hash',encode(extensions.digest(convert_to(packet::text,'UTF8'),'sha256'),'hex'));
END $$;

CREATE FUNCTION public.cohort_fixed_with_running_targets(p_occurrence_id uuid,p_now timestamptz,p_review_hash text,p_target_source text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); review jsonb; response jsonb; packet jsonb; old public.programme_occurrence_zone2_targets%ROWTYPE;
BEGIN
 -- Delegate unrelated/invalid starts unchanged, preserving the old status and
 -- authorization vocabulary. Only an owned opted-in source enters admission.
 IF NOT coalesce(public.cohort_auth_is_athlete(),false) OR NOT EXISTS(
   SELECT 1 FROM public.programme_schedule_occurrences o JOIN public.programme_assignments a ON a.id=o.assignment_id
   WHERE o.id=p_occurrence_id AND a.athlete_id=actor AND (
     EXISTS(SELECT 1 FROM public.programme_occurrence_zone2_targets f WHERE f.occurrence_id=o.id AND f.athlete_id=actor) OR
     EXISTS(SELECT 1 FROM public.session_blocks b WHERE b.session_id=o.protocol_id AND jsonb_path_exists(b.timer_config,'$.running_workout.steps.**.target ? (@.kind == "alpha_quality_pace_v1" || (@.kind == "heart_rate_zone_ref" && @.zone_ref == "athlete_confirmed_zone_2"))')))) THEN
   RETURN public.cohort_fixed_before_zone2(p_occurrence_id,p_now);
 END IF;
 -- One lock order: athlete input -> occurrence -> existing assignment locks.
 PERFORM pg_advisory_xact_lock(84202701,hashtext(actor::text));
 PERFORM pg_advisory_xact_lock(84202702,hashtext(p_occurrence_id::text));
 review:=public.review_running_quality_targets(p_occurrence_id,p_target_source);
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

CREATE OR REPLACE FUNCTION public.cohort_fixed_with_zone2(p_occurrence_id uuid,p_now timestamptz,p_review_hash text) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$ SELECT public.cohort_fixed_with_running_targets(p_occurrence_id,p_now,p_review_hash,'five_k'); $$;
CREATE FUNCTION public.create_or_resume_fixed_programme_occurrence_session(p_occurrence_id uuid,p_target_review_hash text,p_running_target_source text) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$ SELECT public.cohort_fixed_with_running_targets(p_occurrence_id,transaction_timestamp(),p_target_review_hash,p_running_target_source); $$;
-- Preserve the generic function OID/ACL while closing the same bypass for the
-- versioned quality reference. Fail the migration if the expected body drifts.
DO $$ DECLARE definition text; previous text:='@.kind == "heart_rate_zone_ref" && @.zone_ref == "athlete_confirmed_zone_2"'; BEGIN
 definition:=pg_get_functiondef('public.create_or_resume_programme_training_session(jsonb)'::regprocedure);
 IF strpos(definition,previous)=0 THEN RAISE EXCEPTION 'unexpected_generic_start_definition'; END IF;
 EXECUTE replace(definition,previous,'@.kind == "alpha_quality_pace_v1" || (@.kind == "heart_rate_zone_ref" && @.zone_ref == "athlete_confirmed_zone_2")');
END $$;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('confirm_running_quality_input','cohort_alpha_5k_date_eligible_v1','cohort_alpha_quality_window_v1','review_running_quality_targets','cohort_fixed_with_running_targets') LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.sig);
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher') THEN EXECUTE format('REVOKE ALL ON FUNCTION %s FROM cohort_exercise_version_publisher',f.sig); END IF;
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.create_or_resume_fixed_programme_occurrence_session(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher') THEN REVOKE ALL ON FUNCTION public.create_or_resume_fixed_programme_occurrence_session(uuid,text,text) FROM cohort_exercise_version_publisher; END IF; END $$;
GRANT EXECUTE ON FUNCTION public.confirm_running_quality_input(uuid,text,integer,date,boolean,boolean,text),public.review_running_quality_targets(uuid,text),public.create_or_resume_fixed_programme_occurrence_session(uuid,text,text) TO authenticated;
COMMIT;
