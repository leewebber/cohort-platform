-- Read only the exact trial permission through the ordinary athlete API.
-- No table grants, new writes, or access to other authored versions.
CREATE FUNCTION public.read_m31_thursday_trial_permission(
  p_assignment_id uuid,
  p_version_id uuid,
  p_slot_key text
) RETURNS TABLE (
  permission_key text,
  change_kind text,
  target_ref text,
  athlete_agreement_required boolean
)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
  SELECT p.permission_key, p.change_kind, p.target_ref, p.athlete_agreement_required
  FROM public.programme_version_adaptation_permissions AS p
  WHERE p_version_id = '5d095027-a4fb-4529-9ade-7a96a75e743f'::uuid
    AND p_slot_key = 'LW10K-W01-D04'
    AND p.version_id = p_version_id
    AND p.permission_key = 'm31-w01-d04-rdl'
    AND p.target_ref = p_slot_key
    AND p.change_kind = 'substitute_approved_equipment'
    AND p.athlete_agreement_required
    AND EXISTS (
      SELECT 1
      FROM public.programme_assignments AS a
      JOIN public.programme_versions AS v
        ON v.id = a.programme_version_id
      JOIN public.programme_publication_artifacts AS seal
        ON seal.programme_version_id = v.id
        AND seal.package_schema_version = 2
        AND seal.package_content_hash = v.package_content_hash
      JOIN public.programme_schedule_occurrences AS o
        ON o.assignment_id = a.id AND o.programme_version_id = a.programme_version_id
      JOIN public.programme_version_session_slots AS slot
        ON slot.id = o.session_slot_id
        AND slot.package_slot_key = p_slot_key
        AND slot.protocol_id = o.protocol_id
      WHERE a.id = p_assignment_id
        AND a.athlete_id = (SELECT auth.uid())
        AND a.programme_version_id = p.version_id
        AND a.status = 'active' AND a.ended_at IS NULL
        AND a.schedule_mode = 'fixed_schedule' AND a.materialised_at IS NOT NULL
        AND v.lifecycle_status = 'published' AND v.library_scope = 'coach_private'
        AND v.package_content_hash = o.package_content_hash
        AND a.materialised_package_content_hash = o.package_content_hash
        AND o.week_number = 1 AND o.day_key = 'day_4' AND o.session_order = 1
        AND o.protocol_id = 'protocol-514e5f5a-c825-49cd-911a-a2bdf4f6c6d3'
        AND o.package_content_hash = 'f6fdc8bbe341f56d1dc819a3878a7df2ede766bc4b3b295e40efd8709f50352b'
    );
$$;

REVOKE ALL ON FUNCTION public.read_m31_thursday_trial_permission(uuid, uuid, text)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.read_m31_thursday_trial_permission(uuid, uuid, text)
  TO authenticated;

-- The retained v2 publisher compares permission rows against the canonical
-- package, but its private writer does not insert them. Seed only this exact
-- approved row while the draft is still mutable, before the existing seal.
CREATE FUNCTION public.cohort_m31_seed_thursday_trial_permission()
  RETURNS trigger
  LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
  IF OLD.package_schema_version IS DISTINCT FROM 2
     OR OLD.library_scope IS DISTINCT FROM 'coach_private'
     OR OLD.package_content_hash IS DISTINCT FROM
        'f6fdc8bbe341f56d1dc819a3878a7df2ede766bc4b3b295e40efd8709f50352b' THEN
    RAISE EXCEPTION 'Unexpected M3.1 trial package pin';
  END IF;

  INSERT INTO public.programme_version_adaptation_permissions (
    version_id, permission_key, change_kind, target_ref,
    athlete_agreement_required, scope_note
  ) VALUES (
    OLD.id, 'm31-w01-d04-rdl', 'substitute_approved_equipment', 'LW10K-W01-D04',
    TRUE, 'EX-078 to EX-040 at W01-B-barbell_rdl only, with no barbell and two matching dumbbells.'
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_m31_seed_thursday_trial_permission()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER programme_versions_m31_seed_thursday_trial_permission
  BEFORE UPDATE OF lifecycle_status ON public.programme_versions
  FOR EACH ROW
  WHEN (OLD.id = '5d095027-a4fb-4529-9ade-7a96a75e743f'::uuid
        AND OLD.lifecycle_status = 'draft' AND NEW.lifecycle_status = 'published')
  EXECUTE FUNCTION public.cohort_m31_seed_thursday_trial_permission();

-- The older private-v2 publisher can reach the draft hook too. Require
-- the retained publisher's artifact before this transition can commit.
CREATE FUNCTION public.cohort_m31_require_thursday_trial_seal()
  RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.programme_publication_artifacts AS seal
    WHERE seal.programme_version_id = NEW.id
      AND seal.package_schema_version = 2
      AND seal.package_content_hash = NEW.package_content_hash
  ) THEN
    RAISE EXCEPTION 'M3.1 trial requires retained publication seal'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_m31_require_thursday_trial_seal()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE CONSTRAINT TRIGGER programme_versions_m31_require_thursday_trial_seal
  AFTER UPDATE OF lifecycle_status ON public.programme_versions
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  WHEN (OLD.id = '5d095027-a4fb-4529-9ade-7a96a75e743f'::uuid
        AND OLD.lifecycle_status = 'draft' AND NEW.lifecycle_status = 'published')
  EXECUTE FUNCTION public.cohort_m31_require_thursday_trial_seal();
