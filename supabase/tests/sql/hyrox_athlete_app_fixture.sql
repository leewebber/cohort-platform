\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
SELECT ('bc230000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'authenticated','authenticated','v3-app-'||i||'@example.invalid','{}','{}' FROM generate_series(6,7) i;
INSERT INTO public.profiles(id,display_name,is_coach,is_athlete) SELECT id,'Synthetic app integration',false,true FROM auth.users WHERE id IN ('bc230000-0000-4000-8000-000000000006','bc230000-0000-4000-8000-000000000007');
INSERT INTO public.coach_athlete_relationships(coach_id,athlete_id,status) SELECT 'bc230000-0000-4000-8000-000000000001',id,'active' FROM auth.users WHERE id IN ('bc230000-0000-4000-8000-000000000006','bc230000-0000-4000-8000-000000000007');
DO $$ DECLARE actor text; r jsonb; BEGIN
 FOREACH actor IN ARRAY ARRAY['bc230000-0000-4000-8000-000000000006','bc230000-0000-4000-8000-000000000007'] LOOP
 PERFORM set_config('request.jwt.claim.sub',actor,true); PERFORM set_config('role','authenticated',true);
 r:=public.enrol_athlete_in_private_programme_version('bc230000-0000-4000-8000-000000000040','Asia/Makassar',false);
 PERFORM set_config('role','none',true);
 IF r->>'status' NOT IN ('enrolled','materialised','enrolled_materialised') THEN RAISE EXCEPTION 'app fixture enrol failed %',r; END IF;
 END LOOP;
END $$;
COMMIT;
