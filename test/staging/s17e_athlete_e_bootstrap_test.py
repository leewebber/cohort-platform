#!/usr/bin/env python3
"""Non-hosted unit tests for Athlete E bootstrap guards."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "tool" / "staging" / "lib" / "s17e_athlete_e_bootstrap.py"

spec = importlib.util.spec_from_file_location("s17e_athlete_e_bootstrap", LIB)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


class AthleteEBootstrapTests(unittest.TestCase):
    MARKER = "s17e_stage_20260809T120000Z_abcd1234"

    def test_accepts_exact_staging_ref(self):
        plan = mod.build_plan(
            run_marker=self.MARKER,
            project_ref="tsbadngzgvsyfqjupkng",
            dry_run=True,
        )
        self.assertEqual(plan.project_ref, "tsbadngzgvsyfqjupkng")
        self.assertTrue(plan.dry_run)

    def test_rejects_field_manual(self):
        with self.assertRaises(mod.AthleteEBootstrapError) as ctx:
            mod.build_plan(
                run_marker=self.MARKER,
                project_ref="otnhhdxstdnwccehacku",
                project_name="Cohort Field Manual",
            )
        self.assertIn("Field Manual", str(ctx.exception))

    def test_rejects_unknown_project(self):
        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.build_plan(
                run_marker=self.MARKER,
                project_ref="aaaaaaaaaaaaaaaaaaaa",
                project_name="Other Project",
            )

    def test_rejects_protected_namespaces(self):
        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.reject_protected_namespaces("S17 Staging Athlete D")

    def test_rejects_identifier_collision(self):
        email = f"{self.MARKER}.athlete.e@example.invalid"
        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.reject_identifier_collision(email, [email])

    def test_redacts_secrets_in_manifest(self):
        plan = mod.build_plan(
            run_marker=self.MARKER,
            project_ref="tsbadngzgvsyfqjupkng",
            dry_run=True,
        )
        manifest = mod.redacted_manifest(plan)
        self.assertEqual(manifest["secrets"], "***REDACTED***")
        self.assertNotIn("password", manifest)
        self.assertNotIn("token", manifest)
        self.assertTrue(manifest["email_redacted"].endswith("@example.invalid"))
        self.assertIn("…", manifest["email_redacted"])

    def test_dry_run_performs_no_work(self):
        plan = mod.build_plan(
            run_marker=self.MARKER,
            project_ref="tsbadngzgvsyfqjupkng",
            dry_run=True,
        )
        self.assertTrue(mod.dry_run_performs_no_work(plan))
        manifest = mod.redacted_manifest(plan)
        self.assertFalse(manifest["hosted_write"])
        self.assertFalse(manifest["athlete_created"])
        self.assertEqual(manifest["status"], "dry_run_ok")

    def test_emits_expected_proposed_record_manifest(self):
        plan = mod.build_plan(
            run_marker=self.MARKER,
            project_ref="tsbadngzgvsyfqjupkng",
            dry_run=True,
        )
        self.assertEqual(plan.proposed_records, ("auth_user", "athlete_profile"))

    def test_cannot_run_migration_commands(self):
        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.reject_migration_or_cleanup_intent("supabase db push --linked")
        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.reject_migration_or_cleanup_intent("migration repair")

    def test_cannot_delete_or_clean(self):
        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.reject_migration_or_cleanup_intent("./create_s17_athlete_e_fixture.sh --cleanup")

    def test_fails_closed_without_auth_admin(self):
        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.require_auth_admin_capability(False)


if __name__ == "__main__":
    unittest.main()
