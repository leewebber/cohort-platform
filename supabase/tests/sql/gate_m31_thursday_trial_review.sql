-- Disposable review only. The local runner supplies pg_temp.m31_trial_payload
-- from the pinned compiler output and seeds its exact catalogue dependencies.
\set ON_ERROR_STOP on

CREATE FUNCTION pg_temp.m31_reject_seal() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.programme_version_id = '5d095027-a4fb-4529-9ade-7a96a75e743f' THEN
    IF (SELECT count(*) FROM public.programme_version_adaptation_permissions
        WHERE version_id = NEW.programme_version_id) <> 1 THEN
      RAISE EXCEPTION 'M3.1 fault injection did not reach the seeded permission';
    END IF;
    RAISE EXCEPTION USING ERRCODE = 'PT031', MESSAGE = 'M3.1 simulated retained-seal failure';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER m31_review_fail_seal
  BEFORE INSERT ON public.programme_publication_artifacts
  FOR EACH ROW EXECUTE FUNCTION pg_temp.m31_reject_seal();

DO $$
DECLARE
  p jsonb := (SELECT payload FROM pg_temp.m31_trial_payload);
  vid uuid := (p->>'programme_version_id')::uuid;
  r jsonb;
BEGIN
  -- A valid legacy call reaches the draft hook, but the deferred check
  -- refuses the transaction because that caller does not retain a seal.
  BEGIN
    r := public.publish_private_exact_programme_version_v2(p);
    IF r->>'status' IS DISTINCT FROM 'published' THEN
      RAISE EXCEPTION 'Legacy publication did not reach the guard: %', r;
    END IF;
    SET CONSTRAINTS public.programme_versions_m31_require_thursday_trial_seal IMMEDIATE;
    RAISE EXCEPTION 'Legacy publication committed without a seal';
  EXCEPTION WHEN integrity_constraint_violation THEN
    IF SQLERRM <> 'M3.1 trial requires retained publication seal' THEN RAISE; END IF;
  END;

  -- The retained writer reaches artifact insertion after seeding the row.
  BEGIN
    PERFORM public.publish_private_exact_programme_version_retained_v1(p);
    RAISE EXCEPTION 'Expected the retained-seal failure';
  EXCEPTION WHEN SQLSTATE 'PT031' THEN NULL;
  END;

  IF EXISTS (SELECT 1 FROM public.programme_versions WHERE id = vid)
    OR EXISTS (SELECT 1 FROM public.programme_version_adaptation_permissions WHERE version_id = vid)
    OR EXISTS (SELECT 1 FROM public.programme_publication_artifacts WHERE programme_version_id = vid)
    OR EXISTS (SELECT 1 FROM public.programme_lineages WHERE code = p#>>'{programme,lineage_code}')
    OR EXISTS (SELECT 1 FROM public.performance_protocols WHERE protocol_id = p#>>'{sessions,0,protocol_id}') THEN
    RAISE EXCEPTION 'Failed trial publication left residue';
  END IF;
  RAISE NOTICE 'PASS: legacy publication and a failure after permission seeding roll back the whole trial';
END;
$$;

DROP TRIGGER m31_review_fail_seal ON public.programme_publication_artifacts;

-- First publication must commit with the deferred check still enabled.
GRANT SELECT ON pg_temp.m31_trial_payload TO service_role;
SET ROLE service_role;
DO $$
DECLARE
  r jsonb := public.publish_private_exact_programme_version_retained_v1(
    (SELECT payload FROM pg_temp.m31_trial_payload)
  );
BEGIN
  IF r->>'status' IS DISTINCT FROM 'published' THEN
    RAISE EXCEPTION 'Initial retained publication failed: %', r;
  END IF;
END;
$$;
RESET ROLE;

DO $$
DECLARE
  p jsonb := (SELECT payload FROM pg_temp.m31_trial_payload);
  vid uuid := (p->>'programme_version_id')::uuid;
  permission_before jsonb;
  seal_before jsonb;
  changed_canonical jsonb;
  changed_text text;
  r jsonb;
BEGIN
  SELECT to_jsonb(a) INTO STRICT permission_before
  FROM public.programme_version_adaptation_permissions a WHERE a.version_id = vid;
  SELECT to_jsonb(s) INTO STRICT seal_before
  FROM public.programme_publication_artifacts s WHERE s.programme_version_id = vid;
  IF permission_before->>'permission_key' IS DISTINCT FROM 'm31-w01-d04-rdl'
     OR permission_before->>'target_ref' IS DISTINCT FROM 'LW10K-W01-D04'
     OR permission_before->>'change_kind' IS DISTINCT FROM 'substitute_approved_equipment'
     OR permission_before->>'athlete_agreement_required' IS DISTINCT FROM 'true'
     OR seal_before->>'canonical_text' IS DISTINCT FROM p->>'package_canonical_json' THEN
    RAISE EXCEPTION 'Sealed permission or canonical package drifted';
  END IF;

  r := public.publish_private_exact_programme_version_retained_v1(p);
  IF r->>'status' IS DISTINCT FROM 'already_published' THEN
    RAISE EXCEPTION 'Exact retry failed: %', r;
  END IF;

  changed_canonical := jsonb_set((p->>'package_canonical_json')::jsonb,
    '{adaptation_permissions,0,scope_note}', to_jsonb('Different permission scope'::text));
  changed_text := public.cohort_tracking_canonical_text(changed_canonical);
  r := public.publish_private_exact_programme_version_retained_v1(p || jsonb_build_object(
    'package_canonical_json', changed_text,
    'package_content_hash', encode(extensions.digest(convert_to(changed_text, 'UTF8'), 'sha256'), 'hex'),
    'adaptation_permissions', changed_canonical->'adaptation_permissions'
  ));
  IF r->>'status' IS DISTINCT FROM 'conflict'
     OR r->>'code' IS DISTINCT FROM 'immutable_version_conflict' THEN
    RAISE EXCEPTION 'Recompiled conflicting retry was not refused: %', r;
  END IF;

  BEGIN
    UPDATE public.programme_version_adaptation_permissions
    SET scope_note = 'Unexpected mutation' WHERE version_id = vid;
    RAISE EXCEPTION 'Published permission mutation was accepted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;

  IF (SELECT count(*) FROM public.programme_version_adaptation_permissions WHERE version_id = vid) <> 1
     OR (SELECT to_jsonb(a) FROM public.programme_version_adaptation_permissions a
         WHERE a.version_id = vid) IS DISTINCT FROM permission_before
     OR (SELECT to_jsonb(s) FROM public.programme_publication_artifacts s
         WHERE s.programme_version_id = vid) IS DISTINCT FROM seal_before THEN
    RAISE EXCEPTION 'Retry changed the permission or retained seal';
  END IF;
  RAISE NOTICE 'PASS: service-role retained publish commits one seal and permission; exact retry and conflicting retry preserve both rows';
END;
$$;

-- Model an ordinary athlete's database role and validated request subject.
-- The retained app test already proved the same reader through actual GoTrue.
INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, raw_app_meta_data,
                        raw_user_meta_data, created_at, updated_at)
VALUES ('a3100000-0000-4000-8000-000000000011', 'authenticated', 'authenticated',
        'm31-review-athlete@example.invalid', now(), '{"provider":"email"}', '{}', now(), now());
INSERT INTO public.profiles (id, display_name, is_athlete, is_coach)
VALUES ('a3100000-0000-4000-8000-000000000011', 'Disposable M3.1 reviewer', true, false);
INSERT INTO public.private_programme_alpha_eligibility (athlete_id, programme_version_id)
VALUES ('a3100000-0000-4000-8000-000000000011', '5d095027-a4fb-4529-9ade-7a96a75e743f');

SET ROLE authenticated;
SET request.jwt.claim.sub = 'a3100000-0000-4000-8000-000000000011';

DO $$
DECLARE
  athlete uuid := auth.uid();
  vid constant uuid := '5d095027-a4fb-4529-9ade-7a96a75e743f';
  aid uuid;
  r jsonb;
BEGIN
  r := public.save_my_training_setup(athlete, 'Asia/Makassar', true);
  IF r->>'status' IS DISTINCT FROM 'ok' THEN RAISE EXCEPTION 'Setup failed: %', r; END IF;
  r := public.acquire_my_private_programme(athlete, vid, (now() AT TIME ZONE 'Asia/Makassar')::date);
  IF r->>'status' IS DISTINCT FROM 'enrolled' THEN RAISE EXCEPTION 'Acquisition failed: %', r; END IF;
  aid := (r->>'enrolment_id')::uuid;
  IF (SELECT count(*) FROM public.read_m31_thursday_trial_permission(aid, vid, 'LW10K-W01-D04')) <> 1 THEN
    RAISE EXCEPTION 'Owner did not receive the sealed permission';
  END IF;
  PERFORM set_config('m31.review_assignment', aid::text, false);
END;
$$;

SELECT public.end_my_fixed_programme(
  auth.uid(), current_setting('m31.review_assignment')::uuid,
  '5d095027-a4fb-4529-9ade-7a96a75e743f'
) AS ended \gset

DO $$
DECLARE
  vid constant uuid := '5d095027-a4fb-4529-9ade-7a96a75e743f';
  aid uuid := current_setting('m31.review_assignment')::uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.programme_assignments
                 WHERE id = aid AND status = 'paused' AND ended_at IS NOT NULL)
     OR EXISTS (SELECT 1 FROM public.read_m31_thursday_trial_permission(aid, vid, 'LW10K-W01-D04')) THEN
    RAISE EXCEPTION 'End programme did not withdraw permission from the owner';
  END IF;
  RAISE NOTICE 'PASS: ordinary athlete sees one permission before End programme and zero after commit';
END;
$$;

RESET ROLE;
RESET request.jwt.claim.sub;
DO $$
BEGIN
  IF (SELECT count(*) FROM public.programme_version_adaptation_permissions
      WHERE version_id = '5d095027-a4fb-4529-9ade-7a96a75e743f') <> 1 THEN
    RAISE EXCEPTION 'End programme modified the authored permission';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.read_m31_thursday_trial_permission(uuid,uuid,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.read_m31_thursday_trial_permission(uuid,uuid,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.read_m31_thursday_trial_permission(uuid,uuid,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.cohort_m31_seed_thursday_trial_permission()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.cohort_m31_require_thursday_trial_seal()', 'EXECUTE') THEN
    RAISE EXCEPTION 'Unexpected M3.1 function ACL';
  END IF;
  RAISE NOTICE 'PASS: End programme preserves the sealed permission row and function ACLs are bounded';
END;
$$;
