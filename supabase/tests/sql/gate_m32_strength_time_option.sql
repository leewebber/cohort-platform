-- Run only on a disposable replay. The runner provides one exact fixture in pg_temp.m32_fixture.
\set ON_ERROR_STOP on
CREATE FUNCTION pg_temp.m32_fail_after_seal() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT FROM public.programme_publication_artifacts
                  WHERE programme_version_id = NEW.version_id
                    AND scope_seal_hash = NEW.scope_seal_hash) THEN
    RAISE EXCEPTION 'Fault injection did not reach retained publication';
  END IF;
  RAISE EXCEPTION USING ERRCODE = 'PT035', MESSAGE = 'Simulated approval insertion failure';
END;
$$;
CREATE TRIGGER m32_local_fail_after_seal BEFORE INSERT ON public.programme_strength_time_approvals
  FOR EACH ROW EXECUTE FUNCTION pg_temp.m32_fail_after_seal();

DO $$
DECLARE f record; vid uuid;
BEGIN
  SELECT * INTO STRICT f FROM pg_temp.m32_fixture;
  vid := (f.payload->>'programme_version_id')::uuid;
  BEGIN
    PERFORM public.publish_private_strength_time_option_v1(f.payload,
      jsonb_set(f.approval, '{short_minutes}', '29'));
    RAISE EXCEPTION 'Unmatched duration accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM public.publish_private_strength_time_option_v1(f.payload,
      jsonb_set(f.approval, '{omitted_block_position}', '2'));
    RAISE EXCEPTION 'Main strength block allowed to be omitted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM public.publish_private_strength_time_option_v1(f.payload, f.approval);
    RAISE EXCEPTION 'Expected rollback witness';
  EXCEPTION WHEN SQLSTATE 'PT035' THEN NULL;
  END;
  IF EXISTS (SELECT FROM public.programme_versions WHERE id = vid)
     OR EXISTS (SELECT FROM public.programme_publication_artifacts WHERE programme_version_id = vid)
     OR EXISTS (SELECT FROM public.programme_strength_time_approvals WHERE version_id = vid)
     OR EXISTS (SELECT FROM public.performance_protocols WHERE protocol_id = f.approval->>'protocol_id') THEN
    RAISE EXCEPTION 'Failed time publication left residue';
  END IF;
  RAISE NOTICE 'PASS invalid duration and required-block omission refuse; failed approval rolls back the sealed graph';
END;
$$;
DROP TRIGGER m32_local_fail_after_seal ON public.programme_strength_time_approvals;

GRANT SELECT ON pg_temp.m32_fixture TO service_role;
SET ROLE service_role;
DO $$
DECLARE f record; r jsonb;
BEGIN
  SELECT * INTO STRICT f FROM pg_temp.m32_fixture;
  r := public.publish_private_strength_time_option_v1(f.payload, f.approval);
  IF r->>'status' IS DISTINCT FROM 'published' THEN RAISE EXCEPTION 'Service-role publication refused: %', r; END IF;
END;
$$;
RESET ROLE;

DO $$
DECLARE f record; r jsonb; before_rows jsonb; after_rows jsonb; vid uuid;
BEGIN
  SELECT * INTO STRICT f FROM pg_temp.m32_fixture;
  vid := (f.payload->>'programme_version_id')::uuid;
  SELECT jsonb_build_array(to_jsonb(a),to_jsonb(s)) INTO STRICT before_rows
  FROM public.programme_strength_time_approvals a JOIN public.programme_publication_artifacts s ON s.programme_version_id = a.version_id
  WHERE a.version_id = vid AND a.approval = f.approval AND a.scope_seal_hash = s.scope_seal_hash;
  r := public.publish_private_strength_time_option_v1(f.payload, f.approval);
  IF r->>'status' IS DISTINCT FROM 'already_published' THEN RAISE EXCEPTION 'Exact retry failed: %', r; END IF;
  r := public.publish_private_strength_time_option_v1(f.payload, jsonb_set(f.approval,'{short_minutes}','29'));
  IF r->>'code' IS DISTINCT FROM 'immutable_time_approval_conflict' THEN RAISE EXCEPTION 'Changed approval retry accepted: %', r; END IF;
  r := public.publish_private_strength_time_option_v1(
    jsonb_set(f.payload,'{protocol_graphs,0,blocks,1,exercises,0,prescription,sets}','3'), f.approval);
  IF r->>'code' IS DISTINCT FROM 'immutable_version_conflict' THEN RAISE EXCEPTION 'Changed graph retry accepted: %', r; END IF;
  BEGIN
    UPDATE public.programme_strength_time_approvals SET approval = '{}' WHERE version_id = vid;
    RAISE EXCEPTION 'Sealed approval could be changed';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;
  SELECT jsonb_build_array(to_jsonb(a),to_jsonb(s)) INTO STRICT after_rows
  FROM public.programme_strength_time_approvals a JOIN public.programme_publication_artifacts s ON s.programme_version_id = a.version_id
  WHERE a.version_id = vid;
  IF before_rows IS DISTINCT FROM after_rows THEN RAISE EXCEPTION 'Retry changed retained rows'; END IF;

  IF has_table_privilege('authenticated','public.programme_strength_time_approvals','SELECT')
     OR has_table_privilege('service_role','public.programme_strength_time_approvals','INSERT')
     OR has_function_privilege('anon','public.read_my_approved_time_option_v1(uuid,uuid,uuid,text)','EXECUTE')
     OR has_function_privilege('service_role','public.read_my_approved_time_option_v1(uuid,uuid,uuid,text)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.read_my_approved_time_option_v1(uuid,uuid,uuid,text)','EXECUTE')
     OR has_function_privilege('authenticated','public.publish_private_strength_time_option_v1(jsonb,jsonb)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.publish_private_strength_time_option_v1(jsonb,jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'Unexpected strength time authority';
  END IF;
  RAISE NOTICE 'PASS sealed service-role publication, immutable retries, graph/approval conflicts, and exact read grants';
END;
$$;
