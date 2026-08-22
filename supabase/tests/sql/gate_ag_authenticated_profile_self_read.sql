-- Gate AG — authenticated profile read privilege and RLS containment.
-- Runs after Gate AF so its Apollo athlete also proves the real app boundary.

DO $$
DECLARE
  v_other UUID := 'a7000001-0000-4000-8000-000000000001';
  v_coach UUID := 'a7000002-0000-4000-8000-000000000002';
BEGIN
  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000',v_other,'authenticated','authenticated',
      'apollo-gate-ag-other@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''),
    ('00000000-0000-0000-0000-000000000000',v_coach,'authenticated','authenticated',
      'apollo-gate-ag-coach@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','','')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id,display_name,is_athlete,is_coach) VALUES
    (v_other,'Apollo Gate AG other athlete',TRUE,FALSE),
    (v_coach,'Apollo Gate AG coach',FALSE,TRUE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  INSERT INTO coach_athlete_relationships (coach_id,athlete_id,status)
  VALUES (v_coach,v_other,'active')
  ON CONFLICT (coach_id,athlete_id) WHERE status = 'active' DO NOTHING;
END $$;

-- The real app query: SupabaseProfileRepository.getProfile →
-- profiles.select().eq('id', userId).maybeSingle().  SET ROLE ensures this
-- proves the underlying table grant as well as RLS, unlike GUC-only tests.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'af000002-0000-4000-8000-000000000002', true);
DO $$
BEGIN
  IF (SELECT count(*) FROM profiles WHERE id = 'af000002-0000-4000-8000-000000000002') <> 1 THEN
    RAISE EXCEPTION 'AG self profile read was not available';
  END IF;
  IF (SELECT count(*) FROM profiles WHERE id = 'a7000001-0000-4000-8000-000000000001') <> 0 THEN
    RAISE EXCEPTION 'AG cross-athlete profile leakage';
  END IF;
  IF (SELECT count(*) FROM programme_assignments
      WHERE athlete_id = 'af000002-0000-4000-8000-000000000002' AND status = 'active') <> 1 THEN
    RAISE EXCEPTION 'AG Apollo active assignment read regressed';
  END IF;
  IF (SELECT count(*) FROM programme_versions v
      JOIN programme_lineages l ON l.id = v.lineage_id
      WHERE l.code = 'APOLLO-BUILD-12-WEEK' AND v.version_number = 1) <> 1 THEN
    RAISE EXCEPTION 'AG Apollo programme version read regressed';
  END IF;
END $$;
ROLLBACK;

SELECT sprint12_record('AG','athlete_self_profile_read','1','1',NULL,TRUE,NULL);
SELECT sprint12_record('AG','athlete_cross_profile_hidden','0','0',NULL,TRUE,NULL);
SELECT sprint12_record('AG','apollo_assignment_read_retained','1','1',NULL,TRUE,NULL);
SELECT sprint12_record('AG','apollo_programme_read_retained','1','1',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'a7000002-0000-4000-8000-000000000002', true);
DO $$
BEGIN
  IF (SELECT count(*) FROM profiles WHERE id = 'a7000001-0000-4000-8000-000000000001') <> 1 THEN
    RAISE EXCEPTION 'AG existing linked coach profile access regressed';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AG','linked_coach_profile_read_retained','1','1',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE postgres;
DO $$
BEGIN
  IF (SELECT count(*) FROM profiles WHERE id = 'af000002-0000-4000-8000-000000000002') <> 1 THEN
    RAISE EXCEPTION 'AG database admin profile access regressed';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AG','database_admin_profile_read_retained','1','1',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM profiles WHERE id = 'af000002-0000-4000-8000-000000000002';
  RAISE EXCEPTION 'AG anonymous profile read unexpectedly permitted';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END $$;
ROLLBACK;
SELECT sprint12_record('AG','anonymous_profile_read_denied','42501','42501',NULL,TRUE,NULL);

SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='AG' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
