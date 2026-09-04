-- Gate AH — authenticated athlete programme structure reads.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'af000002-0000-4000-8000-000000000002', true);
DO $$
DECLARE v_version uuid;
BEGIN
  SELECT v.id INTO v_version FROM programme_versions v JOIN programme_lineages l ON l.id=v.lineage_id
    WHERE l.code='APOLLO-BUILD-12-WEEK' AND v.version_number=2;
  IF (SELECT count(*) FROM programme_version_phases WHERE version_id=v_version) <> 3 THEN RAISE EXCEPTION 'AH phases unavailable'; END IF;
  IF (SELECT count(*) FROM programme_version_weeks WHERE version_id=v_version) <> 12 THEN RAISE EXCEPTION 'AH weeks unavailable'; END IF;
  IF (SELECT count(*) FROM programme_version_days d JOIN programme_version_weeks w ON w.id=d.week_id WHERE w.version_id=v_version) <> 84 THEN RAISE EXCEPTION 'AH days unavailable'; END IF;
  IF (SELECT count(*) FROM programme_version_session_slots s JOIN programme_version_days d ON d.id=s.day_id JOIN programme_version_weeks w ON w.id=d.week_id WHERE w.version_id=v_version) <> 84 THEN RAISE EXCEPTION 'AH slots unavailable'; END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AH','assigned_apollo_phases','3','3',NULL,TRUE,NULL);
SELECT sprint12_record('AH','assigned_apollo_weeks','12','12',NULL,TRUE,NULL);
SELECT sprint12_record('AH','assigned_apollo_days','84','84',NULL,TRUE,NULL);
SELECT sprint12_record('AH','assigned_apollo_slots','84','84',NULL,TRUE,NULL);
BEGIN;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM 1 FROM programme_version_phases; RAISE EXCEPTION 'AH anonymous structure read permitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END $$;
ROLLBACK;
SELECT sprint12_record('AH','anonymous_structure_read_denied','42501','42501',NULL,TRUE,NULL);
SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='AH' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
