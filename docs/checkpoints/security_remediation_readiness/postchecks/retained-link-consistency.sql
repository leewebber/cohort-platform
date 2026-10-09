SELECT * FROM (
 WITH linked AS (
 SELECT r.record_id,r.athlete_id,r.training_session_id,r.assignment_id AS r_assignment,
  r.programme_session_id AS r_slot,r.programme_id AS r_programme,r.source_protocol_id,
  s.id AS parent_id,s.athlete_id AS s_athlete,s.programme_id AS s_programme,s.week_number AS s_week,s.protocol_id AS s_protocol,
  o.id AS outcome_id,o.assignment_id AS o_assignment,o.session_slot_id AS o_slot,o.week_number AS o_week,o.day_key AS o_day,
  o.session_order AS o_order,o.programme_version_id AS o_version,o.materialised_package_content_hash AS o_hash,
  o.programmed_session_key AS o_key,o.completion_record_id,
  a.id AS assignment_id,a.athlete_id AS a_athlete,a.programme_version_id AS a_version,a.lineage_code,a.materialised_package_content_hash AS a_hash,
  slot.id AS slot_id,slot.session_order,slot.protocol_id,d.day_key,w.week_number,w.version_id,
  format('prog:%s@%s:w%s:%s:s%s:%s',a.id,a.programme_version_id,w.week_number,d.day_key,slot.session_order,slot.protocol_id) AS expected_key
 FROM public.training_session_records r JOIN public.training_sessions s ON s.id=r.training_session_id
 LEFT JOIN public.programme_slot_outcomes o ON o.training_session_id=s.id
 LEFT JOIN public.programme_assignments a ON a.id=o.assignment_id
 LEFT JOIN public.programme_version_session_slots slot ON slot.id=o.session_slot_id
 LEFT JOIN public.programme_version_days d ON d.id=slot.day_id
 LEFT JOIN public.programme_version_weeks w ON w.id=d.week_id)
 SELECT count(*) AS physically_linked_records,count(*) FILTER(WHERE outcome_id IS NOT NULL) AS records_with_retained_outcome,
 count(*) FILTER(WHERE outcome_id IS NOT NULL AND (
  assignment_id IS NULL OR slot_id IS NULL OR version_id IS DISTINCT FROM a_version OR o_week IS DISTINCT FROM week_number
  OR o_day IS DISTINCT FROM day_key OR o_order IS DISTINCT FROM session_order
  OR (o_version IS NOT NULL AND o_version IS DISTINCT FROM a_version)
  OR (o_hash IS NOT NULL AND o_hash IS DISTINCT FROM a_hash)
  OR (o_key IS NOT NULL AND o_key IS DISTINCT FROM expected_key)
  OR (completion_record_id IS NOT NULL AND completion_record_id IS DISTINCT FROM record_id)
  OR a_athlete::text IS DISTINCT FROM athlete_id
  OR (r_assignment IS NOT NULL AND r_assignment IS DISTINCT FROM o_assignment)
  OR (r_slot IS NOT NULL AND r_slot IS DISTINCT FROM o_slot)
  OR (s_programme IS NOT NULL AND s_programme NOT IN(lineage_code,a_version::text))
  OR (s_week IS NOT NULL AND s_week IS DISTINCT FROM o_week)
  OR (r_programme IS NOT NULL AND r_programme NOT IN(lineage_code,a_version::text)))) AS parent_guard_contradictions
 FROM linked
 ) checks;
