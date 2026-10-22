-- No v3 write/start may silently fall through the legacy v1/v2 path.
-- Deliberately no v3 admission capability until canonical dependency authority is resolved.
BEGIN;
-- Preserve the existing public start RPC's effective service execution privilege
-- where retained deployment defaults already granted it. This is not an ACL repair.
CREATE TEMP TABLE base_v3_prior_start_acl ON COMMIT DROP AS
  SELECT has_function_privilege('service_role',
    'public.create_or_resume_programme_training_session(jsonb)','EXECUTE') AS service_execute,
    'public.create_or_resume_programme_training_session(jsonb)'::regprocedure::oid AS generic_oid,
    'public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamptz)'::regprocedure::oid AS fixed_oid;
DO $$
BEGIN
  IF has_function_privilege('anon','public.create_or_resume_programme_training_session(jsonb)','EXECUTE')
    OR EXISTS (SELECT 1 FROM pg_proc p, LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
      WHERE p.oid='public.create_or_resume_programme_training_session(jsonb)'::regprocedure
      AND a.privilege_type='EXECUTE' AND a.grantee=0) THEN
    RAISE EXCEPTION 'unexpected existing canonical start ACL; separate review required';
  END IF;
END $$;
CREATE FUNCTION public.cohort_reject_unresolved_package_version() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NEW.package_schema_version >= 3 THEN
    RAISE EXCEPTION 'v3 authoritative source/definition admission unavailable' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER zz_reject_unresolved_package_version
  BEFORE INSERT OR UPDATE OF package_schema_version ON public.programme_versions
  FOR EACH ROW EXECUTE FUNCTION public.cohort_reject_unresolved_package_version();
REVOKE ALL ON FUNCTION public.cohort_reject_unresolved_package_version() FROM PUBLIC, anon, authenticated, service_role;

-- Copy the old body, then replace the existing OID in place. Renaming the old
-- function could leave a cached definer SQL caller bound to its unguarded OID.
DO $$ BEGIN
  IF to_regprocedure('public.cohort_create_or_resume_fixed_occurrence_pre_v3(uuid,timestamptz)') IS NOT NULL THEN
    RAISE EXCEPTION 'unexpected existing private fixed start body';
  END IF;
  EXECUTE replace(pg_get_functiondef('public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamptz)'::regprocedure),
    'FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(',
    'FUNCTION public.cohort_create_or_resume_fixed_occurrence_pre_v3(');
END $$;
REVOKE ALL ON FUNCTION public.cohort_create_or_resume_fixed_occurrence_pre_v3(uuid,timestamptz)
  FROM PUBLIC, anon, authenticated, service_role;
CREATE OR REPLACE FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(p_occurrence_id uuid, p_now timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND public.cohort_auth_is_athlete() AND EXISTS (
    SELECT 1 FROM public.programme_schedule_occurrences o
    JOIN public.programme_assignments a ON a.id = o.assignment_id
    JOIN public.programme_versions v ON v.id = a.programme_version_id
    WHERE o.id = p_occurrence_id AND a.athlete_id = auth.uid() AND v.package_schema_version >= 3
  ) THEN
    RETURN jsonb_build_object('status','unavailable','code','v3_authoritative_admission_unavailable');
  END IF;
  RETURN public.cohort_create_or_resume_fixed_occurrence_pre_v3(p_occurrence_id,p_now);
END $$;
REVOKE ALL ON FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamptz)
  FROM PUBLIC, anon, authenticated, service_role;

DO $$ BEGIN
  IF to_regprocedure('public.cohort_create_or_resume_programme_training_session_pre_v3(jsonb)') IS NOT NULL THEN
    RAISE EXCEPTION 'unexpected existing private generic start body';
  END IF;
  EXECUTE replace(pg_get_functiondef('public.create_or_resume_programme_training_session(jsonb)'::regprocedure),
    'FUNCTION public.create_or_resume_programme_training_session(',
    'FUNCTION public.cohort_create_or_resume_programme_training_session_pre_v3(');
END $$;
REVOKE ALL ON FUNCTION public.cohort_create_or_resume_programme_training_session_pre_v3(jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
CREATE OR REPLACE FUNCTION public.create_or_resume_programme_training_session(payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE assignment_id uuid;
BEGIN
  BEGIN
    assignment_id := (payload->>'assignment_id')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN public.cohort_create_or_resume_programme_training_session_pre_v3(payload);
  END;
  -- Resolve the assignment's actual version, never the client-nominated version/hash.
  IF auth.uid() IS NOT NULL AND public.cohort_auth_is_athlete() AND EXISTS (
    SELECT 1 FROM public.programme_assignments a
    JOIN public.programme_versions v ON v.id = a.programme_version_id
    WHERE a.id = assignment_id AND a.athlete_id = auth.uid() AND v.package_schema_version >= 3
  ) THEN
    RETURN jsonb_build_object('status','unavailable','code','v3_authoritative_admission_unavailable');
  END IF;
  RETURN public.cohort_create_or_resume_programme_training_session_pre_v3(payload);
END $$;
REVOKE ALL ON FUNCTION public.create_or_resume_programme_training_session(jsonb) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_or_resume_programme_training_session(jsonb) TO authenticated;
DO $$ BEGIN
  IF NOT (SELECT generic_oid='public.create_or_resume_programme_training_session(jsonb)'::regprocedure::oid
    AND fixed_oid='public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamptz)'::regprocedure::oid
    FROM base_v3_prior_start_acl) THEN
    RAISE EXCEPTION 'canonical function OIDs changed';
  END IF;
  IF (SELECT service_execute FROM base_v3_prior_start_acl) THEN
    GRANT EXECUTE ON FUNCTION public.create_or_resume_programme_training_session(jsonb) TO service_role;
  END IF;
END $$;
COMMIT;
