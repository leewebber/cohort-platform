-- M9 Sprint 2: additive content-graph persistence core.
-- Does not rewrite programme_lineages, programme_versions, slots, blocks,
-- exercises_v2, or assignments. Hash canonicalisation remains in the app compiler.

CREATE TABLE IF NOT EXISTS public.content_publishers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  namespace     TEXT NOT NULL,
  display_name  TEXT NOT NULL,
  first_party   BOOLEAN NOT NULL DEFAULT FALSE,
  lifecycle     TEXT NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  retired_at    TIMESTAMPTZ,
  CONSTRAINT content_publishers_namespace_unique UNIQUE (namespace),
  CONSTRAINT content_publishers_lifecycle_check
    CHECK (lifecycle IN ('active', 'retired')),
  CONSTRAINT content_publishers_namespace_token
    CHECK (namespace ~ '^[a-z][a-z0-9_]*$'),
  CONSTRAINT content_publishers_retired_at_consistent
    CHECK (
      (lifecycle = 'active' AND retired_at IS NULL)
      OR (lifecycle = 'retired' AND retired_at IS NOT NULL)
    )
);

COMMENT ON TABLE public.content_publishers IS
  'M9 publisher/namespace registry. namespace is identity and is never reused after retirement. display_name is metadata only.';

INSERT INTO public.content_publishers (
  id, namespace, display_name, first_party, lifecycle
) VALUES (
  '00000000-0000-4000-8000-00000000c001',
  'cohort_global',
  'Cohort',
  TRUE,
  'active'
)
ON CONFLICT (namespace) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.content_publisher_principals (
  publisher_id  UUID NOT NULL
                  REFERENCES public.content_publishers (id) ON DELETE CASCADE,
  principal_id  UUID NOT NULL,
  principal_role TEXT NOT NULL DEFAULT 'publisher',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (publisher_id, principal_id),
  CONSTRAINT content_publisher_principals_role_check
    CHECK (principal_role IN ('owner', 'publisher', 'reader'))
);

COMMENT ON TABLE public.content_publisher_principals IS
  'Who may publish or inspect impact inside a publisher namespace. Display names are not keys.';

ALTER TABLE public.programme_versions
  ADD COLUMN IF NOT EXISTS supersedes_version_id UUID
    REFERENCES public.programme_versions (id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_programme_versions_supersedes
  ON public.programme_versions (supersedes_version_id)
  WHERE supersedes_version_id IS NOT NULL;

COMMENT ON COLUMN public.programme_versions.supersedes_version_id IS
  'Optional M9 predecessor version. Does not repin assignments.';

CREATE TABLE IF NOT EXISTS public.content_graph_manifests (
  id                               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  programme_version_id             UUID NOT NULL
                                     REFERENCES public.programme_versions (id)
                                     ON DELETE RESTRICT,
  publisher_id                     UUID
                                     REFERENCES public.content_publishers (id)
                                     ON DELETE RESTRICT,
  compiler_version                 TEXT NOT NULL,
  graph_format_version             INTEGER NOT NULL,
  source_package_hash              TEXT NOT NULL,
  supplemental_relationship_hash   TEXT NOT NULL,
  graph_structural_hash            TEXT NOT NULL,
  composite_identity               TEXT NOT NULL,
  canonical_payload                JSONB NOT NULL,
  publication_state                TEXT NOT NULL,
  unresolved                       JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at                       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_at                     TIMESTAMPTZ,
  created_by                       UUID,
  CONSTRAINT content_graph_manifests_state_check
    CHECK (publication_state IN ('draft', 'published')),
  CONSTRAINT content_graph_manifests_format_positive
    CHECK (graph_format_version > 0),
  CONSTRAINT content_graph_manifests_sha_source
    CHECK (source_package_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT content_graph_manifests_sha_supplemental
    CHECK (supplemental_relationship_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT content_graph_manifests_sha_graph
    CHECK (graph_structural_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT content_graph_manifests_sha_composite
    CHECK (composite_identity ~ '^[0-9a-f]{64}$'),
  CONSTRAINT content_graph_manifests_unresolved_array
    CHECK (jsonb_typeof(unresolved) = 'array'),
  CONSTRAINT content_graph_manifests_published_at_consistent
    CHECK (
      (publication_state = 'draft' AND published_at IS NULL)
      OR (publication_state = 'published' AND published_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS content_graph_manifests_composite_identity_uidx
  ON public.content_graph_manifests (composite_identity);

CREATE UNIQUE INDEX IF NOT EXISTS content_graph_manifests_one_published_per_version_format
  ON public.content_graph_manifests (
    programme_version_id, graph_format_version, compiler_version
  )
  WHERE publication_state = 'published';

CREATE INDEX IF NOT EXISTS idx_content_graph_manifests_version
  ON public.content_graph_manifests (programme_version_id, publication_state);

CREATE INDEX IF NOT EXISTS idx_content_graph_manifests_publisher
  ON public.content_graph_manifests (publisher_id)
  WHERE publisher_id IS NOT NULL;

COMMENT ON TABLE public.content_graph_manifests IS
  'Derived content-graph manifest v1. Not an authoring source. Row UUID and timestamps are operational and excluded from structural identity.';

CREATE OR REPLACE FUNCTION public.content_graph_prevent_published_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.publication_state = 'published' THEN
      RAISE EXCEPTION 'content_graph_published_immutable'
        USING ERRCODE = 'P0001';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.publication_state = 'published' THEN
    RAISE EXCEPTION 'content_graph_published_immutable'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_content_graph_manifests_immutable
  ON public.content_graph_manifests;
CREATE TRIGGER trg_content_graph_manifests_immutable
  BEFORE UPDATE OR DELETE ON public.content_graph_manifests
  FOR EACH ROW
  EXECUTE FUNCTION public.content_graph_prevent_published_mutation();

CREATE OR REPLACE FUNCTION public.content_graph_prevent_assignment_repin()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.programme_version_id IS DISTINCT FROM OLD.programme_version_id THEN
    RAISE EXCEPTION 'content_graph_assignment_pin_immutable'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_content_graph_assignment_pin_immutable
  ON public.programme_assignments;
CREATE TRIGGER trg_content_graph_assignment_pin_immutable
  BEFORE UPDATE ON public.programme_assignments
  FOR EACH ROW
  EXECUTE FUNCTION public.content_graph_prevent_assignment_repin();

COMMENT ON FUNCTION public.content_graph_prevent_assignment_repin() IS
  'M9: programme_assignments.programme_version_id is enrolment-time pin. No in-place repin in Sprint 2.';
