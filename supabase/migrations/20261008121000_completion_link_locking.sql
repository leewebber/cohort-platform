-- Review fix: retain ownership/link locks through mutation and align fixed lock order.
BEGIN;
CREATE OR REPLACE FUNCTION public.cohort_assert_record_parent_v1(r public.training_session_records)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE s public.training_sessions%ROWTYPE; o public.programme_slot_outcomes%ROWTYPE;
 a public.programme_assignments%ROWTYPE; slot public.programme_version_session_slots%ROWTYPE;
 d public.programme_version_days%ROWTYPE; w public.programme_version_weeks%ROWTYPE; key text;
 assignment_ids uuid[]; outcome_ids uuid[]; seen_ids uuid[]:=ARRAY[]::uuid[]; BEGIN
 IF r.training_session_id IS NULL THEN RETURN; END IF;
 -- Match canonical assignment -> outcome -> parent order, then revalidate
 -- membership after all locks. A moved/deleted/added hint is denied, never used.
 SELECT coalesce(array_agg(id ORDER BY id),ARRAY[]::uuid[]),
  coalesce(array_agg(DISTINCT assignment_id),ARRAY[]::uuid[]) INTO outcome_ids,assignment_ids
 FROM public.programme_slot_outcomes WHERE training_session_id=r.training_session_id;
 IF r.assignment_id IS NOT NULL THEN assignment_ids:=array_append(assignment_ids,r.assignment_id); END IF;
 PERFORM 1 FROM public.programme_assignments WHERE id=ANY(assignment_ids) ORDER BY id FOR SHARE;
 PERFORM 1 FROM public.programme_slot_outcomes WHERE id=ANY(outcome_ids) ORDER BY id FOR SHARE;
 SELECT * INTO s FROM public.training_sessions WHERE id=r.training_session_id FOR UPDATE;
 IF NOT FOUND OR s.athlete_id IS DISTINCT FROM r.athlete_id OR r.athlete_id IS NULL
  OR (r.source_protocol_id IS NOT NULL AND r.source_protocol_id IS DISTINCT FROM s.protocol_id) THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
 END IF;
 FOR o IN SELECT * FROM public.programme_slot_outcomes WHERE training_session_id=s.id ORDER BY id FOR SHARE LOOP
  IF NOT (o.id=ANY(outcome_ids)) OR NOT (o.assignment_id=ANY(assignment_ids)) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  seen_ids:=array_append(seen_ids,o.id);
  SELECT * INTO a FROM public.programme_assignments WHERE id=o.assignment_id;
  SELECT * INTO slot FROM public.programme_version_session_slots WHERE id=o.session_slot_id;
  SELECT * INTO d FROM public.programme_version_days WHERE id=slot.day_id;
  SELECT * INTO w FROM public.programme_version_weeks WHERE id=d.week_id;
  key:=format('prog:%s@%s:w%s:%s:s%s:%s',a.id,a.programme_version_id,w.week_number,d.day_key,slot.session_order,slot.protocol_id);
  IF a.id IS NULL OR slot.id IS NULL OR w.version_id IS DISTINCT FROM a.programme_version_id
   OR o.week_number IS DISTINCT FROM w.week_number OR o.day_key IS DISTINCT FROM d.day_key
   OR o.session_order IS DISTINCT FROM slot.session_order
   OR (o.programme_version_id IS NOT NULL AND o.programme_version_id IS DISTINCT FROM a.programme_version_id)
   OR (o.materialised_package_content_hash IS NOT NULL AND o.materialised_package_content_hash IS DISTINCT FROM a.materialised_package_content_hash)
   OR (o.programmed_session_key IS NOT NULL AND o.programmed_session_key IS DISTINCT FROM key)
   OR (o.completion_record_id IS NOT NULL AND o.completion_record_id IS DISTINCT FROM r.record_id)
   OR a.athlete_id::text IS DISTINCT FROM r.athlete_id
   OR (r.assignment_id IS NOT NULL AND r.assignment_id IS DISTINCT FROM o.assignment_id)
   OR (r.programme_session_id IS NOT NULL AND r.programme_session_id IS DISTINCT FROM o.session_slot_id)
   OR (s.programme_id IS NOT NULL AND s.programme_id NOT IN (a.lineage_code,a.programme_version_id::text))
   OR (s.week_number IS NOT NULL AND s.week_number IS DISTINCT FROM o.week_number)
   OR (r.programme_id IS NOT NULL AND r.programme_id NOT IN (a.lineage_code,a.programme_version_id::text)) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
  END IF;
 END LOOP;
 IF seen_ids IS DISTINCT FROM outcome_ids THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.cohort_assert_record_parent_v1(public.training_session_records)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.cohort_assert_completion_request_v1(p jsonb,mode text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE actor uuid:=auth.uid(); r public.training_session_records%ROWTYPE; s public.training_sessions%ROWTYPE;
 a public.programme_assignments%ROWTYPE; o public.programme_slot_outcomes%ROWTYPE;
 occ public.programme_schedule_occurrences%ROWTYPE; slot public.programme_version_session_slots%ROWTYPE;
 d public.programme_version_days%ROWTYPE; w public.programme_version_weeks%ROWTYPE;
 c jsonb; v_record_id uuid; parent_id bigint; version_id uuid; slot_id uuid; key text; BEGIN
 IF actor IS NULL OR NOT public.cohort_auth_is_athlete() OR p IS NULL OR jsonb_typeof(p)<>'object' THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 v_record_id:=nullif(p->>'record_id','')::uuid;
 SELECT * INTO r FROM public.training_session_records WHERE training_session_records.record_id=v_record_id FOR UPDATE;
 IF r.record_id IS NOT NULL AND r.athlete_id IS DISTINCT FROM actor::text THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 IF mode='correction' THEN
  IF r.record_id IS NULL THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  IF (p ? 'training_session_id' AND p->>'training_session_id' IS DISTINCT FROM r.training_session_id::text)
   OR (p ? 'athlete_id' AND p->>'athlete_id' IS DISTINCT FROM r.athlete_id)
   OR (p ? 'assignment_id' AND p->>'assignment_id' IS DISTINCT FROM r.assignment_id::text)
   OR (p ? 'programme_session_id' AND p->>'programme_session_id' IS DISTINCT FROM r.programme_session_id::text) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  PERFORM public.cohort_assert_record_parent_v1(r); RETURN;
 END IF;
 c:=coalesce(p->'completion_record','{}'::jsonb);
 IF jsonb_typeof(c)<>'object' THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 IF mode='standalone' THEN
  c:=p; parent_id:=nullif(p->>'training_session_id','')::bigint;
  IF p->>'athlete_id' IS DISTINCT FROM actor::text OR v_record_id IS NULL OR parent_id IS NULL
   OR EXISTS(SELECT 1 FROM public.training_session_records t WHERE t.training_session_id=parent_id AND t.athlete_id=actor::text AND t.status<>'in_progress' AND t.record_id<>v_record_id)
   OR nullif(p->>'assignment_id','') IS NOT NULL OR nullif(p->>'programme_session_id','') IS NOT NULL THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 ELSE
  -- Fixed start/backfill already use occurrence -> assignment order.
  -- Initial owner filtering is repeated under the assignment lock below.
  IF mode IN ('fixed','backfill') THEN
   -- Acquire the retained transaction body's own advisory fence before its row.
   PERFORM pg_advisory_xact_lock(CASE WHEN mode='fixed' THEN 84202409 ELSE 84260913 END,
    hashtext(nullif(p->>'occurrence_id','')::uuid::text));
   SELECT * INTO occ FROM public.programme_schedule_occurrences x
    WHERE x.id=nullif(p->>'occurrence_id','')::uuid AND x.assignment_id=nullif(p->>'assignment_id','')::uuid
     AND EXISTS(SELECT 1 FROM public.programme_assignments y WHERE y.id=x.assignment_id AND y.athlete_id=actor)
    FOR UPDATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  END IF;
  SELECT * INTO a FROM public.programme_assignments
   WHERE id=nullif(p->>'assignment_id','')::uuid AND athlete_id=actor FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  IF mode='backfill' THEN slot_id:=occ.session_slot_id; version_id:=occ.programme_version_id;
  ELSE slot_id:=nullif(p->>'session_slot_id','')::uuid; version_id:=nullif(p->>'programme_version_id','')::uuid; END IF;
  SELECT * INTO slot FROM public.programme_version_session_slots WHERE id=slot_id;
  SELECT * INTO d FROM public.programme_version_days WHERE id=slot.day_id;
  SELECT * INTO w FROM public.programme_version_weeks WHERE id=d.week_id;
  IF slot.id IS NULL OR w.version_id IS DISTINCT FROM a.programme_version_id OR version_id IS DISTINCT FROM a.programme_version_id THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  key:=format('prog:%s@%s:w%s:%s:s%s:%s',a.id,a.programme_version_id,w.week_number,d.day_key,slot.session_order,slot.protocol_id);
  SELECT * INTO o FROM public.programme_slot_outcomes WHERE assignment_id=a.id AND session_slot_id=slot.id FOR UPDATE;
  IF mode='backfill' THEN
   IF nullif(p->>'training_session_id','') IS NOT NULL OR nullif(c->>'training_session_id','') IS NOT NULL THEN
    RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
   parent_id:=o.training_session_id;
   IF r.record_id IS NOT NULL AND (o.completion_record_id IS DISTINCT FROM v_record_id OR r.training_session_id IS DISTINCT FROM parent_id) THEN
    RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  ELSE
   parent_id:=nullif(p->>'training_session_id','')::bigint;
   IF o.id IS NULL OR (o.completion_record_id IS NOT NULL AND o.completion_record_id IS DISTINCT FROM v_record_id) OR o.training_session_id IS DISTINCT FROM parent_id
    OR o.programme_version_id IS DISTINCT FROM a.programme_version_id
    OR o.materialised_package_content_hash IS DISTINCT FROM a.materialised_package_content_hash
    OR o.programmed_session_key IS DISTINCT FROM key OR p->>'programmed_session_key' IS DISTINCT FROM key
    OR p->>'logical_completion_key' IS DISTINCT FROM key OR p->>'protocol_id' IS DISTINCT FROM slot.protocol_id
    OR p->>'materialised_package_content_hash' IS DISTINCT FROM a.materialised_package_content_hash
    OR (p->>'expected_week')::int IS DISTINCT FROM w.week_number OR p->>'expected_day_key' IS DISTINCT FROM d.day_key
    OR (p->>'expected_slot_order')::int IS DISTINCT FROM slot.session_order THEN
    RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
   IF mode='fixed' AND (occ.session_slot_id IS DISTINCT FROM slot.id OR occ.programme_version_id IS DISTINCT FROM version_id
    OR occ.programmed_session_key IS DISTINCT FROM key OR occ.protocol_id IS DISTINCT FROM slot.protocol_id
    OR occ.package_content_hash IS DISTINCT FROM a.materialised_package_content_hash) THEN
    RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  END IF;
  IF r.record_id IS NOT NULL AND
   ((r.assignment_id IS NOT NULL AND r.assignment_id IS DISTINCT FROM a.id)
    OR (r.programme_session_id IS NOT NULL AND r.programme_session_id IS DISTINCT FROM slot.id)
    OR (r.status<>'in_progress' AND o.completion_record_id IS DISTINCT FROM r.record_id)) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 END IF;
 IF parent_id IS NOT NULL THEN
  SELECT * INTO s FROM public.training_sessions WHERE id=parent_id AND athlete_id=actor::text FOR UPDATE;
  IF NOT FOUND OR (r.record_id IS NOT NULL AND r.training_session_id IS DISTINCT FROM s.id)
   OR (c ? 'source_protocol_id' AND c->>'source_protocol_id' IS DISTINCT FROM s.protocol_id)
   OR (r.source_protocol_id IS NOT NULL AND r.source_protocol_id IS DISTINCT FROM s.protocol_id) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  IF mode='standalone' AND (s.programme_id IS NOT NULL OR EXISTS(SELECT 1 FROM public.programme_slot_outcomes WHERE training_session_id=s.id)) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  IF mode<>'standalone' AND ((s.programme_id IS NOT NULL AND s.programme_id NOT IN (a.lineage_code,a.programme_version_id::text))
   OR (s.week_number IS NOT NULL AND s.week_number IS DISTINCT FROM w.week_number)) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 END IF;
 IF v_record_id IS NULL OR (c ? 'athlete_id' AND c->>'athlete_id' IS DISTINCT FROM actor::text)
  OR (c ? 'record_id' AND c->>'record_id' IS DISTINCT FROM v_record_id::text)
  OR (c ? 'training_session_id' AND c->>'training_session_id' IS DISTINCT FROM parent_id::text)
  OR (mode<>'standalone' AND ((c ? 'assignment_id' AND c->>'assignment_id' IS DISTINCT FROM a.id::text)
   OR (c ? 'programme_session_id' AND c->>'programme_session_id' IS DISTINCT FROM slot.id::text)
   OR (c ? 'programme_id' AND c->>'programme_id' NOT IN (a.lineage_code,a.programme_version_id::text))
   OR (mode='backfill' AND c ? 'source_protocol_id' AND c->>'source_protocol_id' IS DISTINCT FROM occ.protocol_id))) THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 IF r.record_id IS NOT NULL THEN PERFORM public.cohort_assert_record_parent_v1(r); END IF;
EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
 RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
END $$;
REVOKE ALL ON FUNCTION public.cohort_assert_completion_request_v1(jsonb,text) FROM PUBLIC,anon,authenticated,service_role;

-- Parent-free draft records also retain their checked assignment ownership.
CREATE OR REPLACE FUNCTION public.cohort_guard_completion_record_identity_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE a public.programme_assignments%ROWTYPE; slot_version uuid; slot_week int; slot_protocol text;
 parent public.training_sessions%ROWTYPE; existing public.training_session_records%ROWTYPE;
BEGIN
 IF current_setting('role',true) IN ('authenticated','anon') AND
  (auth.uid() IS NULL OR NEW.athlete_id IS DISTINCT FROM auth.uid()::text OR NOT public.cohort_auth_is_athlete()) THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
 END IF;
 IF TG_OP='UPDATE' AND OLD.record_id IS DISTINCT FROM NEW.record_id THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' THEN existing:=OLD;
 ELSE SELECT * INTO existing FROM public.training_session_records WHERE record_id=NEW.record_id; END IF;
 IF existing.record_id IS NOT NULL AND
  (existing.athlete_id IS DISTINCT FROM NEW.athlete_id
   OR existing.training_session_id IS DISTINCT FROM NEW.training_session_id
   OR (existing.programme_id IS NOT NULL AND existing.programme_id IS DISTINCT FROM NEW.programme_id)
   OR (existing.assignment_id IS NOT NULL AND existing.assignment_id IS DISTINCT FROM NEW.assignment_id)
   OR (existing.programme_session_id IS NOT NULL AND existing.programme_session_id IS DISTINCT FROM NEW.programme_session_id)
   OR (existing.source_protocol_id IS NOT NULL AND existing.source_protocol_id IS DISTINCT FROM NEW.source_protocol_id)) THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
 END IF;
 PERFORM public.cohort_assert_record_parent_v1(NEW);
 IF current_setting('role',true) IN ('authenticated','anon') AND NEW.assignment_id IS NOT NULL THEN
  SELECT * INTO a FROM public.programme_assignments WHERE id=NEW.assignment_id AND athlete_id=auth.uid() FOR SHARE;
  SELECT w.version_id,w.week_number,s.protocol_id INTO slot_version,slot_week,slot_protocol FROM public.programme_version_session_slots s
   JOIN public.programme_version_days d ON d.id=s.day_id JOIN public.programme_version_weeks w ON w.id=d.week_id
   WHERE s.id=NEW.programme_session_id;
  IF a.id IS NULL OR (NEW.programme_session_id IS NOT NULL AND slot_version IS DISTINCT FROM a.programme_version_id) THEN
   RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501';
  END IF;
  -- Backfill creates its parent before its outcome. Require the exact owned
  -- assignment/slot and physical parent metadata during that interval too.
  IF NEW.training_session_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.programme_slot_outcomes WHERE training_session_id=NEW.training_session_id) THEN
   SELECT * INTO parent FROM public.training_sessions WHERE id=NEW.training_session_id;
   IF NEW.programme_session_id IS NULL OR parent.programme_id IS NULL
    OR parent.programme_id NOT IN (a.lineage_code,a.programme_version_id::text)
    OR parent.week_number IS DISTINCT FROM slot_week OR parent.protocol_id IS DISTINCT FROM slot_protocol THEN
    RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
  END IF;
 END IF;
 IF current_setting('role',true) IN ('authenticated','anon') AND NEW.assignment_id IS NULL AND NEW.programme_session_id IS NOT NULL THEN
  RAISE EXCEPTION 'completion_identity_denied' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_guard_completion_record_identity_v1() FROM PUBLIC,anon,authenticated,service_role;

COMMIT;
