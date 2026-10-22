-- Runs after BK fixture; rollback the deliberately unsupported physical version.
-- Test-only postgres trigger bypass creates an otherwise inadmissible v3 pin.
BEGIN;
CREATE FUNCTION pg_temp.v3_assert(ok boolean, description text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'V3_GUARD: %',description; END IF; END $$;

DO $$ DECLARE row public.programme_versions%ROWTYPE; denied boolean := false; BEGIN
  SELECT * INTO row FROM public.programme_versions WHERE id='b2300000-0000-4000-8000-000000000010';
  row.id:=gen_random_uuid(); row.version_number:=999; row.package_schema_version:=3;
  BEGIN INSERT INTO public.programme_versions SELECT row.*;
    EXCEPTION WHEN check_violation OR integrity_constraint_violation THEN denied:=true; END;
  PERFORM pg_temp.v3_assert(denied,'real table refuses unsupported version');
END $$;
ALTER TABLE public.programme_versions DISABLE TRIGGER USER;
UPDATE public.programme_versions SET package_schema_version=3 WHERE id='b2300000-0000-4000-8000-000000000010';
ALTER TABLE public.programme_versions ENABLE TRIGGER USER;
DO $$ DECLARE actor uuid; occurrence uuid; assignment uuid; before_sessions bigint; before_outcomes bigint; r jsonb; BEGIN
  SELECT f.athlete_id,f.occurrence_id,o.assignment_id INTO actor,occurrence,assignment
    FROM public.sprint12_gate_bk_concurrency_fixture f JOIN public.programme_schedule_occurrences o ON o.id=f.occurrence_id
    WHERE fixture_key='concurrency';
  SELECT count(*) INTO before_sessions FROM public.training_sessions;
  SELECT count(*) INTO before_outcomes FROM public.programme_slot_outcomes;
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  PERFORM set_config('role','authenticated',true);
  r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence);
  PERFORM pg_temp.v3_assert(r->>'code'='v3_authoritative_admission_unavailable','fixed start refuses actual v3 version');
  r:=public.create_or_resume_programme_training_session(jsonb_build_object(
    'assignment_id',assignment,'programme_version_id','b2300000-0000-4000-8000-000000000012',
    'materialised_package_content_hash',repeat('a',64),'calculated_prescription','{}'::jsonb));
  PERFORM pg_temp.v3_assert(r->>'code'='v3_authoritative_admission_unavailable','client version/hash/target cannot nominate legacy authority');
  r:=public.create_or_resume_programme_training_session(jsonb_build_object('assignment_id',upper(assignment::text)));
  PERFORM pg_temp.v3_assert(r->>'code'='v3_authoritative_admission_unavailable','uppercase UUID cannot bypass actual-version guard');
  r:=public.create_or_resume_programme_training_session(jsonb_build_object('assignment_id','{'||assignment::text||'}'));
  PERFORM pg_temp.v3_assert(r->>'code'='v3_authoritative_admission_unavailable','alternative UUID syntax cannot bypass actual-version guard');
  PERFORM set_config('request.jwt.claim.sub','b2300000-0000-4000-8000-000000000008',true);
  r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence);
  PERFORM pg_temp.v3_assert(r->>'status'='authorization_failure','foreign occurrence does not disclose v3 state');
  PERFORM set_config('role','none',true);
  PERFORM pg_temp.v3_assert((SELECT count(*) FROM public.training_sessions)=before_sessions,'no session inserted');
  PERFORM pg_temp.v3_assert((SELECT count(*) FROM public.programme_slot_outcomes)=before_outcomes,'no partial outcome');
END $$;
ROLLBACK;
SELECT 'V3_UNRESOLVED_CANONICAL_START=PASS (no v3 admission or snapshot capability)' AS result;
