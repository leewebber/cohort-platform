#!/usr/bin/env python3
"""Local-only tests for reusable Gate 1 harness target guards."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "tool" / "staging" / "run_s17e_gate1_backend_rpc.py"

spec = importlib.util.spec_from_file_location("s17e_gate1_harness", HARNESS)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


class Gate1HarnessGuardTests(unittest.TestCase):
    MARKER = "s17e_stage_20260809T120000Z_abcd1234"

    def setUp(self):
        self.payload = {
            "programme": {
                "lineage_code": "PROG-S17E-GATE1",
                "version_number": 2,
            }
        }
        self.creds = {
            "run_marker": self.MARKER,
            "email": f"{self.MARKER}.athlete.e@example.invalid",
            "user_id": "11111111-1111-4111-8111-111111111111",
            "display_name": "S17E Staging Athlete E",
        }

    def assert_rejected_before_transport(self, *, payload=None, creds=None):
        calls = []

        def transport(name, params):
            calls.append((name, params))
            return 200, {}

        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.invoke_authorised_service_rpc(
                "import_authored_plan_package",
                {"payload": payload if payload is not None else self.payload},
                payload=payload if payload is not None else self.payload,
                creds=creds if creds is not None else self.creds,
                transport=transport,
            )
        self.assertEqual(calls, [], "guard must reject before privileged transport")

    def test_accepts_exact_package_and_athlete_e_identity(self):
        calls = []

        def transport(name, params):
            calls.append((name, params))
            return 200, {"status": "ok"}

        result = mod.invoke_authorised_service_rpc(
            "import_authored_plan_package",
            {"payload": self.payload},
            payload=self.payload,
            creds=self.creds,
            transport=transport,
        )
        self.assertEqual(result, (200, {"status": "ok"}))
        self.assertEqual(len(calls), 1)

    def test_rejects_other_lineage_before_transport(self):
        payload = {"programme": {**self.payload["programme"], "lineage_code": "PROG-X"}}
        self.assert_rejected_before_transport(payload=payload)

    def test_rejects_version_one_before_transport(self):
        payload = {"programme": {**self.payload["programme"], "version_number": 1}}
        self.assert_rejected_before_transport(payload=payload)

    def test_rejects_version_three_before_transport(self):
        payload = {"programme": {**self.payload["programme"], "version_number": 3}}
        self.assert_rejected_before_transport(payload=payload)

    def test_rejects_missing_lineage_before_transport(self):
        payload = {"programme": {"version_number": 2}}
        self.assert_rejected_before_transport(payload=payload)

    def test_rejects_missing_version_before_transport(self):
        payload = {"programme": {"lineage_code": "PROG-S17E-GATE1"}}
        self.assert_rejected_before_transport(payload=payload)

    def test_rejects_malformed_identity_values_before_transport(self):
        for lineage, version in (
            (["PROG-S17E-GATE1"], 2),
            (" PROG-S17E-GATE1", 2),
            ("PROG-S17E-GATE1", "2"),
            ("PROG-S17E-GATE1", True),
        ):
            with self.subTest(lineage=lineage, version=version):
                self.assert_rejected_before_transport(
                    payload={
                        "programme": {
                            "lineage_code": lineage,
                            "version_number": version,
                        }
                    }
                )

    def test_rejects_missing_marker_before_transport(self):
        creds = dict(self.creds)
        creds.pop("run_marker")
        self.assert_rejected_before_transport(creds=creds)

    def test_rejects_malformed_and_near_miss_markers_before_transport(self):
        for marker in (
            "s17_stage_20260809T120000Z_abcd1234",
            "s17e_stage_20260809T120000_abcd1234",
            "s17e_stage_20260809T120000Z_abcd123",
            "s17e_stage_20260809T120000Z_ABCD1234",
            "s17e_stage_20260809T120000Z_abcd1234_extra",
        ):
            with self.subTest(marker=marker):
                creds = {
                    **self.creds,
                    "run_marker": marker,
                    "email": f"{marker}.athlete.e@example.invalid",
                }
                self.assert_rejected_before_transport(creds=creds)

    def test_rejects_marker_email_mismatch_before_transport(self):
        creds = {
            **self.creds,
            "email": "s17e_stage_20260809T120001Z_abcd1234.athlete.e@example.invalid",
        }
        self.assert_rejected_before_transport(creds=creds)

    def test_rejects_non_e_display_identity_before_transport(self):
        creds = {**self.creds, "display_name": "Other fixture"}
        self.assert_rejected_before_transport(creds=creds)

    def test_rejects_invalid_or_zero_user_identity_before_transport(self):
        for user_id in (
            None,
            "not-a-uuid",
            "00000000-0000-0000-0000-000000000000",
        ):
            with self.subTest(user_id=user_id):
                self.assert_rejected_before_transport(
                    creds={**self.creds, "user_id": user_id}
                )

    def test_rejects_service_role_operation_outside_allow_list(self):
        calls = []

        def transport(name, params):
            calls.append((name, params))
            return 200, {}

        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.invoke_authorised_service_rpc(
                "delete_everything",
                {},
                payload=self.payload,
                creds=self.creds,
                transport=transport,
            )
        self.assertEqual(calls, [])

    def test_rejects_mismatched_import_params_before_transport(self):
        calls = []

        def transport(name, params):
            calls.append((name, params))
            return 200, {}

        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.invoke_authorised_service_rpc(
                "import_authored_plan_package",
                {
                    "payload": {
                        "programme": {
                            "lineage_code": "PROG-OTHER",
                            "version_number": 2,
                        }
                    }
                },
                payload=self.payload,
                creds=self.creds,
                transport=transport,
            )
        self.assertEqual(calls, [])

    def test_rejects_unbound_publish_version_before_transport(self):
        calls = []

        def transport(name, params):
            calls.append((name, params))
            return 200, {}

        with self.assertRaises(mod.AthleteEBootstrapError):
            mod.invoke_authorised_service_rpc(
                "publish_cohort_global_programme_version",
                {"p_version_id": "22222222-2222-4222-8222-222222222222"},
                payload=self.payload,
                creds=self.creds,
                transport=transport,
                expected_version_id="11111111-1111-4111-8111-111111111111",
            )
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
