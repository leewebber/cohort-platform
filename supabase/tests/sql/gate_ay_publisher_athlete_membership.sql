-- Gate AY — M10 publisher–athlete consent. Generic fixtures only.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_pub_a UUID := 'e0000001-0000-4000-8000-0000000000a1';
  v_pub_b UUID := 'e0000001-0000-4000-8000-0000000000a2';
  v_owner_a UUID := 'e0000001-0000-4000-8000-0000000000b1';
  v_owner_b UUID := 'e0000001-0000-4000-8000-0000000000b2';
  v_athlete UUID := 'e0000001-0000-4000-8000-0000000000c1';
  v_coach UUID := 'e0000001-0000-4000-8000-0000000000c2';
  v_inv JSONB;
  v_acc JSONB;
  v_roster JSONB;
  v_caps JSONB;
  v_count INT;
  v_id UUID;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.publisher_athlete_invitations;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AY migration-time invitations not zero: %', v_count;
  END IF;
  SELECT COUNT(*) INTO v_count FROM public.publisher_athlete_memberships;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AY migration-time memberships not zero: %', v_count;
  END IF;
  SELECT COUNT(*) INTO v_count FROM public.publisher_athlete_membership_events;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AY migration-time events not zero: %', v_count;
  END IF;

  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_owner_a, 'authenticated', 'authenticated',
      'gate-ay-owner-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_owner_b, 'authenticated', 'authenticated',
      'gate-ay-owner-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete, 'authenticated', 'authenticated',
      'gate-ay-athlete@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coach, 'authenticated', 'authenticated',
      'gate-ay-coach@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, display_name, is_athlete, is_coach) VALUES
    (v_owner_a, 'Gate AY owner A', FALSE, TRUE),
    (v_owner_b, 'Gate AY owner B', FALSE, TRUE),
    (v_athlete, 'Gate AY athlete', TRUE, FALSE),
    (v_coach, 'Gate AY coach', FALSE, TRUE)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.content_publishers (id, namespace, display_name, first_party, lifecycle)
  VALUES
    (v_pub_a, 'gate_ay_a', 'Gate AY A', FALSE, 'active'),
    (v_pub_b, 'gate_ay_b', 'Gate AY B', FALSE, 'active')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.content_publisher_principals (publisher_id, principal_id, principal_role)
  VALUES (v_pub_a, v_owner_a, 'owner'), (v_pub_b, v_owner_b, 'owner')
  ON CONFLICT DO NOTHING;

  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_owner_a::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_inv := public.cohort_publisher_athlete_invite(v_pub_a, v_athlete);
  IF v_inv->>'status' IS DISTINCT FROM 'invited' THEN
    RAISE EXCEPTION 'AY invite failed: %', v_inv;
  END IF;
  v_id := (v_inv->>'invitation_id')::UUID;
  v_inv := public.cohort_publisher_athlete_invite(v_pub_a, v_athlete);
  IF v_inv->>'status' IS DISTINCT FROM 'already_pending' THEN
    RAISE EXCEPTION 'AY already_pending failed: %', v_inv;
  END IF;
  v_roster := public.cohort_publisher_athlete_inspect_roster(v_pub_a);
  IF v_roster->>'status' IS DISTINCT FROM 'empty' THEN
    RAISE EXCEPTION 'AY pending must not roster: %', v_roster;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_owner_b::TEXT, true);
  v_inv := public.cohort_publisher_athlete_accept_invitation(v_id);
  IF v_inv->>'status' IS DISTINCT FROM 'unauthorised' THEN
    RAISE EXCEPTION 'AY foreign accept: %', v_inv;
  END IF;
  v_roster := public.cohort_publisher_athlete_inspect_roster(v_pub_a);
  IF v_roster->>'status' IS DISTINCT FROM 'unauthorised' THEN
    RAISE EXCEPTION 'AY cross-publisher roster: %', v_roster;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_coach::TEXT, true);
  v_inv := public.cohort_publisher_athlete_invite(v_pub_a, v_athlete);
  IF v_inv->>'status' IS DISTINCT FROM 'unauthorised' THEN
    RAISE EXCEPTION 'AY coach-only invite: %', v_inv;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  v_acc := public.cohort_publisher_athlete_accept_invitation(v_id);
  IF v_acc->>'status' IS DISTINCT FROM 'accepted' THEN
    RAISE EXCEPTION 'AY accept failed: %', v_acc;
  END IF;
  v_acc := public.cohort_publisher_athlete_accept_invitation(v_id);
  IF v_acc->>'status' IS DISTINCT FROM 'already_active' THEN
    RAISE EXCEPTION 'AY double accept: %', v_acc;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_owner_a::TEXT, true);
  v_roster := public.cohort_publisher_athlete_inspect_roster(v_pub_a);
  IF v_roster->>'status' IS DISTINCT FROM 'ready' THEN
    RAISE EXCEPTION 'AY roster after accept: %', v_roster;
  END IF;
END;
$$;

-- Revoke using a fresh lookup.
DO $$
DECLARE
  v_pub_a UUID := 'e0000001-0000-4000-8000-0000000000a1';
  v_owner_a UUID := 'e0000001-0000-4000-8000-0000000000b1';
  v_athlete UUID := 'e0000001-0000-4000-8000-0000000000c1';
  v_mem UUID;
  v_res JSONB;
BEGIN
  SELECT id INTO v_mem
  FROM public.publisher_athlete_memberships
  WHERE publisher_id = v_pub_a AND athlete_id = v_athlete AND state = 'active';
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_res := public.cohort_publisher_athlete_revoke_membership(v_mem);
  IF v_res->>'status' IS DISTINCT FROM 'revoked' THEN
    RAISE EXCEPTION 'AY athlete revoke: %', v_res;
  END IF;
  v_res := public.cohort_publisher_athlete_revoke_membership(v_mem);
  IF v_res->>'status' IS DISTINCT FROM 'already_revoked' THEN
    RAISE EXCEPTION 'AY already_revoked: %', v_res;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_owner_a::TEXT, true);
  v_res := public.cohort_publisher_athlete_inspect_roster(v_pub_a);
  IF v_res->>'status' IS DISTINCT FROM 'empty' THEN
    RAISE EXCEPTION 'AY roster after revoke: %', v_res;
  END IF;
  v_res := public.cohort_athlete_runtime_capabilities();
  IF v_res->>'publisher_athlete_membership_invite' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'AY owner caps: %', v_res;
  END IF;
  IF (v_res->>'schema_version')::int < 3 THEN
    RAISE EXCEPTION 'AY schema_version: %', v_res;
  END IF;
END;
$$;

SELECT sprint12_record('AY', 'publisher_athlete_consent', 'ok', 'ok', TRUE, TRUE, NULL);
