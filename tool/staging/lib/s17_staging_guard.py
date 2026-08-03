#!/usr/bin/env python3
"""Fail-closed Cohort Staging guards for Sprint 1.7 Athlete D harness.

Local-only unit-testable helpers. Hosted contact is performed by callers
when explicitly authorised (B4b), never by this module alone.
"""

from __future__ import annotations

import json
import os
import re
import stat
from pathlib import Path
from typing import Any

STAGING_NAME = "Cohort Staging"
STAGING_REF_PREFIX = "tsbadngz"
STAGING_REGION = "eu-west-2"
STAGING_STATUS_TOKEN = "ACTIVE"
PRODUCTION_REF_PREFIX = "otnhhdxs"
PRODUCTION_NAME = "Cohort Field Manual"
STAGING_HOST_MARKER = "tsbadngzgvsyfqjupkng"
RUN_MARKER_RE = re.compile(
    r"^s17_stage_\d{8}T\d{6}Z_[0-9a-f]{8}$"
)
EMAIL_RE = re.compile(
    r"^s17_stage_\d{8}T\d{6}Z_[0-9a-f]{8}\.athlete\.d@example\.invalid$"
)


class StagingGuardError(Exception):
    """Fail-closed staging identity or path error."""


def redact_ref(ref: str) -> str:
    ref = (ref or "").strip()
    if len(ref) < 12:
        return (ref[:4] + "…") if ref else ""
    return f"{ref[:8]}…"


def redact_email(email: str) -> str:
    email = (email or "").strip()
    if "@" not in email:
        return "***"
    local, _, domain = email.partition("@")
    return f"{local[:8]}…@{domain}"


def redact_uuid(value: str) -> str:
    value = (value or "").strip()
    if len(value) < 8:
        return "***"
    return f"{value[:8]}…"


def is_production_ref(ref: str) -> bool:
    return (ref or "").startswith(PRODUCTION_REF_PREFIX)


def is_staging_ref(ref: str) -> bool:
    return (ref or "").startswith(STAGING_REF_PREFIX)


def classify_project(project: dict[str, Any]) -> str:
    ref = project.get("ref") or project.get("id") or ""
    name = project.get("name") or ""
    if name == STAGING_NAME and is_staging_ref(ref):
        return "staging"
    if is_production_ref(ref) or name == PRODUCTION_NAME:
        return "production"
    return "other"


def select_staging_project(projects: list[dict[str, Any]]) -> dict[str, Any]:
    staging = [p for p in projects if classify_project(p) == "staging"]
    production = [p for p in projects if classify_project(p) == "production"]
    if len(staging) != 1:
        raise StagingGuardError(
            f"REFUSED: expected exactly one Cohort Staging project, found {len(staging)}"
        )
    selected = staging[0]
    ref = selected.get("ref") or selected.get("id") or ""
    status = selected.get("status") or ""
    region = selected.get("region")
    if selected.get("name") != STAGING_NAME:
        raise StagingGuardError("REFUSED: staging name mismatch")
    if not is_staging_ref(ref):
        raise StagingGuardError("REFUSED: staging ref prefix mismatch")
    if is_production_ref(ref):
        raise StagingGuardError("REFUSED: production ref selected")
    if region != STAGING_REGION:
        raise StagingGuardError(f"REFUSED: unexpected staging region {region!r}")
    if STAGING_STATUS_TOKEN not in status.upper():
        raise StagingGuardError(f"REFUSED: staging status {status!r}")
    if not production:
        raise StagingGuardError("REFUSED: production candidate missing for exclusion proof")
    return {
        "name": selected.get("name"),
        "ref": ref,
        "ref_prefix": redact_ref(ref),
        "region": region,
        "status": status,
        "production_linked": bool(production[0].get("linked")),
        "production_ref_prefix": redact_ref(
            production[0].get("ref") or production[0].get("id") or ""
        ),
    }


def reject_production_url(url: str) -> None:
    url = (url or "").strip().lower()
    if not url:
        raise StagingGuardError("REFUSED: missing staging URL")
    if PRODUCTION_REF_PREFIX in url:
        raise StagingGuardError("REFUSED: production URL/ref detected")
    if STAGING_HOST_MARKER not in url:
        raise StagingGuardError("REFUSED: URL is not Cohort Staging host marker")


def reject_service_role_material(*values: str) -> None:
    for value in values:
        lowered = (value or "").lower()
        if "service_role" in lowered:
            raise StagingGuardError("REFUSED: service_role material must not reach Flutter")


def assert_private_dir(path: Path) -> None:
    if not path.is_dir():
        raise StagingGuardError(f"REFUSED: missing private directory {path}")
    mode = path.stat().st_mode & 0o777
    if mode != 0o700:
        raise StagingGuardError(f"REFUSED: private directory mode must be 700, got {oct(mode)}")


def assert_private_file(path: Path) -> None:
    if not path.is_file():
        raise StagingGuardError(f"REFUSED: missing private file {path}")
    mode = path.stat().st_mode & 0o777
    if mode != 0o600:
        raise StagingGuardError(f"REFUSED: private file mode must be 600, got {oct(mode)}")


def assert_outside_git_worktrees(path: Path, worktree_roots: list[Path]) -> None:
    resolved = path.resolve()
    for root in worktree_roots:
        try:
            resolved.relative_to(root.resolve())
        except ValueError:
            continue
        raise StagingGuardError(
            f"REFUSED: credential/config path must not live inside Git worktree {root}"
        )


def validate_run_marker(marker: str) -> None:
    if not RUN_MARKER_RE.match(marker or ""):
        raise StagingGuardError("REFUSED: invalid Athlete D run marker")


def validate_athlete_d_email(email: str, run_marker: str) -> None:
    if not EMAIL_RE.match(email or ""):
        raise StagingGuardError("REFUSED: Athlete D email must be non-personal @example.invalid")
    if not email.startswith(run_marker):
        raise StagingGuardError("REFUSED: Athlete D email must embed run marker")


def contains_forbidden_athlete_lookup(source: str) -> bool:
    """True if source text appears to enumerate/reuse Athlete A/B/C fixtures."""
    patterns = [
        r"Athlete C",
        r"athlete_c",
        r"athleteC",
        r"S15A Staging Athlete C",
        r"Athlete A",
        r"Athlete B",
        r"S13 Staging Athlete A",
        r"S13 Staging Athlete B",
        r"f55719cd-9721-48af-895c-c5547f8d0ec2",  # documented Athlete A id
        r"1e268186-281a-464a-b2a4-da2d2cde33ba",  # documented Athlete B id
    ]
    return any(re.search(p, source) for p in patterns)


def parse_projects_json(raw: str) -> list[dict[str, Any]]:
    text = raw.strip()
    idx = text.find("[")
    if idx < 0:
        idx = text.find("{")
    data = json.loads(text[idx:])
    if isinstance(data, dict) and "projects" in data:
        data = data["projects"]
    if not isinstance(data, list):
        raise StagingGuardError("REFUSED: unexpected projects payload")
    return data


def journey_codes() -> list[str]:
    return list("ABCDEFGHIJK")


def journey_result_values() -> list[str]:
    return ["PASS", "FAIL", "BLOCKED", "NOT RUN"]


def ensure_confirmation() -> None:
    if os.environ.get("CONFIRM_COHORT_STAGING") != "1":
        raise StagingGuardError(
            "REFUSED: set CONFIRM_COHORT_STAGING=1 after positively confirming Cohort Staging."
        )
