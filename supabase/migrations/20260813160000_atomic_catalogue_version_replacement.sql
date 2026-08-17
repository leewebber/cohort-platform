-- Atomic catalogue-version replacement for immutable Cohort Global programmes.
--
-- This migration intentionally does not add the sole-eligible-version unique
-- index. Hosted beta currently contains one known duplicate-eligible lineage;
-- the authorised replacement RPC must reconcile that state before the index
-- migration can be applied.

-- Preserve published content immutability while permitting one strict
-- published+approved -> archived+unapproved lifecycle transition.
CREATE OR REPLACE FUNCTION public.cohort_reject_published_programme_content_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old_version_id UUID;
  v_new_version_id UUID;
BEGIN
  IF TG_TABLE_NAME = 'programme_versions' THEN
    IF TG_OP = 'UPDATE' THEN
      -- Strict retirement transition: lifecycle, approval revocation,
      -- archived_at and updated_at only.
      IF OLD.lifecycle_status = 'published'
         AND NEW.lifecycle_status = 'archived'
         AND NEW.approved_for_global = FALSE
         AND NEW.archived_at IS NOT NULL
         AND NEW.id IS NOT DISTINCT FROM OLD.id
         AND NEW.lineage_id IS NOT DISTINCT FROM OLD.lineage_id
         AND NEW.version_number IS NOT DISTINCT FROM OLD.version_number
         AND NEW.library_scope IS NOT DISTINCT FROM OLD.library_scope
         AND NEW.owner_type IS NOT DISTINCT FROM OLD.owner_type
         AND NEW.owner_id IS NOT DISTINCT FROM OLD.owner_id
         AND NEW.organisation_id IS NOT DISTINCT FROM OLD.organisation_id
         AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
         AND NEW.name IS NOT DISTINCT FROM OLD.name
         AND NEW.description IS NOT DISTINCT FROM OLD.description
         AND NEW.duration_weeks IS NOT DISTINCT FROM OLD.duration_weeks
         AND NEW.target_athlete IS NOT DISTINCT FROM OLD.target_athlete
         AND NEW.difficulty IS NOT DISTINCT FROM OLD.difficulty
         AND NEW.primary_goal IS NOT DISTINCT FROM OLD.primary_goal
         AND NEW.equipment_requirements IS NOT DISTINCT FROM OLD.equipment_requirements
         AND NEW.sessions_per_week IS NOT DISTINCT FROM OLD.sessions_per_week
         AND NEW.approved_for_adaptation IS NOT DISTINCT FROM OLD.approved_for_adaptation
         AND NEW.published_at IS NOT DISTINCT FROM OLD.published_at
         AND NEW.created_at IS NOT DISTINCT FROM OLD.created_at
         AND NEW.package_schema_version IS NOT DISTINCT FROM OLD.package_schema_version
         AND NEW.package_content_hash IS NOT DISTINCT FROM OLD.package_content_hash
         AND NEW.coaching_intent IS NOT DISTINCT FROM OLD.coaching_intent
         AND NEW.package_imported_at IS NOT DISTINCT FROM OLD.package_imported_at
         AND NEW.package_imported_by IS NOT DISTINCT FROM OLD.package_imported_by
      THEN
        RETURN NEW;
      END IF;

      -- Strict catalogue-approval whitelist: approved_for_global
      -- (+ updated_at) only.
      IF OLD.lifecycle_status = 'published'
         AND NEW.lifecycle_status = 'published'
         AND NEW.approved_for_global IS DISTINCT FROM OLD.approved_for_global
         AND NEW.id IS NOT DISTINCT FROM OLD.id
         AND NEW.lineage_id IS NOT DISTINCT FROM OLD.lineage_id
         AND NEW.version_number IS NOT DISTINCT FROM OLD.version_number
         AND NEW.library_scope IS NOT DISTINCT FROM OLD.library_scope
         AND NEW.owner_type IS NOT DISTINCT FROM OLD.owner_type
         AND NEW.owner_id IS NOT DISTINCT FROM OLD.owner_id
         AND NEW.organisation_id IS NOT DISTINCT FROM OLD.organisation_id
         AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
         AND NEW.name IS NOT DISTINCT FROM OLD.name
         AND NEW.description IS NOT DISTINCT FROM OLD.description
         AND NEW.duration_weeks IS NOT DISTINCT FROM OLD.duration_weeks
         AND NEW.target_athlete IS NOT DISTINCT FROM OLD.target_athlete
         AND NEW.difficulty IS NOT DISTINCT FROM OLD.difficulty
         AND NEW.primary_goal IS NOT DISTINCT FROM OLD.primary_goal
         AND NEW.equipment_requirements IS NOT DISTINCT FROM OLD.equipment_requirements
         AND NEW.sessions_per_week IS NOT DISTINCT FROM OLD.sessions_per_week
         AND NEW.approved_for_adaptation IS NOT DISTINCT FROM OLD.approved_for_adaptation
         AND NEW.published_at IS NOT DISTINCT FROM OLD.published_at
         AND NEW.archived_at IS NOT DISTINCT FROM OLD.archived_at
         AND NEW.created_at IS NOT DISTINCT FROM OLD.created_at
         AND NEW.package_schema_version IS NOT DISTINCT FROM OLD.package_schema_version
         AND NEW.package_content_hash IS NOT DISTINCT FROM OLD.package_content_hash
         AND NEW.coaching_intent IS NOT DISTINCT FROM OLD.coaching_intent
         AND NEW.package_imported_at IS NOT DISTINCT FROM OLD.package_imported_at
         AND NEW.package_imported_by IS NOT DISTINCT FROM OLD.package_imported_by
      THEN
        RETURN NEW;
      END IF;

      IF OLD.lifecycle_status = 'published' THEN
        RAISE EXCEPTION 'Published programme version content is immutable'
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;

      -- Strict publish transition: lifecycle + published_at (+ updated_at)
      -- only.
      IF OLD.lifecycle_status = 'draft' AND NEW.lifecycle_status = 'published' THEN
        IF NEW.published_at IS NULL THEN
          RAISE EXCEPTION 'published_at is required when publishing'
            USING ERRCODE = 'check_violation';
        END IF;
        IF NEW.approved_for_global IS DISTINCT FROM FALSE THEN
          RAISE EXCEPTION 'Catalogue approval cannot occur during publication'
            USING ERRCODE = 'check_violation';
        END IF;
        IF NEW.id IS NOT DISTINCT FROM OLD.id
           AND NEW.lineage_id IS NOT DISTINCT FROM OLD.lineage_id
           AND NEW.version_number IS NOT DISTINCT FROM OLD.version_number
           AND NEW.library_scope IS NOT DISTINCT FROM OLD.library_scope
           AND NEW.owner_type IS NOT DISTINCT FROM OLD.owner_type
           AND NEW.owner_id IS NOT DISTINCT FROM OLD.owner_id
           AND NEW.organisation_id IS NOT DISTINCT FROM OLD.organisation_id
           AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
           AND NEW.name IS NOT DISTINCT FROM OLD.name
           AND NEW.description IS NOT DISTINCT FROM OLD.description
           AND NEW.duration_weeks IS NOT DISTINCT FROM OLD.duration_weeks
           AND NEW.target_athlete IS NOT DISTINCT FROM OLD.target_athlete
           AND NEW.difficulty IS NOT DISTINCT FROM OLD.difficulty
           AND NEW.primary_goal IS NOT DISTINCT FROM OLD.primary_goal
           AND NEW.equipment_requirements IS NOT DISTINCT FROM OLD.equipment_requirements
           AND NEW.sessions_per_week IS NOT DISTINCT FROM OLD.sessions_per_week
           AND NEW.approved_for_adaptation IS NOT DISTINCT FROM OLD.approved_for_adaptation
           AND NEW.archived_at IS NOT DISTINCT FROM OLD.archived_at
           AND NEW.created_at IS NOT DISTINCT FROM OLD.created_at
           AND NEW.package_schema_version IS NOT DISTINCT FROM OLD.package_schema_version
           AND NEW.package_content_hash IS NOT DISTINCT FROM OLD.package_content_hash
           AND NEW.coaching_intent IS NOT DISTINCT FROM OLD.coaching_intent
           AND NEW.package_imported_at IS NOT DISTINCT FROM OLD.package_imported_at
           AND NEW.package_imported_by IS NOT DISTINCT FROM OLD.package_imported_by
        THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Publish transition cannot alter authored programme content'
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;

      IF OLD.lifecycle_status = 'archived' THEN
        RAISE EXCEPTION 'Archived programme versions are immutable'
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
      IF OLD.lifecycle_status IN ('published', 'archived') THEN
        RAISE EXCEPTION 'Published or archived programme versions cannot be deleted'
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      RETURN OLD;
    END IF;
  END IF;

  -- Child / structure tables: INSERT checks destination; DELETE checks origin;
  -- UPDATE checks BOTH original and proposed parents independently.
  IF TG_TABLE_NAME IN (
    'programme_version_phases',
    'programme_version_weeks',
    'programme_version_adaptation_permissions',
    'programme_version_protected_invariants',
    'programme_version_assessments',
    'programme_version_evidence_requirements',
    'programme_version_comparison_identities'
  ) THEN
    IF TG_OP = 'INSERT' THEN
      IF public.cohort_programme_version_is_immutable(NEW.version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    ELSIF TG_OP = 'DELETE' THEN
      IF public.cohort_programme_version_is_immutable(OLD.version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    ELSIF TG_OP = 'UPDATE' THEN
      IF public.cohort_programme_version_is_immutable(OLD.version_id)
         OR public.cohort_programme_version_is_immutable(NEW.version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'programme_version_days' THEN
    IF TG_OP = 'INSERT' THEN
      v_new_version_id := public.cohort_programme_version_id_for_week(NEW.week_id);
      IF public.cohort_programme_version_is_immutable(v_new_version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    ELSIF TG_OP = 'DELETE' THEN
      v_old_version_id := public.cohort_programme_version_id_for_week(OLD.week_id);
      IF public.cohort_programme_version_is_immutable(v_old_version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    ELSIF TG_OP = 'UPDATE' THEN
      v_old_version_id := public.cohort_programme_version_id_for_week(OLD.week_id);
      v_new_version_id := public.cohort_programme_version_id_for_week(NEW.week_id);
      IF public.cohort_programme_version_is_immutable(v_old_version_id)
         OR public.cohort_programme_version_is_immutable(v_new_version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'programme_version_session_slots' THEN
    IF TG_OP = 'INSERT' THEN
      v_new_version_id := public.cohort_programme_version_id_for_day(NEW.day_id);
      IF public.cohort_programme_version_is_immutable(v_new_version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    ELSIF TG_OP = 'DELETE' THEN
      v_old_version_id := public.cohort_programme_version_id_for_day(OLD.day_id);
      IF public.cohort_programme_version_is_immutable(v_old_version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    ELSIF TG_OP = 'UPDATE' THEN
      v_old_version_id := public.cohort_programme_version_id_for_day(OLD.day_id);
      v_new_version_id := public.cohort_programme_version_id_for_day(NEW.day_id);
      IF public.cohort_programme_version_is_immutable(v_old_version_id)
         OR public.cohort_programme_version_is_immutable(v_new_version_id) THEN
        RAISE EXCEPTION 'Published or archived programme package content is immutable (%)', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- Direct approval remains a separate service-role gate, but it can no longer
-- create a second eligible version for a lineage.
CREATE OR REPLACE FUNCTION public.approve_cohort_global_programme_version(
  p_version_id UUID,
  p_actor TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.programme_versions%ROWTYPE;
  v_slot_count INT;
BEGIN
  IF p_version_id IS NULL OR nullif(trim(COALESCE(p_actor, '')), '') IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_args');
  END IF;

  SELECT * INTO v_row
  FROM public.programme_versions
  WHERE id = p_version_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'version_not_found');
  END IF;

  -- Every approval/replacement for a lineage serialises on the lineage row.
  PERFORM 1
  FROM public.programme_lineages
  WHERE id = v_row.lineage_id
  FOR UPDATE;

  SELECT * INTO v_row
  FROM public.programme_versions
  WHERE id = p_version_id
  FOR UPDATE;

  IF v_row.lifecycle_status <> 'published' OR v_row.archived_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'draft_catalogue_approval_forbidden'
    );
  END IF;
  IF v_row.library_scope <> 'cohort_global' OR v_row.owner_type <> 'global' THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'not_cohort_global');
  END IF;
  IF v_row.package_content_hash IS NULL OR v_row.package_schema_version IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'missing_package_provenance'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.programme_versions competing
    WHERE competing.lineage_id = v_row.lineage_id
      AND competing.id <> v_row.id
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

  IF v_row.approved_for_global = TRUE THEN
    RETURN jsonb_build_object(
      'status', 'already_catalogue_approved',
      'programme_version_id', p_version_id,
      'approved_for_global', TRUE,
      'actor', trim(p_actor)
    );
  END IF;

  SELECT COUNT(*) INTO v_slot_count
  FROM public.programme_version_session_slots s
  JOIN public.programme_version_days d ON d.id = s.day_id
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = p_version_id;

  IF v_slot_count < 1 OR EXISTS (
    SELECT 1
    FROM public.programme_version_session_slots s
    JOIN public.programme_version_days d ON d.id = s.day_id
    JOIN public.programme_version_weeks w ON w.id = d.week_id
    LEFT JOIN public.performance_protocols p ON p.protocol_id = s.protocol_id
    WHERE w.version_id = p_version_id
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

  UPDATE public.programme_versions
  SET approved_for_global = TRUE,
      updated_at = NOW()
  WHERE id = p_version_id;

  RETURN jsonb_build_object(
    'status', 'catalogue_approved',
    'programme_version_id', p_version_id,
    'approved_for_global', TRUE,
    'actor', trim(p_actor)
  );
END;
$$;

-- Atomically retire one approved immutable version and approve its replacement.
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

  -- A nested block gives typed failure while rolling both row changes back as
  -- one subtransaction if a trigger/constraint/invariant rejects either write.
  BEGIN
    UPDATE public.programme_versions
    SET approved_for_global = FALSE,
        lifecycle_status = 'archived',
        archived_at = NOW(),
        updated_at = NOW()
    WHERE id = p_retiring_version_id;

    UPDATE public.programme_versions
    SET approved_for_global = TRUE,
        updated_at = NOW()
    WHERE id = p_replacement_version_id;

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
    'actor', trim(p_actor)
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

-- Re-assert the direct approval grants after CREATE OR REPLACE.
REVOKE ALL ON FUNCTION public.approve_cohort_global_programme_version(
  UUID, TEXT
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_cohort_global_programme_version(
  UUID, TEXT
) FROM anon;
REVOKE ALL ON FUNCTION public.approve_cohort_global_programme_version(
  UUID, TEXT
) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_cohort_global_programme_version(
  UUID, TEXT
) TO service_role;

COMMENT ON FUNCTION public.replace_approved_cohort_global_programme_version(
  UUID, UUID, TEXT
) IS
  'Service-role-only atomic catalogue replacement. Serialises on programme lineage, archives+unapproves the retiring immutable version, approves one valid published replacement, and is idempotent.';

COMMENT ON FUNCTION public.approve_cohort_global_programme_version(UUID, TEXT) IS
  'Service-role-only initial catalogue approval gate. Serialises on programme lineage and refuses to create a second eligible version; replacements use replace_approved_cohort_global_programme_version.';
