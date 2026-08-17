-- Correct replace_approved_cohort_global_programme_version for the lawful
-- reconciliation state where the selected replacement is already published,
-- package-valid, catalogue-eligible, and globally approved.
--
-- In that state the RPC must retire the current approved version atomically
-- without issuing any UPDATE against the immutable replacement row.
-- Do not edit 20260813160000; uniqueness (20260813161000) remains pending
-- until after hosted reconciliation.

CREATE OR REPLACE FUNCTION public.replace_approved_cohort_global_programme_version(
  p_retiring_version_id UUID,
  p_replacement_version_id UUID,
  p_actor TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_retiring public.programme_versions%ROWTYPE;
  v_replacement public.programme_versions%ROWTYPE;
  v_slot_count INT;
  v_eligible_count INT;
  v_replacement_already_approved BOOLEAN := FALSE;
BEGIN
  IF p_retiring_version_id IS NULL
     OR p_replacement_version_id IS NULL
     OR p_retiring_version_id = p_replacement_version_id
     OR nullif(trim(COALESCE(p_actor, '')), '') IS NULL
  THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_args');
  END IF;

  SELECT * INTO v_replacement
  FROM public.programme_versions
  WHERE id = p_replacement_version_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'replacement_not_found'
    );
  END IF;

  -- Serialise every catalogue lifecycle operation for this lineage.
  PERFORM 1
  FROM public.programme_lineages
  WHERE id = v_replacement.lineage_id
  FOR UPDATE;

  SELECT * INTO v_retiring
  FROM public.programme_versions
  WHERE id = p_retiring_version_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'retiring_version_not_found'
    );
  END IF;

  SELECT * INTO v_replacement
  FROM public.programme_versions
  WHERE id = p_replacement_version_id
  FOR UPDATE;

  IF v_retiring.lineage_id <> v_replacement.lineage_id THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'wrong_lineage');
  END IF;

  -- Exact retry/reconciliation after a successful prior call.
  IF v_retiring.lifecycle_status = 'archived'
     AND v_retiring.approved_for_global = FALSE
     AND v_retiring.archived_at IS NOT NULL
     AND v_replacement.lifecycle_status = 'published'
     AND v_replacement.approved_for_global = TRUE
     AND v_replacement.archived_at IS NULL
  THEN
    SELECT COUNT(*) INTO v_eligible_count
    FROM public.programme_versions eligible
    WHERE eligible.lineage_id = v_replacement.lineage_id
      AND eligible.lifecycle_status = 'published'
      AND eligible.library_scope = 'cohort_global'
      AND eligible.owner_type = 'global'
      AND eligible.approved_for_global = TRUE
      AND eligible.archived_at IS NULL;

    IF v_eligible_count = 1 THEN
      RETURN jsonb_build_object(
        'status', 'already_replaced',
        'code', 'idempotent_success',
        'retiring_version_id', p_retiring_version_id,
        'replacement_version_id', p_replacement_version_id,
        'eligible_version_count', 1,
        'actor', trim(p_actor)
      );
    END IF;
  END IF;

  IF v_retiring.lifecycle_status <> 'published'
     OR v_retiring.approved_for_global <> TRUE
     OR v_retiring.archived_at IS NOT NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'lifecycle_invariant_failure',
      'code', 'retiring_version_not_current'
    );
  END IF;

  IF v_replacement.lifecycle_status <> 'published'
     OR v_replacement.library_scope <> 'cohort_global'
     OR v_replacement.owner_type <> 'global'
     OR v_replacement.archived_at IS NOT NULL
     OR v_replacement.package_schema_version IS NULL
     OR v_replacement.package_content_hash IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_replacement'
    );
  END IF;

  SELECT COUNT(*) INTO v_slot_count
  FROM public.programme_version_session_slots s
  JOIN public.programme_version_days d ON d.id = s.day_id
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = p_replacement_version_id;

  IF v_slot_count < 1 OR EXISTS (
    SELECT 1
    FROM public.programme_version_session_slots s
    JOIN public.programme_version_days d ON d.id = s.day_id
    JOIN public.programme_version_weeks w ON w.id = d.week_id
    LEFT JOIN public.performance_protocols p ON p.protocol_id = s.protocol_id
    WHERE w.version_id = p_replacement_version_id
      AND (
        p.protocol_id IS NULL
        OR p.lifecycle_status <> 'published'
        OR COALESCE(p.content_kind, '') = 'session_template'
        OR s.protocol_id LIKE 'TMP-%'
      )
  ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_replacement_structure'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.programme_versions competing
    WHERE competing.lineage_id = v_replacement.lineage_id
      AND competing.id NOT IN (
        p_retiring_version_id,
        p_replacement_version_id
      )
      AND competing.lifecycle_status = 'published'
      AND competing.library_scope = 'cohort_global'
      AND competing.owner_type = 'global'
      AND competing.approved_for_global = TRUE
      AND competing.archived_at IS NULL
  ) THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'conflicting_eligible_version'
    );
  END IF;

  -- Already published+valid+approved: approval is satisfied; do not UPDATE the
  -- immutable replacement row (no content rewrite, no updated_at bump).
  v_replacement_already_approved := (
    v_replacement.approved_for_global = TRUE
  );

  -- A nested block gives typed failure while rolling both row changes back as
  -- one subtransaction if a trigger/constraint/invariant rejects either write.
  BEGIN
    UPDATE public.programme_versions
    SET approved_for_global = FALSE,
        lifecycle_status = 'archived',
        archived_at = NOW(),
        updated_at = NOW()
    WHERE id = p_retiring_version_id;

    IF NOT v_replacement_already_approved THEN
      UPDATE public.programme_versions
      SET approved_for_global = TRUE,
          updated_at = NOW()
      WHERE id = p_replacement_version_id;
    END IF;

    SELECT COUNT(*) INTO v_eligible_count
    FROM public.programme_versions eligible
    WHERE eligible.lineage_id = v_replacement.lineage_id
      AND eligible.lifecycle_status = 'published'
      AND eligible.library_scope = 'cohort_global'
      AND eligible.owner_type = 'global'
      AND eligible.approved_for_global = TRUE
      AND eligible.archived_at IS NULL;

    IF v_eligible_count <> 1 THEN
      RAISE EXCEPTION 'Catalogue replacement did not leave one eligible version'
        USING ERRCODE = 'integrity_constraint_violation';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'status', 'lifecycle_invariant_failure',
      'code', 'atomic_replacement_rolled_back'
    );
  END;

  RETURN jsonb_build_object(
    'status', 'replaced',
    'code', 'catalogue_version_replaced',
    'retiring_version_id', p_retiring_version_id,
    'replacement_version_id', p_replacement_version_id,
    'eligible_version_count', 1,
    'actor', trim(p_actor),
    'replacement_approval',
      CASE
        WHEN v_replacement_already_approved THEN 'already_satisfied'
        ELSE 'approved_in_transaction'
      END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.replace_approved_cohort_global_programme_version(
  UUID, UUID, TEXT
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.replace_approved_cohort_global_programme_version(
  UUID, UUID, TEXT
) FROM anon;
REVOKE ALL ON FUNCTION public.replace_approved_cohort_global_programme_version(
  UUID, UUID, TEXT
) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.replace_approved_cohort_global_programme_version(
  UUID, UUID, TEXT
) TO service_role;

COMMENT ON FUNCTION public.replace_approved_cohort_global_programme_version(
  UUID, UUID, TEXT
) IS
  'Service-role-only atomic catalogue replacement. Serialises on programme lineage, archives+unapproves the retiring immutable version, approves one valid published replacement when needed (or leaves an already-approved replacement untouched), and is idempotent.';
