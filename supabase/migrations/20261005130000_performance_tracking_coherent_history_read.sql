-- C2 local coherent read boundary. No result writes, RLS or table-grant changes.
-- Programme witness admission is stopped: authenticated lacks SELECT on
-- training_sessions in the disposable baseline. Never bypass that with definer
-- helpers. A supplied claim is validated and fails explicitly, never ignored.
CREATE FUNCTION public.read_performance_tracking_history_v1(
  p_record_id uuid,
  p_programme_claim jsonb DEFAULT NULL
) RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, pg_temp
AS $function$
WITH
actor AS MATERIALIZED (SELECT auth.uid()::text AS id),
claim AS MATERIALIZED (
  SELECT CASE WHEN p_programme_claim IS NULL THEN true
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
response AS (
  SELECT CASE
    WHEN a.id IS NULL THEN jsonb_build_object('status','failure','code','ownership_denied')
    WHEN p_record_id IS NULL THEN jsonb_build_object('status','failure','code','invalid_record_id')
    WHEN NOT c.valid THEN jsonb_build_object('status','failure','code','invalid_programme_claim')
    WHEN NOT EXISTS (SELECT 1 FROM owned) THEN jsonb_build_object(
      'status','no_visible_record','athlete_id',a.id)
    WHEN p_programme_claim IS NOT NULL THEN
      CASE WHEN (SELECT assignment_id IS NULL OR training_session_id IS NULL
          OR source_protocol_id IS NULL FROM owned)
        THEN jsonb_build_object('status','failure','code','programme_scope_unproven')
        WHEN (SELECT assignment_id::text IS DISTINCT FROM p_programme_claim->>'assignment_id'
          OR training_session_id::text IS DISTINCT FROM p_programme_claim->>'training_session_id'
          OR source_protocol_id IS DISTINCT FROM p_programme_claim->>'protocol_id' FROM owned)
        THEN jsonb_build_object('status','failure','code','programme_scope_conflict')
        ELSE jsonb_build_object('status','failure','code','programme_authority_unavailable') END
    WHEN n.blocks + n.exercises + n.sets + n.corrections > 10000
      THEN jsonb_build_object('status','failure','code','evidence_limit_exceeded')
    ELSE jsonb_build_object(
      'status','ok','athlete_id',a.id,'consistency','single_statement_snapshot',
      'complete_record_tree',true,'complete_audit_set',true,
      'counts',to_jsonb(n),
      'record',(SELECT to_jsonb(r) FROM owned r),
      'blocks',coalesce((SELECT jsonb_agg(to_jsonb(b) ORDER BY block_result_id) FROM blocks b),'[]'::jsonb),
      'exercises',coalesce((SELECT jsonb_agg(to_jsonb(e) ORDER BY exercise_result_id) FROM exercises e),'[]'::jsonb),
      'sets',coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY set_result_id) FROM sets s),'[]'::jsonb),
      'corrections',coalesce((SELECT jsonb_agg(to_jsonb(k) ORDER BY correction_id) FROM corrections k),'[]'::jsonb)
    ) END AS body
  FROM actor a CROSS JOIN claim c CROSS JOIN counts n
)
SELECT CASE WHEN octet_length(body::text) > 4194304
  THEN jsonb_build_object('status','failure','code','evidence_limit_exceeded')
  ELSE body END FROM response;
$function$;

REVOKE ALL ON FUNCTION public.read_performance_tracking_history_v1(uuid,jsonb) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.read_performance_tracking_history_v1(uuid,jsonb) TO authenticated;
COMMENT ON FUNCTION public.read_performance_tracking_history_v1(uuid,jsonb) IS
  'C2 current athlete-owned History tree/audit snapshot; <=10000 child/audit rows and <=4MiB JSON. No historical replay or programme witness until missing SELECT authority is separately resolved.';
