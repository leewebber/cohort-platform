-- LOCAL REHEARSAL ONLY, after all 27 fixture events and 48 exact source rows.
\set ON_ERROR_STOP on
DO $$ DECLARE p jsonb;r jsonb;first_source jsonb;changed jsonb;BEGIN
 SELECT document INTO p FROM public.local_hyrox_ops_data WHERE key='payload';
 SELECT document#>'{sources,0,source}' INTO first_source FROM public.local_hyrox_ops_data WHERE key='prepared';
 PERFORM public.local_hyrox_assert((SELECT count(*) FROM public.performance_protocols WHERE protocol_id LIKE 'LOCAL-HYROX-%')=48,'48 source revisions');
 PERFORM public.local_hyrox_register_source(first_source);
 BEGIN
   PERFORM public.local_hyrox_register_source(jsonb_set(first_source,'{blocks,0,content}','"CONFLICT"'));
   RAISE EXCEPTION 'source conflict accepted';
 EXCEPTION WHEN raise_exception THEN
   IF SQLERRM<>'local_source_exact_conflict' THEN RAISE;END IF;
 END;
 PERFORM public.local_hyrox_assert(public.cohort_v3_session_source(first_source-'blocks')=first_source,'source retry/conflict exact');
 PERFORM set_config('role','authenticated',true);
 BEGIN PERFORM public.retain_published_exercise_event_v1('{}','{}',NULL);RAISE EXCEPTION 'athlete retained exercise';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.local_hyrox_register_source(first_source);RAISE EXCEPTION 'athlete registered source';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.publish_private_exact_programme_version_v3(p);RAISE EXCEPTION 'athlete published programme';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('role','service_role',true);
 BEGIN PERFORM public.retain_published_exercise_event_v1('{}','{}',NULL);RAISE EXCEPTION 'service retained exercise';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('role','none',true);
END $$;
BEGIN;
CREATE FUNCTION public.local_hyrox_fail_artifact() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'injected_local_artifact_failure';END $$;
CREATE TRIGGER local_hyrox_fail_artifact BEFORE INSERT ON public.programme_v3_publication_artifacts FOR EACH ROW EXECUTE FUNCTION public.local_hyrox_fail_artifact();
DO $$ DECLARE p jsonb;r jsonb;BEGIN
 SELECT document INTO p FROM public.local_hyrox_ops_data WHERE key='payload';
 PERFORM set_config('role','service_role',true);r:=public.publish_private_exact_programme_version_v3(p);PERFORM set_config('role','none',true);
 PERFORM public.local_hyrox_assert(r->>'status'='validation_failure','injected publication fails');
 PERFORM public.local_hyrox_assert(NOT EXISTS(SELECT 1 FROM public.programme_versions WHERE id='bc310000-0000-4000-8000-000000000040'),'failed publication rolls version back');
 PERFORM public.local_hyrox_assert(NOT EXISTS(SELECT 1 FROM public.cohort_v3_publication_claims),'failed publication rolls claim back');
 PERFORM public.local_hyrox_assert((SELECT count(*) FROM public.performance_protocols WHERE protocol_id LIKE 'LOCAL-HYROX-%')=48,'prior source stage remains committed');
END $$;
ROLLBACK;
DO $$ DECLARE p jsonb;r jsonb;BEGIN
 SELECT document INTO p FROM public.local_hyrox_ops_data WHERE key='payload';
 PERFORM set_config('role','service_role',true);r:=public.publish_private_exact_programme_version_v3(p);PERFORM set_config('role','none',true);
 PERFORM public.local_hyrox_assert(r->>'status'='published','48-source canonical programme admitted');
 PERFORM set_config('role','service_role',true);r:=public.publish_private_exact_programme_version_v3(p);PERFORM set_config('role','none',true);
 PERFORM public.local_hyrox_assert(r->>'status'='already_published','programme exact retry');
 PERFORM set_config('role','service_role',true);r:=public.publish_private_exact_programme_version_v3(p||'{"owner_id":"bc310000-0000-4000-8000-000000000007"}');PERFORM set_config('role','none',true);
 PERFORM public.local_hyrox_assert(r->>'status'='validation_failure','changed owner refuses');
 PERFORM public.local_hyrox_assert((SELECT jsonb_array_length(physical_seal->'sessions') FROM public.programme_v3_publication_artifacts WHERE programme_version_id='bc310000-0000-4000-8000-000000000040')=48,'all 48 sealed');
END $$;
DO $$ DECLARE actor text;r jsonb;BEGIN
 FOREACH actor IN ARRAY ARRAY['bc310000-0000-4000-8000-000000000006','bc310000-0000-4000-8000-000000000007'] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor,true);PERFORM set_config('role','authenticated',true);
  r:=public.enrol_athlete_in_private_programme_version('bc310000-0000-4000-8000-000000000040','Asia/Makassar',(now() AT TIME ZONE 'Asia/Makassar')::date-56,false);
  PERFORM set_config('role','none',true);
  PERFORM public.local_hyrox_assert(r->>'status' IN ('enrolled','materialised','enrolled_materialised'),'synthetic-only enrol');
 END LOOP;
END $$;
-- Build synthetic historical fixtures before any occurrence has started. The
-- private enrol materialiser currently resets even an explicit date to today.
-- This administrative fixture is not proof that backdated enrolment works.
DO $$ DECLARE a record;r jsonb;BEGIN
 FOR a IN SELECT id,athlete_id FROM public.programme_assignments WHERE athlete_id IN
 ('bc310000-0000-4000-8000-000000000006','bc310000-0000-4000-8000-000000000007') LOOP
  PERFORM public.local_hyrox_assert(NOT EXISTS(SELECT 1 FROM public.programme_slot_outcomes WHERE assignment_id=a.id),'only untouched synthetic assignment aged');
  DELETE FROM public.programme_schedule_projections WHERE assignment_id=a.id;
  PERFORM set_config('cohort.allow_materialisation_write','on',true);
  UPDATE public.programme_assignments SET started_at=(now() AT TIME ZONE 'Asia/Makassar')::date-56 WHERE id=a.id;
  PERFORM set_config('request.jwt.claim.sub',a.athlete_id::text,true);
  PERFORM set_config('role','authenticated',true);
  r:=public.ensure_programme_schedule_projection(a.id);
  PERFORM set_config('role','none',true);
  PERFORM public.local_hyrox_assert(r->>'status'='initialised','synthetic past calendar initialized');
 END LOOP;
END $$;
SELECT 'LOCAL_HYROX_PUBLICATION_CONFLICT_ROLLBACK_ROLES=PASS';
