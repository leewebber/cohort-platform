-- Run against a disposable replay only. The caller supplies pg_temp.m31_fixtures
-- (payload jsonb, approval jsonb), with catalogue rows from retained evidence.
\set ON_ERROR_STOP on

CREATE FUNCTION pg_temp.m31_fail_seal() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.programme_equipment_substitution_approvals
      WHERE version_id = NEW.programme_version_id)
    OR NOT EXISTS (SELECT 1 FROM public.programme_version_adaptation_permissions
      WHERE version_id = NEW.programme_version_id) THEN
    RAISE EXCEPTION 'Fault injection did not reach staged approval and permission';
  END IF;
  RAISE EXCEPTION USING ERRCODE = 'PT031', MESSAGE = 'Simulated seal failure';
END;
$$;
CREATE TRIGGER m31_local_fail_seal BEFORE INSERT ON public.programme_publication_artifacts
  FOR EACH ROW EXECUTE FUNCTION pg_temp.m31_fail_seal();

DO $$
DECLARE f record; r jsonb;
BEGIN
  FOR f IN SELECT * FROM pg_temp.m31_fixtures LOOP
    r := public.publish_private_exact_programme_version_v2(f.payload);
    IF r->>'code' IS DISTINCT FROM 'sealed_equipment_approval_required' THEN
      RAISE EXCEPTION 'Legacy route did not refuse the unsealed approval: %', r;
    END IF;
    BEGIN
      PERFORM public.publish_private_equipment_substitution_v1(f.payload,
        jsonb_set(f.approval, '{source_occurrence_id}', '"wrong-placement"'));
      RAISE EXCEPTION 'Invalid occurrence was accepted';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;
    BEGIN
      PERFORM public.publish_private_equipment_substitution_v1(f.payload,
        jsonb_set(f.approval, '{prescription,load}', '{"type":"fixedKg","kg":80}'));
      RAISE EXCEPTION 'Barbell load carryover was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
      PERFORM public.publish_private_equipment_substitution_v1(f.payload, f.approval);
      RAISE EXCEPTION 'Expected forced seal failure';
    EXCEPTION WHEN SQLSTATE 'PT031' THEN NULL;
    END;
  END LOOP;
  IF EXISTS (SELECT 1 FROM public.programme_versions v JOIN pg_temp.m31_fixtures fixture
      ON v.id = (fixture.payload->>'programme_version_id')::uuid)
    OR EXISTS (SELECT 1 FROM public.programme_equipment_substitution_approvals)
    OR EXISTS (SELECT 1 FROM public.programme_lineages l JOIN pg_temp.m31_fixtures fixture
      ON l.code = fixture.payload#>>'{programme,lineage_code}')
    OR EXISTS (SELECT 1 FROM public.performance_protocols p JOIN pg_temp.m31_fixtures fixture
      ON p.protocol_id = fixture.approval->>'protocol_id') THEN
    RAISE EXCEPTION 'Failed publication left residue';
  END IF;
  RAISE NOTICE 'PASS legacy refusal, wrong placement, fixed load refusal and atomic rollback for both fixture versions';
END;
$$;

DROP TRIGGER m31_local_fail_seal ON public.programme_publication_artifacts;
GRANT SELECT ON pg_temp.m31_fixtures TO service_role;
SET ROLE service_role;
DO $$
DECLARE f record; r jsonb;
BEGIN
  FOR f IN SELECT * FROM pg_temp.m31_fixtures LOOP
    r := public.publish_private_equipment_substitution_v1(f.payload, f.approval);
    IF r->>'status' IS DISTINCT FROM 'published' THEN
      RAISE EXCEPTION 'Service-role publication failed: %', r;
    END IF;
  END LOOP;
END;
$$;
RESET ROLE;

DO $$
DECLARE f record; vid uuid; r jsonb; before_rows jsonb; after_rows jsonb;
BEGIN
  FOR f IN SELECT * FROM pg_temp.m31_fixtures LOOP
    vid := (f.payload->>'programme_version_id')::uuid;
    SELECT jsonb_build_array(to_jsonb(a), to_jsonb(p), to_jsonb(s)) INTO STRICT before_rows
    FROM public.programme_equipment_substitution_approvals a
    JOIN public.programme_version_adaptation_permissions p USING (version_id)
    JOIN public.programme_publication_artifacts s ON s.programme_version_id = a.version_id
    WHERE a.version_id = vid AND a.approval = f.approval AND a.package_hash = s.package_content_hash;
    r := public.publish_private_equipment_substitution_v1(f.payload, f.approval);
    IF r->>'status' IS DISTINCT FROM 'already_published' THEN
      RAISE EXCEPTION 'Exact retry did not return already_published: %', r;
    END IF;
    r := public.publish_private_equipment_substitution_v1(f.payload,
      jsonb_set(f.approval, '{explanation}', '"changed approval"'));
    IF r->>'code' IS DISTINCT FROM 'immutable_equipment_approval_conflict' THEN
      RAISE EXCEPTION 'Changed approval retry did not conflict: %', r;
    END IF;
    BEGIN
      UPDATE public.programme_equipment_substitution_approvals
        SET approval = '{}' WHERE version_id = vid;
      RAISE EXCEPTION 'Sealed approval allowed mutation';
    EXCEPTION WHEN integrity_constraint_violation THEN NULL;
    END;
    SELECT jsonb_build_array(to_jsonb(a), to_jsonb(p), to_jsonb(s)) INTO STRICT after_rows
    FROM public.programme_equipment_substitution_approvals a
    JOIN public.programme_version_adaptation_permissions p USING (version_id)
    JOIN public.programme_publication_artifacts s ON s.programme_version_id = a.version_id
    WHERE a.version_id = vid;
    IF before_rows IS DISTINCT FROM after_rows THEN RAISE EXCEPTION 'Immutable rows changed on retry'; END IF;
  END LOOP;
  IF has_table_privilege('authenticated','public.programme_equipment_substitution_approvals','SELECT')
    OR has_table_privilege('service_role','public.programme_equipment_substitution_approvals','INSERT')
    OR NOT has_function_privilege('authenticated','public.read_my_approved_equipment_substitution_v1(uuid,uuid,uuid,text)','EXECUTE')
    OR has_function_privilege('anon','public.read_my_approved_equipment_substitution_v1(uuid,uuid,uuid,text)','EXECUTE')
    OR has_function_privilege('authenticated','public.publish_private_equipment_substitution_v1(jsonb,jsonb)','EXECUTE')
    OR NOT has_function_privilege('service_role','public.publish_private_equipment_substitution_v1(jsonb,jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'Unexpected approval access grants';
  END IF;
  RAISE NOTICE 'PASS two data-only service-role publications, exact retries, conflicts, immutable rows and scoped grants';
END;
$$;

-- The existing retained publisher still handles a private v2 graph without
-- equipment permission. Roll back this compatibility witness.
DO $$
DECLARE p jsonb; c jsonb; txt text; g jsonb; r jsonb;
  vid constant uuid := 'a3100000-0000-4000-8000-000000000014';
  pid constant text := 'protocol-a3100000-0000-4000-8000-000000000015';
BEGIN
  SELECT payload INTO p FROM pg_temp.m31_fixtures ORDER BY payload->>'programme_version_id' LIMIT 1;
  c := (p->>'package_canonical_json')::jsonb;
  c := jsonb_set(c, '{programme,lineage_code}', '"M31-LOCAL-COMPATIBILITY"');
  c := jsonb_set(c, '{sessions,0,protocol_id}', to_jsonb(pid));
  c := jsonb_set(c, '{sessions,0,session_lineage_id}', '"a3100000-0000-4000-8000-000000000016"');
  c := jsonb_set(c, '{adaptation_permissions}', '[]');
  g := jsonb_set(p->'protocol_graphs', '{0,protocol_id}', to_jsonb(pid));
  txt := public.cohort_tracking_canonical_text(c);
  p := p || jsonb_build_object(
    'programme_version_id',vid,'programme',(c->'programme')-'owner_type'-'library_scope',
    'sessions',c->'sessions','protocol_graphs',g,'adaptation_permissions','[]'::jsonb,
    'package_canonical_json',txt,
    'package_content_hash',encode(extensions.digest(convert_to(txt,'UTF8'),'sha256'),'hex')
  );
  BEGIN
    r := public.publish_private_exact_programme_version_retained_v1(p);
    IF r->>'status' IS DISTINCT FROM 'published'
       OR EXISTS (SELECT 1 FROM public.programme_equipment_substitution_approvals WHERE version_id = vid) THEN
      RAISE EXCEPTION 'Existing no-equipment publication failed: %', r;
    END IF;
    RAISE EXCEPTION USING ERRCODE = 'PT032', MESSAGE = 'Rollback compatibility witness';
  EXCEPTION WHEN SQLSTATE 'PT032' THEN NULL;
  END;
  RAISE NOTICE 'PASS unchanged retained publication for a private v2 graph without equipment permission';
END;
$$;
