-- Explicit new owner-gated read authority; existing invoker RPC is unchanged.
CREATE FUNCTION public.read_performance_tracking_programme_history_v1(p_record_id uuid,p_programme_claim jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $function$
WITH actor AS MATERIALIZED (SELECT auth.uid()::text AS id),
claim AS MATERIALIZED (
  SELECT CASE WHEN p_programme_claim IS NULL THEN false
    WHEN jsonb_typeof(p_programme_claim) IS DISTINCT FROM 'object'
      OR octet_length(p_programme_claim::text) > 16384 THEN false
    ELSE
      NOT EXISTS (
        SELECT 1 FROM jsonb_object_keys(p_programme_claim) k
        WHERE k NOT IN ('assignment_id','occurrence_id','training_session_id',
          'programme_version_id','package_hash','slot_key','protocol_id',
          'protocol_revision','block_id','workout_id','step_id','repeat_ordinal','mapping_hash')
      )
      AND NOT EXISTS (
        SELECT 1 FROM unnest(ARRAY['assignment_id','occurrence_id',
          'programme_version_id']) k
        WHERE jsonb_typeof(p_programme_claim->k) IS DISTINCT FROM 'string'
          OR (p_programme_claim->>k) !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      )
      AND jsonb_typeof(p_programme_claim->'training_session_id') = 'string'
      AND (p_programme_claim->>'training_session_id') ~ '^[1-9][0-9]{0,18}$'
      AND (length(p_programme_claim->>'training_session_id') < 19
        OR (p_programme_claim->>'training_session_id') <= '9223372036854775807')
      AND NOT EXISTS (
        SELECT 1 FROM unnest(ARRAY['slot_key','protocol_id','block_id']) k
        WHERE jsonb_typeof(p_programme_claim->k) IS DISTINCT FROM 'string'
          OR nullif(p_programme_claim->>k, '') IS NULL
          OR btrim(p_programme_claim->>k) IS DISTINCT FROM p_programme_claim->>k
      )
      AND (p_programme_claim->>'block_id') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      AND jsonb_typeof(p_programme_claim->'package_hash') = 'string'
      AND (p_programme_claim->>'package_hash') ~ '^[0-9a-f]{64}$'
      AND jsonb_typeof(p_programme_claim->'protocol_revision') = 'number'
      AND (p_programme_claim->>'protocol_revision') ~ '^[1-9][0-9]{0,8}$'
      AND CASE WHEN p_programme_claim ?| ARRAY['workout_id','step_id','repeat_ordinal','mapping_hash']
        THEN NOT EXISTS (
          SELECT 1 FROM unnest(ARRAY['workout_id','step_id']) k
          WHERE jsonb_typeof(p_programme_claim->k) IS DISTINCT FROM 'string'
            OR nullif(p_programme_claim->>k, '') IS NULL
            OR btrim(p_programme_claim->>k) IS DISTINCT FROM p_programme_claim->>k
        )
        AND jsonb_typeof(p_programme_claim->'repeat_ordinal') = 'number'
        AND (p_programme_claim->>'repeat_ordinal') ~ '^[1-9][0-9]{0,8}$'
        AND jsonb_typeof(p_programme_claim->'mapping_hash') = 'string'
        AND (p_programme_claim->>'mapping_hash') ~ '^[0-9a-f]{64}$'
        ELSE true END
    END IS TRUE AS valid
),
owned AS MATERIALIZED (
  SELECT r.* FROM public.training_session_records r CROSS JOIN actor a
  WHERE r.record_id = p_record_id AND r.athlete_id = a.id
),
blocks AS MATERIALIZED (
  SELECT b.* FROM public.training_block_results b JOIN owned r ON r.record_id = b.session_record_id
),
exercises AS MATERIALIZED (
  SELECT e.* FROM public.training_exercise_results e JOIN blocks b ON b.block_result_id = e.block_result_id
),
sets AS MATERIALIZED (
  SELECT s.* FROM public.training_set_results s JOIN exercises e ON e.exercise_result_id = s.exercise_result_id
),
corrections AS MATERIALIZED (
  SELECT c.* FROM public.performance_result_corrections c JOIN owned r ON r.record_id = c.record_id
),
counts AS MATERIALIZED (
  SELECT (SELECT count(*) FROM blocks) AS blocks,
    (SELECT count(*) FROM exercises) AS exercises,
    (SELECT count(*) FROM sets) AS sets,
    (SELECT count(*) FROM corrections) AS corrections
),
assignment AS MATERIALIZED (
 SELECT a.* FROM public.programme_assignments a JOIN owned r ON a.id=r.assignment_id
 CROSS JOIN actor who WHERE a.athlete_id::text=who.id
),
version AS MATERIALIZED (
 SELECT v.* FROM public.programme_versions v JOIN assignment a ON v.id=a.programme_version_id
),
artifact AS MATERIALIZED (
 SELECT ar.* FROM public.programme_publication_artifacts ar JOIN version v ON ar.programme_version_id=v.id
),
projection AS MATERIALIZED (
 SELECT p.* FROM public.programme_schedule_projections p JOIN assignment a ON p.assignment_id=a.id
 CROSS JOIN actor who WHERE p.athlete_id::text=who.id
),
occurrence AS MATERIALIZED (
 SELECT o.* FROM public.programme_schedule_occurrences o JOIN assignment a ON o.assignment_id=a.id
 WHERE o.id::text=p_programme_claim->>'occurrence_id'
),
outcome AS MATERIALIZED (
 SELECT o.* FROM public.programme_slot_outcomes o JOIN assignment a ON o.assignment_id=a.id
 JOIN owned r ON r.programme_session_id=o.session_slot_id
),
session AS MATERIALIZED (
 SELECT t.* FROM public.training_sessions t JOIN owned r ON t.id=r.training_session_id
 CROSS JOIN actor who WHERE t.athlete_id=who.id
),
slot AS MATERIALIZED (
 SELECT s.*,w.version_id,w.week_number,d.day_key,d.day_order FROM public.programme_version_session_slots s
 JOIN owned r ON s.id=r.programme_session_id JOIN public.programme_version_days d ON d.id=s.day_id
 JOIN public.programme_version_weeks w ON w.id=d.week_id
),
frozen AS MATERIALIZED (
 SELECT f.* FROM public.programme_occurrence_running_target_snapshots f JOIN owned r ON f.training_session_id=r.training_session_id
 JOIN assignment a ON f.assignment_id=a.id CROSS JOIN actor who WHERE f.athlete_id::text=who.id
),
seal AS MATERIALIZED (
 SELECT public.cohort_tracking_scope_seal(ar.programme_version_id,ar.canonical_text::jsonb) AS current_scope,
 ar.scope_seal_text::jsonb AS retained_scope FROM artifact ar
),
scope_block AS MATERIALIZED (
 SELECT ss AS authored_session,bb AS authored_block FROM seal se
 CROSS JOIN LATERAL jsonb_array_elements(se.retained_scope->'sessions') ss
 CROSS JOIN LATERAL jsonb_array_elements(ss->'blocks') bb
 WHERE ss->>'protocol_id'=p_programme_claim->>'protocol_id' AND bb->>'block_id'=p_programme_claim->>'block_id'
),
limits AS MATERIALIZED (
 SELECT n.*, coalesce((SELECT octet_length(to_jsonb(r)::text) FROM owned r),0)
  +coalesce((SELECT sum(octet_length(to_jsonb(b)::text)) FROM blocks b),0)
  +coalesce((SELECT sum(octet_length(to_jsonb(e)::text)) FROM exercises e),0)
  +coalesce((SELECT sum(octet_length(to_jsonb(s)::text)) FROM sets s),0)
  +coalesce((SELECT sum(octet_length(to_jsonb(c)::text)) FROM corrections c),0)
  +coalesce((SELECT octet_length(canonical_text)+octet_length(scope_seal_text) FROM artifact),0) AS bytes
 FROM counts n
),
checks AS MATERIALIZED (
 SELECT CASE
 WHEN who.id IS NULL THEN 'ownership_denied'
 WHEN p_record_id IS NULL THEN 'invalid_record_id'
 WHEN NOT cl.valid THEN 'invalid_programme_claim'
 WHEN NOT EXISTS(SELECT 1 FROM owned) THEN 'programme_scope_unproven'
 WHEN EXISTS(SELECT 1 FROM owned r WHERE r.assignment_id IS NULL OR r.training_session_id IS NULL OR r.programme_session_id IS NULL OR r.source_protocol_id IS NULL) THEN 'programme_scope_unproven'
 WHEN EXISTS(SELECT 1 FROM owned r WHERE r.assignment_id::text IS DISTINCT FROM p_programme_claim->>'assignment_id'
  OR r.training_session_id::text IS DISTINCT FROM p_programme_claim->>'training_session_id'
  OR r.source_protocol_id IS DISTINCT FROM p_programme_claim->>'protocol_id') THEN 'programme_scope_conflict'
 WHEN n.blocks+n.exercises+n.sets+n.corrections>10000 OR n.bytes>4194304 THEN 'evidence_limit_exceeded'
 WHEN EXISTS(SELECT 1 FROM corrections c JOIN owned r ON true WHERE c.athlete_id IS DISTINCT FROM who.id OR c.actor_id::text IS DISTINCT FROM who.id OR c.training_session_id IS DISTINCT FROM r.training_session_id) THEN 'programme_scope_conflict'
 WHEN NOT EXISTS(SELECT 1 FROM assignment) OR NOT EXISTS(SELECT 1 FROM version)
  OR NOT EXISTS(SELECT 1 FROM projection) OR NOT EXISTS(SELECT 1 FROM occurrence)
  OR NOT EXISTS(SELECT 1 FROM outcome) OR NOT EXISTS(SELECT 1 FROM session)
  OR NOT EXISTS(SELECT 1 FROM slot) THEN 'programme_scope_unproven'
 WHEN EXISTS(SELECT 1 FROM assignment a,version v,projection p,occurrence o,outcome ot,session t,slot s,owned r
  WHERE a.programme_version_id::text IS DISTINCT FROM p_programme_claim->>'programme_version_id'
   OR a.materialised_package_content_hash IS DISTINCT FROM p_programme_claim->>'package_hash'
   OR a.materialised_package_schema_version IS DISTINCT FROM v.package_schema_version::text
   OR v.package_content_hash IS DISTINCT FROM a.materialised_package_content_hash
   OR v.lifecycle_status NOT IN ('published','archived') OR v.published_at IS NULL
   OR p.programme_version_id IS DISTINCT FROM v.id OR p.package_content_hash IS DISTINCT FROM v.package_content_hash
   OR o.programme_version_id IS DISTINCT FROM v.id OR o.package_content_hash IS DISTINCT FROM v.package_content_hash
   OR o.session_slot_id IS DISTINCT FROM s.id OR o.protocol_id IS DISTINCT FROM t.protocol_id
   OR o.week_number IS DISTINCT FROM s.week_number OR o.day_key IS DISTINCT FROM s.day_key OR o.session_order IS DISTINCT FROM s.session_order
   OR o.programmed_session_key IS DISTINCT FROM pg_catalog.format('prog:%s@%s:w%s:%s:s%s:%s',a.id::text,v.id::text,o.week_number,o.day_key,o.session_order,btrim(o.protocol_id))
   OR s.version_id IS DISTINCT FROM v.id OR s.package_slot_key IS DISTINCT FROM p_programme_claim->>'slot_key'
   OR s.protocol_id IS DISTINCT FROM r.source_protocol_id OR t.protocol_id IS DISTINCT FROM s.protocol_id
   OR ot.training_session_id IS DISTINCT FROM t.id OR ot.programme_version_id IS DISTINCT FROM v.id
   OR ot.materialised_package_content_hash IS DISTINCT FROM v.package_content_hash
   OR ot.programmed_session_key IS DISTINCT FROM o.programmed_session_key
   OR ot.week_number IS DISTINCT FROM s.week_number OR ot.day_key IS DISTINCT FROM s.day_key OR ot.session_order IS DISTINCT FROM s.session_order
   OR (ot.replacement_protocol_id IS NOT NULL AND ot.replacement_protocol_id IS DISTINCT FROM s.protocol_id)
   OR (r.status IN ('completed','partially_completed') AND (ot.outcome_status NOT IN ('completed','completed_partial') OR ot.completion_record_id IS DISTINCT FROM r.record_id))
   OR (r.status='in_progress' AND ot.outcome_status IS DISTINCT FROM 'in_progress')) THEN 'programme_scope_conflict'
 WHEN NOT EXISTS(SELECT 1 FROM artifact) THEN 'programme_scope_unproven'
 WHEN EXISTS(SELECT 1 FROM artifact ar,version v,seal se WHERE ar.package_content_hash IS DISTINCT FROM v.package_content_hash
  OR ar.package_schema_version IS DISTINCT FROM v.package_schema_version
  OR se.current_scope IS DISTINCT FROM se.retained_scope) THEN 'programme_scope_conflict'
 WHEN (SELECT count(*) FROM scope_block)<>1 OR (SELECT count(*) FROM blocks WHERE source_block_id=p_programme_claim->>'block_id')<>1 THEN 'programme_scope_unproven'
 WHEN EXISTS(SELECT 1 FROM scope_block b WHERE b.authored_session->>'revision_number' IS DISTINCT FROM p_programme_claim->>'protocol_revision') THEN 'programme_scope_conflict'
 WHEN EXISTS(SELECT 1 FROM blocks b WHERE b.source_block_id=p_programme_claim->>'block_id'
  AND b.block_snapshot ? 'sourceBlockId' AND b.block_snapshot->>'sourceBlockId' IS DISTINCT FROM b.source_block_id) THEN 'programme_scope_conflict'
 WHEN p_programme_claim ? 'workout_id' AND EXISTS(SELECT 1 FROM slot s WHERE
  s.authored_running_v1 IS NULL OR s.authored_running_v1->>'workout_id' IS DISTINCT FROM p_programme_claim->>'workout_id'
  OR s.authored_running_v1->>'execution_mapping_sha256' IS DISTINCT FROM p_programme_claim->>'mapping_hash'
  OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(s.authored_running_v1->'executable_step_bindings')='array' THEN s.authored_running_v1->'executable_step_bindings' ELSE '[]'::jsonb END) binding
   WHERE binding->>'step_id'=p_programme_claim->>'step_id' AND binding->>'session_block_id'=p_programme_claim->>'block_id')) THEN 'programme_scope_conflict'
 WHEN p_programme_claim ? 'workout_id' AND NOT EXISTS(
  SELECT 1 FROM slot s,blocks b,frozen f,occurrence o
  WHERE b.source_block_id=p_programme_claim->>'block_id' AND f.occurrence_id=o.id
   AND f.snapshot->>'programme_version_id'=s.version_id::text AND f.snapshot->>'session_slot_id'=s.id::text
   AND f.snapshot->>'package_content_hash'=p_programme_claim->>'package_hash'
   AND s.authored_running_v1->>'workout_id'=p_programme_claim->>'workout_id'
   AND s.authored_running_v1->>'execution_mapping_sha256'=p_programme_claim->>'mapping_hash'
   AND b.block_snapshot#>>'{structuredRunningV1,workout_id}'=p_programme_claim->>'workout_id'
   AND b.block_snapshot#>>'{structuredRunningV1,session_block_id}'=p_programme_claim->>'block_id'
   AND b.block_snapshot#>>'{structuredRunningV1,package_content_hash}'=p_programme_claim->>'package_hash'
   AND b.block_snapshot#>>'{structuredRunningV1,execution_mapping_sha256}'=p_programme_claim->>'mapping_hash'
   AND b.block_snapshot#>'{structuredRunningV1,frozen_target_snapshot}'=f.snapshot
   AND EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(s.authored_running_v1->'executable_step_bindings')='array' THEN s.authored_running_v1->'executable_step_bindings' ELSE '[]'::jsonb END) binding
     WHERE binding->>'step_id'=p_programme_claim->>'step_id' AND binding->>'session_block_id'=p_programme_claim->>'block_id')
   AND EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(b.block_snapshot#>'{structuredRunningV1,work_repetitions}')='array' THEN b.block_snapshot#>'{structuredRunningV1,work_repetitions}' ELSE '[]'::jsonb END) rep
     WHERE rep->>'workout_id'=p_programme_claim->>'workout_id' AND rep->>'session_block_id'=p_programme_claim->>'block_id'
      AND rep->>'authored_step_id'=p_programme_claim->>'step_id' AND rep->>'repeat_ordinal'=p_programme_claim->>'repeat_ordinal')) THEN 'programme_scope_unproven'
 ELSE NULL END AS code
 FROM actor who CROSS JOIN claim cl CROSS JOIN limits n
),
response AS (
 SELECT CASE WHEN ch.code IS NOT NULL THEN jsonb_build_object('status','failure','code',ch.code)
 ELSE jsonb_build_object('status','ok','athlete_id',a.id,'consistency','single_statement_snapshot',
 'complete_record_tree',true,'complete_audit_set',true,'counts',(SELECT to_jsonb(n) FROM counts n),
 'record',(SELECT to_jsonb(r) FROM owned r),
 'blocks',coalesce((SELECT jsonb_agg(to_jsonb(b) ORDER BY block_result_id) FROM blocks b),'[]'::jsonb),
 'exercises',coalesce((SELECT jsonb_agg(to_jsonb(e) ORDER BY exercise_result_id) FROM exercises e),'[]'::jsonb),
 'sets',coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY set_result_id) FROM sets s),'[]'::jsonb),
 'corrections',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY correction_id) FROM corrections c),'[]'::jsonb),
 'programme',jsonb_build_object('claim',p_programme_claim,'artifact',(SELECT to_jsonb(ar) FROM artifact ar),
  'current_scope',(SELECT current_scope FROM seal))) END AS body FROM actor a CROSS JOIN checks ch
)
SELECT CASE WHEN octet_length(body::text)>4194304 THEN jsonb_build_object('status','failure','code','evidence_limit_exceeded') ELSE body END FROM response;
$function$;
REVOKE ALL ON FUNCTION public.read_performance_tracking_programme_history_v1(uuid,jsonb) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.read_performance_tracking_programme_history_v1(uuid,jsonb) TO authenticated;
