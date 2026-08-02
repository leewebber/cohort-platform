-- Sprint 1.4A corrective: harden materialisation write guard.
--
-- The Sprint 1.4A trigger allowed bypass when GUC
-- cohort.allow_materialisation_write=on. Authenticated callers can set
-- transaction-local GUCs, so that alone is insufficient.
--
-- Require the GUC AND a privileged database role (the SECURITY DEFINER RPC
-- owner runs the UPDATE as postgres). Ordinary authenticated athletes cannot
-- combine set_config + UPDATE to mutate materialisation-controlled columns.

CREATE OR REPLACE FUNCTION public.cohort_programme_assignment_protect_materialisation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  -- Authorised path: Sprint 1.4A SECURITY DEFINER RPC (owner = postgres) sets
  -- the transaction-local GUC before UPDATE. Authenticated athletes may set the
  -- GUC but current_user remains 'authenticated', so they cannot bypass.
  IF COALESCE(current_setting('cohort.allow_materialisation_write', true), '') = 'on'
     AND current_user IN ('postgres', 'supabase_admin')
  THEN
    RETURN NEW;
  END IF;

  IF NEW.materialised_at IS DISTINCT FROM OLD.materialised_at
     OR NEW.materialisation_source IS DISTINCT FROM OLD.materialisation_source
     OR NEW.materialised_package_content_hash IS DISTINCT FROM OLD.materialised_package_content_hash
     OR NEW.materialised_package_schema_version IS DISTINCT FROM OLD.materialised_package_schema_version
     OR NEW.programme_version_id IS DISTINCT FROM OLD.programme_version_id
     OR NEW.lineage_code IS DISTINCT FROM OLD.lineage_code
     OR (
       OLD.materialised_at IS NOT NULL
       AND NEW.started_at IS DISTINCT FROM OLD.started_at
     )
     OR (
       NEW.materialised_at IS NOT NULL
       AND OLD.materialised_at IS NULL
     )
  THEN
    RAISE EXCEPTION 'programme_assignments materialisation-controlled columns are RPC-only'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.cohort_programme_assignment_protect_materialisation() IS
  'Blocks direct authenticated updates to materialisation-controlled columns. Bypass requires cohort.allow_materialisation_write=on AND current_user in (postgres, supabase_admin), which the SECURITY DEFINER materialisation RPC satisfies.';
