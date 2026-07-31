-- Sprint 1.2: Authored Plan Package import, package child tables, immutability,
-- catalogue SELECT leak fix, and service-role-only import/publish/approve RPCs.
--
-- Applies after 20260730150000_seed_cohort_session_templates.sql
--
-- Authority:
--   Import → hidden Cohort Global draft only (never publish, never approve).
--   Publish and catalogue approval are separate RPCs (service_role only).
--   Ordinary authenticated users must not read global drafts or unapproved published globals.

-- ---------------------------------------------------------------------------
-- 1. programme_versions package provenance columns
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_versions
  ADD COLUMN IF NOT EXISTS package_schema_version INT,
  ADD COLUMN IF NOT EXISTS package_content_hash TEXT,
  ADD COLUMN IF NOT EXISTS coaching_intent TEXT,
  ADD COLUMN IF NOT EXISTS package_imported_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS package_imported_by TEXT;

ALTER TABLE public.programme_versions
  DROP CONSTRAINT IF EXISTS programme_versions_package_schema_version_check;
ALTER TABLE public.programme_versions
  ADD CONSTRAINT programme_versions_package_schema_version_check
  CHECK (
    package_schema_version IS NULL
    OR package_schema_version >= 1
  );

ALTER TABLE public.programme_versions
  DROP CONSTRAINT IF EXISTS programme_versions_package_content_hash_check;
ALTER TABLE public.programme_versions
  ADD CONSTRAINT programme_versions_package_content_hash_check
  CHECK (
    package_content_hash IS NULL
    OR package_content_hash ~ '^[0-9a-f]{64}$'
  );

ALTER TABLE public.programme_versions
  DROP CONSTRAINT IF EXISTS programme_versions_package_provenance_pair_check;
ALTER TABLE public.programme_versions
  ADD CONSTRAINT programme_versions_package_provenance_pair_check
  CHECK (
    (package_schema_version IS NULL AND package_content_hash IS NULL)
    OR (package_schema_version IS NOT NULL AND package_content_hash IS NOT NULL)
  );

ALTER TABLE public.programme_versions
  DROP CONSTRAINT IF EXISTS programme_versions_approved_for_global_requires_published;
ALTER TABLE public.programme_versions
  ADD CONSTRAINT programme_versions_approved_for_global_requires_published
  CHECK (
    approved_for_global = FALSE
    OR lifecycle_status = 'published'
  );

CREATE INDEX IF NOT EXISTS idx_programme_versions_package_content_hash
  ON public.programme_versions (package_content_hash)
  WHERE package_content_hash IS NOT NULL;

COMMENT ON COLUMN public.programme_versions.package_schema_version IS
  'Authored Plan Package interchange schema version. Null for legacy non-package versions.';
COMMENT ON COLUMN public.programme_versions.package_content_hash IS
  'Lowercase SHA-256 of canonical package JSON. Not globally unique. Null for legacy versions.';
COMMENT ON COLUMN public.programme_versions.coaching_intent IS
  'Authored coaching intent from Plan Package. Distinct from description.';
COMMENT ON COLUMN public.programme_versions.package_imported_at IS
  'Trusted import timestamp set by service-role import RPC.';
COMMENT ON COLUMN public.programme_versions.package_imported_by IS
  'Trusted import actor identifier supplied to import RPC (not client owner spoof).';

-- ---------------------------------------------------------------------------
-- 2. Schedule slot package fields
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_version_session_slots
  ADD COLUMN IF NOT EXISTS package_slot_key TEXT,
  ADD COLUMN IF NOT EXISTS authored_progression JSONB;

ALTER TABLE public.programme_version_session_slots
  DROP CONSTRAINT IF EXISTS programme_version_session_slots_authored_progression_check;
ALTER TABLE public.programme_version_session_slots
  ADD CONSTRAINT programme_version_session_slots_authored_progression_check
  CHECK (
    authored_progression IS NULL
    OR (
      jsonb_typeof(authored_progression) = 'object'
      AND COALESCE(authored_progression->>'prescription_summary', '') <> ''
    )
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_programme_version_session_slots_package_slot_key
  ON public.programme_version_session_slots (day_id, package_slot_key)
  WHERE package_slot_key IS NOT NULL;

COMMENT ON COLUMN public.programme_version_session_slots.package_slot_key IS
  'Package-local slot identity for adaptation/assessment references.';
COMMENT ON COLUMN public.programme_version_session_slots.authored_progression IS
  'Authored progression object: prescription_summary (required) plus optional notes.';

-- ---------------------------------------------------------------------------
-- 3. Package child tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.programme_version_adaptation_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id UUID NOT NULL
    REFERENCES public.programme_versions (id) ON DELETE CASCADE,
  permission_key TEXT NOT NULL,
  change_kind TEXT NOT NULL,
  target_ref TEXT NOT NULL,
  athlete_agreement_required BOOLEAN NOT NULL,
  scope_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_adaptation_permissions_key_unique
    UNIQUE (version_id, permission_key),
  CONSTRAINT programme_version_adaptation_permissions_agreement_check
    CHECK (athlete_agreement_required = TRUE),
  CONSTRAINT programme_version_adaptation_permissions_change_kind_check
    CHECK (change_kind IN (
      'reduce_volume',
      'remove_optional_accessories',
      'compress_for_time',
      'substitute_approved_equipment',
      'substitute_approved_exercise',
      'convert_approved_modality'
    ))
);

CREATE INDEX IF NOT EXISTS idx_programme_version_adaptation_permissions_version
  ON public.programme_version_adaptation_permissions (version_id);

CREATE TABLE IF NOT EXISTS public.programme_version_protected_invariants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id UUID NOT NULL
    REFERENCES public.programme_versions (id) ON DELETE CASCADE,
  invariant_key TEXT NOT NULL,
  kind TEXT NOT NULL,
  target_ref TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_protected_invariants_key_unique
    UNIQUE (version_id, invariant_key),
  CONSTRAINT programme_version_protected_invariants_kind_check
    CHECK (kind IN (
      'session_slot_immutable',
      'assessment_immutable',
      'progression_locked'
    ))
);

CREATE INDEX IF NOT EXISTS idx_programme_version_protected_invariants_version
  ON public.programme_version_protected_invariants (version_id);

CREATE TABLE IF NOT EXISTS public.programme_version_comparison_identities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id UUID NOT NULL
    REFERENCES public.programme_versions (id) ON DELETE CASCADE,
  comparison_key TEXT NOT NULL,
  session_lineage_id TEXT NOT NULL,
  label TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_comparison_identities_key_unique
    UNIQUE (version_id, comparison_key)
);

CREATE INDEX IF NOT EXISTS idx_programme_version_comparison_identities_version
  ON public.programme_version_comparison_identities (version_id);

CREATE TABLE IF NOT EXISTS public.programme_version_assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id UUID NOT NULL
    REFERENCES public.programme_versions (id) ON DELETE CASCADE,
  assessment_key TEXT NOT NULL,
  slot_ref TEXT NOT NULL,
  evidence_requirement TEXT NOT NULL,
  comparison_identity_key TEXT NOT NULL,
  label TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_assessments_key_unique
    UNIQUE (version_id, assessment_key),
  CONSTRAINT programme_version_assessments_comparison_fk
    FOREIGN KEY (version_id, comparison_identity_key)
    REFERENCES public.programme_version_comparison_identities (version_id, comparison_key)
);

CREATE INDEX IF NOT EXISTS idx_programme_version_assessments_version
  ON public.programme_version_assessments (version_id);

CREATE TABLE IF NOT EXISTS public.programme_version_evidence_requirements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id UUID NOT NULL
    REFERENCES public.programme_versions (id) ON DELETE CASCADE,
  evidence_key TEXT NOT NULL,
  comparison_identity_key TEXT NOT NULL,
  metric TEXT NOT NULL,
  required BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_evidence_requirements_key_unique
    UNIQUE (version_id, evidence_key),
  CONSTRAINT programme_version_evidence_requirements_comparison_fk
    FOREIGN KEY (version_id, comparison_identity_key)
    REFERENCES public.programme_version_comparison_identities (version_id, comparison_key)
);

CREATE INDEX IF NOT EXISTS idx_programme_version_evidence_requirements_version
  ON public.programme_version_evidence_requirements (version_id);

COMMENT ON TABLE public.programme_version_adaptation_permissions IS
  'Authored Plan Package adaptation permissions. Package authority only — not runtime adaptation events.';
COMMENT ON TABLE public.programme_version_protected_invariants IS
  'Authored Plan Package protected invariants.';
COMMENT ON TABLE public.programme_version_assessments IS
  'Authored Plan Package assessment declarations.';
COMMENT ON TABLE public.programme_version_evidence_requirements IS
  'Authored Plan Package performance-evidence requirements (descriptive).';
COMMENT ON TABLE public.programme_version_comparison_identities IS
  'Authored like-for-like comparison identities anchored to session lineage.';

-- ---------------------------------------------------------------------------
-- 4. Close global-draft catalogue SELECT leak
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS programme_versions_select_catalogue ON public.programme_versions;

CREATE POLICY programme_versions_select_catalogue
  ON public.programme_versions
  FOR SELECT
  TO authenticated
  USING (
    lifecycle_status = 'published'
    AND library_scope = 'cohort_global'
    AND approved_for_global = TRUE
  );

COMMENT ON POLICY programme_versions_select_catalogue ON public.programme_versions IS
  'Authenticated athlete/catalogue read: published and globally approved Cohort Global versions only. Global drafts and published-but-unapproved versions are hidden.';

-- Child catalogue SELECT policies previously allowed reading structure for global drafts
-- via parent readability. Restrict phase/week/day/slot catalogue selects similarly.

DROP POLICY IF EXISTS programme_version_phases_select_catalogue ON public.programme_version_phases;
CREATE POLICY programme_version_phases_select_catalogue
  ON public.programme_version_phases
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_versions v
      WHERE v.id = version_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

DROP POLICY IF EXISTS programme_version_weeks_select_catalogue ON public.programme_version_weeks;
CREATE POLICY programme_version_weeks_select_catalogue
  ON public.programme_version_weeks
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_versions v
      WHERE v.id = version_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

DROP POLICY IF EXISTS programme_version_days_select_catalogue ON public.programme_version_days;
CREATE POLICY programme_version_days_select_catalogue
  ON public.programme_version_days
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_version_weeks w
      JOIN public.programme_versions v ON v.id = w.version_id
      WHERE w.id = week_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

DROP POLICY IF EXISTS programme_version_session_slots_select_catalogue
  ON public.programme_version_session_slots;
CREATE POLICY programme_version_session_slots_select_catalogue
  ON public.programme_version_session_slots
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_version_days d
      JOIN public.programme_version_weeks w ON w.id = d.week_id
      JOIN public.programme_versions v ON v.id = w.version_id
      WHERE d.id = day_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

-- ---------------------------------------------------------------------------
-- 4b. Align lineage catalogue helper with published+approved boundary
-- ---------------------------------------------------------------------------
-- Used by programme_lineages_select_catalogue. Must not treat global drafts as
-- catalogue-readable (closes draft-lineage enumeration after SELECT grants).
-- Coach-owned lineage access remains on separate select_coach policies.

CREATE OR REPLACE FUNCTION public.cohort_programme_lineage_has_dev_readable_version(
  p_lineage_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.programme_versions v
    WHERE v.lineage_id = p_lineage_id
      AND v.lifecycle_status = 'published'
      AND v.library_scope = 'cohort_global'
      AND v.approved_for_global = TRUE
  );
$$;

COMMENT ON FUNCTION public.cohort_programme_lineage_has_dev_readable_version(UUID) IS
  'SECURITY DEFINER lineage catalogue read gate: TRUE only when a related version is published, cohort_global, and approved_for_global. Avoids programme_lineages → programme_versions RLS recursion. Global drafts are not catalogue-readable.';

-- ---------------------------------------------------------------------------
-- 4c. Catalogue Data API SELECT contract (authenticated browse only)
-- ---------------------------------------------------------------------------
-- programme_versions: direct catalogue table for listCatalogueVersions.
-- programme_lineages: required by PostgREST embed programme_lineages!inner(code).
-- RLS remains the row-visibility boundary (published + cohort_global + approved).
-- No anonymous catalogue product path. No write privileges granted here.

REVOKE SELECT ON TABLE public.programme_versions FROM PUBLIC, anon;
REVOKE SELECT ON TABLE public.programme_lineages FROM PUBLIC, anon;

GRANT SELECT ON TABLE public.programme_versions TO authenticated;
GRANT SELECT ON TABLE public.programme_lineages TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. Child-table RLS (no athlete read of hidden package data)
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_version_adaptation_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programme_version_protected_invariants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programme_version_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programme_version_evidence_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programme_version_comparison_identities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS programme_version_adaptation_permissions_select_catalogue
  ON public.programme_version_adaptation_permissions;
CREATE POLICY programme_version_adaptation_permissions_select_catalogue
  ON public.programme_version_adaptation_permissions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.programme_versions v
      WHERE v.id = version_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

DROP POLICY IF EXISTS programme_version_protected_invariants_select_catalogue
  ON public.programme_version_protected_invariants;
CREATE POLICY programme_version_protected_invariants_select_catalogue
  ON public.programme_version_protected_invariants
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.programme_versions v
      WHERE v.id = version_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

DROP POLICY IF EXISTS programme_version_assessments_select_catalogue
  ON public.programme_version_assessments;
CREATE POLICY programme_version_assessments_select_catalogue
  ON public.programme_version_assessments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.programme_versions v
      WHERE v.id = version_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

DROP POLICY IF EXISTS programme_version_evidence_requirements_select_catalogue
  ON public.programme_version_evidence_requirements;
CREATE POLICY programme_version_evidence_requirements_select_catalogue
  ON public.programme_version_evidence_requirements
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.programme_versions v
      WHERE v.id = version_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

DROP POLICY IF EXISTS programme_version_comparison_identities_select_catalogue
  ON public.programme_version_comparison_identities;
CREATE POLICY programme_version_comparison_identities_select_catalogue
  ON public.programme_version_comparison_identities
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.programme_versions v
      WHERE v.id = version_id
        AND v.lifecycle_status = 'published'
        AND v.library_scope = 'cohort_global'
        AND v.approved_for_global = TRUE
    )
  );

-- Coach-private package children readable/writable only for owned drafts (structure parity).
DROP POLICY IF EXISTS programme_version_adaptation_permissions_select_coach
  ON public.programme_version_adaptation_permissions;
CREATE POLICY programme_version_adaptation_permissions_select_coach
  ON public.programme_version_adaptation_permissions
  FOR SELECT TO authenticated
  USING (public.cohort_programme_version_is_dev_coach_readable(version_id));

DROP POLICY IF EXISTS programme_version_protected_invariants_select_coach
  ON public.programme_version_protected_invariants;
CREATE POLICY programme_version_protected_invariants_select_coach
  ON public.programme_version_protected_invariants
  FOR SELECT TO authenticated
  USING (public.cohort_programme_version_is_dev_coach_readable(version_id));

DROP POLICY IF EXISTS programme_version_assessments_select_coach
  ON public.programme_version_assessments;
CREATE POLICY programme_version_assessments_select_coach
  ON public.programme_version_assessments
  FOR SELECT TO authenticated
  USING (public.cohort_programme_version_is_dev_coach_readable(version_id));

DROP POLICY IF EXISTS programme_version_evidence_requirements_select_coach
  ON public.programme_version_evidence_requirements;
CREATE POLICY programme_version_evidence_requirements_select_coach
  ON public.programme_version_evidence_requirements
  FOR SELECT TO authenticated
  USING (public.cohort_programme_version_is_dev_coach_readable(version_id));

DROP POLICY IF EXISTS programme_version_comparison_identities_select_coach
  ON public.programme_version_comparison_identities;
CREATE POLICY programme_version_comparison_identities_select_coach
  ON public.programme_version_comparison_identities
  FOR SELECT TO authenticated
  USING (public.cohort_programme_version_is_dev_coach_readable(version_id));

-- No authenticated INSERT/UPDATE/DELETE on package child tables.
-- Package-owned rows are created only by service-role import RPC.

-- ---------------------------------------------------------------------------
-- 6. Published/archived immutability triggers (DB boundary)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_version_is_immutable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.programme_versions v
    WHERE v.id = p_version_id
      AND v.lifecycle_status IN ('published', 'archived')
  );
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_is_immutable(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_immutable(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_immutable(UUID) TO service_role;

-- Compatibility alias used by earlier Sprint 1.2 drafts; now means immutable snapshot.
CREATE OR REPLACE FUNCTION public.cohort_programme_version_is_published(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.cohort_programme_version_is_immutable(p_version_id);
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_is_published(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_published(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_published(UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.cohort_programme_version_id_for_week(p_week_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT w.version_id
  FROM public.programme_version_weeks w
  WHERE w.id = p_week_id;
$$;

CREATE OR REPLACE FUNCTION public.cohort_programme_version_id_for_day(p_day_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT w.version_id
  FROM public.programme_version_days d
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  WHERE d.id = p_day_id;
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_id_for_week(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cohort_programme_version_id_for_day(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_id_for_week(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_id_for_week(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_id_for_day(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_id_for_day(UUID) TO service_role;

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
      -- Strict archive transition: lifecycle + archived_at (+ updated_at) only.
      IF OLD.lifecycle_status = 'published'
         AND NEW.lifecycle_status = 'archived'
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
         AND NEW.approved_for_global IS NOT DISTINCT FROM OLD.approved_for_global
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

      -- Strict catalogue-approval whitelist: approved_for_global (+ updated_at) only.
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

      -- Strict publish transition: lifecycle + published_at (+ updated_at) only.
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

DROP TRIGGER IF EXISTS programme_versions_immutability ON public.programme_versions;
CREATE TRIGGER programme_versions_immutability
  BEFORE UPDATE OR DELETE ON public.programme_versions
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_phases_immutability ON public.programme_version_phases;
CREATE TRIGGER programme_version_phases_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_phases
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_weeks_immutability ON public.programme_version_weeks;
CREATE TRIGGER programme_version_weeks_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_weeks
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_days_immutability ON public.programme_version_days;
CREATE TRIGGER programme_version_days_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_days
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_session_slots_immutability
  ON public.programme_version_session_slots;
CREATE TRIGGER programme_version_session_slots_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_session_slots
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_adaptation_permissions_immutability
  ON public.programme_version_adaptation_permissions;
CREATE TRIGGER programme_version_adaptation_permissions_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_adaptation_permissions
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_protected_invariants_immutability
  ON public.programme_version_protected_invariants;
CREATE TRIGGER programme_version_protected_invariants_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_protected_invariants
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_assessments_immutability
  ON public.programme_version_assessments;
CREATE TRIGGER programme_version_assessments_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_assessments
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_evidence_requirements_immutability
  ON public.programme_version_evidence_requirements;
CREATE TRIGGER programme_version_evidence_requirements_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_evidence_requirements
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();

DROP TRIGGER IF EXISTS programme_version_comparison_identities_immutability
  ON public.programme_version_comparison_identities;
CREATE TRIGGER programme_version_comparison_identities_immutability
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_version_comparison_identities
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_published_programme_content_mutation();


-- ---------------------------------------------------------------------------
-- 6b. Authoritative package-graph equivalence (idempotency gate)
-- ---------------------------------------------------------------------------
-- Compares a persisted programme version against a validated import payload.
-- phase_key is not stored; phase identity uses persisted phase_order (unique
-- per version) and week.phase_id → phase.phase_order linkage.
-- Returns TRUE only for a complete, consistent match of all package-owned domains.

CREATE OR REPLACE FUNCTION public.cohort_authored_plan_package_graph_matches(
  p_version_id UUID,
  payload JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prog JSONB;
  v_phase JSONB;
  v_week JSONB;
  v_day JSONB;
  v_slot JSONB;
  v_item JSONB;
  v_expected INT;
  v_actual INT;
  v_phase_order INT;
  v_week_number INT;
  v_day_key TEXT;
  v_slot_key TEXT;
  v_session_key TEXT;
  v_protocol_id TEXT;
  v_phase_key TEXT;
  v_expected_phase_order INT;
BEGIN
  IF p_version_id IS NULL OR payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN FALSE;
  END IF;

  v_prog := payload->'programme';
  IF v_prog IS NULL OR jsonb_typeof(v_prog) <> 'object' THEN
    RETURN FALSE;
  END IF;

  -- Programme authored metadata (package truth, not lifecycle/ownership).
  IF NOT EXISTS (
    SELECT 1
    FROM public.programme_versions v
    WHERE v.id = p_version_id
      AND v.name IS NOT DISTINCT FROM trim(v_prog->>'name')
      AND v.coaching_intent IS NOT DISTINCT FROM trim(v_prog->>'coaching_intent')
      AND v.description IS NOT DISTINCT FROM nullif(trim(COALESCE(v_prog->>'description', '')), '')
      AND v.duration_weeks IS NOT DISTINCT FROM NULLIF(v_prog->>'duration_weeks', '')::INT
      AND v.sessions_per_week IS NOT DISTINCT FROM NULLIF(v_prog->>'sessions_per_week', '')::INT
      AND v.primary_goal IS NOT DISTINCT FROM nullif(trim(COALESCE(v_prog->>'primary_goal', '')), '')
      AND v.package_schema_version IS NOT DISTINCT FROM NULLIF(payload->>'package_schema_version', '')::INT
      AND v.package_content_hash IS NOT DISTINCT FROM lower(trim(COALESCE(payload->>'package_content_hash', '')))
  ) THEN
    RETURN FALSE;
  END IF;

  -- Phases: identity = phase_order (DB unique). Key set + authored values.
  v_expected := CASE
    WHEN jsonb_typeof(payload->'phases') = 'array' THEN jsonb_array_length(payload->'phases')
    ELSE 0
  END;
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_phases p
  WHERE p.version_id = p_version_id;
  IF v_actual IS DISTINCT FROM v_expected THEN
    RETURN FALSE;
  END IF;

  IF v_expected > 0 THEN
    FOR v_phase IN SELECT value FROM jsonb_array_elements(payload->'phases')
    LOOP
      v_phase_order := NULLIF(v_phase->>'phase_order', '')::INT;
      IF v_phase_order IS NULL THEN
        RETURN FALSE;
      END IF;
      IF NOT EXISTS (
        SELECT 1
        FROM public.programme_version_phases p
        WHERE p.version_id = p_version_id
          AND p.phase_order = v_phase_order
          AND p.title IS NOT DISTINCT FROM trim(v_phase->>'title')
          AND p.intent IS NOT DISTINCT FROM nullif(trim(COALESCE(v_phase->>'intent', '')), '')
          AND p.coach_note IS NOT DISTINCT FROM nullif(trim(COALESCE(v_phase->>'coach_note', '')), '')
      ) THEN
        RETURN FALSE;
      END IF;
    END LOOP;
  END IF;

  -- Weeks: identity = week_number.
  v_expected := jsonb_array_length(payload->'weeks');
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_weeks w
  WHERE w.version_id = p_version_id;
  IF v_actual IS DISTINCT FROM v_expected THEN
    RETURN FALSE;
  END IF;

  FOR v_week IN SELECT value FROM jsonb_array_elements(payload->'weeks')
  LOOP
    v_week_number := NULLIF(v_week->>'week_number', '')::INT;
    IF v_week_number IS NULL THEN
      RETURN FALSE;
    END IF;

    v_phase_key := nullif(trim(COALESCE(v_week->>'phase_key', '')), '');
    v_expected_phase_order := NULL;
    IF v_phase_key IS NOT NULL THEN
      SELECT NULLIF(p->>'phase_order', '')::INT INTO v_expected_phase_order
      FROM jsonb_array_elements(COALESCE(payload->'phases', '[]'::JSONB)) AS p
      WHERE trim(p->>'phase_key') = v_phase_key
      LIMIT 1;
      IF v_expected_phase_order IS NULL THEN
        RETURN FALSE;
      END IF;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.programme_version_weeks w
      LEFT JOIN public.programme_version_phases ph ON ph.id = w.phase_id
      WHERE w.version_id = p_version_id
        AND w.week_number = v_week_number
        AND w.title IS NOT DISTINCT FROM nullif(trim(COALESCE(v_week->>'title', '')), '')
        AND w.intent IS NOT DISTINCT FROM nullif(trim(COALESCE(v_week->>'intent', '')), '')
        AND w.coach_note IS NOT DISTINCT FROM nullif(trim(COALESCE(v_week->>'coach_note', '')), '')
        AND (
          (v_phase_key IS NULL AND w.phase_id IS NULL)
          OR (v_phase_key IS NOT NULL AND ph.version_id = p_version_id AND ph.phase_order = v_expected_phase_order)
        )
    ) THEN
      RETURN FALSE;
    END IF;

    -- Days under this week.
    v_expected := jsonb_array_length(COALESCE(v_week->'days', '[]'::JSONB));
    SELECT COUNT(*) INTO v_actual
    FROM public.programme_version_days d
    JOIN public.programme_version_weeks w ON w.id = d.week_id
    WHERE w.version_id = p_version_id
      AND w.week_number = v_week_number;
    IF v_actual IS DISTINCT FROM v_expected THEN
      RETURN FALSE;
    END IF;

    FOR v_day IN SELECT value FROM jsonb_array_elements(COALESCE(v_week->'days', '[]'::JSONB))
    LOOP
      v_day_key := trim(COALESCE(v_day->>'day_key', ''));
      IF v_day_key = '' THEN
        RETURN FALSE;
      END IF;
      IF NOT EXISTS (
        SELECT 1
        FROM public.programme_version_days d
        JOIN public.programme_version_weeks w ON w.id = d.week_id
        WHERE w.version_id = p_version_id
          AND w.week_number = v_week_number
          AND d.day_key = v_day_key
          AND d.day_order IS NOT DISTINCT FROM (v_day->>'day_order')::INT
          AND d.day_type IS NOT DISTINCT FROM trim(v_day->>'day_type')
          AND d.title IS NOT DISTINCT FROM nullif(trim(COALESCE(v_day->>'title', '')), '')
          AND d.intent IS NOT DISTINCT FROM nullif(trim(COALESCE(v_day->>'intent', '')), '')
          AND d.coach_note IS NOT DISTINCT FROM nullif(trim(COALESCE(v_day->>'coach_note', '')), '')
      ) THEN
        RETURN FALSE;
      END IF;

      -- Slots under this day.
      v_expected := jsonb_array_length(COALESCE(v_day->'slots', '[]'::JSONB));
      SELECT COUNT(*) INTO v_actual
      FROM public.programme_version_session_slots s
      JOIN public.programme_version_days d ON d.id = s.day_id
      JOIN public.programme_version_weeks w ON w.id = d.week_id
      WHERE w.version_id = p_version_id
        AND w.week_number = v_week_number
        AND d.day_key = v_day_key;
      IF v_actual IS DISTINCT FROM v_expected THEN
        RETURN FALSE;
      END IF;

      FOR v_slot IN SELECT value FROM jsonb_array_elements(COALESCE(v_day->'slots', '[]'::JSONB))
      LOOP
        v_slot_key := trim(COALESCE(v_slot->>'slot_key', ''));
        v_session_key := trim(COALESCE(v_slot->>'session_key', ''));
        SELECT trim(s.value->>'protocol_id') INTO v_protocol_id
        FROM jsonb_array_elements(payload->'sessions') AS s(value)
        WHERE trim(s.value->>'session_key') = v_session_key
        LIMIT 1;

        IF v_slot_key = '' OR v_protocol_id IS NULL OR trim(v_protocol_id) = '' THEN
          RETURN FALSE;
        END IF;

        IF NOT EXISTS (
          SELECT 1
          FROM public.programme_version_session_slots s
          JOIN public.programme_version_days d ON d.id = s.day_id
          JOIN public.programme_version_weeks w ON w.id = d.week_id
          WHERE w.version_id = p_version_id
            AND w.week_number = v_week_number
            AND d.day_key = v_day_key
            AND s.package_slot_key IS NOT DISTINCT FROM v_slot_key
            AND s.session_order IS NOT DISTINCT FROM (v_slot->>'session_order')::INT
            AND s.protocol_id IS NOT DISTINCT FROM trim(v_protocol_id)
            AND s.display_title IS NOT DISTINCT FROM nullif(trim(COALESCE(v_slot->>'display_title', '')), '')
            AND s.time_of_day IS NOT DISTINCT FROM COALESCE(nullif(trim(COALESCE(v_slot->>'time_of_day', '')), ''), 'any')
            AND s.is_optional IS NOT DISTINCT FROM COALESCE((v_slot->>'is_optional')::BOOLEAN, FALSE)
            AND s.completion_expectation IS NOT DISTINCT FROM COALESCE(nullif(trim(COALESCE(v_slot->>'completion_expectation', '')), ''), 'required')
            AND s.coach_note IS NOT DISTINCT FROM nullif(trim(COALESCE(v_slot->>'coach_note', '')), '')
            AND s.authored_progression IS NOT DISTINCT FROM (v_slot->'progression')
        ) THEN
          RETURN FALSE;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  -- Global slot key set: every persisted package_slot_key must be expected.
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_session_slots s
  JOIN public.programme_version_days d ON d.id = s.day_id
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = p_version_id
    AND s.package_slot_key IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(payload->'weeks') AS wk(value),
           jsonb_array_elements(COALESCE(wk.value->'days', '[]'::JSONB)) AS dy(value),
           jsonb_array_elements(COALESCE(dy.value->'slots', '[]'::JSONB)) AS sl(value)
      WHERE trim(sl.value->>'slot_key') = s.package_slot_key
    );
  IF v_actual <> 0 THEN
    RETURN FALSE;
  END IF;

  -- Comparison identities
  v_expected := jsonb_array_length(COALESCE(payload->'comparison_identities', '[]'::JSONB));
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_comparison_identities c
  WHERE c.version_id = p_version_id;
  IF v_actual IS DISTINCT FROM v_expected THEN
    RETURN FALSE;
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'comparison_identities', '[]'::JSONB))
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM public.programme_version_comparison_identities c
      WHERE c.version_id = p_version_id
        AND c.comparison_key IS NOT DISTINCT FROM trim(v_item->>'id')
        AND c.session_lineage_id IS NOT DISTINCT FROM trim(v_item->>'session_lineage_id')
        AND c.label IS NOT DISTINCT FROM trim(v_item->>'label')
    ) THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  -- Adaptation permissions
  v_expected := jsonb_array_length(COALESCE(payload->'adaptation_permissions', '[]'::JSONB));
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_adaptation_permissions a
  WHERE a.version_id = p_version_id;
  IF v_actual IS DISTINCT FROM v_expected THEN
    RETURN FALSE;
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'adaptation_permissions', '[]'::JSONB))
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM public.programme_version_adaptation_permissions a
      WHERE a.version_id = p_version_id
        AND a.permission_key IS NOT DISTINCT FROM trim(v_item->>'id')
        AND a.change_kind IS NOT DISTINCT FROM trim(v_item->>'change_kind')
        AND a.target_ref IS NOT DISTINCT FROM trim(v_item->>'target_ref')
        AND a.athlete_agreement_required IS NOT DISTINCT FROM TRUE
        AND a.scope_note IS NOT DISTINCT FROM nullif(trim(COALESCE(v_item->>'scope_note', '')), '')
    ) THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  -- Protected invariants
  v_expected := jsonb_array_length(COALESCE(payload->'protected_invariants', '[]'::JSONB));
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_protected_invariants i
  WHERE i.version_id = p_version_id;
  IF v_actual IS DISTINCT FROM v_expected THEN
    RETURN FALSE;
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'protected_invariants', '[]'::JSONB))
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM public.programme_version_protected_invariants i
      WHERE i.version_id = p_version_id
        AND i.invariant_key IS NOT DISTINCT FROM trim(v_item->>'id')
        AND i.kind IS NOT DISTINCT FROM trim(v_item->>'kind')
        AND i.target_ref IS NOT DISTINCT FROM trim(v_item->>'target_ref')
        AND i.description IS NOT DISTINCT FROM trim(v_item->>'description')
    ) THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  -- Assessments
  v_expected := jsonb_array_length(COALESCE(payload->'assessments', '[]'::JSONB));
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_assessments a
  WHERE a.version_id = p_version_id;
  IF v_actual IS DISTINCT FROM v_expected THEN
    RETURN FALSE;
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'assessments', '[]'::JSONB))
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM public.programme_version_assessments a
      WHERE a.version_id = p_version_id
        AND a.assessment_key IS NOT DISTINCT FROM trim(v_item->>'id')
        AND a.slot_ref IS NOT DISTINCT FROM trim(v_item->>'slot_ref')
        AND a.evidence_requirement IS NOT DISTINCT FROM trim(v_item->>'evidence_requirement')
        AND a.comparison_identity_key IS NOT DISTINCT FROM trim(v_item->>'comparison_identity_id')
        AND a.label IS NOT DISTINCT FROM nullif(trim(COALESCE(v_item->>'label', '')), '')
    ) THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  -- Evidence requirements
  v_expected := jsonb_array_length(COALESCE(payload->'performance_evidence_requirements', '[]'::JSONB));
  SELECT COUNT(*) INTO v_actual
  FROM public.programme_version_evidence_requirements e
  WHERE e.version_id = p_version_id;
  IF v_actual IS DISTINCT FROM v_expected THEN
    RETURN FALSE;
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'performance_evidence_requirements', '[]'::JSONB))
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM public.programme_version_evidence_requirements e
      WHERE e.version_id = p_version_id
        AND e.evidence_key IS NOT DISTINCT FROM trim(v_item->>'id')
        AND e.comparison_identity_key IS NOT DISTINCT FROM trim(v_item->>'comparison_identity_id')
        AND e.metric IS NOT DISTINCT FROM trim(v_item->>'metric')
        AND e.required IS NOT DISTINCT FROM (v_item->>'required')::BOOLEAN
    ) THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_authored_plan_package_graph_matches(UUID, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cohort_authored_plan_package_graph_matches(UUID, JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.cohort_authored_plan_package_graph_matches(UUID, JSONB) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_authored_plan_package_graph_matches(UUID, JSONB) TO service_role;

COMMENT ON FUNCTION public.cohort_authored_plan_package_graph_matches(UUID, JSONB) IS
  'Sprint 1.2 idempotency gate: TRUE only when persisted package graph completely matches the validated import payload.';

-- ---------------------------------------------------------------------------
-- 7. Import RPC (service_role only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.import_authored_plan_package(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_schema_version INT;
  v_hash TEXT;
  v_imported_by TEXT;
  v_programme JSONB;
  v_lineage_code TEXT;
  v_version_number INT;
  v_lineage public.programme_lineages%ROWTYPE;
  v_existing public.programme_versions%ROWTYPE;
  v_version_id UUID;
  v_phase JSONB;
  v_week JSONB;
  v_day JSONB;
  v_slot JSONB;
  v_item JSONB;
  v_phase_id UUID;
  v_week_id UUID;
  v_day_id UUID;
  v_phase_map JSONB := '{}'::JSONB;
  v_slot_keys TEXT[] := ARRAY[]::TEXT[];
  v_assessment_keys TEXT[] := ARRAY[]::TEXT[];
  v_comparison_keys TEXT[] := ARRAY[]::TEXT[];
  v_session_lineages TEXT[] := ARRAY[]::TEXT[];
  v_session_keys TEXT[] := ARRAY[]::TEXT[];
  v_session JSONB;
  v_protocol_id TEXT;
  v_session_lineage_id TEXT;
  v_revision_number INT;
  v_lifecycle TEXT;
  v_content_kind TEXT;
  v_row_count INT;
  v_assessment_slot TEXT;
  v_cmp_key TEXT;
  v_target TEXT;
  v_kind TEXT;
  v_session_key TEXT;
  v_slot_key TEXT;
  v_match_count INT;
  v_lineage_missing BOOLEAN := FALSE;
  v_constraint TEXT;
  v_week_numbers INT[] := ARRAY[]::INT[];
  v_phase_orders INT[] := ARRAY[]::INT[];
  v_day_keys TEXT[] := ARRAY[]::TEXT[];
  v_day_orders INT[] := ARRAY[]::INT[];
  v_session_orders INT[] := ARRAY[]::INT[];
  v_permission_keys TEXT[] := ARRAY[]::TEXT[];
  v_invariant_keys TEXT[] := ARRAY[]::TEXT[];
  v_evidence_keys TEXT[] := ARRAY[]::TEXT[];
BEGIN
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_payload', 'message', 'Payload must be a JSON object.');
  END IF;

  -- Reject client-selected ownership / publication / approval.
  IF payload ? 'lifecycle_status' OR payload ? 'approved_for_global' OR payload ? 'published_at'
     OR payload ? 'owner_type' OR payload ? 'owner_id' OR payload ? 'library_scope' THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'ownership_or_lifecycle_spoof',
      'message', 'Caller cannot select ownership, publication, or catalogue approval state.'
    );
  END IF;

  v_schema_version := NULLIF(payload->>'package_schema_version', '')::INT;
  v_hash := lower(trim(COALESCE(payload->>'package_content_hash', '')));
  v_imported_by := nullif(trim(COALESCE(payload->>'imported_by', '')), '');
  v_programme := payload->'programme';

  IF v_schema_version IS DISTINCT FROM 1 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'unsupported_schema_version', 'message', 'Unsupported package_schema_version.');
  END IF;
  IF v_hash IS NULL OR v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_hash', 'message', 'package_content_hash must be 64 lowercase hex chars.');
  END IF;
  IF v_imported_by IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_imported_by', 'message', 'imported_by is required.');
  END IF;
  IF v_programme IS NULL OR jsonb_typeof(v_programme) <> 'object' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_programme', 'message', 'programme object is required.');
  END IF;

  v_lineage_code := trim(COALESCE(v_programme->>'lineage_code', ''));
  v_version_number := NULLIF(v_programme->>'version_number', '')::INT;
  IF v_lineage_code = '' OR v_version_number IS NULL OR v_version_number < 1 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_programme_identity', 'message', 'lineage_code and version_number are required.');
  END IF;
  IF nullif(trim(COALESCE(v_programme->>'name', '')), '') IS NULL
     OR nullif(trim(COALESCE(v_programme->>'coaching_intent', '')), '') IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_programme_fields', 'message', 'programme.name and coaching_intent are required.');
  END IF;

  -- -----------------------------------------------------------------------
  -- Pre-write validation: sessions, structure keys, and package references.
  -- No programme_lineages / programme_versions writes occur before this completes.
  -- -----------------------------------------------------------------------
  IF jsonb_typeof(payload->'sessions') <> 'array' OR jsonb_array_length(payload->'sessions') < 1 THEN
    RETURN jsonb_build_object('status', 'session_resolution_failure', 'code', 'sessions_required', 'message', 'At least one session revision reference is required.');
  END IF;

  FOR v_session IN SELECT value FROM jsonb_array_elements(payload->'sessions')
  LOOP
    v_session_key := trim(COALESCE(v_session->>'session_key', ''));
    v_protocol_id := trim(COALESCE(v_session->>'protocol_id', ''));
    v_session_lineage_id := trim(COALESCE(v_session->>'session_lineage_id', ''));
    v_revision_number := NULLIF(v_session->>'revision_number', '')::INT;
    IF v_session_key = '' OR v_protocol_id = '' OR v_session_lineage_id = '' OR v_revision_number IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'session_resolution_failure',
        'code', 'incomplete_session_identity',
        'message', 'Session revision identity incomplete.'
      );
    END IF;
    IF v_session_key = ANY (v_session_keys) THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'duplicate_session_key',
        'message', 'Duplicate session_key in package sessions catalogue.'
      );
    END IF;
    v_session_keys := array_append(v_session_keys, v_session_key);
    v_session_lineages := array_append(v_session_lineages, v_session_lineage_id);

    SELECT
      p.lifecycle_status,
      COALESCE(p.content_kind, ''),
      p.session_lineage_id::TEXT,
      p.revision_number
    INTO
      v_lifecycle,
      v_content_kind,
      v_target,
      v_row_count
    FROM public.performance_protocols p
    WHERE p.protocol_id = v_protocol_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'session_resolution_failure',
        'code', 'session_missing',
        'message', 'Referenced session revision was not found.'
      );
    END IF;
    IF v_lifecycle IS DISTINCT FROM 'published' THEN
      RETURN jsonb_build_object(
        'status', 'session_resolution_failure',
        'code', 'session_not_published',
        'message', 'Referenced session revision is not published.'
      );
    END IF;
    IF v_content_kind = 'session_template' OR v_protocol_id LIKE 'TMP-%' THEN
      RETURN jsonb_build_object(
        'status', 'session_resolution_failure',
        'code', 'canonical_template_forbidden',
        'message', 'Canonical session templates cannot be live-attached to programme slots.'
      );
    END IF;
    IF v_target IS DISTINCT FROM v_session_lineage_id
       OR v_row_count IS DISTINCT FROM v_revision_number THEN
      RETURN jsonb_build_object(
        'status', 'session_resolution_failure',
        'code', 'session_identity_mismatch',
        'message', 'Session identity does not match the published revision.'
      );
    END IF;
  END LOOP;

  IF jsonb_typeof(payload->'weeks') <> 'array' OR jsonb_array_length(payload->'weeks') < 1 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'weeks_required', 'message', 'At least one week is required.');
  END IF;

  -- Collect phase keys/orders (optional) and validate uniqueness before writes.
  IF jsonb_typeof(payload->'phases') = 'array' THEN
    FOR v_phase IN SELECT value FROM jsonb_array_elements(payload->'phases')
    LOOP
      v_target := trim(COALESCE(v_phase->>'phase_key', ''));
      v_row_count := NULLIF(v_phase->>'phase_order', '')::INT;
      IF v_target = '' OR v_phase_map ? v_target THEN
        RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'phase_key missing or duplicated.');
      END IF;
      IF v_row_count IS NULL OR v_row_count = ANY (v_phase_orders) THEN
        RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'phase_order missing or duplicated.');
      END IF;
      v_phase_map := v_phase_map || jsonb_build_object(v_target, 'pending');
      v_phase_orders := array_append(v_phase_orders, v_row_count);
    END LOOP;
  END IF;

  FOR v_week IN SELECT value FROM jsonb_array_elements(payload->'weeks')
  LOOP
    v_revision_number := NULLIF(v_week->>'week_number', '')::INT;
    IF v_revision_number IS NULL OR v_revision_number = ANY (v_week_numbers) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'week_number missing or duplicated.');
    END IF;
    v_week_numbers := array_append(v_week_numbers, v_revision_number);

    v_target := nullif(trim(COALESCE(v_week->>'phase_key', '')), '');
    IF v_target IS NOT NULL AND NOT (v_phase_map ? v_target) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Week references unknown phase_key.');
    END IF;

    -- Per-week day uniqueness (day_key and day_order are unique under a week).
    v_day_keys := ARRAY[]::TEXT[];
    v_day_orders := ARRAY[]::INT[];

    FOR v_day IN SELECT value FROM jsonb_array_elements(COALESCE(v_week->'days', '[]'::JSONB))
    LOOP
      v_assessment_slot := trim(COALESCE(v_day->>'day_key', ''));
      v_match_count := NULLIF(v_day->>'day_order', '')::INT;
      IF v_assessment_slot = '' OR v_assessment_slot = ANY (v_day_keys) THEN
        RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'day_key missing or duplicated within week.');
      END IF;
      IF v_match_count IS NULL OR v_match_count = ANY (v_day_orders) THEN
        RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'day_order missing or duplicated within week.');
      END IF;
      v_day_keys := array_append(v_day_keys, v_assessment_slot);
      v_day_orders := array_append(v_day_orders, v_match_count);

      v_session_orders := ARRAY[]::INT[];
      FOR v_slot IN SELECT value FROM jsonb_array_elements(COALESCE(v_day->'slots', '[]'::JSONB))
      LOOP
        v_slot_key := trim(COALESCE(v_slot->>'slot_key', ''));
        v_session_key := trim(COALESCE(v_slot->>'session_key', ''));
        v_row_count := NULLIF(v_slot->>'session_order', '')::INT;
        IF v_slot_key = '' THEN
          RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_slot_key', 'message', 'slot_key is required.');
        END IF;
        IF v_slot_key = ANY (v_slot_keys) THEN
          RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'Duplicate package_slot_key in package.');
        END IF;
        IF v_row_count IS NULL OR v_row_count = ANY (v_session_orders) THEN
          RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'session_order missing or duplicated within day.');
        END IF;
        SELECT COUNT(*) INTO v_match_count
        FROM unnest(v_session_keys) AS sk(session_key)
        WHERE sk.session_key = v_session_key;
        IF v_match_count <> 1 THEN
          RETURN jsonb_build_object(
            'status', 'validation_failure',
            'code', 'broken_reference',
            'message', 'Slot session_key is missing or ambiguous.'
          );
        END IF;
        IF v_slot->'progression' IS NULL
           OR jsonb_typeof(v_slot->'progression') <> 'object'
           OR nullif(trim(COALESCE(v_slot->'progression'->>'prescription_summary', '')), '') IS NULL THEN
          RETURN jsonb_build_object(
            'status', 'validation_failure',
            'code', 'invalid_authored_progression',
            'message', 'Authored progression requires prescription_summary.'
          );
        END IF;
        v_slot_keys := array_append(v_slot_keys, v_slot_key);
        v_session_orders := array_append(v_session_orders, v_row_count);
      END LOOP;
    END LOOP;
  END LOOP;

  IF coalesce(array_length(v_slot_keys, 1), 0) < 1 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'incomplete_structure', 'message', 'At least one session slot is required.');
  END IF;

  -- Comparison identities (anchors are package session lineages, not exact revisions).
  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'comparison_identities', '[]'::JSONB))
  LOOP
    v_cmp_key := trim(COALESCE(v_item->>'id', ''));
    v_session_lineage_id := trim(COALESCE(v_item->>'session_lineage_id', ''));
    IF v_cmp_key = '' OR v_cmp_key = ANY (v_comparison_keys) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'comparison identity id missing or duplicated.');
    END IF;
    IF NOT (v_session_lineage_id = ANY (v_session_lineages)) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Comparison identity session_lineage_id is not in package sessions.');
    END IF;
    v_comparison_keys := array_append(v_comparison_keys, v_cmp_key);
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'adaptation_permissions', '[]'::JSONB))
  LOOP
    v_cmp_key := trim(COALESCE(v_item->>'id', ''));
    IF v_cmp_key = '' OR v_cmp_key = ANY (v_permission_keys) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'adaptation permission id missing or duplicated.');
    END IF;
    v_permission_keys := array_append(v_permission_keys, v_cmp_key);
    IF (v_item->>'athlete_agreement_required')::BOOLEAN IS DISTINCT FROM TRUE THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'agreement_required', 'message', 'athlete_agreement_required must be true.');
    END IF;
    v_target := trim(COALESCE(v_item->>'target_ref', ''));
    IF v_target <> 'programme' AND NOT (v_target = ANY (v_slot_keys)) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Adaptation target_ref does not resolve to a package slot.');
    END IF;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'assessments', '[]'::JSONB))
  LOOP
    v_target := trim(COALESCE(v_item->>'id', ''));
    IF v_target = '' OR v_target = ANY (v_assessment_keys) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'assessment id missing or duplicated.');
    END IF;
    v_assessment_keys := array_append(v_assessment_keys, v_target);
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'protected_invariants', '[]'::JSONB))
  LOOP
    v_cmp_key := trim(COALESCE(v_item->>'id', ''));
    IF v_cmp_key = '' OR v_cmp_key = ANY (v_invariant_keys) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'protected invariant id missing or duplicated.');
    END IF;
    v_invariant_keys := array_append(v_invariant_keys, v_cmp_key);
    v_kind := trim(COALESCE(v_item->>'kind', ''));
    v_target := trim(COALESCE(v_item->>'target_ref', ''));
    IF v_kind = 'assessment_immutable' THEN
      IF NOT (v_target = ANY (v_assessment_keys)) AND NOT (v_target = ANY (v_slot_keys)) THEN
        RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Protected invariant target_ref does not resolve.');
      END IF;
    ELSIF v_target <> 'programme'
          AND NOT (v_target = ANY (v_slot_keys))
          AND NOT (v_target = ANY (v_assessment_keys)) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Protected invariant target_ref does not resolve.');
    END IF;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'assessments', '[]'::JSONB))
  LOOP
    v_assessment_slot := trim(COALESCE(v_item->>'slot_ref', ''));
    v_cmp_key := trim(COALESCE(v_item->>'comparison_identity_id', ''));
    IF NOT (v_assessment_slot = ANY (v_slot_keys)) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Assessment slot_ref does not resolve to a package slot.');
    END IF;
    IF v_cmp_key = '' OR NOT (v_cmp_key = ANY (v_comparison_keys)) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Assessment comparison_identity_id does not resolve.');
    END IF;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'performance_evidence_requirements', '[]'::JSONB))
  LOOP
    v_target := trim(COALESCE(v_item->>'id', ''));
    IF v_target = '' OR v_target = ANY (v_evidence_keys) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_package_identity', 'message', 'evidence requirement id missing or duplicated.');
    END IF;
    v_evidence_keys := array_append(v_evidence_keys, v_target);
    v_cmp_key := trim(COALESCE(v_item->>'comparison_identity_id', ''));
    IF v_cmp_key = '' OR NOT (v_cmp_key = ANY (v_comparison_keys)) THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'broken_reference', 'message', 'Evidence requirement comparison_identity_id does not resolve.');
    END IF;
  END LOOP;

  -- Reset phase map for write phase (keys only).
  v_phase_map := '{}'::JSONB;

  -- -----------------------------------------------------------------------
  -- Concurrency-safe lineage resolution + collision classification.
  -- Advisory xact lock serialises creators of the same lineage_code.
  -- -----------------------------------------------------------------------
  PERFORM pg_advisory_xact_lock(
    872314001,
    hashtext(v_lineage_code)
  );

  SELECT * INTO v_lineage
  FROM public.programme_lineages
  WHERE code = v_lineage_code
  FOR UPDATE;

  IF NOT FOUND THEN
    v_lineage_missing := TRUE;
  ELSE
    SELECT * INTO v_existing
    FROM public.programme_versions
    WHERE lineage_id = v_lineage.id
      AND version_number = v_version_number
    FOR UPDATE;

    IF FOUND THEN
      IF v_existing.lifecycle_status = 'published' THEN
        RETURN jsonb_build_object(
          'status', 'published_version_conflict',
          'code', 'published_version_exists',
          'message', 'Target programme version is published and cannot be overwritten.',
          'programme_version_id', v_existing.id
        );
      END IF;
      IF v_existing.lifecycle_status <> 'draft' THEN
        RETURN jsonb_build_object(
          'status', 'version_collision',
          'code', 'non_draft_exists',
          'message', 'Target programme version exists and is not an importable draft.',
          'programme_version_id', v_existing.id
        );
      END IF;
      IF v_existing.package_content_hash IS NOT NULL
         AND v_existing.package_content_hash = v_hash
         AND v_existing.package_schema_version = v_schema_version
         AND v_existing.library_scope = 'cohort_global'
         AND v_existing.owner_type = 'global'
         AND v_existing.owner_id IS NULL
         AND v_existing.approved_for_global = FALSE THEN
        IF public.cohort_authored_plan_package_graph_matches(v_existing.id, payload) THEN
          RETURN jsonb_build_object(
            'status', 'idempotent_existing_draft',
            'code', 'same_hash_existing_draft',
            'programme_version_id', v_existing.id,
            'lineage_id', v_lineage.id,
            'lineage_code', v_lineage.code,
            'version_number', v_existing.version_number,
            'package_content_hash', v_existing.package_content_hash,
            'lifecycle_status', v_existing.lifecycle_status,
            'approved_for_global', FALSE
          );
        END IF;
        -- Provenance matches but persisted graph is hollow/altered/incomplete.
        RETURN jsonb_build_object(
          'status', 'partial_state_conflict',
          'code', 'partial_existing_draft',
          'message', 'Existing draft provenance matches but package graph is incomplete or inconsistent. Fail closed; no repair.',
          'programme_version_id', v_existing.id
        );
      END IF;
      IF v_existing.package_content_hash IS NOT NULL
         AND v_existing.package_content_hash IS DISTINCT FROM v_hash THEN
        RETURN jsonb_build_object(
          'status', 'version_collision',
          'code', 'hash_collision',
          'message', 'Same lineage/version exists with a different package_content_hash. Bump version_number.',
          'programme_version_id', v_existing.id
        );
      END IF;
      RETURN jsonb_build_object(
        'status', 'partial_state_conflict',
        'code', 'partial_existing_draft',
        'message', 'Existing draft is incomplete or inconsistent with this package. Fail closed; no repair.',
        'programme_version_id', v_existing.id
      );
    END IF;
  END IF;

  -- -----------------------------------------------------------------------
  -- Atomic write section. Any exception rolls back lineage + all children.
  -- -----------------------------------------------------------------------
  BEGIN
    IF v_lineage_missing THEN
      INSERT INTO public.programme_lineages (code, created_by)
      VALUES (v_lineage_code, v_imported_by)
      RETURNING * INTO v_lineage;
    END IF;

    INSERT INTO public.programme_versions (
      lineage_id,
      version_number,
      lifecycle_status,
      library_scope,
      owner_type,
      owner_id,
      organisation_id,
      created_by,
      name,
      description,
      duration_weeks,
      sessions_per_week,
      primary_goal,
      coaching_intent,
      package_schema_version,
      package_content_hash,
      package_imported_at,
      package_imported_by,
      approved_for_global,
      approved_for_adaptation
    ) VALUES (
      v_lineage.id,
      v_version_number,
      'draft',
      'cohort_global',
      'global',
      NULL,
      NULL,
      v_imported_by,
      trim(v_programme->>'name'),
      nullif(trim(COALESCE(v_programme->>'description', '')), ''),
      NULLIF(v_programme->>'duration_weeks', '')::INT,
      NULLIF(v_programme->>'sessions_per_week', '')::INT,
      nullif(trim(COALESCE(v_programme->>'primary_goal', '')), ''),
      trim(v_programme->>'coaching_intent'),
      v_schema_version,
      v_hash,
      NOW(),
      v_imported_by,
      FALSE,
      FALSE
    )
    RETURNING id INTO v_version_id;

    IF jsonb_typeof(payload->'phases') = 'array' THEN
      FOR v_phase IN SELECT value FROM jsonb_array_elements(payload->'phases')
      LOOP
        INSERT INTO public.programme_version_phases (
          version_id, phase_order, title, intent, coach_note
        ) VALUES (
          v_version_id,
          (v_phase->>'phase_order')::INT,
          trim(v_phase->>'title'),
          nullif(trim(COALESCE(v_phase->>'intent', '')), ''),
          nullif(trim(COALESCE(v_phase->>'coach_note', '')), '')
        )
        RETURNING id INTO v_phase_id;
        v_phase_map := v_phase_map || jsonb_build_object(trim(v_phase->>'phase_key'), v_phase_id::TEXT);
      END LOOP;
    END IF;

    FOR v_week IN SELECT value FROM jsonb_array_elements(payload->'weeks')
    LOOP
      v_phase_id := NULL;
      IF nullif(trim(COALESCE(v_week->>'phase_key', '')), '') IS NOT NULL THEN
        v_phase_id := NULLIF(v_phase_map->>trim(v_week->>'phase_key'), '')::UUID;
      END IF;

      INSERT INTO public.programme_version_weeks (
        version_id, phase_id, week_number, title, intent, coach_note
      ) VALUES (
        v_version_id,
        v_phase_id,
        (v_week->>'week_number')::INT,
        nullif(trim(COALESCE(v_week->>'title', '')), ''),
        nullif(trim(COALESCE(v_week->>'intent', '')), ''),
        nullif(trim(COALESCE(v_week->>'coach_note', '')), '')
      )
      RETURNING id INTO v_week_id;

      FOR v_day IN SELECT value FROM jsonb_array_elements(COALESCE(v_week->'days', '[]'::JSONB))
      LOOP
        INSERT INTO public.programme_version_days (
          week_id, day_key, day_order, day_type, title, intent, coach_note
        ) VALUES (
          v_week_id,
          trim(v_day->>'day_key'),
          (v_day->>'day_order')::INT,
          trim(v_day->>'day_type'),
          nullif(trim(COALESCE(v_day->>'title', '')), ''),
          nullif(trim(COALESCE(v_day->>'intent', '')), ''),
          nullif(trim(COALESCE(v_day->>'coach_note', '')), '')
        )
        RETURNING id INTO v_day_id;

        FOR v_slot IN SELECT value FROM jsonb_array_elements(COALESCE(v_day->'slots', '[]'::JSONB))
        LOOP
          SELECT s.value->>'protocol_id' INTO v_protocol_id
          FROM jsonb_array_elements(payload->'sessions') AS s(value)
          WHERE trim(s.value->>'session_key') = trim(v_slot->>'session_key');

          INSERT INTO public.programme_version_session_slots (
            day_id,
            session_order,
            protocol_id,
            display_title,
            time_of_day,
            is_optional,
            completion_expectation,
            coach_note,
            package_slot_key,
            authored_progression
          ) VALUES (
            v_day_id,
            (v_slot->>'session_order')::INT,
            trim(v_protocol_id),
            nullif(trim(COALESCE(v_slot->>'display_title', '')), ''),
            COALESCE(nullif(trim(COALESCE(v_slot->>'time_of_day', '')), ''), 'any'),
            COALESCE((v_slot->>'is_optional')::BOOLEAN, FALSE),
            COALESCE(nullif(trim(COALESCE(v_slot->>'completion_expectation', '')), ''), 'required'),
            nullif(trim(COALESCE(v_slot->>'coach_note', '')), ''),
            trim(v_slot->>'slot_key'),
            v_slot->'progression'
          );
        END LOOP;
      END LOOP;
    END LOOP;

    FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'comparison_identities', '[]'::JSONB))
    LOOP
      INSERT INTO public.programme_version_comparison_identities (
        version_id, comparison_key, session_lineage_id, label
      ) VALUES (
        v_version_id,
        trim(v_item->>'id'),
        trim(v_item->>'session_lineage_id'),
        trim(v_item->>'label')
      );
    END LOOP;

    FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'adaptation_permissions', '[]'::JSONB))
    LOOP
      INSERT INTO public.programme_version_adaptation_permissions (
        version_id, permission_key, change_kind, target_ref, athlete_agreement_required, scope_note
      ) VALUES (
        v_version_id,
        trim(v_item->>'id'),
        trim(v_item->>'change_kind'),
        trim(v_item->>'target_ref'),
        TRUE,
        nullif(trim(COALESCE(v_item->>'scope_note', '')), '')
      );
    END LOOP;

    FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'protected_invariants', '[]'::JSONB))
    LOOP
      INSERT INTO public.programme_version_protected_invariants (
        version_id, invariant_key, kind, target_ref, description
      ) VALUES (
        v_version_id,
        trim(v_item->>'id'),
        trim(v_item->>'kind'),
        trim(v_item->>'target_ref'),
        trim(v_item->>'description')
      );
    END LOOP;

    FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'assessments', '[]'::JSONB))
    LOOP
      INSERT INTO public.programme_version_assessments (
        version_id, assessment_key, slot_ref, evidence_requirement, comparison_identity_key, label
      ) VALUES (
        v_version_id,
        trim(v_item->>'id'),
        trim(v_item->>'slot_ref'),
        trim(v_item->>'evidence_requirement'),
        trim(v_item->>'comparison_identity_id'),
        nullif(trim(COALESCE(v_item->>'label', '')), '')
      );
    END LOOP;

    FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'performance_evidence_requirements', '[]'::JSONB))
    LOOP
      INSERT INTO public.programme_version_evidence_requirements (
        version_id, evidence_key, comparison_identity_key, metric, required
      ) VALUES (
        v_version_id,
        trim(v_item->>'id'),
        trim(v_item->>'comparison_identity_id'),
        trim(v_item->>'metric'),
        (v_item->>'required')::BOOLEAN
      );
    END LOOP;

    RETURN jsonb_build_object(
      'status', 'imported_draft',
      'code', 'created_hidden_draft',
      'programme_version_id', v_version_id,
      'lineage_id', v_lineage.id,
      'lineage_code', v_lineage.code,
      'version_number', v_version_number,
      'package_content_hash', v_hash,
      'package_schema_version', v_schema_version,
      'lifecycle_status', 'draft',
      'library_scope', 'cohort_global',
      'owner_type', 'global',
      'approved_for_global', FALSE
    );
  EXCEPTION
    WHEN unique_violation THEN
      -- Writes in this block are rolled back. Discriminate race vs package uniqueness
      -- without leaking constraint names or SQL detail to the caller.
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;

      SELECT * INTO v_lineage
      FROM public.programme_lineages
      WHERE code = v_lineage_code;

      IF FOUND THEN
        SELECT * INTO v_existing
        FROM public.programme_versions
        WHERE lineage_id = v_lineage.id
          AND version_number = v_version_number;

        IF FOUND THEN
          IF v_existing.lifecycle_status = 'published' THEN
            RETURN jsonb_build_object(
              'status', 'published_version_conflict',
              'code', 'published_version_exists',
              'message', 'Target programme version is published and cannot be overwritten.',
              'programme_version_id', v_existing.id
            );
          END IF;
          IF v_existing.lifecycle_status = 'draft'
             AND v_existing.package_content_hash IS NOT NULL
             AND v_existing.package_content_hash = v_hash
             AND v_existing.package_schema_version = v_schema_version
             AND v_existing.library_scope = 'cohort_global'
             AND v_existing.owner_type = 'global'
             AND v_existing.owner_id IS NULL
             AND v_existing.approved_for_global = FALSE
             AND public.cohort_authored_plan_package_graph_matches(v_existing.id, payload) THEN
            RETURN jsonb_build_object(
              'status', 'idempotent_existing_draft',
              'code', 'same_hash_existing_draft',
              'programme_version_id', v_existing.id,
              'lineage_id', v_lineage.id,
              'lineage_code', v_lineage.code,
              'version_number', v_existing.version_number,
              'package_content_hash', v_existing.package_content_hash,
              'lifecycle_status', v_existing.lifecycle_status,
              'approved_for_global', FALSE
            );
          END IF;
          IF v_existing.package_content_hash IS NOT NULL
             AND v_existing.package_content_hash IS DISTINCT FROM v_hash THEN
            RETURN jsonb_build_object(
              'status', 'version_collision',
              'code', 'hash_collision',
              'message', 'Same lineage/version exists with a different package_content_hash. Bump version_number.',
              'programme_version_id', v_existing.id
            );
          END IF;
          RETURN jsonb_build_object(
            'status', 'partial_state_conflict',
            'code', 'partial_existing_draft',
            'message', 'Existing draft is incomplete or inconsistent with this package. Fail closed; no repair.',
            'programme_version_id', v_existing.id
          );
        END IF;
      END IF;

      -- Race only when the uniqueness conflict is on lineage/version identity.
      IF v_constraint IN (
        'programme_lineages_code_unique',
        'programme_versions_lineage_version_unique'
      ) THEN
        RETURN jsonb_build_object(
          'status', 'version_collision',
          'code', 'lineage_or_version_race',
          'message', 'Concurrent import conflicted on lineage or version identity. Retry safely.'
        );
      END IF;

      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'duplicate_package_identity',
        'message', 'Import rejected due to duplicate package identity and was rolled back.'
      );
    WHEN check_violation THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'constraint_violation',
        'message', 'Import rejected by database constraints and was rolled back.'
      );
    WHEN foreign_key_violation THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'broken_reference',
        'message', 'Import references an unknown package identity and was rolled back.'
      );
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'status', 'database_failure',
        'code', 'unexpected_database_failure',
        'message', 'Import failed and was rolled back.'
      );
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.import_authored_plan_package(JSONB) TO service_role;

COMMENT ON FUNCTION public.import_authored_plan_package(JSONB) IS
  'Sprint 1.2 service-role-only atomic Plan Package import. Always creates/returns a hidden Cohort Global draft. Never publishes or approves for catalogue. Pre-write validation; write-section failures roll back completely.';

-- ---------------------------------------------------------------------------
-- 8. Publish + catalogue-approve RPCs (service_role only, separate gates)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.publish_cohort_global_programme_version(
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
  WHERE id = p_version_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'version_not_found');
  END IF;
  IF v_row.lifecycle_status <> 'draft' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'not_draft');
  END IF;
  IF v_row.library_scope <> 'cohort_global' OR v_row.owner_type <> 'global' THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'not_cohort_global');
  END IF;
  IF v_row.package_content_hash IS NULL OR v_row.package_schema_version IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_package_provenance');
  END IF;
  IF v_row.approved_for_global = TRUE THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'already_catalogue_approved');
  END IF;

  SELECT COUNT(*) INTO v_slot_count
  FROM public.programme_version_session_slots s
  JOIN public.programme_version_days d ON d.id = s.day_id
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = p_version_id;

  IF v_slot_count < 1 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'incomplete_structure');
  END IF;

  IF EXISTS (
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
    RETURN jsonb_build_object('status', 'session_resolution_failure', 'code', 'session_not_eligible');
  END IF;

  UPDATE public.programme_versions
  SET lifecycle_status = 'published',
      published_at = NOW(),
      approved_for_global = FALSE,
      updated_at = NOW()
  WHERE id = p_version_id;

  RETURN jsonb_build_object(
    'status', 'published',
    'programme_version_id', p_version_id,
    'published_at', NOW(),
    'approved_for_global', FALSE,
    'actor', trim(p_actor)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.publish_cohort_global_programme_version(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.publish_cohort_global_programme_version(UUID, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.publish_cohort_global_programme_version(UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.publish_cohort_global_programme_version(UUID, TEXT) TO service_role;

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
BEGIN
  IF p_version_id IS NULL OR nullif(trim(COALESCE(p_actor, '')), '') IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_args');
  END IF;

  SELECT * INTO v_row
  FROM public.programme_versions
  WHERE id = p_version_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'version_not_found');
  END IF;
  IF v_row.lifecycle_status <> 'published' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'draft_catalogue_approval_forbidden');
  END IF;
  IF v_row.library_scope <> 'cohort_global' OR v_row.owner_type <> 'global' THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'not_cohort_global');
  END IF;

  -- Strict whitelist: catalogue flag + audit timestamp only.
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

REVOKE ALL ON FUNCTION public.approve_cohort_global_programme_version(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_cohort_global_programme_version(UUID, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.approve_cohort_global_programme_version(UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_cohort_global_programme_version(UUID, TEXT) TO service_role;

COMMENT ON FUNCTION public.publish_cohort_global_programme_version(UUID, TEXT) IS
  'Service-role-only publish gate for Cohort Global package drafts. Leaves approved_for_global false.';
COMMENT ON FUNCTION public.approve_cohort_global_programme_version(UUID, TEXT) IS
  'Service-role-only catalogue approval gate. Updates only approved_for_global and updated_at.';

-- Manual verification checklist (local only — do not apply remotely from CI):
-- 1. anon/authenticated EXECUTE import_authored_plan_package → denied
-- 2. service_role import creates draft with approved_for_global=false
-- 3. authenticated SELECT global draft → denied
-- 4. publish leaves approved_for_global false; athlete SELECT still denied
-- 5. approve then athlete SELECT catalogue → allowed
-- 6. UPDATE published package hash → denied by trigger
-- 7. Reparent child from published → draft parent → denied
-- 8. Missing session before lineage write → zero programme_lineages rows
-- 9. Concurrent same lineage/version/hash → one create + idempotent
-- 10. Hosted preflight must ABORT if approved_for_global=true on non-published rows
