-- FUTURE HOSTED DEPLOYMENT REQUIRES SEPARATE APPROVAL. No usable memberships/seeds.
BEGIN;
DO $$ DECLARE r text; BEGIN
 FOREACH r IN ARRAY ARRAY['cohort_publication_approval_writer','cohort_publication_event_delivery'] LOOP
  IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r) THEN
   IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r AND (rolcanlogin OR rolinherit OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls OR rolconfig IS NOT NULL OR rolvaliduntil IS NOT NULL))
    OR EXISTS(SELECT 1 FROM pg_auth_members WHERE (roleid=r::regrole AND (member<>current_user::regrole OR set_option OR inherit_option OR NOT admin_option)) OR member=r::regrole) THEN RAISE EXCEPTION 'unexpected producer authority %',r; END IF;
  ELSE EXECUTE format('CREATE ROLE %I NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS',r); END IF;
 END LOOP;
END $$;
CREATE TABLE public.publication_approval_drafts (
 event_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
 request_id uuid NOT NULL, prepared_by uuid NOT NULL,
 kind text NOT NULL CHECK(kind IN ('exercise_published','exercise_retired','programme_approved')),
 input jsonb NOT NULL, artifact jsonb NOT NULL, artifact_sha256 text NOT NULL,
 prepared_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(prepared_by,request_id), CHECK(artifact_sha256=public.cohort_v3_hash(artifact))
);
CREATE TABLE public.publication_approval_events (
 event_id uuid PRIMARY KEY REFERENCES public.publication_approval_drafts(event_id),
 approved_by uuid NOT NULL, approved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 record jsonb NOT NULL
);
CREATE TABLE public.publication_event_delivery (
 event_id uuid PRIMARY KEY REFERENCES public.publication_approval_events(event_id),
 state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','inflight','delivered','blocked')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0),
 lease_id uuid, lease_until timestamptz, next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 last_code text, receipt jsonb,
 CHECK((state='inflight')=(lease_id IS NOT NULL AND lease_until IS NOT NULL))
);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['publication_approval_drafts','publication_approval_events','publication_event_delivery'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated,service_role,cohort_exercise_version_publisher,cohort_publication_approval_writer,cohort_publication_event_delivery',t);
 END LOOP;
END $$;
CREATE TRIGGER publication_draft_immutable BEFORE UPDATE OR DELETE ON public.publication_approval_drafts
 FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();
CREATE TRIGGER publication_approval_event_immutable BEFORE UPDATE OR DELETE ON public.publication_approval_events
 FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();

CREATE FUNCTION public.prepare_publication_approval_v1(p_actor uuid,p_request_id uuid,p_kind text,p_input jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE prior public.publication_approval_drafts%ROWTYPE; e uuid; stamp text; ref text; a jsonb; d jsonb; original public.published_exercise_definition_versions%ROWTYPE;
BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_approval_writer' THEN RAISE EXCEPTION 'approval writer required' USING ERRCODE='42501'; END IF;
 IF p_actor IS NULL OR p_request_id IS NULL OR octet_length(p_input::text)>2097152 THEN RAISE EXCEPTION 'invalid approval input' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text||p_request_id::text,0));
 SELECT * INTO prior FROM public.publication_approval_drafts WHERE prepared_by=p_actor AND request_id=p_request_id;
 IF FOUND THEN
  IF prior.kind IS DISTINCT FROM p_kind OR prior.input IS DISTINCT FROM p_input THEN RAISE EXCEPTION 'immutable request conflict' USING ERRCODE='23505'; END IF;
  RETURN jsonb_build_object('event_id',prior.event_id,'artifact',prior.artifact,'artifact_sha256',prior.artifact_sha256,'kind',prior.kind,'status','pending_review');
 END IF;
 e:=extensions.gen_random_uuid(); stamp:=to_char(clock_timestamp() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');ref:='cohort-publication-approval:'||e::text;
 IF p_kind='exercise_published' THEN
  IF public.cohort_v3_object(p_input,ARRAY['canonical_text','approved_binding_kinds']) IS NOT TRUE OR jsonb_typeof(p_input->'canonical_text') IS DISTINCT FROM 'string' OR jsonb_typeof(p_input->'approved_binding_kinds') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid definition draft' USING ERRCODE='22023'; END IF;
  d:=(p_input->>'canonical_text')::jsonb;
  IF p_input->>'canonical_text' IS DISTINCT FROM public.cohort_tracking_canonical_text(d) OR octet_length(p_input->>'canonical_text')>262144
   OR d->>'owner' IS DISTINCT FROM 'founder' OR d->>'lifecycle_status' IS DISTINCT FROM 'draft'
   OR d ? 'published_at' OR d->>'id' !~ '^EX-[0-9]+$' OR jsonb_typeof(d->'id') IS DISTINCT FROM 'string'
   OR jsonb_typeof(d->'version') IS DISTINCT FROM 'string' OR coalesce(length(btrim(d->>'version')),0) NOT BETWEEN 1 AND 128
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_input->'approved_binding_kinds') x WHERE x#>>'{}' NOT IN ('runningIntervals','dedicatedRowIntervals','backSquat') OR jsonb_typeof(x)<>'string')
   OR (SELECT count(*) FROM jsonb_array_elements(p_input->'approved_binding_kinds'))<>(SELECT count(DISTINCT value)FROM jsonb_array_elements(p_input->'approved_binding_kinds')) THEN RAISE EXCEPTION 'unassigned or invalid definition draft' USING ERRCODE='22023'; END IF;
  -- Reserve proposed publication metadata for exact review, not effective publication.
  d:=d||jsonb_build_object('lifecycle_status','published','published_at',stamp);
  a:=jsonb_build_object('canonical_text',public.cohort_tracking_canonical_text(d),'publication',jsonb_build_object('issuer','founder_exercise_publication_v1','event_id',e,'source_reference',ref,'published_at',stamp,'approved_binding_kinds',p_input->'approved_binding_kinds'),'retirement',NULL);
 ELSIF p_kind='exercise_retired' THEN
  IF public.cohort_v3_object(p_input,ARRAY['publication_event_id']) IS NOT TRUE THEN RAISE EXCEPTION 'invalid retirement input' USING ERRCODE='22023'; END IF;
  SELECT * INTO original FROM public.published_exercise_definition_versions WHERE publication->>'event_id'=p_input->>'publication_event_id';
  IF NOT FOUND THEN RAISE EXCEPTION 'exact retained original required' USING ERRCODE='22023'; END IF;
  a:=jsonb_build_object('canonical_text',original.canonical_text,'publication',original.publication,'retirement',jsonb_build_object('issuer','founder_exercise_publication_v1','event_id',e,'publication_event_id',p_input->>'publication_event_id','source_reference',ref,'retired_at',stamp));
 ELSIF p_kind='programme_approved' THEN
  IF public.cohort_v3_object(p_input,ARRAY['source','canonical_sha256','programme_version_id','owner_id']) IS NOT TRUE OR jsonb_typeof(p_input->'source') IS DISTINCT FROM 'string'
   OR jsonb_typeof(p_input->'canonical_sha256') IS DISTINCT FROM 'string' OR jsonb_typeof(p_input->'programme_version_id') IS DISTINCT FROM 'string' OR jsonb_typeof(p_input->'owner_id') IS DISTINCT FROM 'string' OR octet_length(p_input->>'source')>1048576 OR p_input->>'canonical_sha256' !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'invalid programme draft' USING ERRCODE='22023'; END IF;
  PERFORM (p_input->>'programme_version_id')::uuid;PERFORM (p_input->>'owner_id')::uuid;a:=p_input;
 ELSE RAISE EXCEPTION 'unsupported event kind' USING ERRCODE='22023'; END IF;
 INSERT INTO public.publication_approval_drafts(event_id,request_id,prepared_by,kind,input,artifact,artifact_sha256)
 VALUES(e,p_request_id,p_actor,p_kind,p_input,a,public.cohort_v3_hash(a));
 RETURN jsonb_build_object('event_id',e,'artifact',a,'artifact_sha256',public.cohort_v3_hash(a),'kind',p_kind,'status','pending_review');
END $$;

CREATE FUNCTION public.read_publication_approval_draft_v1(p_actor uuid,p_event_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE d public.publication_approval_drafts%ROWTYPE; BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_approval_writer' THEN RAISE EXCEPTION 'approval writer required' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.publication_approval_drafts WHERE event_id=p_event_id AND prepared_by=p_actor;
 IF NOT FOUND THEN RAISE EXCEPTION 'draft unavailable' USING ERRCODE='22023'; END IF;
 RETURN jsonb_build_object('event_id',d.event_id,'kind',d.kind,'artifact',d.artifact,'artifact_sha256',d.artifact_sha256,'prepared_at',d.prepared_at,'approved',EXISTS(SELECT 1 FROM public.publication_approval_events WHERE event_id=p_event_id));
END $$;

CREATE FUNCTION public.approve_publication_event_v1(p_actor uuid,p_event_id uuid,p_artifact_sha256 text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE d public.publication_approval_drafts%ROWTYPE;rec jsonb;BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_approval_writer' THEN RAISE EXCEPTION 'approval writer required' USING ERRCODE='42501'; END IF;
 SELECT * INTO d FROM public.publication_approval_drafts WHERE event_id=p_event_id AND prepared_by=p_actor FOR UPDATE;
 IF NOT FOUND OR d.artifact_sha256 IS DISTINCT FROM p_artifact_sha256 THEN RAISE EXCEPTION 'exact review digest required' USING ERRCODE='23505'; END IF;
 IF d.kind='exercise_retired' THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(d.artifact#>>'{retirement,publication_event_id}',1));
  IF EXISTS(SELECT 1 FROM public.publication_approval_events x JOIN public.publication_approval_drafts y USING(event_id) WHERE y.kind='exercise_retired' AND y.event_id<>d.event_id AND y.artifact#>>'{retirement,publication_event_id}'=d.artifact#>>'{retirement,publication_event_id}') THEN RAISE EXCEPTION 'retirement approval conflict' USING ERRCODE='23505'; END IF;
 END IF;
 rec:=jsonb_build_object('contract','cohort.trusted-publication-event.v1','event_id',d.event_id,'kind',d.kind,'approval',jsonb_build_object('status','approved','reference','cohort-publication-approval:'||d.event_id::text),'artifact',d.artifact);
 INSERT INTO public.publication_approval_events(event_id,approved_by,record) VALUES(d.event_id,p_actor,rec) ON CONFLICT(event_id) DO NOTHING;
 INSERT INTO public.publication_event_delivery(event_id) VALUES(d.event_id) ON CONFLICT(event_id) DO NOTHING;
 RETURN jsonb_build_object('event_id',d.event_id,'artifact_sha256',d.artifact_sha256,'status','approved','delivery_state',(SELECT state FROM public.publication_event_delivery WHERE event_id=d.event_id));
END $$;

CREATE FUNCTION public.resolve_publication_approval_event_v1(p_event_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE rec jsonb; retired jsonb; BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_event_delivery' THEN RAISE EXCEPTION 'delivery capability required' USING ERRCODE='42501'; END IF;
 SELECT record INTO rec FROM public.publication_approval_events WHERE event_id=p_event_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'approved event not ready' USING ERRCODE='22023'; END IF;
 IF rec->>'kind'='exercise_published' THEN
  SELECT x.record#>'{artifact,retirement}' INTO retired FROM public.publication_approval_events x WHERE x.record->>'kind'='exercise_retired' AND x.record#>>'{artifact,retirement,publication_event_id}'=p_event_id::text;
  IF retired IS NOT NULL THEN rec:=jsonb_set(rec,'{artifact,retirement}',retired); END IF;
 END IF;
 RETURN rec;
END $$;

CREATE FUNCTION public.list_publication_deliveries_v1(p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_event_delivery' THEN RAISE EXCEPTION 'delivery capability required' USING ERRCODE='42501'; END IF;
 RETURN (SELECT coalesce(jsonb_agg(x ORDER BY x.approved_at,x.event_id),'[]'::jsonb) FROM (SELECT q.event_id,e.approved_at,q.state,q.attempts,q.next_attempt_at,q.lease_until,q.last_code FROM public.publication_event_delivery q JOIN public.publication_approval_events e USING(event_id) WHERE e.approved_by=p_actor AND q.state<>'delivered' ORDER BY e.approved_at,q.event_id LIMIT 100) x);
END $$;

CREATE FUNCTION public.claim_publication_delivery_v1(p_actor uuid,p_event_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE q public.publication_event_delivery%ROWTYPE;l uuid;BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_event_delivery' THEN RAISE EXCEPTION 'delivery capability required' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.publication_approval_events WHERE event_id=p_event_id AND approved_by=p_actor) THEN RAISE EXCEPTION 'event owner required' USING ERRCODE='42501'; END IF;
 SELECT * INTO q FROM public.publication_event_delivery WHERE event_id=p_event_id FOR UPDATE;
 IF q.state IN ('delivered','blocked') THEN RETURN jsonb_build_object('status',q.state,'event_id',p_event_id); END IF;
 IF q.next_attempt_at>clock_timestamp() OR(q.state='inflight' AND q.lease_until>clock_timestamp()) THEN RETURN jsonb_build_object('status','wait','event_id',p_event_id); END IF;
 l:=extensions.gen_random_uuid();UPDATE public.publication_event_delivery SET state='inflight',attempts=attempts+1,lease_id=l,lease_until=clock_timestamp()+interval '3 minutes' WHERE event_id=p_event_id;
 RETURN jsonb_build_object('status','claimed','event_id',p_event_id,'lease_id',l);
END $$;

CREATE FUNCTION public.finish_publication_delivery_v1(p_actor uuid,p_event_id uuid,p_lease_id uuid,p_outcome text,p_receipt jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE q public.publication_event_delivery%ROWTYPE;BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_event_delivery' THEN RAISE EXCEPTION 'delivery capability required' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.publication_approval_events WHERE event_id=p_event_id AND approved_by=p_actor) THEN RAISE EXCEPTION 'event owner required' USING ERRCODE='42501'; END IF;
 SELECT * INTO q FROM public.publication_event_delivery WHERE event_id=p_event_id FOR UPDATE;
 IF q.state<>'inflight' OR q.lease_id IS DISTINCT FROM p_lease_id OR q.lease_until<clock_timestamp() THEN RAISE EXCEPTION 'stale delivery lease' USING ERRCODE='23505'; END IF;
 IF p_outcome NOT IN ('delivered','retry','blocked') OR p_receipt IS NULL OR jsonb_typeof(p_receipt)<>'object' OR octet_length(p_receipt::text)>2048
  OR p_receipt-ARRAY['status','code','event_id','event_received','approval_evidence','programme_version_id','approved_for_global','retired']<>'{}' THEN RAISE EXCEPTION 'invalid safe delivery receipt' USING ERRCODE='22023'; END IF;
 IF p_outcome='delivered' AND (p_receipt->>'event_id' IS DISTINCT FROM p_event_id::text OR p_receipt->'event_received' IS DISTINCT FROM 'true'::jsonb OR p_receipt->>'approval_evidence' IS DISTINCT FROM 'verified_producer_record' OR coalesce(p_receipt->>'status','') NOT IN ('retained','published','already_published')) THEN RAISE EXCEPTION 'invalid delivery acknowledgement' USING ERRCODE='22023'; END IF;
 UPDATE public.publication_event_delivery SET state=CASE WHEN p_outcome='retry' THEN 'pending' ELSE p_outcome END,
  next_attempt_at=clock_timestamp()+make_interval(secs=>least(3600,30*power(2,least(q.attempts-1,7)))::int),lease_id=NULL,lease_until=NULL,
  last_code=CASE WHEN p_outcome='delivered' THEN NULL ELSE p_outcome END,receipt=p_receipt WHERE event_id=p_event_id;
 RETURN jsonb_build_object('event_id',p_event_id,'status',p_outcome);
END $$;

CREATE FUNCTION public.retry_publication_delivery_v1(p_actor uuid,p_event_id uuid,p_artifact_sha256 text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF current_setting('role',true) IS DISTINCT FROM 'cohort_publication_event_delivery' THEN RAISE EXCEPTION 'delivery capability required' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.publication_approval_events e JOIN public.publication_approval_drafts d USING(event_id) WHERE e.event_id=p_event_id AND e.approved_by=p_actor AND d.artifact_sha256=p_artifact_sha256) THEN RAISE EXCEPTION 'exact approved event owner/digest required' USING ERRCODE='42501'; END IF;
 UPDATE public.publication_event_delivery SET state='pending',next_attempt_at=clock_timestamp() WHERE event_id=p_event_id AND state='blocked';
 RETURN jsonb_build_object('event_id',p_event_id,'status','retry_requested');
END $$;

DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN (
 'retry_publication_delivery_v1','prepare_publication_approval_v1','read_publication_approval_draft_v1','approve_publication_event_v1','resolve_publication_approval_event_v1','list_publication_deliveries_v1','claim_publication_delivery_v1','finish_publication_delivery_v1') LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role,cohort_exercise_version_publisher,cohort_publication_approval_writer,cohort_publication_event_delivery',f.oid::regprocedure);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %I',f.oid::regprocedure,CASE WHEN f.proname IN ('prepare_publication_approval_v1','read_publication_approval_draft_v1','approve_publication_event_v1') THEN 'cohort_publication_approval_writer' ELSE 'cohort_publication_event_delivery' END);
 END LOOP;
END $$;
COMMIT;
