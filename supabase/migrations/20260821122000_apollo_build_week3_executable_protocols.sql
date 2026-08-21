-- Apollo Build Week 3 executable protocols.
-- Authoritative content: tool/programmes/apollo_build_12_week_implementation_source.md
-- This intentionally creates session definitions only: no programme version or Plan Package.

-- Deterministic, dogfood-only session lineages and revision ids. Collisions fail closed.
DO $$
DECLARE v_existing integer; v_exact integer;
BEGIN
  SELECT count(*) INTO v_existing FROM public.performance_protocols WHERE protocol_id LIKE 'APOLLO-W3-%-R1';
  SELECT count(*) INTO v_exact FROM public.performance_protocols
   WHERE (protocol_id,name,authoring_scope,organisation_id,lifecycle_status) IN (
    ('APOLLO-W3-MON-R1','Apollo Strength','organisation','apollo-dogfood','draft'),
    ('APOLLO-W3-TUE-R1','Apollo Base','organisation','apollo-dogfood','draft'),
    ('APOLLO-W3-WED-R1','Racehorse Strength','organisation','apollo-dogfood','draft'),
    ('APOLLO-W3-THU-R1','Apollo Engine','organisation','apollo-dogfood','draft'),
    ('APOLLO-W3-FRI-R1','Apollo Sculpt','organisation','apollo-dogfood','draft'),
    ('APOLLO-W3-SAT-R1','Apollo Athletic','organisation','apollo-dogfood','draft'),
    ('APOLLO-W3-SUN-R1','Apollo Long','organisation','apollo-dogfood','draft')
   );
  IF v_existing = 7 AND v_exact = 7 THEN RETURN; END IF;
  IF v_existing <> 0 THEN RAISE EXCEPTION 'Apollo Week 3 protocol identity/content conflict'; END IF;
  INSERT INTO public.session_lineages(id,display_name) VALUES
   ('a1300001-0000-4000-8000-000000000001','Apollo Strength'),('a1300002-0000-4000-8000-000000000002','Apollo Base'),
   ('a1300003-0000-4000-8000-000000000003','Racehorse Strength'),('a1300004-0000-4000-8000-000000000004','Apollo Engine'),
   ('a1300005-0000-4000-8000-000000000005','Apollo Sculpt'),('a1300006-0000-4000-8000-000000000006','Apollo Athletic'),
   ('a1300007-0000-4000-8000-000000000007','Apollo Long');
  INSERT INTO public.performance_protocols(protocol_id,name,purpose,published,content_kind,authoring_scope,endorsement_status,organisation_id,session_lineage_id,revision_number,lifecycle_status,duration_min,primary_session_intent,coaching_notes) VALUES
   ('APOLLO-W3-MON-R1','Apollo Strength','Heavy upper-body strength plus Apollo-priority hypertrophy.','false','session','organisation','organisation_approved','apollo-dogfood','a1300001-0000-4000-8000-000000000001',1,'draft',90,'upper_body_strength','Week 3 overload; weighted dip progresses to four sets.'),
   ('APOLLO-W3-TUE-R1','Apollo Base','Aerobic base, trunk strength and mobility.','false','session','organisation','organisation_approved','apollo-dogfood','a1300002-0000-4000-8000-000000000002',1,'draft',80,'aerobic_base','Track distance, average pace and average HR.'),
   ('APOLLO-W3-WED-R1','Racehorse Strength','Lower-body strength and posterior-chain emphasis.','false','session','organisation','organisation_approved','apollo-dogfood','a1300003-0000-4000-8000-000000000003',1,'draft',90,'lower_body_strength','RDL progresses to five controlled-eccentric sets.'),
   ('APOLLO-W3-THU-R1','Apollo Engine','Hard intervals.','false','session','organisation','organisation_approved','apollo-dogfood','a1300004-0000-4000-8000-000000000004',1,'draft',57,'intervals','Record every interval pace; 20 total quality minutes.'),
   ('APOLLO-W3-FRI-R1','Apollo Sculpt','Upper-body hypertrophy with bodyweight strength retained.','false','session','organisation','organisation_approved','apollo-dogfood','a1300005-0000-4000-8000-000000000005',1,'draft',90,'upper_body_hypertrophy','Isolation rest and neck work are explicit.'),
   ('APOLLO-W3-SAT-R1','Apollo Athletic','Power, athletic strength and mixed conditioning.','false','session','organisation','organisation_approved','apollo-dogfood','a1300006-0000-4000-8000-000000000006',1,'draft',70,'athletic_power','EMOM target RPE 7-8; scale only for clean completion.'),
   ('APOLLO-W3-SUN-R1','Apollo Long','Aerobic endurance and recovery-compatible cardiovascular development.','false','session','organisation','organisation_approved','apollo-dogfood','a1300007-0000-4000-8000-000000000007',1,'draft',85,'aerobic_endurance','No fast finish.');
END $$;

-- Ordered blocks retain approved warm-ups, mobility, intervals and EMOM as executable data.
INSERT INTO public.session_blocks(block_id,session_id,block_type,title,content,workout_format,timer_config,coach_notes,position) VALUES
 ('b1300001-0000-4000-8000-000000000001','APOLLO-W3-MON-R1','warm_up','Apollo Shoulder Balance Warm-Up','Thoracic extension over foam roller: 5 slow reps at 2-3 positions; Open-book rotation: 6/side; Serratus wall slide + reach: 2x8; Wall Y/lower-trap raise: 2x8-10 very light; Single-arm cable/band row with reach: 2x10/side; then 2-4 progressive sets for first compound.','none',NULL,'Do not cue permanent shoulders down and back.',1),
 ('b1300002-0000-4000-8000-000000000002','APOLLO-W3-MON-R1','strength','Main strength','Eight main prescriptions plus controlled neck work.','none',NULL,NULL,2),
 ('b1300003-0000-4000-8000-000000000003','APOLLO-W3-TUE-R1','warm_up','Run preparation','5 minutes brisk walk/easy jog before Zone 2.','none',NULL,NULL,1),
 ('b1300004-0000-4000-8000-000000000004','APOLLO-W3-TUE-R1','conditioning','Zone 2 run','60 minutes conversational Zone 2 at RPE 3-4.','intervals','{"work_seconds":3600,"tracking":["distance","average_pace","average_hr"],"intensity":"zone_2"}'::jsonb,'Track distance, average pace and average HR.',2),
 ('b1300005-0000-4000-8000-000000000005','APOLLO-W3-TUE-R1','core','Hanging Leg Raise','3 x 8-12; rest 60-90 seconds.','none',NULL,NULL,3),
 ('b1300006-0000-4000-8000-000000000006','APOLLO-W3-TUE-R1','cool_down','Full Apollo mobility flow','Knee-to-wall ankle rocks 2x8/side; 90/90 hip switches 2x8/side; adductor rock-back 2x8/side; half-kneeling hip-flexor stretch with reach 45 sec/side; deep-squat pry 2x30 sec; open-book rotation 6/side; wall slide with reach 2x8; passive hang 2x30 sec.','none',NULL,NULL,4),
 ('b1300007-0000-4000-8000-000000000007','APOLLO-W3-WED-R1','warm_up','Lower-body warm-up','Easy cardio 5 min; knee-to-wall ankle rocks 8/side; 90/90 hip switches 8/side; adductor rock-backs 8/side; glute bridge 2x10; bodyweight squat 2x8; progressive squat and RDL warm-up sets.','none',NULL,NULL,1),
 ('b1300008-0000-4000-8000-000000000008','APOLLO-W3-WED-R1','strength','Racehorse strength','All unilateral prescriptions are per leg; carries are heavy.','none',NULL,NULL,2),
 ('b1300009-0000-4000-8000-000000000009','APOLLO-W3-THU-R1','warm_up','Interval warm-up','12-minute easy jog; leg swings 10/side; A-skips 2x20m; 3x20-second strides.','none',NULL,NULL,1),
 ('b1300010-0000-4000-8000-000000000010','APOLLO-W3-THU-R1','conditioning','Hard intervals','5 x 4 minutes hard; 2-minute easy-jog recoveries; 20 total quality minutes.','intervals','{"rounds":5,"work_seconds":240,"recovery_seconds":120,"tracking":["interval_pace"],"effort":"hard","total_quality_seconds":1200}'::jsonb,'Controlled enough that pace does not collapse.',2),
 ('b1300011-0000-4000-8000-000000000011','APOLLO-W3-THU-R1','cool_down','Easy-jog cooldown','10 minutes easy jogging.','none','{"work_seconds":600}'::jsonb,NULL,3),
 ('b1300012-0000-4000-8000-000000000012','APOLLO-W3-FRI-R1','warm_up','Apollo Shoulder Balance Warm-Up','Thoracic extension over foam roller: 5 slow reps at 2-3 positions; Open-book rotation: 6/side; Serratus wall slide + reach: 2x8; Wall Y/lower-trap raise: 2x8-10 very light; Single-arm cable/band row with reach: 2x10/side; then 2-4 progressive sets for first compound.','none',NULL,NULL,1),
 ('b1300013-0000-4000-8000-000000000013','APOLLO-W3-FRI-R1','strength','Apollo Sculpt','Ten prescriptions, including controlled neck work.','none',NULL,'Isolation rest 60-90 seconds; neck rest 45-60 seconds.',2),
 ('b1300014-0000-4000-8000-000000000014','APOLLO-W3-SAT-R1','warm_up','Athletic warm-up','Easy cardio 5 min; ankle pogos 2x20; World''s greatest stretch 5/side; glute bridge 10; jump landing rehearsal 2x3; progressive trap-bar warm-up sets.','none',NULL,NULL,1),
 ('b1300015-0000-4000-8000-000000000015','APOLLO-W3-SAT-R1','strength','Strength and power','Box jumps have full 2-3 minute recovery.','none',NULL,NULL,2),
 ('b1300016-0000-4000-8000-000000000016','APOLLO-W3-SAT-R1','conditioning','Alternating EMOM','Minute 1: RowErg 12 calories. Minute 2: Burpees 8 reps.','emom','{"duration_seconds":600,"interval_seconds":60,"alternating":[{"minute":1,"exercise":"EX-049","calories":12},{"minute":2,"exercise":"EX-009","reps":8}],"target_rpe":"7-8"}'::jsonb,'Reduce calories or reps only if clean work cannot finish inside the minute.',3),
 ('b1300017-0000-4000-8000-000000000017','APOLLO-W3-SUN-R1','warm_up','Run preparation','5 minutes brisk walk/easy jog before Zone 2.','none',NULL,NULL,1),
 ('b1300018-0000-4000-8000-000000000018','APOLLO-W3-SUN-R1','conditioning','Zone 2 run','75 minutes conversational Zone 2 at RPE 3-4; no fast finish.','intervals','{"work_seconds":4500,"tracking":["distance","average_pace","average_hr"],"intensity":"zone_2","fast_finish":false}'::jsonb,NULL,2),
 ('b1300019-0000-4000-8000-000000000019','APOLLO-W3-SUN-R1','cool_down','Full Apollo mobility flow','Knee-to-wall ankle rocks 2x8/side; 90/90 hip switches 2x8/side; adductor rock-back 2x8/side; half-kneeling hip-flexor stretch with reach 45 sec/side; deep-squat pry 2x30 sec; open-book rotation 6/side; wall slide with reach 2x8; passive hang 2x30 sec.','none',NULL,NULL,3);

INSERT INTO public.session_block_exercises(block_id,exercise_id,position,display_label_override,prescription)
SELECT b.block_id,v.exercise_id,v.position,v.label,v.prescription
FROM (VALUES
 ('b1300002-0000-4000-8000-000000000002'::uuid,'EX-095',1,'Weighted Pull-Up','{"sets":4,"reps":"5-6","rir":2,"rest_seconds":180,"tempo":"controlled eccentric, purposeful concentric"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-136',2,'Incline Barbell Bench Press','{"sets":4,"reps":"6-8","rir":2,"rest_seconds":"150-180"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-088',3,'Standing Overhead Press','{"sets":3,"reps":"6-8","rir":2,"rest_seconds":"150-180"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-090',4,'Chest-Supported Row','{"sets":3,"reps":"8-10","rest_seconds":"90-120"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-138',5,'Cable Lateral Raise','{"sets":4,"reps":"12-15","rest_seconds":"60-90"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-087',6,'Weighted Dip','{"sets":4,"reps":"6-10","rest_seconds":"90-120"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-139',7,'Overhead Cable Triceps Extension','{"sets":2,"reps":"10-15","rest_seconds":"60-90"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-145',8,'Neck Flexion','{"sets":2,"reps":"12-15","rir":"2-3","rest_seconds":"45-60","resistance":"manual/towel"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-146',9,'Neck Extension','{"sets":2,"reps":"12-15","rir":"2-3","rest_seconds":"45-60","resistance":"manual/towel"}'::jsonb),('b1300002-0000-4000-8000-000000000002'::uuid,'EX-147',10,'Neck Lateral Flexion','{"sets":2,"reps":"12-15/side","rir":"2-3","rest_seconds":"45-60","resistance":"manual/towel"}'::jsonb),
 ('b1300005-0000-4000-8000-000000000005'::uuid,'EX-119',1,'Hanging Leg Raise','{"sets":3,"reps":"8-12","rest_seconds":"60-90"}'::jsonb),
 ('b1300008-0000-4000-8000-000000000008'::uuid,'EX-073',1,'Back Squat','{"sets":4,"reps":5,"rir":"2-3","rest_seconds":180}'::jsonb),('b1300008-0000-4000-8000-000000000008'::uuid,'EX-078',2,'Romanian Deadlift','{"sets":5,"reps":"6-8","rest_seconds":"150-180","eccentric_seconds":3}'::jsonb),('b1300008-0000-4000-8000-000000000008'::uuid,'EX-141',3,'Bulgarian Split Squat','{"sets":3,"reps":"8/leg","rest_seconds":"90-120"}'::jsonb),('b1300008-0000-4000-8000-000000000008'::uuid,'EX-123',4,'Back Extension','{"sets":3,"reps":"10-12","rest_seconds":"60-90"}'::jsonb),('b1300008-0000-4000-8000-000000000008'::uuid,'EX-140',5,'Leg Curl','{"sets":3,"reps":"10-15","rest_seconds":"60-90"}'::jsonb),('b1300008-0000-4000-8000-000000000008'::uuid,'EX-125',6,'Calf Raise','{"sets":3,"reps":"8-12","rest_seconds":"60-90"}'::jsonb),('b1300008-0000-4000-8000-000000000008'::uuid,'EX-101',7,'Farmer Carry','{"sets":3,"distance_m":"30-40","load":"heavy","rest_seconds":"90-120"}'::jsonb),
 ('b1300010-0000-4000-8000-000000000010'::uuid,'EX-129',1,'Run intervals','{"rounds":5,"work_seconds":240,"recovery_seconds":120,"record":"pace_each_interval","total_quality_seconds":1200}'::jsonb),
 ('b1300013-0000-4000-8000-000000000013'::uuid,'EX-087',1,'Weighted Dip','{"sets":3,"reps":"8-10","rest_seconds":"90-120"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-137',2,'Neutral-Grip Pull-Up','{"sets":3,"reps":"8-10","rest_seconds":"90-120"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-142',3,'One-Arm Cable Row','{"sets":3,"reps":"10-12/side","rest_seconds":"90-120"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-143',4,'Low-to-High Cable Fly','{"sets":4,"reps":"10-15","rest_seconds":"60-90"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-138',5,'Cable Lateral Raise','{"sets":4,"reps":"12-20","rest_seconds":"60-90"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-144',6,'Rear-Delt Fly','{"sets":4,"reps":"15-20","rest_seconds":"60-90"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-139',7,'Overhead Triceps Extension','{"sets":4,"reps":"10-15","rest_seconds":"60-90"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-120',8,'Incline Dumbbell Curl','{"sets":2,"reps":"10-12","rest_seconds":"60-90"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-113',9,'Ab Wheel','{"sets":3,"reps":"6-12","rest_seconds":"60-90"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-145',10,'Neck Flexion','{"sets":2,"reps":"12-15","rest_seconds":"45-60"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-146',11,'Neck Extension','{"sets":2,"reps":"12-15","rest_seconds":"45-60"}'::jsonb),('b1300013-0000-4000-8000-000000000013'::uuid,'EX-147',12,'Neck Lateral Flexion','{"sets":2,"reps":"12-15/side","rest_seconds":"45-60"}'::jsonb),
 ('b1300015-0000-4000-8000-000000000015'::uuid,'EX-059',1,'Box Jump','{"sets":4,"reps":3,"rest_seconds":"120-180"}'::jsonb),('b1300015-0000-4000-8000-000000000015'::uuid,'EX-079',2,'Trap-Bar Deadlift','{"sets":3,"reps":"4-6","rir":"2-3","rest_seconds":"150-180"}'::jsonb),('b1300015-0000-4000-8000-000000000015'::uuid,'EX-025',3,'Walking Dumbbell Lunge','{"sets":3,"reps":"10 steps/leg","rest_seconds":"90-120"}'::jsonb),('b1300015-0000-4000-8000-000000000015'::uuid,'EX-122',4,'Nordic Hamstring Curl','{"sets":3,"reps":"4-6","rest_seconds":"90-120"}'::jsonb),('b1300015-0000-4000-8000-000000000015'::uuid,'EX-101',5,'Farmer Carry','{"sets":3,"distance_m":40,"rest_seconds":"90-120"}'::jsonb),
 ('b1300016-0000-4000-8000-000000000016'::uuid,'EX-049',1,'RowErg','{"calories":12,"minute":1}'::jsonb),('b1300016-0000-4000-8000-000000000016'::uuid,'EX-009',2,'Burpees','{"reps":8,"minute":2}'::jsonb),
 ('b1300018-0000-4000-8000-000000000018'::uuid,'EX-129',1,'Zone 2 Run','{"duration_seconds":4500,"rpe":"3-4","fast_finish":false}'::jsonb)
) AS v(block_id,exercise_id,position,label,prescription)
JOIN public.session_blocks b ON b.block_id=v.block_id
WHERE NOT EXISTS (SELECT 1 FROM public.session_block_exercises e WHERE e.block_id=v.block_id);

-- A partial block/exercise seed is a corruption, never an invitation to silently repair it.
DO $$
BEGIN
 IF (SELECT count(*) FROM public.session_blocks WHERE session_id LIKE 'APOLLO-W3-%-R1') <> 19
    OR (SELECT count(*) FROM public.session_block_exercises e JOIN public.session_blocks b ON b.block_id=e.block_id WHERE b.session_id LIKE 'APOLLO-W3-%-R1') <> 39 THEN
   RAISE EXCEPTION 'Apollo Week 3 seed conflict: deterministic content is incomplete or mismatched';
 END IF;
END $$;
