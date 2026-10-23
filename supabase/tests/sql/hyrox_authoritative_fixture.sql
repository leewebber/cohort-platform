\set ON_ERROR_STOP on
INSERT INTO auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data) VALUES
 ('bc230000-0000-4000-8000-000000000001','authenticated','authenticated','v3-coach@example.invalid','{}','{}'),
 ('bc230000-0000-4000-8000-000000000002','authenticated','authenticated','v3-a@example.invalid','{}','{}'),
 ('bc230000-0000-4000-8000-000000000003','authenticated','authenticated','v3-b@example.invalid','{}','{}'),
 ('bc230000-0000-4000-8000-000000000004','authenticated','authenticated','v3-c@example.invalid','{}','{}'),
 ('bc230000-0000-4000-8000-000000000005','authenticated','authenticated','v3-d@example.invalid','{}','{}');
INSERT INTO public.profiles(id,display_name,is_coach,is_athlete)
 SELECT id,'Synthetic authoritative gate',id::text LIKE '%0001',id::text NOT LIKE '%0001' FROM auth.users WHERE id::text LIKE 'bc230000-%';
INSERT INTO public.exercises_v2(exercise_id,name,published) VALUES
 ('EX-900900','Synthetic running fixture',true),('EX-900901','Synthetic rowing fixture',true),('EX-900902','Synthetic squat fixture',true);
SELECT public.sprint12_ensure_published_session('v3.synthetic.source','bc230000-0000-4000-8000-000000000010',1,'Synthetic source fixture');
INSERT INTO public.session_blocks(block_id,session_id,position,block_type,title,content,workout_format,timer_config,performance_capture_mode)
 SELECT public.cohort_stable_uuid('v3.synthetic.source:block:'||i),'v3.synthetic.source',i,
 CASE i WHEN 3 THEN 'strength' ELSE 'conditioning' END,'Synthetic block '||i,'Approved rule arithmetic fixture only',
 CASE i WHEN 3 THEN 'none' ELSE 'intervals' END,
 CASE i WHEN 1 THEN '{"workSeconds":240,"restSeconds":120,"rounds":4}'::jsonb WHEN 2 THEN '{"workSeconds":120,"restSeconds":90,"rounds":6}'::jsonb ELSE NULL END,'auto'
 FROM generate_series(1,3) i;
INSERT INTO public.session_block_exercises(id,block_id,exercise_id,position,prescription)
 SELECT public.cohort_stable_uuid('v3.synthetic.source:ex:'||i||':1'),public.cohort_stable_uuid('v3.synthetic.source:block:'||i),
 'EX-'||(900899+i),1, CASE i WHEN 3 THEN '{"sets":3,"reps":8,"five_rm_basis_points":8000,"rir":"3"}'::jsonb ELSE NULL END FROM generate_series(1,3) i;
CREATE TABLE public.v3_gate_data(key text PRIMARY KEY,document jsonb NOT NULL);
