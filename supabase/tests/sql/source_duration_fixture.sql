INSERT INTO public.session_blocks(block_id,session_id,position,block_type,title,content,workout_format,timer_config,performance_capture_mode)
 VALUES(public.cohort_stable_uuid('v3.synthetic.source:duration'),'v3.synthetic.source',4,'conditioning','Synthetic duration window','Explicit athlete choice; fixture only','steady_state','{"durationRangeSeconds":[2700,3600]}','completion');
INSERT INTO public.session_block_exercises(id,block_id,exercise_id,position)
 VALUES(public.cohort_stable_uuid('v3.synthetic.source:duration:exercise'),public.cohort_stable_uuid('v3.synthetic.source:duration'),'EX-900900',1);
UPDATE public.session_block_exercises SET prescription=prescription||'{"rest_seconds_range":[150,180]}'::jsonb
 WHERE block_id=public.cohort_stable_uuid('v3.synthetic.source:block:3');
