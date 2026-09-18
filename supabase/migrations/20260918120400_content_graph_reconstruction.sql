-- M9 Sprint 2: local reconstruction job tracking. No hosted content rewrite.

CREATE TABLE IF NOT EXISTS public.content_graph_reconstruction_jobs (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_key                  TEXT NOT NULL,
  source_fingerprint       TEXT NOT NULL,
  dry_run                  BOOLEAN NOT NULL DEFAULT TRUE,
  status                   TEXT NOT NULL,
  classified_resolvable    INTEGER NOT NULL DEFAULT 0,
  classified_supplemental  INTEGER NOT NULL DEFAULT 0,
  classified_unresolved    INTEGER NOT NULL DEFAULT 0,
  classified_invalid       INTEGER NOT NULL DEFAULT 0,
  rows_written             INTEGER NOT NULL DEFAULT 0,
  report                   JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT content_graph_reconstruction_jobs_status_check
    CHECK (status IN ('dry_run', 'applied', 'rejected', 'interrupted')),
  CONSTRAINT content_graph_reconstruction_jobs_sha
    CHECK (source_fingerprint ~ '^[0-9a-f]{64}$')
);

CREATE UNIQUE INDEX IF NOT EXISTS content_graph_reconstruction_jobs_key_uidx
  ON public.content_graph_reconstruction_jobs (job_key);

ALTER TABLE public.content_graph_reconstruction_jobs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.content_graph_reconstruction_jobs FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.content_graph_reconstruction_jobs
  TO service_role;

CREATE OR REPLACE FUNCTION public.content_graph_record_reconstruction(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_key TEXT;
  v_fp TEXT;
  v_dry BOOLEAN;
  v_status TEXT;
  v_existing public.content_graph_reconstruction_jobs%ROWTYPE;
  v_id UUID;
  v_written INTEGER;
BEGIN
  IF NOT public.content_graph_is_service_role()
     AND NOT public.cohort_auth_is_coach() THEN
    RETURN jsonb_build_object('status', 'unauthorised', 'code', 'unauthorised');
  END IF;
  IF public.cohort_auth_is_athlete()
     AND NOT public.cohort_auth_is_coach()
     AND NOT public.content_graph_is_service_role() THEN
    RETURN jsonb_build_object('status', 'unauthorised', 'code', 'athlete_denied');
  END IF;

  v_key := NULLIF(trim(p_payload->>'job_key'), '');
  v_fp := lower(NULLIF(trim(p_payload->>'source_fingerprint'), ''));
  v_dry := COALESCE((p_payload->>'dry_run')::BOOLEAN, TRUE);
  v_status := CASE WHEN v_dry THEN 'dry_run' ELSE 'applied' END;
  v_written := COALESCE((p_payload->>'rows_written')::INTEGER, 0);

  IF v_key IS NULL OR v_fp IS NULL OR v_fp !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('status', 'rejected', 'code', 'invalid_fingerprint');
  END IF;

  SELECT * INTO v_existing
  FROM public.content_graph_reconstruction_jobs
  WHERE job_key = v_key
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.source_fingerprint IS DISTINCT FROM v_fp THEN
      UPDATE public.content_graph_reconstruction_jobs
      SET status = 'rejected',
          updated_at = NOW(),
          report = jsonb_build_object(
            'code', 'source_changed_during_resume',
            'previous_fingerprint', v_existing.source_fingerprint
          )
      WHERE id = v_existing.id;
      RETURN jsonb_build_object(
        'status', 'rejected',
        'code', 'source_changed_during_resume',
        'job_id', v_existing.id
      );
    END IF;
    UPDATE public.content_graph_reconstruction_jobs
    SET status = v_status,
        classified_resolvable = COALESCE((p_payload->>'classified_resolvable')::INTEGER, v_existing.classified_resolvable),
        classified_supplemental = COALESCE((p_payload->>'classified_supplemental')::INTEGER, v_existing.classified_supplemental),
        classified_unresolved = COALESCE((p_payload->>'classified_unresolved')::INTEGER, v_existing.classified_unresolved),
        classified_invalid = COALESCE((p_payload->>'classified_invalid')::INTEGER, v_existing.classified_invalid),
        rows_written = v_written,
        report = COALESCE(p_payload->'report', v_existing.report),
        dry_run = v_dry,
        updated_at = NOW()
    WHERE id = v_existing.id;
    RETURN jsonb_build_object(
      'status', CASE WHEN v_written = 0 AND NOT v_dry THEN 'noop' ELSE v_status END,
      'job_id', v_existing.id,
      'second_pass_noop', v_written = 0 AND v_existing.status = 'applied'
    );
  END IF;

  INSERT INTO public.content_graph_reconstruction_jobs (
    job_key,
    source_fingerprint,
    dry_run,
    status,
    classified_resolvable,
    classified_supplemental,
    classified_unresolved,
    classified_invalid,
    rows_written,
    report
  ) VALUES (
    v_key,
    v_fp,
    v_dry,
    v_status,
    COALESCE((p_payload->>'classified_resolvable')::INTEGER, 0),
    COALESCE((p_payload->>'classified_supplemental')::INTEGER, 0),
    COALESCE((p_payload->>'classified_unresolved')::INTEGER, 0),
    COALESCE((p_payload->>'classified_invalid')::INTEGER, 0),
    v_written,
    COALESCE(p_payload->'report', '{}'::jsonb)
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'status', v_status,
    'job_id', v_id,
    'second_pass_noop', FALSE
  );
END;
$$;

REVOKE ALL ON FUNCTION public.content_graph_record_reconstruction(JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.content_graph_record_reconstruction(JSONB)
  TO authenticated, service_role;

COMMENT ON TABLE public.content_graph_reconstruction_jobs IS
  'Local/idempotent reconstruction ledger. Does not rewrite authored programme content or assignment pins.';
