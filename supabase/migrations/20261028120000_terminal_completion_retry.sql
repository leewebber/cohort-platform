-- M2.4: recover canonical committed completion without reopening write eligibility.
-- No historical results are rewritten. Null receipts retain the established
-- logical-key/fingerprint contract for completions committed before this migration.
BEGIN;
ALTER TABLE public.programme_slot_outcomes
 ADD COLUMN IF NOT EXISTS completion_request_sha256 text
 CHECK (completion_request_sha256 IS NULL OR completion_request_sha256 ~ '^[0-9a-f]{64}$');

-- The receipt is server-only and immutable once committed.
CREATE OR REPLACE FUNCTION public.cohort_guard_completion_receipt_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,pg_temp AS $$
BEGIN
 IF (TG_OP='UPDATE' AND OLD.completion_request_sha256 IS NOT NULL
      AND NEW.completion_request_sha256 IS DISTINCT FROM OLD.completion_request_sha256)
  OR (NEW.completion_request_sha256 IS NOT NULL AND current_user NOT IN ('postgres','supabase_admin')) THEN
  RAISE EXCEPTION 'completion_receipt_immutable' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_guard_completion_receipt_v1() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS completion_receipt_guard ON public.programme_slot_outcomes;
CREATE TRIGGER completion_receipt_guard BEFORE INSERT OR UPDATE OF completion_request_sha256
 ON public.programme_slot_outcomes FOR EACH ROW EXECUTE FUNCTION public.cohort_guard_completion_receipt_v1();

-- Transport keys and locally recomputed finish time/duration are not actuals.
-- Everything else, including immutable snapshot/provenance, is bound to the
-- first successful transaction and remains independent of later corrections.
CREATE OR REPLACE FUNCTION public.cohort_completion_request_sha256_v1(p jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SECURITY DEFINER
SET search_path=pg_catalog,public,extensions,pg_temp AS $$
 SELECT encode(digest(((p - 'idempotency_key' - 'occurrence_id' - 'completion_record') ||
  jsonb_build_object('completion_record',(p->'completion_record') - 'completed_at' - 'duration_seconds'))::text,'sha256'),'hex');
$$;
REVOKE ALL ON FUNCTION public.cohort_completion_request_sha256_v1(jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.cohort_replay_programme_completion_v1(p jsonb, fixed boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE a public.programme_assignments%ROWTYPE; o public.programme_slot_outcomes%ROWTYPE;
 r public.training_session_records%ROWTYPE; v public.programme_versions%ROWTYPE;
 occ public.programme_schedule_occurrences%ROWTYPE; same_request boolean;
BEGIN
 -- The public wrapper has already locked and validated the full owner/link chain.
 SELECT * INTO a FROM public.programme_assignments WHERE id=(p->>'assignment_id')::uuid FOR UPDATE;
 SELECT * INTO o FROM public.programme_slot_outcomes
  WHERE assignment_id=a.id AND session_slot_id=(p->>'session_slot_id')::uuid FOR UPDATE;
 IF o.completion_record_id IS NULL THEN RETURN NULL; END IF;
 -- Completion only explains 'completed'. Paused/reassigned and unavailable or
 -- revoked versions remain denied, even for a formerly committed request.
 IF a.status NOT IN ('active','completed') OR a.materialised_at IS NULL THEN
  RETURN jsonb_build_object('status','validation_failure','code','assignment_inactive'); END IF;
 IF fixed AND a.schedule_mode IS DISTINCT FROM 'fixed_schedule' THEN
  RETURN jsonb_build_object('status','validation_failure','code','fixed_assignment_ineligible'); END IF;
 SELECT * INTO v FROM public.programme_versions WHERE id=a.programme_version_id FOR SHARE;
 IF v.id IS NULL OR v.lifecycle_status IS DISTINCT FROM 'published' OR v.archived_at IS NOT NULL THEN
  RETURN jsonb_build_object('status','validation_failure','code','exact_version_missing'); END IF;
 IF v.package_content_hash IS DISTINCT FROM a.materialised_package_content_hash THEN
  RETURN jsonb_build_object('status','validation_failure','code','package_hash_mismatch'); END IF;
 SELECT * INTO r FROM public.training_session_records WHERE record_id=o.completion_record_id FOR UPDATE;
 IF r.record_id IS NULL OR r.status NOT IN ('completed','partially_completed','abandoned')
  OR o.outcome_status NOT IN ('completed','completed_partial') THEN
  RETURN jsonb_build_object('status','conflict','code','occurrence_session_integrity_failure'); END IF;
 IF fixed THEN
  SELECT * INTO occ FROM public.programme_schedule_occurrences WHERE id=(p->>'occurrence_id')::uuid;
  IF occ.disposition IS DISTINCT FROM 'completed' THEN
   RETURN jsonb_build_object('status','conflict','code','occurrence_session_integrity_failure'); END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM public.programme_slot_outcomes x WHERE x.assignment_id=a.id
  AND x.idempotency_key=p->>'idempotency_key' AND x.id<>o.id) THEN
  RETURN jsonb_build_object('status','conflict','code','idempotency_payload_conflict'); END IF;
 same_request:=o.idempotency_key=p->>'idempotency_key';
 IF nullif(trim(p->>'idempotency_key'),'') IS NULL OR
  o.actuals_fingerprint IS DISTINCT FROM p->>'actuals_fingerprint'
  OR o.logical_completion_key IS DISTINCT FROM p->>'logical_completion_key'
  OR r.status IS DISTINCT FROM p->>'status'
  OR (o.completion_request_sha256 IS NOT NULL AND o.completion_request_sha256 IS DISTINCT FROM public.cohort_completion_request_sha256_v1(p)) THEN
  RETURN jsonb_build_object('status','conflict','code',CASE WHEN same_request THEN 'idempotency_payload_conflict' ELSE 'logical_completion_payload_conflict' END);
 END IF;
 -- No record, outcome, occurrence, cursor or timestamp is written on replay.
 RETURN jsonb_build_object('status','already_committed',
  'code',CASE WHEN same_request THEN 'idempotent_replay' ELSE 'logical_completion_replay' END,
  'completion_record_id',r.record_id,'training_session_id',r.training_session_id,'outcome_id',o.id,
  'logical_completion_key',o.logical_completion_key,'programmed_session_key',o.programmed_session_key,
  'assignment',to_jsonb(a),'completion_record',to_jsonb(r),'terminal_programme',a.status='completed') ||
  CASE WHEN fixed THEN jsonb_build_object('occurrence_id',occ.id,'original_scheduled_date',occ.original_scheduled_date) ELSE '{}'::jsonb END;
END $$;
REVOKE ALL ON FUNCTION public.cohort_replay_programme_completion_v1(jsonb,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.complete_programme_session_and_advance(payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE result jsonb; BEGIN
 IF payload ? 'athlete_id' OR payload ? 'next_week' OR payload ? 'next_day_key'
  OR payload ? 'next_slot_order' OR payload ? 'next_cursor' THEN
  RETURN jsonb_build_object('status','validation_failure','code','client_nominated_authority_forbidden'); END IF;
 PERFORM public.cohort_assert_completion_request_v1(payload,'programme');
 result:=public.cohort_replay_programme_completion_v1(payload,false);
 IF result IS NOT NULL THEN RETURN result; END IF;
 BEGIN
  result:=public.cohort_completion_programme_body_v1(payload);
  IF result->>'status' NOT IN ('committed','already_committed') THEN RAISE EXCEPTION 'completion_body_rejected' USING ERRCODE='ZC001'; END IF;
  IF result->>'status'='committed' THEN
   UPDATE public.programme_slot_outcomes SET completion_request_sha256=public.cohort_completion_request_sha256_v1(payload)
    WHERE assignment_id=(payload->>'assignment_id')::uuid AND session_slot_id=(payload->>'session_slot_id')::uuid
     AND completion_record_id=(payload->>'record_id')::uuid AND completion_request_sha256 IS NULL;
  END IF;
 EXCEPTION WHEN SQLSTATE 'ZC001' THEN RETURN result;
 END;
 RETURN result;
EXCEPTION WHEN insufficient_privilege THEN RETURN jsonb_build_object('status','authorization_failure','code','completion_identity_denied');
END $$;
-- CREATE OR REPLACE retains the existing function OID, owner and grants.

CREATE OR REPLACE FUNCTION public.complete_fixed_programme_occurrence_and_advance(payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE result jsonb; BEGIN
 IF payload ? 'athlete_id' OR payload ? 'next_week' OR payload ? 'next_day_key'
  OR payload ? 'next_slot_order' OR payload ? 'next_cursor' THEN
  RETURN jsonb_build_object('status','validation_failure','code','client_nominated_authority_forbidden'); END IF;
 PERFORM public.cohort_assert_completion_request_v1(payload,'fixed');
 result:=public.cohort_replay_programme_completion_v1(payload,true);
 IF result IS NOT NULL THEN RETURN result; END IF;
 BEGIN
  result:=public.cohort_completion_fixed_body_v1(payload);
  IF result->>'status' NOT IN ('committed','already_committed') THEN RAISE EXCEPTION 'completion_body_rejected' USING ERRCODE='ZC001'; END IF;
  IF result->>'status'='committed' THEN
   UPDATE public.programme_slot_outcomes SET completion_request_sha256=public.cohort_completion_request_sha256_v1(payload)
    WHERE assignment_id=(payload->>'assignment_id')::uuid AND session_slot_id=(payload->>'session_slot_id')::uuid
     AND completion_record_id=(payload->>'record_id')::uuid AND completion_request_sha256 IS NULL;
  END IF;
 EXCEPTION WHEN SQLSTATE 'ZC001' THEN RETURN result;
 END;
 RETURN result;
EXCEPTION WHEN insufficient_privilege THEN RETURN jsonb_build_object('status','authorization_failure','code','completion_identity_denied');
END $$;
-- CREATE OR REPLACE retains the existing function OID, owner and grants.
COMMIT;
