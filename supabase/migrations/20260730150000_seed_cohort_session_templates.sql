-- Cohort Session Template starter catalogue (TMP-001..TMP-010)
-- Idempotent when existing TMP-* rows are already official Cohort templates.
-- Does not overwrite conflicting rows. Wrong-classification collisions fail loudly.
-- Incomplete step sets (non-zero but wrong count) fail loudly — no silent repair.
-- Source of truth: lib/features/training_library/services/cohort_session_template_catalogue.dart
-- Deployment: apply via normal Supabase migration. Not invoked from app startup.

-- Fail closed: a colliding TMP-* row that is not a full official template must not
-- masquerade as the canonical catalogue entry via ON CONFLICT DO NOTHING.
DO $$
DECLARE
  bad RECORD;
BEGIN
  FOR bad IN
    SELECT
      protocol_id,
      content_kind,
      authoring_scope,
      endorsement_status,
      published,
      owner_id
    FROM performance_protocols
    WHERE protocol_id IN (
      'TMP-001', 'TMP-002', 'TMP-003', 'TMP-004', 'TMP-005',
      'TMP-006', 'TMP-007', 'TMP-008', 'TMP-009', 'TMP-010'
    )
      AND NOT (
        content_kind = 'session_template'
        AND authoring_scope = 'cohort_global'
        AND endorsement_status = 'cohort_endorsed'
        AND published = 'true'
        AND owner_id IS NULL
      )
  LOOP
    RAISE EXCEPTION
      'Canonical template seed conflict for %: existing row is not an official Cohort template (kind=%, scope=%, endorsement=%, published=%, owner_id=%). Refusing to treat it as TMP catalogue content. Resolve manually before re-running this migration.',
      bad.protocol_id,
      bad.content_kind,
      bad.authoring_scope,
      bad.endorsement_status,
      bad.published,
      bad.owner_id;
  END LOOP;
END $$;

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-001', 'Full-Body Strength', 'Balanced strength session covering squat, hinge, push, and pull.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Strength', 'Strength', 55, 'Medium',
  'Intermediate', 'Gym', 'Barbell, Full Gym', NULL, 'General Fitness, Strength',
  'Moderate', 'Moderate', 3, NULL, NULL,
  NULL, NULL, NULL, 'full_body_strength',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-001', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "8 min"}'::jsonb),
  ('TMP-001', 2, 'Main', 'exercise', 'standard', 'EX-073', 'Back Squat', NULL, '{"sets": "4", "reps": "5", "rest": "2 min", "load": "Working weight"}'::jsonb),
  ('TMP-001', 3, 'Main', 'exercise', 'standard', 'EX-078', 'Romanian Deadlift', NULL, '{"sets": "3", "reps": "8", "rest": "90 sec", "load": "Working weight"}'::jsonb),
  ('TMP-001', 4, 'Main', 'exercise', 'standard', 'EX-083', 'Bench Press', NULL, '{"sets": "3", "reps": "6", "rest": "2 min", "load": "Working weight"}'::jsonb),
  ('TMP-001', 5, 'Main', 'exercise', 'standard', 'EX-090', 'Chest Supported Row', NULL, '{"sets": "3", "reps": "8", "rest": "90 sec", "load": "Working weight"}'::jsonb),
  ('TMP-001', 6, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-001'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-001'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-002', 'Upper-Body Strength', 'Press and pull emphasis for upper-body strength development.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Strength', 'Strength', 50, 'Medium',
  'Intermediate', 'Gym', 'Barbell, Bench, Full Gym', NULL, 'General Fitness, Strength',
  'Moderate', 'Moderate', 3, NULL, NULL,
  NULL, NULL, NULL, 'upper_body_strength',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-002', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "8 min"}'::jsonb),
  ('TMP-002', 2, 'Main', 'exercise', 'standard', 'EX-083', 'Bench Press', NULL, '{"sets": "4", "reps": "5", "rest": "2 min", "load": "Working weight"}'::jsonb),
  ('TMP-002', 3, 'Main', 'exercise', 'standard', 'EX-091', 'Barbell Row', NULL, '{"sets": "4", "reps": "6", "rest": "2 min", "load": "Working weight"}'::jsonb),
  ('TMP-002', 4, 'Main', 'exercise', 'standard', 'EX-088', 'Strict Press', NULL, '{"sets": "3", "reps": "6", "rest": "90 sec", "load": "Working weight"}'::jsonb),
  ('TMP-002', 5, 'Main', 'exercise', 'standard', 'EX-096', 'Chin Up', NULL, '{"sets": "3", "reps": "6-8", "rest": "90 sec"}'::jsonb),
  ('TMP-002', 6, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-002'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-002'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-003', 'Lower-Body Strength', 'Squat and hinge focus for lower-body strength.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Strength', 'Strength', 50, 'Medium',
  'Intermediate', 'Gym', 'Barbell, Full Gym', NULL, 'General Fitness, Strength',
  'High', 'High', 3, NULL, NULL,
  NULL, NULL, NULL, 'lower_body_strength',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-003', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "8 min"}'::jsonb),
  ('TMP-003', 2, 'Main', 'exercise', 'standard', 'EX-073', 'Back Squat', NULL, '{"sets": "4", "reps": "5", "rest": "2-3 min", "load": "Working weight"}'::jsonb),
  ('TMP-003', 3, 'Main', 'exercise', 'standard', 'EX-078', 'Romanian Deadlift', NULL, '{"sets": "3", "reps": "6", "rest": "2 min", "load": "Working weight"}'::jsonb),
  ('TMP-003', 4, 'Accessory', 'exercise', 'standard', 'EX-098', 'Lateral Lunge', NULL, '{"sets": "3", "reps": "8/side", "rest": "60 sec"}'::jsonb),
  ('TMP-003', 5, 'Accessory', 'exercise', 'standard', 'EX-125', 'Standing Calf Raise', NULL, '{"sets": "3", "reps": "10", "rest": "60 sec"}'::jsonb),
  ('TMP-003', 6, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-003'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-003'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-004', 'Aerobic Conditioning', 'Steady aerobic engine work with controlled intensity.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Engine', 'Conditioning', 40, 'Medium',
  'Beginner', 'Gym', 'Bike Erg, Row Erg', 'Ski Erg', 'General Fitness, Endurance',
  'Moderate', 'Low', 3, NULL, NULL,
  NULL, NULL, NULL, 'aerobic_conditioning',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-004', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Easy warm-up', NULL, '{"duration": "5 min"}'::jsonb),
  ('TMP-004', 2, 'Main', 'exercise', 'standard', NULL, 'Steady aerobic block', 'Sustain conversational effort on bike or rower.', '{"duration": "25 min"}'::jsonb),
  ('TMP-004', 3, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-004'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-004'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-005', 'Threshold Intervals', 'Controlled threshold intervals for aerobic capacity.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Threshold', 'Intervals', 45, 'Medium',
  'Intermediate', 'Gym', 'Bike Erg, Row Erg', NULL, 'Endurance, Intermediate',
  'High', 'Moderate', 3, FALSE, NULL,
  NULL, NULL, NULL, 'threshold',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-005', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "8 min"}'::jsonb),
  ('TMP-005', 2, 'Main', 'exercise', 'standard', NULL, 'Threshold intervals', 'Strong but sustainable effort; quality over pace chasing.', '{"sets": "5", "duration": "3 min", "rest": "2 min"}'::jsonb),
  ('TMP-005', 3, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-005'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-005'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-006', 'HYROX Mixed Conditioning', 'Mixed-modal conditioning with station work and compromised running.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Engine', 'Hybrid', 50, 'Medium',
  'Intermediate', 'Gym', 'Sandbag, Wall Ball, Row Erg, Running Shoes', NULL, 'HYROX, Intermediate',
  'High', 'High', 3, TRUE, TRUE,
  NULL, NULL, NULL, 'hyrox_specific_conditioning',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-006', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "8 min"}'::jsonb),
  ('TMP-006', 2, 'Main', 'exercise', 'standard', NULL, 'Station circuit', 'Rotate wall ball, sandbag carry, and rower. Keep transitions deliberate.', '{"sets": "4"}'::jsonb),
  ('TMP-006', 3, 'Main', 'exercise', 'standard', NULL, 'Compromised run or substitute', 'Easy-moderate run, or bike/row substitute if needed.', '{"duration": "8-10 min"}'::jsonb),
  ('TMP-006', 4, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-006'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-006'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-007', 'Minimal Equipment Strength', 'Strength session using dumbbells or kettlebells only.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Strength', 'Strength', 40, 'Medium',
  'Beginner', 'Home', 'Dumbbell, Minimal Kit', 'Kettlebell', 'Travel, General Fitness, Beginner',
  'Moderate', 'Moderate', 3, NULL, NULL,
  TRUE, TRUE, NULL, 'full_body_strength',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-007', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "5 min"}'::jsonb),
  ('TMP-007', 2, 'Main', 'exercise', 'standard', NULL, 'Goblet squat pattern', 'Use a dumbbell or kettlebell.', '{"sets": "3", "reps": "10", "rest": "75 sec"}'::jsonb),
  ('TMP-007', 3, 'Main', 'exercise', 'standard', NULL, 'Single-arm row', NULL, '{"sets": "3", "reps": "10/side", "rest": "60 sec"}'::jsonb),
  ('TMP-007', 4, 'Main', 'exercise', 'standard', NULL, 'Floor press', NULL, '{"sets": "3", "reps": "8", "rest": "75 sec"}'::jsonb),
  ('TMP-007', 5, 'Finisher', 'exercise', 'standard', 'EX-102', 'Suitcase carry', NULL, '{"sets": "3", "distance": "20-30 m/side", "rest": "60 sec"}'::jsonb),
  ('TMP-007', 6, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "4 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-007'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-007'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-008', 'Bodyweight Session', 'No-equipment strength and movement quality session.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Strength', 'Strength', 35, 'Short',
  'Beginner', 'Anywhere', 'Bodyweight', NULL, 'Travel, Beginner, General Fitness',
  'Low', 'Low', 3, NULL, NULL,
  TRUE, TRUE, TRUE, 'movement_quality',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-008', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "5 min"}'::jsonb),
  ('TMP-008', 2, 'Main', 'exercise', 'standard', NULL, 'Squat pattern', NULL, '{"sets": "3", "reps": "12", "rest": "45 sec"}'::jsonb),
  ('TMP-008', 3, 'Main', 'exercise', 'standard', NULL, 'Push-up pattern', NULL, '{"sets": "3", "reps": "8-12", "rest": "45 sec"}'::jsonb),
  ('TMP-008', 4, 'Main', 'exercise', 'standard', NULL, 'Hip hinge / good morning pattern', NULL, '{"sets": "3", "reps": "10", "rest": "45 sec"}'::jsonb),
  ('TMP-008', 5, 'Core', 'exercise', 'standard', 'EX-112', 'Hollow hold', NULL, '{"sets": "3", "duration": "20-30 sec", "rest": "30 sec"}'::jsonb),
  ('TMP-008', 6, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "4 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-008'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-008'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-009', 'Mobility & Recovery', 'Low-demand mobility and recovery session for reset days.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Mobility', 'Recovery', 30, 'Short',
  'Beginner', 'Anywhere', 'Bodyweight', NULL, 'Recovery, Travel, Beginner',
  'Very Low', 'Very Low', 3, NULL, NULL,
  TRUE, TRUE, TRUE, 'mobility',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-009', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Breathing reset', NULL, '{"duration": "3 min"}'::jsonb),
  ('TMP-009', 2, 'Main', 'exercise', 'standard', NULL, 'Hip and thoracic mobility circuit', 'Controlled ranges; no forcing end range.', '{"duration": "15 min"}'::jsonb),
  ('TMP-009', 3, 'Main', 'exercise', 'standard', 'EX-115', 'Bird dog', NULL, '{"sets": "2", "reps": "6/side"}'::jsonb),
  ('TMP-009', 4, 'Main', 'exercise', 'standard', 'EX-116', 'Side plank', NULL, '{"sets": "2", "duration": "20-30 sec/side"}'::jsonb),
  ('TMP-009', 5, 'Cool-down', 'exercise', 'standard', NULL, 'Closing stretch', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-009'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-009'
);

INSERT INTO performance_protocols (
  protocol_id, name, purpose, published, content_kind, authoring_scope, endorsement_status,
  owner_id, primary_capability, session_type, duration_min, duration_category,
  technical_complexity, environment, required_equipment, optional_equipment, suitable_for,
  physiological_demand, recovery_cost, adaptability, running_required, running_replaceable,
  hotel_friendly, indoor_friendly, noise_friendly, primary_session_intent, coaching_notes,
  lifecycle_status, revision_number
) VALUES (
  'TMP-010', 'Simple Benchmark Test', 'Repeatable mixed benchmark for tracking work capacity over time.', 'true', 'session_template', 'cohort_global', 'cohort_endorsed',
  NULL, 'Engine', 'Benchmark', 25, 'Short',
  'Intermediate', 'Gym', 'Pull-up Bar, Bodyweight', NULL, 'General Fitness, Intermediate',
  'High', 'Moderate', 3, NULL, NULL,
  NULL, NULL, NULL, 'work_capacity',
  'Starter Cohort template. Customise after Use Template — the source stays unchanged.',
  'published', 1
)
ON CONFLICT (protocol_id) DO NOTHING;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('TMP-010', 1, 'Warm-up', 'exercise', 'standard', NULL, 'Warm-up', NULL, '{"duration": "6 min"}'::jsonb),
  ('TMP-010', 2, 'Main', 'exercise', 'standard', NULL, 'Benchmark: 10-min AMRAP', '5 chin-ups, 10 push-ups, 15 air squats. Record total rounds + reps.', '{"duration": "10 min"}'::jsonb),
  ('TMP-010', 3, 'Cool-down', 'exercise', 'standard', NULL, 'Cool-down', NULL, '{"duration": "5 min"}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE EXISTS (
  SELECT 1 FROM performance_protocols p
  WHERE p.protocol_id = 'TMP-010'
    AND p.content_kind = 'session_template'
    AND p.authoring_scope = 'cohort_global'
    AND p.endorsement_status = 'cohort_endorsed'
    AND p.published = 'true'
    AND p.owner_id IS NULL
)
AND NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = 'TMP-010'
);

-- Fail closed on partially populated or corrupted canonical step sets.
-- Empty steps are completed by the inserts above; wrong non-zero counts are not repaired.
DO $$
DECLARE
  expected CONSTANT jsonb := '{
    "TMP-001": 6,
    "TMP-002": 6,
    "TMP-003": 6,
    "TMP-004": 3,
    "TMP-005": 3,
    "TMP-006": 4,
    "TMP-007": 6,
    "TMP-008": 6,
    "TMP-009": 5,
    "TMP-010": 3
  }'::jsonb;
  tid text;
  expected_count int;
  actual_count int;
BEGIN
  FOR tid, expected_count IN
    SELECT key, value::int FROM jsonb_each_text(expected)
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM performance_protocols p
      WHERE p.protocol_id = tid
        AND p.content_kind = 'session_template'
        AND p.authoring_scope = 'cohort_global'
        AND p.endorsement_status = 'cohort_endorsed'
        AND p.published = 'true'
        AND p.owner_id IS NULL
    ) THEN
      RAISE EXCEPTION
        'Canonical template seed incomplete: official header for % is missing after seed inserts.',
        tid;
    END IF;

    SELECT count(*)::int INTO actual_count
    FROM protocol_steps s
    WHERE s.protocol_id = tid;

    IF actual_count <> expected_count THEN
      RAISE EXCEPTION
        'Canonical template seed conflict for %: expected % steps but found %. Refusing to treat a partial or corrupt step set as deployed. Resolve manually before re-running this migration.',
        tid,
        expected_count,
        actual_count;
    END IF;
  END LOOP;
END $$;
