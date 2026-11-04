-- Preserve the explicit start-date anchor only inside the existing M1.2
-- private-free acquisition authority. No dates/rows are rewritten or backfilled.
BEGIN;
DO $anchor$
DECLARE original record; updated record; definition text; source_hash text;
BEGIN
 SELECT oid,prosrc,proowner,proacl,prosecdef,proconfig INTO STRICT original
 FROM pg_proc WHERE oid='public.materialise_athlete_plan_from_enrolment(uuid,text)'::regprocedure;
 source_hash:=encode(extensions.digest(convert_to(original.prosrc,'UTF8'),'sha256'),'hex');
 IF source_hash='ab6cfa3822b0ae4499ae58e2844a0e1dc26ac94952e8adb59b80d2eeb42c2c59' THEN RETURN; END IF;
 IF source_hash<>'c9c4c61622f8d3a22147b32e1e469548b07e293ec2078c4ed68f4399a16d8449' THEN RAISE EXCEPTION 'private_alpha_start_anchor_unexpected_materialiser'; END IF;
 definition:=pg_get_functiondef(original.oid);
 IF length(definition)-length(replace(definition,$old$v_start := public.cohort_resolve_athlete_local_date(v_tz);$old$,''))<>length($old$v_start := public.cohort_resolve_athlete_local_date(v_tz);$old$) THEN
  RAISE EXCEPTION 'private_alpha_start_anchor_expected_one_resolver';
 END IF;
 EXECUTE replace(definition,$old$v_start := public.cohort_resolve_athlete_local_date(v_tz);$old$,$new$-- M11_PRIVATE_ALPHA_EXPLICIT_START_ANCHOR_V1
    IF v_assignment.schedule_mode = 'fixed_schedule'
       AND v_assignment.started_at IS NOT NULL
       AND current_setting('cohort.private_alpha_acquisition', true)
           = v_assignment.athlete_id::text || ':' || v_assignment.programme_version_id::text
    THEN
      v_start := v_assignment.started_at;
    ELSE
      v_start := public.cohort_resolve_athlete_local_date(v_tz);
    END IF;$new$);
 SELECT oid,prosrc,proowner,proacl,prosecdef,proconfig INTO STRICT updated
 FROM pg_proc WHERE oid='public.materialise_athlete_plan_from_enrolment(uuid,text)'::regprocedure;
 IF updated.oid<>original.oid OR updated.proowner<>original.proowner
    OR updated.proacl IS DISTINCT FROM original.proacl
    OR updated.prosecdef IS DISTINCT FROM original.prosecdef
    OR updated.proconfig IS DISTINCT FROM original.proconfig
    OR encode(extensions.digest(convert_to(updated.prosrc,'UTF8'),'sha256'),'hex')<>'ab6cfa3822b0ae4499ae58e2844a0e1dc26ac94952e8adb59b80d2eeb42c2c59'
 THEN RAISE EXCEPTION 'private_alpha_start_anchor_identity_or_authority_changed'; END IF;
END $anchor$;
COMMIT;
