-- Run only as the disposable local administrative fixture actor.
\set ON_ERROR_STOP on
BEGIN;
DO $$ DECLARE v public.published_exercise_definition_versions%ROWTYPE; changed text; result jsonb; publication jsonb; BEGIN
 SELECT * INTO v FROM public.published_exercise_definition_versions WHERE exercise_id='EX-900900' AND definition_version='7';
 changed:=public.cohort_tracking_canonical_text(v.canonical_text::jsonb||'{"version":"release-A"}'::jsonb);
 PERFORM set_config('role','cohort_exercise_version_publisher',true);
 result:=public.retain_published_exercise_definition_v1(v.canonical_text,v.publication);
 IF result->>'content_digest'<>v.content_digest THEN RAISE EXCEPTION 'exact version retry changed content'; END IF;
 publication:=v.publication||jsonb_build_object('event_id',gen_random_uuid(),'source_reference','synthetic-exact-string-version');
 result:=public.retain_published_exercise_definition_v1(changed,publication);
 PERFORM public.retire_published_exercise_version_v1('EX-900900','release-A',jsonb_build_object('issuer','founder_exercise_publication_v1',
   'event_id',gen_random_uuid(),'publication_event_id',publication->>'event_id','source_reference','synthetic exact retirement','retired_at','2026-10-23T00:01:00Z'));
 IF result->>'definition_version'<>'release-A' THEN RAISE EXCEPTION 'string version was normalised/invented'; END IF;
 BEGIN
   PERFORM public.retain_published_exercise_definition_v1(v.canonical_text||' ',v.publication);
   RAISE EXCEPTION 'noncanonical bytes accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','none',true);
 changed:=public.cohort_tracking_canonical_text(v.canonical_text::jsonb||'{"canonical_name":"forged change"}');
 PERFORM set_config('role','cohort_exercise_version_publisher',true);
 BEGIN
   PERFORM public.retain_published_exercise_definition_v1(changed,v.publication);
   RAISE EXCEPTION 'same-version replacement accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM set_config('role','none',true);
 IF (SELECT content_digest FROM public.published_exercise_definition_versions WHERE exercise_id=v.exercise_id AND definition_version=v.definition_version)<>v.content_digest THEN
   RAISE EXCEPTION 'published version mutated'; END IF;
END $$;
-- Deliberately overgrant in a rollback-only probe: actor check still rejects service.
GRANT EXECUTE ON FUNCTION public.retain_published_exercise_definition_v1(text,jsonb) TO service_role;
DO $$ BEGIN
 PERFORM set_config('role','service_role',true);
 BEGIN PERFORM public.retain_published_exercise_definition_v1('{}','{}');
   RAISE EXCEPTION 'service self-attested publication accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'V3_EXACT_PUBLISHED_VERSION_PROVENANCE_IMMUTABILITY=PASS' AS result;
