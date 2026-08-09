#!/usr/bin/env python3
"""Test-only Athlete E bootstrap planning and fail-closed guards.

This module never contacts hosted Staging by itself. Hosted create remains a
separately authorised shell path and must not run in prerequisite resolution.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

STAGING_NAME = "Cohort Staging"
STAGING_REF = "tsbadngzgvsyfqjupkng"
STAGING_REGION = "eu-west-2"
PRODUCTION_NAME = "Cohort Field Manual"
PRODUCTION_REF_PREFIX = "otnhhdxs"

RUN_MARKER_RE = re.compile(r"^s17e_stage_\d{8}T\d{6}Z_[0-9a-f]{8}$")
EMAIL_RE = re.compile(
    r"^s17e_stage_\d{8}T\d{6}Z_[0-9a-f]{8}\.athlete\.e@example\.invalid$"
)

PROTECTED_NAMESPACE_TOKENS = (
    "Athlete A",
    "Athlete B",
    "Athlete C",
    "Athlete D",
    "athlete.a@",
    "athlete.b@",
    "athlete.c@",
    "athlete.d@",
    "S13 Staging Athlete A",
    "S13 Staging Athlete B",
    "S15A Staging Athlete C",
    "S17 Staging Athlete D",
    "f55719cd-9721-48af-895c-c5547f8d0ec2",
    "1e268186-281a-464a-b2a4-da2d2cde33ba",
)

FORBIDDEN_COMMAND_TOKENS = (
    "db push",
    "migration up",
    "migration repair",
    "supabase db push",
    "DROP DATABASE",
    "DELETE FROM",
    "cleanup",
    "--delete",
    "--cleanup",
)


class AthleteEBootstrapError(Exception):
    """Fail-closed Athlete E bootstrap error."""


@dataclass(frozen=True)
class AthleteEPlan:
    run_marker: str
    display_name: str
    email_pattern: str
    project_ref: str
    dry_run: bool
    proposed_records: tuple[str, ...]
    notes: tuple[str, ...]


def redact_email(email: str) -> str:
    email = (email or "").strip()
    if "@" not in email:
        return "***"
    local, _, domain = email.partition("@")
    return f"{local[:8]}…@{domain}"


def redact_secret(value: str) -> str:
    if not value:
        return ""
    return "***REDACTED***"


def redact_uuid(value: str) -> str:
    value = (value or "").strip()
    if len(value) < 8:
        return "***"
    return f"{value[:8]}…"


def require_exact_staging_ref(project_ref: str) -> str:
    ref = (project_ref or "").strip()
    if ref != STAGING_REF:
        if ref.startswith(PRODUCTION_REF_PREFIX) or ref == "":
            raise AthleteEBootstrapError(
                "REFUSED: Cohort Field Manual / production ref rejected"
            )
        raise AthleteEBootstrapError(
            f"REFUSED: project ref must be exactly {STAGING_REF}"
        )
    return ref


def reject_production_project(name: str | None, ref: str | None) -> None:
    name = name or ""
    ref = ref or ""
    if name == PRODUCTION_NAME or ref.startswith(PRODUCTION_REF_PREFIX):
        raise AthleteEBootstrapError("REFUSED: Cohort Field Manual rejected")


def reject_unknown_project(name: str | None, ref: str | None) -> None:
    name = name or ""
    ref = (ref or "").strip()
    if name != STAGING_NAME or ref != STAGING_REF:
        raise AthleteEBootstrapError("REFUSED: unknown project rejected")


def validate_run_marker(marker: str) -> str:
    if not RUN_MARKER_RE.match(marker or ""):
        raise AthleteEBootstrapError("REFUSED: invalid Athlete E run marker")
    return marker


def validate_athlete_e_email(email: str, run_marker: str) -> str:
    if not EMAIL_RE.match(email or ""):
        raise AthleteEBootstrapError(
            "REFUSED: Athlete E email must be non-personal @example.invalid"
        )
    if not email.startswith(run_marker):
        raise AthleteEBootstrapError(
            "REFUSED: Athlete E email must embed run marker"
        )
    return email


def reject_protected_namespaces(*texts: str) -> None:
    blob = "\n".join(texts)
    for token in PROTECTED_NAMESPACE_TOKENS:
        if token in blob:
            raise AthleteEBootstrapError(
                f"REFUSED: protected athlete namespace token present: {token}"
            )


def reject_identifier_collision(
    proposed_email: str, existing_emails: list[str] | None = None
) -> None:
    existing = set(existing_emails or [])
    if proposed_email in existing:
        raise AthleteEBootstrapError("REFUSED: identifier collision with existing email")


def reject_migration_or_cleanup_intent(command_text: str) -> None:
    lowered = (command_text or "").lower()
    for token in FORBIDDEN_COMMAND_TOKENS:
        if token.lower() in lowered:
            raise AthleteEBootstrapError(
                f"REFUSED: forbidden command/intent: {token}"
            )


def require_auth_admin_capability(service_role_present: bool) -> None:
    if not service_role_present:
        raise AthleteEBootstrapError(
            "REFUSED: authentication administration capability unavailable"
        )


def build_plan(
    *,
    run_marker: str,
    project_ref: str,
    project_name: str = STAGING_NAME,
    dry_run: bool = True,
    existing_emails: list[str] | None = None,
) -> AthleteEPlan:
    reject_production_project(project_name, project_ref)
    reject_unknown_project(project_name, project_ref)
    require_exact_staging_ref(project_ref)
    marker = validate_run_marker(run_marker)
    email = f"{marker}.athlete.e@example.invalid"
    validate_athlete_e_email(email, marker)
    reject_protected_namespaces(marker, email, "S17E Staging Athlete E")
    reject_identifier_collision(email, existing_emails)
    return AthleteEPlan(
        run_marker=marker,
        display_name="S17E Staging Athlete E",
        email_pattern=email,
        project_ref=project_ref,
        dry_run=dry_run,
        proposed_records=(
            "auth_user",
            "athlete_profile",
            # Enrolment/materialisation remain future T1–T12 workflow steps,
            # not automatic bootstrap side-effects beyond sign-in readiness.
        ),
        notes=(
            "Test-only Athlete E bootstrap; not general onboarding.",
            "Dry-run performs no hosted work.",
            "Hosted create requires separate founder authorisation.",
            "Must not reuse Athlete A/B/C/D identifiers.",
            "Must not run supabase db push or migration repair.",
            "No cleanup/delete mode.",
        ),
    )


def redacted_manifest(plan: AthleteEPlan) -> dict[str, Any]:
    return {
        "status": "dry_run_ok" if plan.dry_run else "planned_hosted_not_executed",
        "run_marker": plan.run_marker,
        "display_name": plan.display_name,
        "email_redacted": redact_email(plan.email_pattern),
        "project_ref": plan.project_ref,
        "dry_run": plan.dry_run,
        "hosted_write": False,
        "athlete_created": False,
        "proposed_records": list(plan.proposed_records),
        "notes": list(plan.notes),
        "secrets": redact_secret("never-emit"),
    }


def dry_run_performs_no_work(plan: AthleteEPlan) -> bool:
    return plan.dry_run is True
