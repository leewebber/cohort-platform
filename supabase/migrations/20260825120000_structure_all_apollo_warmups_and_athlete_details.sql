-- Structure every authored Apollo preparation/mobility block using the
-- founder-approved Section F prescriptions. Existing protocol and package
-- identities remain unchanged. Internal provenance is retained here in SQL
-- comments and fail-closed assertions, never in athlete-facing fields.

CREATE TEMP TABLE expected_apollo_preparation_blocks ON COMMIT DROP AS
SELECT
  block_id,
  session_id,
  title,
  CASE title
    WHEN 'Apollo Shoulder Balance Warm-Up' THEN 'shoulder'
    WHEN 'Run preparation' THEN 'run_preparation'
    WHEN 'Full Apollo mobility flow' THEN 'mobility'
    WHEN 'Apollo mobility' THEN 'mobility'
    WHEN 'Lower-body warm-up' THEN 'lower'
    WHEN 'Interval warm-up' THEN 'interval'
    WHEN 'Athletic warm-up' THEN 'athletic'
  END AS template
FROM public.session_blocks
WHERE session_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
  AND title IN (
    'Apollo Shoulder Balance Warm-Up',
    'Run preparation',
    'Full Apollo mobility flow',
    'Apollo mobility',
    'Lower-body warm-up',
    'Interval warm-up',
    'Athletic warm-up'
  );

CREATE TEMP TABLE expected_apollo_preparation_links (
  template TEXT NOT NULL,
  position INTEGER NOT NULL,
  exercise_id TEXT NOT NULL,
  label TEXT NOT NULL,
  prescription JSONB NOT NULL,
  PRIMARY KEY (template, position),
  UNIQUE (template, exercise_id)
) ON COMMIT DROP;

INSERT INTO expected_apollo_preparation_links
  (template, position, exercise_id, label, prescription)
VALUES
  ('shoulder', 1, 'EX-150', 'Thoracic extension over foam roller', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"tempo":"slow","coach_cue":"Use 2–3 positions."}'),
  ('shoulder', 2, 'EX-151', 'Open-book rotation', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true,"coach_cue":"Complete each side."}'),
  ('shoulder', 3, 'EX-152', 'Serratus wall slide + reach', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'),
  ('shoulder', 4, 'EX-153', 'Wall Y/lower-trap raise', '{"sets":2,"reps":{"type":"range","min_reps":8,"max_reps":10},"load":{"type":"freeText","text":"Very light"}}'),
  ('shoulder', 5, 'EX-154', 'Single-arm cable/band row with reach', '{"sets":2,"reps":{"type":"exact","exact_reps":10},"per_side":true,"coach_cue":"Complete each side."}'),
  ('run_preparation', 1, 'EX-161', 'Brisk walk or easy jog', '{"sets":1,"reps":{"type":"duration","text":"5 min"},"coach_cue":"Complete before starting Zone 2."}'),
  ('mobility', 1, 'EX-156', 'Knee-to-wall ankle rocks', '{"sets":2,"reps":{"type":"exact","exact_reps":8},"per_side":true}'),
  ('mobility', 2, 'EX-157', '90/90 hip switches', '{"sets":2,"reps":{"type":"exact","exact_reps":8},"per_side":true}'),
  ('mobility', 3, 'EX-158', 'Adductor rock-back', '{"sets":2,"reps":{"type":"exact","exact_reps":8},"per_side":true}'),
  ('mobility', 4, 'EX-168', 'Half-kneeling hip-flexor stretch with reach', '{"sets":1,"reps":{"type":"duration","text":"45 sec"},"per_side":true}'),
  ('mobility', 5, 'EX-169', 'Deep-squat pry', '{"sets":2,"reps":{"type":"duration","text":"30 sec"}}'),
  ('mobility', 6, 'EX-151', 'Open-book rotation', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true}'),
  ('mobility', 7, 'EX-152', 'Wall slide with reach', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'),
  ('mobility', 8, 'EX-111', 'Passive hang', '{"sets":2,"reps":{"type":"duration","text":"30 sec"}}'),
  ('lower', 1, 'EX-155', 'Easy cardio', '{"sets":1,"reps":{"type":"duration","text":"5 min"}}'),
  ('lower', 2, 'EX-156', 'Knee-to-wall ankle rocks', '{"sets":1,"reps":{"type":"exact","exact_reps":8},"per_side":true}'),
  ('lower', 3, 'EX-157', '90/90 hip switches', '{"sets":1,"reps":{"type":"exact","exact_reps":8},"per_side":true}'),
  ('lower', 4, 'EX-158', 'Adductor rock-backs', '{"sets":1,"reps":{"type":"exact","exact_reps":8},"per_side":true}'),
  ('lower', 5, 'EX-159', 'Glute bridge', '{"sets":2,"reps":{"type":"exact","exact_reps":10}}'),
  ('lower', 6, 'EX-160', 'Bodyweight squat', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'),
  ('interval', 1, 'EX-129', 'Easy jog', '{"sets":1,"reps":{"type":"duration","text":"12 min"}}'),
  ('interval', 2, 'EX-165', 'Leg swings', '{"sets":1,"reps":{"type":"exact","exact_reps":10},"per_side":true}'),
  ('interval', 3, 'EX-166', 'A-skips', '{"sets":2,"reps":{"type":"distance","text":"20 m"}}'),
  ('interval', 4, 'EX-167', 'Running strides', '{"sets":3,"reps":{"type":"duration","text":"20 sec"}}'),
  ('athletic', 1, 'EX-155', 'Easy cardio', '{"sets":1,"reps":{"type":"duration","text":"5 min"}}'),
  ('athletic', 2, 'EX-162', 'Ankle pogos', '{"sets":2,"reps":{"type":"exact","exact_reps":20}}'),
  ('athletic', 3, 'EX-163', 'World''s greatest stretch', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"per_side":true}'),
  ('athletic', 4, 'EX-159', 'Glute bridge', '{"sets":1,"reps":{"type":"exact","exact_reps":10}}'),
  ('athletic', 5, 'EX-164', 'Jump landing rehearsal', '{"sets":2,"reps":{"type":"exact","exact_reps":3}}');

DO $$
DECLARE
  v_total INTEGER;
  v_exact INTEGER;
  v_existing_links INTEGER;
  v_exact_existing_links INTEGER;
BEGIN
  SELECT count(*) INTO v_total FROM expected_apollo_preparation_blocks;
  IF v_total <> 106 THEN
    RAISE EXCEPTION 'Apollo preparation inventory conflict: expected 106 blocks, found %', v_total;
  END IF;

  IF (SELECT count(*) FROM expected_apollo_preparation_blocks WHERE template = 'shoulder') <> 24
    OR (SELECT count(*) FROM expected_apollo_preparation_blocks WHERE template = 'run_preparation') <> 23
    OR (SELECT count(*) FROM expected_apollo_preparation_blocks WHERE template = 'mobility') <> 25
    OR (SELECT count(*) FROM expected_apollo_preparation_blocks WHERE template = 'lower') <> 12
    OR (SELECT count(*) FROM expected_apollo_preparation_blocks WHERE template = 'interval') <> 11
    OR (SELECT count(*) FROM expected_apollo_preparation_blocks WHERE template = 'athletic') <> 11 THEN
    RAISE EXCEPTION 'Apollo preparation inventory conflict: template counts differ from the approved 84-protocol source';
  END IF;

  SELECT count(*) INTO v_exact
  FROM public.session_blocks b
  JOIN expected_apollo_preparation_blocks e USING (block_id)
  WHERE b.block_type IN ('warm_up', 'cool_down')
    AND (
      (e.template = 'shoulder' AND (
        b.content IN (
          'Thoracic extension over foam roller: 5 slow reps at 2-3 positions; Open-book rotation: 6/side; Serratus wall slide + reach: 2x8; Wall Y/lower-trap raise: 2x8-10 very light; Single-arm cable/band row with reach: 2x10/side; then 2-4 progressive sets for first compound.',
          'Thoracic extension over foam roller: 5 slow reps at 2-3 positions; Open-book rotation: 6/side; Serratus wall slide + reach: 2x8; Wall Y/lower-trap raise: 2x8-10 very light; Single-arm cable/band row with reach: 2x10/side; then progressive weighted pull-up warm-up sets.',
          ''
        )
        AND b.coach_notes IN (
          'Do not cue permanent shoulders down and back.',
          'Then 2-4 progressive sets for first compound. Do not cue permanent shoulders down and back.',
          'Then 2-4 progressive sets for first compound.',
          'Then complete progressive weighted pull-up warm-up sets. Do not cue permanent shoulders down and back.'
        ) OR b.coach_notes IS NULL
      ))
      OR (e.template = 'run_preparation'
        AND b.content IN ('5 minutes brisk walk/easy jog before Zone 2.', '')
        AND b.coach_notes IS NULL)
      OR (b.title = 'Full Apollo mobility flow'
        AND b.content IN ('Knee-to-wall ankle rocks 2x8/side; 90/90 hip switches 2x8/side; adductor rock-back 2x8/side; half-kneeling hip-flexor stretch with reach 45 sec/side; deep-squat pry 2x30 sec; open-book rotation 6/side; wall slide with reach 2x8; passive hang 2x30 sec.', '')
        AND b.coach_notes IS NULL)
      OR (b.title = 'Apollo mobility'
        AND b.content IN ('15-20 minutes Apollo mobility.', '20 minutes Apollo mobility.', '')
        AND b.coach_notes IS NULL)
      OR (e.template = 'lower'
        AND b.content IN ('Easy cardio 5 min; knee-to-wall ankle rocks 8/side; 90/90 hip switches 8/side; adductor rock-backs 8/side; glute bridge 2x10; bodyweight squat 2x8; progressive squat and RDL warm-up sets.', '')
        AND (b.coach_notes = 'Then complete progressive squat and RDL warm-up sets.' OR b.coach_notes IS NULL))
      OR (e.template = 'interval'
        AND b.content IN ('12-minute easy jog; leg swings 10/side; A-skips 2x20m; 3x20-second strides.', '')
        AND b.coach_notes IS NULL)
      OR (e.template = 'athletic'
        AND b.content IN ('Easy cardio 5 min; ankle pogos 2x20; World''s greatest stretch 5/side; glute bridge 10; jump landing rehearsal 2x3; progressive trap-bar warm-up sets.', '')
        AND (b.coach_notes = 'Then complete progressive trap-bar warm-up sets.' OR b.coach_notes IS NULL))
    );
  IF v_exact <> 106 THEN
    RAISE EXCEPTION 'Apollo preparation correction refused: % of 106 blocks match approved pre/post state', v_exact;
  END IF;

  SELECT count(*) INTO v_existing_links
  FROM public.session_block_exercises x
  JOIN expected_apollo_preparation_blocks e USING (block_id);

  SELECT count(*) INTO v_exact_existing_links
  FROM public.session_block_exercises x
  JOIN expected_apollo_preparation_blocks e USING (block_id)
  JOIN expected_apollo_preparation_links t
    ON t.template = e.template
   AND t.position = x.position
   AND t.exercise_id = x.exercise_id
   AND t.label = x.display_label_override
   AND t.prescription = x.prescription;
  IF NOT (
    (v_existing_links = 5 AND v_exact_existing_links = 5
      AND (SELECT count(*) FROM public.session_block_exercises
           WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID) = 5)
    OR (v_existing_links = 514 AND v_exact_existing_links = 514)
  ) THEN
    RAISE EXCEPTION 'Apollo preparation correction refused: existing ordered identities, labels, or prescriptions conflict with the approved templates';
  END IF;
END $$;

-- New deterministic identities are allocated only where no canonical movement
-- already exists. Running, passive hang, open-book rotation, and wall slide
-- reuse EX-129, EX-111, EX-151, and EX-152 respectively.
DO $$
DECLARE
  v_existing INTEGER;
  v_exact INTEGER;
  v_name_slug_conflicts INTEGER;
BEGIN
  SELECT count(*) INTO v_existing
  FROM public.exercises_v2
  WHERE exercise_id BETWEEN 'EX-155' AND 'EX-169';

  SELECT count(*) INTO v_exact
  FROM public.exercises_v2
  WHERE (exercise_id, name, slug, published) IN (
    ('EX-155', 'Easy Cardio', 'easy-cardio', TRUE),
    ('EX-156', 'Knee-to-Wall Ankle Rock', 'knee-to-wall-ankle-rock', TRUE),
    ('EX-157', '90/90 Hip Switch', '90-90-hip-switch', TRUE),
    ('EX-158', 'Adductor Rock-Back', 'adductor-rock-back', TRUE),
    ('EX-159', 'Glute Bridge', 'glute-bridge', TRUE),
    ('EX-160', 'Bodyweight Squat', 'bodyweight-squat', TRUE),
    ('EX-161', 'Brisk Walk or Easy Jog', 'brisk-walk-or-easy-jog', TRUE),
    ('EX-162', 'Ankle Pogo', 'ankle-pogo', TRUE),
    ('EX-163', 'World''s Greatest Stretch', 'worlds-greatest-stretch', TRUE),
    ('EX-164', 'Jump Landing Rehearsal', 'jump-landing-rehearsal', TRUE),
    ('EX-165', 'Leg Swing', 'leg-swing', TRUE),
    ('EX-166', 'A-Skip', 'a-skip', TRUE),
    ('EX-167', 'Running Stride', 'running-stride', TRUE),
    ('EX-168', 'Half-Kneeling Hip-Flexor Stretch with Reach', 'half-kneeling-hip-flexor-stretch-reach', TRUE),
    ('EX-169', 'Deep-Squat Pry', 'deep-squat-pry', TRUE)
  );

  SELECT count(*) INTO v_name_slug_conflicts
  FROM public.exercises_v2
  WHERE exercise_id NOT BETWEEN 'EX-155' AND 'EX-169'
    AND (
      lower(btrim(COALESCE(name, ''))) IN (
        'easy cardio', 'knee-to-wall ankle rock', '90/90 hip switch',
        'adductor rock-back', 'glute bridge', 'bodyweight squat',
        'brisk walk or easy jog', 'ankle pogo', 'world''s greatest stretch',
        'jump landing rehearsal', 'leg swing', 'a-skip', 'running stride',
        'half-kneeling hip-flexor stretch with reach', 'deep-squat pry'
      )
      OR lower(btrim(COALESCE(slug, ''))) IN (
        'easy-cardio', 'knee-to-wall-ankle-rock', '90-90-hip-switch',
        'adductor-rock-back', 'glute-bridge', 'bodyweight-squat',
        'brisk-walk-or-easy-jog', 'ankle-pogo', 'worlds-greatest-stretch',
        'jump-landing-rehearsal', 'leg-swing', 'a-skip', 'running-stride',
        'half-kneeling-hip-flexor-stretch-reach', 'deep-squat-pry'
      )
    );

  IF v_name_slug_conflicts <> 0 THEN
    RAISE EXCEPTION 'Apollo warm-up identity seed refused: an existing canonical name or slug must be reused explicitly';
  END IF;
  IF v_existing = 15 AND v_exact = 15 THEN RETURN; END IF;
  IF v_existing <> 0 THEN
    RAISE EXCEPTION 'Apollo warm-up identity seed conflict: EX-155..EX-169 must be absent or exactly expected';
  END IF;

  INSERT INTO public.exercises_v2 (
    exercise_id, name, slug, published, category, movement_pattern,
    equipment, primary_capability, purpose, setup, execution,
    coaching_cues, common_mistakes
  ) VALUES
    ('EX-155', 'Easy Cardio', 'easy-cardio', TRUE, 'Cardio', 'Locomotion', 'Appropriate cardio equipment or bodyweight', 'Preparation', 'Gradually raises body temperature before lower-body or athletic work.', 'Choose an easy cardio mode available to you.', 'Move continuously at an easy effort for the prescribed time.', 'Keep the effort easy and finish ready for the next movement.', 'Starting too hard and turning the preparation into conditioning.'),
    ('EX-156', 'Knee-to-Wall Ankle Rock', 'knee-to-wall-ankle-rock', TRUE, 'Mobility', 'Ankle Dorsiflexion', 'Wall', 'Mobility', 'Prepares ankle movement for squatting, landing, and running.', 'Face a wall with one foot flat and the toes a short distance away.', 'Drive the knee toward the wall while keeping the heel grounded, then return.', 'Track the knee over the toes and keep the whole foot down.', 'Lifting the heel or letting the arch collapse.'),
    ('EX-157', '90/90 Hip Switch', '90-90-hip-switch', TRUE, 'Mobility', 'Hip Rotation', 'Bodyweight', 'Mobility', 'Prepares controlled hip rotation for lower-body movement.', 'Sit tall with both knees bent and feet wider than hip width.', 'Rotate both knees from one side to the other under control.', 'Stay tall and move through the hips rather than forcing range.', 'Rushing or collapsing heavily through the torso.'),
    ('EX-158', 'Adductor Rock-Back', 'adductor-rock-back', TRUE, 'Mobility', 'Hip Adduction', 'Bodyweight', 'Mobility', 'Prepares the inner thigh and hips for squatting and lunging.', 'Start on hands and knees, then extend one leg out to the side with the foot grounded.', 'Keep a neutral spine and guide the hips backward, then return.', 'Move smoothly and keep the extended foot planted.', 'Rounding the back or forcing the end position.'),
    ('EX-159', 'Glute Bridge', 'glute-bridge', TRUE, 'Activation', 'Hip Extension', 'Bodyweight', 'Hip Control', 'Prepares hip extension before lower-body strength and power work.', 'Lie on your back with knees bent and feet planted.', 'Drive through the feet to lift the hips, pause tall, then lower with control.', 'Keep the ribs settled and finish through the hips.', 'Overarching the lower back instead of extending the hips.'),
    ('EX-160', 'Bodyweight Squat', 'bodyweight-squat', TRUE, 'Squat', 'Squat', 'Bodyweight', 'Movement Preparation', 'Rehearses the squat pattern before loaded work.', 'Stand in a comfortable squat stance with the whole foot grounded.', 'Sit between the hips to a controlled depth, then stand tall.', 'Keep the knees tracking with the toes and maintain balance through the foot.', 'Heels lifting or knees collapsing inward.'),
    ('EX-161', 'Brisk Walk or Easy Jog', 'brisk-walk-or-easy-jog', TRUE, 'Cardio', 'Locomotion', 'Running Shoes', 'Preparation', 'Gradually prepares the body for the prescribed aerobic run.', 'Choose a brisk walk or easy jog that feels comfortable.', 'Move continuously for the prescribed time before starting Zone 2.', 'Keep the effort conversational and unhurried.', 'Starting at the main-session pace before the preparation is complete.'),
    ('EX-162', 'Ankle Pogo', 'ankle-pogo', TRUE, 'Plyometric', 'Jump', 'Bodyweight', 'Elastic Strength', 'Prepares quick, low-amplitude ankle stiffness for jumping and athletic work.', 'Stand tall with feet under the hips and knees softly unlocked.', 'Make small repeated hops from the ankles with brief ground contact.', 'Stay tall, quiet, and springy.', 'Turning the movement into deep squat jumps.'),
    ('EX-163', 'World''s Greatest Stretch', 'worlds-greatest-stretch', TRUE, 'Mobility', 'Lunge and Rotation', 'Bodyweight', 'Mobility', 'Prepares the hips and upper-back rotation for athletic movement.', 'Step into a long lunge with both hands inside the front foot.', 'Reach and rotate toward the front leg, then return before changing sides.', 'Keep the front foot planted and rotate smoothly.', 'Forcing range or losing front-foot contact.'),
    ('EX-164', 'Jump Landing Rehearsal', 'jump-landing-rehearsal', TRUE, 'Plyometric', 'Landing', 'Bodyweight', 'Landing Control', 'Rehearses a stable landing before power work.', 'Stand tall in an athletic stance with space to land safely.', 'Make a small jump and absorb the landing under control.', 'Land quietly with hips and knees aligned.', 'Landing stiff-legged or allowing the knees to collapse inward.'),
    ('EX-165', 'Leg Swing', 'leg-swing', TRUE, 'Mobility', 'Hip Flexion and Extension', 'Stable support', 'Running Preparation', 'Prepares dynamic hip movement before faster running.', 'Stand tall beside a stable support.', 'Swing one leg forward and back under control, then change sides.', 'Keep the torso tall and begin with a comfortable range.', 'Twisting the torso or forcing the swing.'),
    ('EX-166', 'A-Skip', 'a-skip', TRUE, 'Running Drill', 'Locomotion', 'Running Shoes', 'Running Technique', 'Rehearses rhythm and front-side mechanics before faster running.', 'Stand tall with space to travel forward.', 'Skip forward while lifting the knee and striking the ground beneath the body.', 'Stay tall, keep a quick rhythm, and place the foot under the hips.', 'Reaching the foot forward or losing posture.'),
    ('EX-167', 'Running Stride', 'running-stride', TRUE, 'Running Drill', 'Locomotion', 'Running Shoes', 'Running Preparation', 'Bridges easy running and the faster pace of the main session.', 'Begin from an easy jog on a clear, level route.', 'Increase speed smoothly for the prescribed time, then ease down before the next stride.', 'Accelerate gradually and stay relaxed.', 'Sprinting from the first step or stopping abruptly.'),
    ('EX-168', 'Half-Kneeling Hip-Flexor Stretch with Reach', 'half-kneeling-hip-flexor-stretch-reach', TRUE, 'Mobility', 'Hip Extension', 'Bodyweight', 'Mobility', 'Prepares hip extension with an overhead reach.', 'Kneel on one knee with the front foot planted and torso tall.', 'Gently shift forward and reach overhead on the kneeling side.', 'Keep the ribs controlled and squeeze the back glute lightly.', 'Arching the lower back to create extra range.'),
    ('EX-169', 'Deep-Squat Pry', 'deep-squat-pry', TRUE, 'Mobility', 'Squat', 'Bodyweight', 'Mobility', 'Builds comfort in a controlled deep-squat position.', 'Take a comfortable squat stance with feet fully grounded.', 'Sink into a deep squat and gently shift within the available range.', 'Keep the whole foot down and breathe steadily.', 'Forcing depth or losing balance through the feet.');
END $$;

-- Correct athlete-facing information for every reused Apollo preparation
-- identity. Identity and equipment metadata are preserved.
DO $$
DECLARE
  v_exact INTEGER;
BEGIN
  SELECT count(*) INTO v_exact
  FROM public.exercises_v2
  WHERE (exercise_id, name, slug, published) IN (
    ('EX-111', 'Dead Hang', 'dead-hang', TRUE),
    ('EX-129', 'Running', 'running', TRUE),
    ('EX-150', 'Thoracic Extension Over Foam Roller', 'thoracic-extension-over-foam-roller', TRUE),
    ('EX-151', 'Open-Book Thoracic Rotation', 'open-book-thoracic-rotation', TRUE),
    ('EX-152', 'Serratus Wall Slide + Reach', 'serratus-wall-slide-reach', TRUE),
    ('EX-153', 'Wall Y / Lower-Trap Raise', 'wall-y-lower-trap-raise', TRUE),
    ('EX-154', 'Single-Arm Cable/Band Row with Reach', 'single-arm-cable-band-row-with-reach', TRUE)
  );
  IF v_exact <> 7 THEN
    RAISE EXCEPTION 'Apollo warm-up canonical reuse conflict: expected exact EX-111/129/150..154 identities';
  END IF;

  UPDATE public.exercises_v2 AS x
  SET purpose = d.purpose,
      setup = d.setup,
      execution = d.execution,
      coaching_cues = d.coaching_cues,
      common_mistakes = d.common_mistakes
  FROM (VALUES
    ('EX-111', 'Prepares a comfortable overhead position while engaging the grip.', 'Take a secure overhand grip on a pull-up bar with space below the feet.', 'Hang with long arms for the prescribed time while breathing steadily.', 'Use a secure grip and keep the position comfortable.', 'Forcing a painful range or losing a secure grip.'),
    ('EX-129', 'Develops aerobic capacity and running efficiency at the prescribed duration and intensity.', 'Choose a safe route or treadmill and begin at the prescribed effort.', 'Run with a relaxed, repeatable rhythm for the programmed time or distance.', 'Stay tall, relaxed, and consistent.', 'Starting faster than the prescribed effort.'),
    ('EX-150', 'Prepares thoracic extension for overhead and pressing positions.', 'Place a foam roller across the upper back and support the head comfortably.', 'Extend gently over the roller at each prescribed position, then return.', 'Move slowly and keep the lower ribs controlled.', 'Forcing range through the lower back.'),
    ('EX-151', 'Prepares controlled upper-back rotation.', 'Lie on one side with hips and knees bent and arms reaching forward.', 'Rotate the top arm and upper back open, then return with control.', 'Keep the knees together and follow the moving hand with the eyes.', 'Letting the knees separate to create extra rotation.'),
    ('EX-152', 'Prepares coordinated shoulder-blade upward rotation and reach.', 'Stand with forearms against a wall and ribs gently settled.', 'Slide the arms upward, reach at the top, then return under control.', 'Keep gentle wall contact and finish with a smooth reach.', 'Shrugging abruptly or arching the lower back.'),
    ('EX-153', 'Prepares lower-trapezius control for overhead movement.', 'Stand facing a wall with arms in a comfortable Y position.', 'Raise the arms lightly while maintaining a controlled shoulder-blade position.', 'Use very light effort and keep the neck relaxed.', 'Using momentum or forcing the shoulders down and back.'),
    ('EX-154', 'Prepares controlled reaching and rowing through the shoulder blade.', 'Set a cable or band at a comfortable height and take a single-arm stance.', 'Allow a controlled reach, then row the handle back without twisting.', 'Reach smoothly and keep the torso quiet.', 'Rotating the torso or shortening the reach.')
  ) AS d(exercise_id, purpose, setup, execution, coaching_cues, common_mistakes)
  WHERE x.exercise_id = d.exercise_id;
END $$;

-- Remove the one known protocol provenance leak without changing authored
-- coaching content elsewhere.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.performance_protocols
    WHERE protocol_id = 'APOLLO-W1-MON-R1'
      AND coaching_notes IN ('Week 1 reference slice; no programme version.', '')
       OR protocol_id = 'APOLLO-W1-MON-R1' AND coaching_notes IS NULL
  ) THEN
    RAISE EXCEPTION 'Apollo session copy correction refused: unexpected Week 1 Monday coaching notes';
  END IF;
  UPDATE public.performance_protocols
  SET coaching_notes = NULL
  WHERE protocol_id = 'APOLLO-W1-MON-R1';
END $$;

UPDATE public.session_blocks b
SET content = '',
    coach_notes = CASE
      WHEN b.title = 'Apollo Shoulder Balance Warm-Up'
        AND b.session_id = 'APOLLO-W12-MON-R1'
        THEN 'Then complete progressive weighted pull-up warm-up sets. Do not cue permanent shoulders down and back.'
      WHEN b.title = 'Apollo Shoulder Balance Warm-Up'
        AND b.coach_notes LIKE '%Do not cue permanent shoulders down and back.'
        THEN 'Then 2-4 progressive sets for first compound. Do not cue permanent shoulders down and back.'
      WHEN b.title = 'Apollo Shoulder Balance Warm-Up'
        THEN 'Then 2-4 progressive sets for first compound.'
      WHEN b.title = 'Lower-body warm-up'
        THEN 'Then complete progressive squat and RDL warm-up sets.'
      WHEN b.title = 'Athletic warm-up'
        THEN 'Then complete progressive trap-bar warm-up sets.'
      ELSE b.coach_notes
    END
FROM expected_apollo_preparation_blocks e
WHERE b.block_id = e.block_id;

INSERT INTO public.session_block_exercises (
  block_id, exercise_id, position, display_label_override, prescription
)
SELECT e.block_id, t.exercise_id, t.position, t.label, t.prescription
FROM expected_apollo_preparation_blocks e
JOIN (VALUES
  ('shoulder', 1, 'EX-150', 'Thoracic extension over foam roller', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"tempo":"slow","coach_cue":"Use 2–3 positions."}'::JSONB),
  ('shoulder', 2, 'EX-151', 'Open-book rotation', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true,"coach_cue":"Complete each side."}'::JSONB),
  ('shoulder', 3, 'EX-152', 'Serratus wall slide + reach', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'::JSONB),
  ('shoulder', 4, 'EX-153', 'Wall Y/lower-trap raise', '{"sets":2,"reps":{"type":"range","min_reps":8,"max_reps":10},"load":{"type":"freeText","text":"Very light"}}'::JSONB),
  ('shoulder', 5, 'EX-154', 'Single-arm cable/band row with reach', '{"sets":2,"reps":{"type":"exact","exact_reps":10},"per_side":true,"coach_cue":"Complete each side."}'::JSONB),
  ('run_preparation', 1, 'EX-161', 'Brisk walk or easy jog', '{"sets":1,"reps":{"type":"duration","text":"5 min"},"coach_cue":"Complete before starting Zone 2."}'::JSONB),
  ('mobility', 1, 'EX-156', 'Knee-to-wall ankle rocks', '{"sets":2,"reps":{"type":"exact","exact_reps":8},"per_side":true}'::JSONB),
  ('mobility', 2, 'EX-157', '90/90 hip switches', '{"sets":2,"reps":{"type":"exact","exact_reps":8},"per_side":true}'::JSONB),
  ('mobility', 3, 'EX-158', 'Adductor rock-back', '{"sets":2,"reps":{"type":"exact","exact_reps":8},"per_side":true}'::JSONB),
  ('mobility', 4, 'EX-168', 'Half-kneeling hip-flexor stretch with reach', '{"sets":1,"reps":{"type":"duration","text":"45 sec"},"per_side":true}'::JSONB),
  ('mobility', 5, 'EX-169', 'Deep-squat pry', '{"sets":2,"reps":{"type":"duration","text":"30 sec"}}'::JSONB),
  ('mobility', 6, 'EX-151', 'Open-book rotation', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true}'::JSONB),
  ('mobility', 7, 'EX-152', 'Wall slide with reach', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'::JSONB),
  ('mobility', 8, 'EX-111', 'Passive hang', '{"sets":2,"reps":{"type":"duration","text":"30 sec"}}'::JSONB),
  ('lower', 1, 'EX-155', 'Easy cardio', '{"sets":1,"reps":{"type":"duration","text":"5 min"}}'::JSONB),
  ('lower', 2, 'EX-156', 'Knee-to-wall ankle rocks', '{"sets":1,"reps":{"type":"exact","exact_reps":8},"per_side":true}'::JSONB),
  ('lower', 3, 'EX-157', '90/90 hip switches', '{"sets":1,"reps":{"type":"exact","exact_reps":8},"per_side":true}'::JSONB),
  ('lower', 4, 'EX-158', 'Adductor rock-backs', '{"sets":1,"reps":{"type":"exact","exact_reps":8},"per_side":true}'::JSONB),
  ('lower', 5, 'EX-159', 'Glute bridge', '{"sets":2,"reps":{"type":"exact","exact_reps":10}}'::JSONB),
  ('lower', 6, 'EX-160', 'Bodyweight squat', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'::JSONB),
  ('interval', 1, 'EX-129', 'Easy jog', '{"sets":1,"reps":{"type":"duration","text":"12 min"}}'::JSONB),
  ('interval', 2, 'EX-165', 'Leg swings', '{"sets":1,"reps":{"type":"exact","exact_reps":10},"per_side":true}'::JSONB),
  ('interval', 3, 'EX-166', 'A-skips', '{"sets":2,"reps":{"type":"distance","text":"20 m"}}'::JSONB),
  ('interval', 4, 'EX-167', 'Running strides', '{"sets":3,"reps":{"type":"duration","text":"20 sec"}}'::JSONB),
  ('athletic', 1, 'EX-155', 'Easy cardio', '{"sets":1,"reps":{"type":"duration","text":"5 min"}}'::JSONB),
  ('athletic', 2, 'EX-162', 'Ankle pogos', '{"sets":2,"reps":{"type":"exact","exact_reps":20}}'::JSONB),
  ('athletic', 3, 'EX-163', 'World''s greatest stretch', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"per_side":true}'::JSONB),
  ('athletic', 4, 'EX-159', 'Glute bridge', '{"sets":1,"reps":{"type":"exact","exact_reps":10}}'::JSONB),
  ('athletic', 5, 'EX-164', 'Jump landing rehearsal', '{"sets":2,"reps":{"type":"exact","exact_reps":3}}'::JSONB)
) AS t(template, position, exercise_id, label, prescription)
  ON t.template = e.template
WHERE NOT EXISTS (
  SELECT 1
  FROM public.session_block_exercises x
  WHERE x.block_id = e.block_id
    AND x.position = t.position
);

DO $$
DECLARE
  v_links INTEGER;
  v_blocks INTEGER;
BEGIN
  SELECT count(*) INTO v_links
  FROM public.session_block_exercises x
  JOIN expected_apollo_preparation_blocks e USING (block_id);
  SELECT count(DISTINCT x.block_id) INTO v_blocks
  FROM public.session_block_exercises x
  JOIN expected_apollo_preparation_blocks e USING (block_id);
  IF v_links <> 514 OR v_blocks <> 106 THEN
    RAISE EXCEPTION 'Apollo preparation structure incomplete: % links across % blocks; expected 514 across 106', v_links, v_blocks;
  END IF;
END $$;
