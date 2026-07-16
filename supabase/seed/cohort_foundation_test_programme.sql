-- Development fixture: COHORT-FOUNDATION-TEST
-- Minimal unpublished Cohort Global programme for Programme Engine store testing.
-- Not wired to Home. Safe to re-run via fixed UUID ON CONFLICT guards.
--
-- Structure:
--   Version 1 (draft)
--   Week 1
--     day_1: BW-001 bodyweight grinder
--     day_2: RN-006 intervals
--     day_3: rest
--     day_4: FG-009 circuit
--
-- Protocol IDs are existing published examples used elsewhere in the app.

INSERT INTO programme_lineages (
  id,
  code,
  created_by
)
VALUES (
  'aaaaaaaa-bbbb-cccc-dddd-000000000001'::uuid,
  'COHORT-FOUNDATION-TEST',
  'dev-coach'
)
ON CONFLICT (code) DO NOTHING;

INSERT INTO programme_versions (
  id,
  lineage_id,
  version_number,
  lifecycle_status,
  library_scope,
  owner_type,
  created_by,
  name,
  description,
  duration_weeks,
  sessions_per_week,
  approved_for_global,
  approved_for_adaptation
)
SELECT
  'aaaaaaaa-bbbb-cccc-dddd-000000000002'::uuid,
  l.id,
  1,
  'draft',
  'cohort_global',
  'global',
  'dev-coach',
  'Cohort Foundation Test',
  'Minimal development fixture for Programme Engine store validation.',
  1,
  3,
  FALSE,
  FALSE
FROM programme_lineages l
WHERE l.code = 'COHORT-FOUNDATION-TEST'
ON CONFLICT (lineage_id, version_number) DO NOTHING;

INSERT INTO programme_version_weeks (
  id,
  version_id,
  week_number,
  title
)
SELECT
  'aaaaaaaa-bbbb-cccc-dddd-000000000010'::uuid,
  v.id,
  1,
  'Week 1'
FROM programme_versions v
JOIN programme_lineages l ON l.id = v.lineage_id
WHERE l.code = 'COHORT-FOUNDATION-TEST'
  AND v.version_number = 1
ON CONFLICT (version_id, week_number) DO NOTHING;

INSERT INTO programme_version_days (
  id,
  week_id,
  day_key,
  day_order,
  title,
  day_type
)
SELECT
  day_seed.id,
  w.id,
  day_seed.day_key,
  day_seed.day_order,
  day_seed.title,
  day_seed.day_type
FROM programme_version_weeks w
JOIN programme_versions v ON v.id = w.version_id
JOIN programme_lineages l ON l.id = v.lineage_id
JOIN (
  VALUES
    ('aaaaaaaa-bbbb-cccc-dddd-000000000101'::uuid, 'day_1', 1, 'Bodyweight', 'training'),
    ('aaaaaaaa-bbbb-cccc-dddd-000000000102'::uuid, 'day_2', 2, 'Intervals', 'training'),
    ('aaaaaaaa-bbbb-cccc-dddd-000000000103'::uuid, 'day_3', 3, 'Rest', 'rest'),
    ('aaaaaaaa-bbbb-cccc-dddd-000000000104'::uuid, 'day_4', 4, 'Circuit', 'training')
) AS day_seed(id uuid, day_key text, day_order int, title text, day_type text)
  ON TRUE
WHERE l.code = 'COHORT-FOUNDATION-TEST'
  AND v.version_number = 1
  AND w.week_number = 1
ON CONFLICT (week_id, day_key) DO NOTHING;

INSERT INTO programme_version_session_slots (
  id,
  day_id,
  session_order,
  protocol_id,
  display_title,
  time_of_day,
  completion_expectation
)
SELECT
  slot_seed.id,
  d.id,
  slot_seed.session_order,
  slot_seed.protocol_id,
  slot_seed.display_title,
  slot_seed.time_of_day,
  slot_seed.completion_expectation
FROM programme_version_days d
JOIN programme_version_weeks w ON w.id = d.week_id
JOIN programme_versions v ON v.id = w.version_id
JOIN programme_lineages l ON l.id = v.lineage_id
JOIN (
  VALUES
    (
      'aaaaaaaa-bbbb-cccc-dddd-000000000201'::uuid,
      'day_1',
      1,
      'BW-001',
      'Bodyweight Grinder',
      'morning',
      'required'
    ),
    (
      'aaaaaaaa-bbbb-cccc-dddd-000000000202'::uuid,
      'day_2',
      1,
      'RN-006',
      'Classic Threshold Intervals',
      'afternoon',
      'required'
    ),
    (
      'aaaaaaaa-bbbb-cccc-dddd-000000000204'::uuid,
      'day_4',
      1,
      'FG-009',
      'Full Gym Chipper',
      'evening',
      'required'
    )
) AS slot_seed(
  id uuid,
  day_key text,
  session_order int,
  protocol_id text,
  display_title text,
  time_of_day text,
  completion_expectation text
)
  ON d.day_key = slot_seed.day_key
WHERE l.code = 'COHORT-FOUNDATION-TEST'
  AND v.version_number = 1
  AND w.week_number = 1
ON CONFLICT (day_id, session_order) DO NOTHING;
