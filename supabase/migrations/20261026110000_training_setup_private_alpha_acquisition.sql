-- M1.2: minimum persisted training setup and exact private-free eligibility.
-- Local implementation only. No seeds, hosted apply, content or assignments.
BEGIN;

CREATE TABLE public.athlete_training_setup (
  athlete_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  timezone text NOT NULL,
  completed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.private_programme_alpha_eligibility (
  athlete_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  programme_version_id uuid NOT NULL REFERENCES public.programme_versions(id),
  expires_at timestamptz,
  revoked_at timestamptz,
  PRIMARY KEY (athlete_id, programme_version_id)
);
COMMENT ON TABLE public.private_programme_alpha_eligibility IS
 'Closed operator-managed exact recipient eligibility. Not enrolment, payment or content approval. No client writes; no seeds.';
ALTER TABLE public.athlete_training_setup ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.private_programme_alpha_eligibility ENABLE ROW LEVEL SECURITY;
-- All access is through the narrow authenticated RPCs below. Explicitly remove
-- hosted creation defaults too; never broaden existing grants or policies.
REVOKE ALL ON public.athlete_training_setup, public.private_programme_alpha_eligibility
 FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.read_my_training_setup(p_expected_athlete_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE s public.athlete_training_setup%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR p_expected_athlete_id IS DISTINCT FROM auth.uid() OR NOT public.cohort_auth_is_athlete() THEN
  RETURN jsonb_build_object('status','access_denied'); END IF;
 SELECT * INTO s FROM public.athlete_training_setup WHERE athlete_id=auth.uid();
 RETURN jsonb_build_object('status','ok','timezone',s.timezone,'complete',s.completed_at IS NOT NULL);
END $$;

CREATE FUNCTION public.save_my_training_setup(p_expected_athlete_id uuid,p_timezone text, p_complete boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE s public.athlete_training_setup%ROWTYPE; tz text:=btrim(p_timezone);
BEGIN
 IF auth.uid() IS NULL OR p_expected_athlete_id IS DISTINCT FROM auth.uid() OR NOT public.cohort_auth_is_athlete() THEN
  RETURN jsonb_build_object('status','access_denied'); END IF;
 IF tz IS NULL OR tz !~ '^[A-Za-z_]+/[A-Za-z0-9_+\-]+(/[A-Za-z0-9_+\-]+)*$'
  OR tz LIKE 'Etc/%' OR tz LIKE 'posix/%' OR tz LIKE 'right/%'
  OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=tz) THEN
  RETURN jsonb_build_object('status','invalid_timezone'); END IF;
 PERFORM pg_advisory_xact_lock(84202613,hashtext(auth.uid()::text));
 SELECT * INTO s FROM public.athlete_training_setup WHERE athlete_id=auth.uid() FOR UPDATE;
 IF s.completed_at IS NOT NULL AND s.timezone IS DISTINCT FROM tz THEN
  RETURN jsonb_build_object('status','setup_already_completed'); END IF;
 INSERT INTO public.athlete_training_setup(athlete_id,timezone,completed_at)
 VALUES(auth.uid(),tz,CASE WHEN p_complete THEN transaction_timestamp() END)
 ON CONFLICT(athlete_id) DO UPDATE SET timezone=excluded.timezone,
  completed_at=coalesce(athlete_training_setup.completed_at,excluded.completed_at),updated_at=now();
 RETURN public.read_my_training_setup(p_expected_athlete_id);
END $$;

CREATE FUNCTION public.cohort_private_alpha_eligible(p_version_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT auth.uid() IS NOT NULL AND public.cohort_auth_is_athlete()
 AND EXISTS(SELECT 1 FROM public.athlete_training_setup s
   WHERE s.athlete_id=auth.uid() AND s.completed_at IS NOT NULL)
 AND EXISTS(SELECT 1 FROM public.private_programme_alpha_eligibility e
   JOIN public.programme_versions v ON v.id=e.programme_version_id
   WHERE e.athlete_id=auth.uid() AND e.programme_version_id=p_version_id
   AND e.revoked_at IS NULL AND (e.expires_at IS NULL OR e.expires_at>now())
   AND v.package_schema_version IN (1,2)
   AND public.cohort_programme_version_is_private_assignable(v.id));
$$;
REVOKE ALL ON FUNCTION public.cohort_private_alpha_eligible(uuid) FROM PUBLIC,anon,authenticated,service_role;

-- Same existing version and owner/relationship contracts; a bounded recipient
-- row adds alpha eligibility without synthetic ownership or coach membership.
CREATE OR REPLACE FUNCTION public.cohort_athlete_may_enrol_private_programme_version(p_version_id uuid) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE u uuid:=auth.uid(); v public.programme_versions%ROWTYPE;
BEGIN
 IF u IS NULL OR NOT public.cohort_auth_is_athlete()
 OR NOT public.cohort_programme_version_is_private_assignable(p_version_id) THEN RETURN false; END IF;
 SELECT * INTO v FROM public.programme_versions WHERE id=p_version_id;
 IF NOT FOUND THEN RETURN false; END IF;
 RETURN (nullif(btrim(coalesce(v.owner_id,'')),'') IS NOT DISTINCT FROM u::text)
 OR EXISTS(SELECT 1 FROM public.coach_athlete_relationships r
   WHERE r.status='active' AND r.athlete_id=u AND r.coach_id::text=v.owner_id)
 OR (public.cohort_private_alpha_eligible(p_version_id)
   AND coalesce(current_setting('cohort.private_alpha_acquisition',true),'')=u::text||':'||p_version_id::text);
END $$;
CREATE OR REPLACE FUNCTION public.cohort_private_programme_visible_to_caller(p_version_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT public.cohort_athlete_may_enrol_private_programme_version(p_version_id)
 OR public.cohort_private_alpha_eligible(p_version_id);
$$;

CREATE FUNCTION public.cohort_private_alpha_ready(p_version_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.programme_versions v
 JOIN public.programme_publication_artifacts a ON a.programme_version_id=v.id
 WHERE v.id=p_version_id AND v.package_schema_version IN (1,2)
 AND a.package_content_hash=v.package_content_hash AND a.package_schema_version=v.package_schema_version
 AND public.cohort_programme_version_is_private_assignable(v.id)
 AND public.cohort_private_version_graphs_are_executable(v.id));
$$;
REVOKE ALL ON FUNCTION public.cohort_private_alpha_ready(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.read_my_private_programme_catalogue(p_expected_athlete_id uuid,p_version_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE items jsonb;
BEGIN
 IF auth.uid() IS NULL OR p_expected_athlete_id IS DISTINCT FROM auth.uid() OR NOT public.cohort_auth_is_athlete() THEN
  RETURN jsonb_build_object('status','access_denied'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.athlete_training_setup WHERE athlete_id=auth.uid() AND completed_at IS NOT NULL) THEN
  RETURN jsonb_build_object('status','onboarding_required'); END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'version_id',v.id,'title',v.name,'summary',coalesce(v.description,v.primary_goal,v.coaching_intent),
  'duration_weeks',v.duration_weeks,'sessions_per_week',v.sessions_per_week,
  'equipment',v.equipment_requirements,'level',v.difficulty,
  'ready',public.cohort_private_alpha_ready(v.id),'already_active',a.id IS NOT NULL,
  'assignment_id',a.id,'started_at',a.started_at,'timezone',s.timezone
 ) ORDER BY v.name,v.id),'[]'::jsonb) INTO items
 FROM public.programme_versions v
 JOIN public.athlete_training_setup s ON s.athlete_id=auth.uid()
 LEFT JOIN public.programme_assignments a ON a.programme_version_id=v.id AND a.athlete_id=auth.uid() AND a.status='active'
 WHERE v.package_schema_version IN (1,2) AND (p_version_id IS NULL OR v.id=p_version_id)
 AND public.cohort_private_programme_visible_to_caller(v.id);
 IF p_version_id IS NOT NULL AND jsonb_array_length(items)=0 THEN
  RETURN jsonb_build_object('status','access_denied'); END IF;
 RETURN jsonb_build_object('status','ok','programmes',items);
END $$;

CREATE FUNCTION public.acquire_my_private_programme(p_expected_athlete_id uuid,p_version_id uuid,p_start_date date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE u uuid:=auth.uid(); tz text; a public.programme_assignments%ROWTYPE; result jsonb;
BEGIN
 IF u IS NULL OR p_expected_athlete_id IS DISTINCT FROM u OR NOT public.cohort_auth_is_athlete() THEN RETURN jsonb_build_object('status','access_denied'); END IF;
 PERFORM pg_advisory_xact_lock(84202613,hashtext(u::text));
 SELECT timezone INTO tz FROM public.athlete_training_setup WHERE athlete_id=u AND completed_at IS NOT NULL FOR SHARE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','onboarding_required'); END IF;
 -- Lock the exact eligibility/version inputs through the delegated transaction.
 PERFORM 1 FROM public.private_programme_alpha_eligibility WHERE athlete_id=u AND programme_version_id=p_version_id FOR SHARE;
 PERFORM 1 FROM public.programme_versions WHERE id=p_version_id FOR SHARE;
 IF NOT public.cohort_private_programme_visible_to_caller(p_version_id) THEN
  RETURN jsonb_build_object('status','access_denied'); END IF;
 IF NOT public.cohort_private_alpha_ready(p_version_id) THEN
  RETURN jsonb_build_object('status','programme_unavailable'); END IF;
 SELECT * INTO a FROM public.programme_assignments WHERE athlete_id=u AND status='active' FOR UPDATE;
 IF FOUND THEN
  IF a.programme_version_id<>p_version_id THEN RETURN jsonb_build_object('status','active_enrolment_exists'); END IF;
  RETURN jsonb_build_object('status','already_enrolled','enrolment_id',a.id,
   'programme_version_id',a.programme_version_id,'athlete_id',u,'started_at',a.started_at,'timezone',a.timezone);
 END IF;
 IF p_start_date IS NULL THEN RETURN jsonb_build_object('status','invalid_start_date'); END IF;
 -- Exact transaction-local authority only inside this no-replacement wrapper.
 -- A new recipient grant cannot activate via legacy replacement-capable RPCs.
 PERFORM set_config('cohort.private_alpha_acquisition',u::text||':'||p_version_id::text,true);
 result:=public.enrol_athlete_in_private_programme_version(p_version_id,tz,p_start_date,false);
 -- The existing function raises on materialisation/projection failure, rolling
 -- back the entire operation. A retry either creates one pin or returns it.
 IF result->>'status'='enrolled' AND public.cohort_private_alpha_eligible(p_version_id) THEN
  UPDATE public.programme_assignments SET enrolment_source='non_commercial_test'
   WHERE id=(result->>'enrolment_id')::uuid AND athlete_id=u;
  result:=result||jsonb_build_object('enrolment_source','non_commercial_test');
 END IF;
 RETURN result;
END $$;

REVOKE ALL ON FUNCTION public.read_my_training_setup(uuid),public.save_my_training_setup(uuid,text,boolean),
 public.read_my_private_programme_catalogue(uuid,uuid),public.acquire_my_private_programme(uuid,uuid,date)
 FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.read_my_training_setup(uuid),public.save_my_training_setup(uuid,text,boolean),
 public.read_my_private_programme_catalogue(uuid,uuid),public.acquire_my_private_programme(uuid,uuid,date) TO authenticated;
COMMIT;
