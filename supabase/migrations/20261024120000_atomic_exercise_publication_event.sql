-- Extends only the existing producer boundary. No producer membership or content.
BEGIN;
CREATE FUNCTION public.retain_published_exercise_event_v1(
 p_canonical_text text,p_publication jsonb,p_retirement jsonb DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE retained jsonb; retired boolean; prior public.published_exercise_definition_versions%ROWTYPE; definition jsonb;
BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_exercise_version_publisher' THEN
  RAISE EXCEPTION 'verified exercise publication producer required' USING ERRCODE='42501';
 END IF;
 -- Retirement of an already retained version remains possible after catalogue
 -- identity withdrawal. Reuse exact retained proof and the existing retirement
 -- authority; do not reinterpret a current catalogue row as publication history.
 IF p_retirement IS NOT NULL THEN
  definition:=p_canonical_text::jsonb;
  SELECT * INTO prior FROM public.published_exercise_definition_versions
   WHERE exercise_id=definition->>'id' AND definition_version=definition->>'version' FOR UPDATE;
  IF FOUND THEN
   IF prior.canonical_text IS DISTINCT FROM p_canonical_text OR prior.publication IS DISTINCT FROM p_publication THEN
    RAISE EXCEPTION 'immutable published definition conflict' USING ERRCODE='23505';
   END IF;
   retained:=to_jsonb(prior);
  END IF;
 END IF;
 IF retained IS NULL THEN
  retained:=public.retain_published_exercise_definition_v1(p_canonical_text,p_publication);
 END IF;
 IF p_retirement IS NOT NULL THEN
  IF p_retirement->>'event_id' IS NOT DISTINCT FROM p_publication->>'event_id' THEN
   RAISE EXCEPTION 'distinct retirement event required' USING ERRCODE='22023';
  END IF;
  PERFORM public.retire_published_exercise_version_v1(retained->>'exercise_id',retained->>'definition_version',p_retirement);
 END IF;
 SELECT EXISTS(SELECT 1 FROM public.published_exercise_version_retirements
  WHERE exercise_id=retained->>'exercise_id' AND definition_version=retained->>'definition_version') INTO retired;
 RETURN jsonb_build_object('status','retained','exercise_id',retained->>'exercise_id',
  'definition_version',retained->>'definition_version','content_digest',retained->>'content_digest','retired',retired);
END $$;
REVOKE ALL ON FUNCTION public.retain_published_exercise_event_v1(text,jsonb,jsonb)
 FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.retain_published_exercise_event_v1(text,jsonb,jsonb)
 TO cohort_exercise_version_publisher;
COMMENT ON FUNCTION public.retain_published_exercise_event_v1(text,jsonb,jsonb) IS
 'Producer-only atomic retention plus known retirement. Delegates authority/validation/conflicts to existing immutable version/event boundary. No approval or producer provisioning.';
COMMIT;
