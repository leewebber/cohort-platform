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
-- 6. Published immutability triggers (DB boundary)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_version_is_published(p_version_id UUID)
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
      AND v.lifecycle_status = 'published'
  );
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_is_published(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_published(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_published(UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.cohort_reject_published_programme_content_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_version_id UUID;
  v_lifecycle TEXT;
BEGIN
  IF TG_TABLE_NAME = 'programme_versions' THEN
    v_lifecycle := CASE WHEN TG_OP = 'DELETE' THEN OLD.lifecycle_status ELSE OLD.lifecycle_status END;
    IF TG_OP = 'UPDATE' THEN
      -- Allow only: draft→published (+published_at), published→archived (+archived_at),
      -- and approved_for_global toggle on published rows (catalogue gate).
      IF OLD.lifecycle_status = 'published' THEN
        IF NEW.lifecycle_status = 'archived'
           AND NEW.archived_at IS NOT NULL
           AND NEW.package_content_hash IS NOT DISTINCT FROM OLD.package_content_hash
           AND NEW.package_schema_version IS NOT DISTINCT FROM OLD.package_schema_version
           AND NEW.coaching_intent IS NOT DISTINCT FROM OLD.coaching_intent
           AND NEW.name IS NOT DISTINCT FROM OLD.name
           AND NEW.description IS NOT DISTINCT FROM OLD.description
           AND NEW.duration_weeks IS NOT DISTINCT FROM OLD.duration_weeks
           AND NEW.primary_goal IS NOT DISTINCT FROM OLD.primary_goal
           AND NEW.sessions_per_week IS NOT DISTINCT FROM OLD.sessions_per_week
           AND NEW.library_scope IS NOT DISTINCT FROM OLD.library_scope
           AND NEW.owner_type IS NOT DISTINCT FROM OLD.owner_type
           AND NEW.owner_id IS NOT DISTINCT FROM OLD.owner_id
           AND NEW.lineage_id IS NOT DISTINCT FROM OLD.lineage_id
           AND NEW.version_number IS NOT DISTINCT FROM OLD.version_number
           AND NEW.package_imported_at IS NOT DISTINCT FROM OLD.package_imported_at
           AND NEW.package_imported_by IS NOT DISTINCT FROM OLD.package_imported_by
           AND NEW.approved_for_adaptation IS NOT DISTINCT FROM OLD.approved_for_adaptation
        THEN
          RETURN NEW;
        END IF;
        IF NEW.lifecycle_status = 'published'
           AND NEW.approved_for_global IS DISTINCT FROM OLD.approved_for_global
           AND NEW.package_content_hash IS NOT DISTINCT FROM OLD.package_content_hash
           AND NEW.package_schema_version IS NOT DISTINCT FROM OLD.package_schema_version
           AND NEW.coaching_intent IS NOT DISTINCT FROM OLD.coaching_intent
           AND NEW.name IS NOT DISTINCT FROM OLD.name
           AND NEW.description IS NOT DISTINCT FROM OLD.description
           AND NEW.lineage_id IS NOT DISTINCT FROM OLD.lineage_id
           AND NEW.version_number IS NOT DISTINCT FROM OLD.version_number
           AND NEW.published_at IS NOT DISTINCT FROM OLD.published_at
           AND NEW.library_scope IS NOT DISTINCT FROM OLD.library_scope
           AND NEW.owner_type IS NOT DISTINCT FROM OLD.owner_type
        THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Published programme version content is immutable'
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      IF OLD.lifecycle_status = 'draft' AND NEW.lifecycle_status = 'published' THEN
        IF NEW.published_at IS NULL THEN
          RAISE EXCEPTION 'published_at is required when publishing'
            USING ERRCODE = 'check_violation';
        END IF;
        IF NEW.approved_for_global = TRUE THEN
          RAISE EXCEPTION 'Catalogue approval cannot occur during publication'
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
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

  -- Child / structure tables: resolve version_id
  IF TG_TABLE_NAME = 'programme_version_phases' THEN
    v_version_id := COALESCE(NEW.version_id, OLD.version_id);
  ELSIF TG_TABLE_NAME = 'programme_version_weeks' THEN
    v_version_id := COALESCE(NEW.version_id, OLD.version_id);
  ELSIF TG_TABLE_NAME = 'programme_version_days' THEN
    SELECT w.version_id INTO v_version_id
    FROM public.programme_version_weeks w
    WHERE w.id = COALESCE(NEW.week_id, OLD.week_id);
  ELSIF TG_TABLE_NAME = 'programme_version_session_slots' THEN
    SELECT w.version_id INTO v_version_id
    FROM public.programme_version_days d
    JOIN public.programme_version_weeks w ON w.id = d.week_id
    WHERE d.id = COALESCE(NEW.day_id, OLD.day_id);
  ELSIF TG_TABLE_NAME IN (
    'programme_version_adaptation_permissions',
    'programme_version_protected_invariants',
    'programme_version_assessments',
    'programme_version_evidence_requirements',
    'programme_version_comparison_identities'
  ) THEN
    v_version_id := COALESCE(NEW.version_id, OLD.version_id);
  END IF;

  IF v_version_id IS NOT NULL AND public.cohort_programme_version_is_published(v_version_id) THEN
    RAISE EXCEPTION 'Published programme package content is immutable (%)', TG_TABLE_NAME
      USING ERRCODE = 'integrity_constraint_violation';
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

  -- Resolve / create lineage under lock.
  SELECT * INTO v_lineage
  FROM public.programme_lineages
  WHERE code = v_lineage_code
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.programme_lineages (code, created_by)
    VALUES (v_lineage_code, v_imported_by)
    RETURNING * INTO v_lineage;
  END IF;

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
       AND v_existing.approved_for_global = FALSE THEN
      -- Exact idempotent replay: no writes.
      RETURN jsonb_build_object(
        'status', 'idempotent_existing_draft',
        'code', 'same_hash_existing_draft',
        'programme_version_id', v_existing.id,
        'lineage_id', v_lineage.id,
        'lineage_code', v_lineage.code,
        'version_number', v_existing.version_number,
        'package_content_hash', v_existing.package_content_hash,
        'lifecycle_status', v_existing.lifecycle_status
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
    -- Draft exists without matching complete package provenance → partial state.
    RETURN jsonb_build_object(
      'status', 'partial_state_conflict',
      'code', 'partial_existing_draft',
      'message', 'Existing draft is incomplete or inconsistent with this package. Fail closed; no repair.',
      'programme_version_id', v_existing.id
    );
  END IF;

  -- Verify every session revision (published, exact identity, not templates).
  IF jsonb_typeof(payload->'sessions') <> 'array' OR jsonb_array_length(payload->'sessions') < 1 THEN
    RETURN jsonb_build_object('status', 'session_resolution_failure', 'code', 'sessions_required', 'message', 'At least one session revision reference is required.');
  END IF;

  FOR v_session IN SELECT value FROM jsonb_array_elements(payload->'sessions')
  LOOP
    v_protocol_id := trim(COALESCE(v_session->>'protocol_id', ''));
    v_session_lineage_id := trim(COALESCE(v_session->>'session_lineage_id', ''));
    v_revision_number := NULLIF(v_session->>'revision_number', '')::INT;
    IF v_protocol_id = '' OR v_session_lineage_id = '' OR v_revision_number IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'session_resolution_failure',
        'code', 'incomplete_session_identity',
        'message', 'Session revision identity incomplete.'
      );
    END IF;

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
        'message', format('Session revision %s not found.', v_protocol_id)
      );
    END IF;

    IF v_lifecycle IS DISTINCT FROM 'published' THEN
      RETURN jsonb_build_object(
        'status', 'session_resolution_failure',
        'code', 'session_not_published',
        'message', format('Session revision %s is not published.', v_protocol_id)
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
        'message', format('Session identity mismatch for %s.', v_protocol_id)
      );
    END IF;
  END LOOP;

  -- Create draft version (ownership enforced server-side).
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

  -- Phases
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

  IF jsonb_typeof(payload->'weeks') <> 'array' OR jsonb_array_length(payload->'weeks') < 1 THEN
    RAISE EXCEPTION 'weeks required' USING ERRCODE = 'check_violation';
  END IF;

  FOR v_week IN SELECT value FROM jsonb_array_elements(payload->'weeks')
  LOOP
    v_phase_id := NULL;
    IF nullif(trim(COALESCE(v_week->>'phase_key', '')), '') IS NOT NULL THEN
      v_phase_id := NULLIF(v_phase_map->>trim(v_week->>'phase_key'), '')::UUID;
      IF v_phase_id IS NULL THEN
        RAISE EXCEPTION 'Unknown phase_key %', v_week->>'phase_key' USING ERRCODE = 'foreign_key_violation';
      END IF;
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
        -- Resolve session_key → protocol_id from payload sessions catalogue.
        SELECT s.value->>'protocol_id' INTO v_protocol_id
        FROM jsonb_array_elements(payload->'sessions') AS s(value)
        WHERE trim(s.value->>'session_key') = trim(v_slot->>'session_key')
        LIMIT 1;

        IF v_protocol_id IS NULL OR trim(v_protocol_id) = '' THEN
          RAISE EXCEPTION 'Unknown session_key %', v_slot->>'session_key'
            USING ERRCODE = 'foreign_key_violation';
        END IF;

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

        v_slot_keys := array_append(v_slot_keys, trim(v_slot->>'slot_key'));
      END LOOP;
    END LOOP;
  END LOOP;

  -- Comparison identities first (FK target for assessments/evidence).
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
    IF (v_item->>'athlete_agreement_required')::BOOLEAN IS DISTINCT FROM TRUE THEN
      RAISE EXCEPTION 'athlete_agreement_required must be true' USING ERRCODE = 'check_violation';
    END IF;
    v_target := trim(v_item->>'target_ref');
    IF v_target <> 'programme' AND NOT (v_target = ANY (v_slot_keys)) THEN
      RAISE EXCEPTION 'adaptation target_ref % unresolved', v_target USING ERRCODE = 'foreign_key_violation';
    END IF;
    INSERT INTO public.programme_version_adaptation_permissions (
      version_id, permission_key, change_kind, target_ref, athlete_agreement_required, scope_note
    ) VALUES (
      v_version_id,
      trim(v_item->>'id'),
      trim(v_item->>'change_kind'),
      v_target,
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
    v_assessment_slot := trim(v_item->>'slot_ref');
    IF NOT (v_assessment_slot = ANY (v_slot_keys)) THEN
      RAISE EXCEPTION 'assessment slot_ref % unresolved', v_assessment_slot
        USING ERRCODE = 'foreign_key_violation';
    END IF;
    INSERT INTO public.programme_version_assessments (
      version_id, assessment_key, slot_ref, evidence_requirement, comparison_identity_key, label
    ) VALUES (
      v_version_id,
      trim(v_item->>'id'),
      v_assessment_slot,
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
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'status', 'database_failure',
      'code', SQLSTATE,
      'message', SQLERRM
    );
END;
$$;

REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.import_authored_plan_package(JSONB) TO service_role;

COMMENT ON FUNCTION public.import_authored_plan_package(JSONB) IS
  'Sprint 1.2 service-role-only atomic Plan Package import. Always creates/returns a hidden Cohort Global draft. Never publishes or approves for catalogue.';

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

  -- Ensure every slot protocol is still published.
  IF EXISTS (
    SELECT 1
    FROM public.programme_version_session_slots s
    JOIN public.programme_version_days d ON d.id = s.day_id
    JOIN public.programme_version_weeks w ON w.id = d.week_id
    LEFT JOIN public.performance_protocols p ON p.protocol_id = s.protocol_id
    WHERE w.version_id = p_version_id
      AND (p.protocol_id IS NULL OR p.lifecycle_status <> 'published')
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
  'Service-role-only catalogue approval gate. Requires published. Does not mutate authored content.';

-- Manual verification checklist (local only — do not apply remotely from CI):
-- 1. anon/authenticated EXECUTE import_authored_plan_package → denied
-- 2. service_role import creates draft with approved_for_global=false
-- 3. authenticated SELECT global draft → denied
-- 4. publish leaves approved_for_global false; athlete SELECT still denied
-- 5. approve then athlete SELECT catalogue → allowed
-- 6. UPDATE published package hash → denied by trigger
