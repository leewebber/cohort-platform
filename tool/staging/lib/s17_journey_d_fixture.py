#!/usr/bin/env python3
"""Journey D adaptation fixture creator (B4d.20) — local dry-run + guarded live plan.

Default mode is zero-write dry-run. Live mutation requires CONFIRM_COHORT_STAGING=1
and S17_JD_LIVE_CREATE=1. This module never contacts hosted environments by itself;
callers supply project lists (fixture or authorised CLI).
"""

from __future__ import annotations

import json
import os
import re
import secrets
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from s17_staging_guard import (
    StagingGuardError,
    ensure_confirmation,
    parse_projects_json,
    redact_email,
    redact_ref,
    select_staging_project,
)

JD_MARKER_RE = re.compile(r"^s17_jd_adapt_\d{8}T\d{6}Z_[0-9a-f]{8}$")
JD_EMAIL_RE = re.compile(
    r"^s17_jd_adapt_\d{8}T\d{6}Z_[0-9a-f]{8}\.athlete\.jd@example\.invalid$"
)

LINEAGE_CODE = "PROG-S17-JD-ADAPT"
PACKAGE_REL = "tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml"
PROTOCOL_INTENT_REL = "tool/staging/fixtures/journey_d/protocol_intent.json"

RESERVED_LINEAGES = {
    "PROG-S15A-STAGING",
    "PROG-S13-ELIG",
    "PROG-S13-INELIG",
}
RESERVED_MARKERS_PREFIXES = ("s17_stage_",)  # Athlete D markers
RESERVED_SUBSTRINGS = (
    "Athlete C",
    "Athlete D",
    "athlete.c@",
    "athlete.d@",
    "S15A Staging Athlete C",
    "PROG-S15A-STAGING",
    "PROG-S13-ELIG",
    "e9bd7e19-6eb9-4f7e-abf6-d08ac4368748",
)

AVAILABLE_EQUIPMENT = [
    "cohort.equipment.kettlebell",
    "cohort.equipment.bodyweight",
    "cohort.equipment.dumbbell",
]
SOURCE_EXERCISE = "cohort.exercise.back_squat"
REPLACEMENT_EXERCISE = "cohort.exercise.goblet_squat"
SUBSTITUTION_RULE = "cohort.substitution.back_squat_to_goblet_squat"

STAGE_ORDER = [
    "validate_environment",
    "validate_inputs_and_marker",
    "compile_validate_package_local",
    "resolve_substitution_local",
    "emit_intended_write_manifest",
    "check_marker_uniqueness_readonly",
    "create_synthetic_athlete",
    "publish_fixture_protocol_current",
    "publish_fixture_protocol_later",
    "rebind_validate_package_for_import",
    "import_programme_version_and_permissions",
    "publish_approve_staging_fixture_version",
    "enrol_assignment",
    "materialise_schedule",
    "stop_prepare_ready",
    "post_create_readonly_eligibility",
    "stop_without_journey_d",
]

# Canonical interfaces for each future mutation/local stage.
# Protocol content is NOT created by import_authored_plan_package - that RPC
# resolves already-published session revisions. Improvised SQL is forbidden.
# B4d.21b: executable rebind path lives in lib/staging_tooling/journey_d/.
STAGE_INTERFACES = {
    "validate_environment": "s17_staging_guard.select_staging_project",
    "validate_inputs_and_marker": "s17_journey_d_fixture.validate_marker",
    "compile_validate_package_local": "PlanPackageCompiler.compile (local Dart)",
    "resolve_substitution_local": "KnowledgeGraphReader + SessionAdaptationPlanner",
    "emit_intended_write_manifest": "s17_journey_d_fixture.build_manifest",
    "check_marker_uniqueness_readonly": "read-only staging probe (live only)",
    "create_synthetic_athlete": "Supabase Auth Admin API createUser + athlete profile",
    "publish_fixture_protocol_current": (
        "ProtocolBuilderJourneyDPublisher → "
        "ProtocolBuilderService.publishDraft "
        "(PROT-S17-JD-ADAPT-CURRENT)"
    ),
    "publish_fixture_protocol_later": (
        "ProtocolBuilderJourneyDPublisher → "
        "ProtocolBuilderService.publishDraft "
        "(PROT-S17-JD-ADAPT-LATER)"
    ),
    "rebind_validate_package_for_import": (
        "JourneyDRebindPipeline typed session_lineage_id rebind + "
        "PlanPackageValidator + PlanPackageCanonicaliser + SHA-256"
    ),
    "import_programme_version_and_permissions": (
        "rpc import_authored_plan_package "
        "(validated rebound package only; symbolic lineages refused)"
    ),
    "publish_approve_staging_fixture_version": (
        "rpc publish_cohort_global_programme_version + "
        "approve_cohort_global_programme_version "
        "(staging fixture only — required for catalogue enrol RPC)"
    ),
    "enrol_assignment": "rpc enrol_athlete_in_catalogue_programme_version",
    "materialise_schedule": "rpc materialise_athlete_plan_from_enrolment",
    "stop_prepare_ready": "local stop — no further mutation",
    "post_create_readonly_eligibility": "diagnose_s17_journey_d_adaptation_readonly.sh",
    "stop_without_journey_d": "hard stop — Journey D unreachable",
}

MUTATING_STAGES = {
    "create_synthetic_athlete",
    "publish_fixture_protocol_current",
    "publish_fixture_protocol_later",
    "rebind_validate_package_for_import",
    "import_programme_version_and_permissions",
    "publish_approve_staging_fixture_version",
    "enrol_assignment",
    "materialise_schedule",
}

REBIND_PATH_STATUS = "REBIND_PATH_READY"
EXPECTED_PRE_REBIND_HASH = (
    "156dfe8cf262e43f4e7e47cab070a37f466d3271fe26b29ca80e5c5e49e8a7d7"
)
SYMBOLIC_LINEAGES = (
    "SL-S17-JD-ADAPT-CURRENT",
    "SL-S17-JD-ADAPT-LATER",
)


@dataclass
class StageRecord:
    name: str
    canonical_interface: str
    status: str = "not_started"  # not_started|applied|failed|unknown
    mutating: bool = False
    detail: str = ""


@dataclass
class WriteLedger:
    marker: str
    mode: str
    live_authorized: bool
    stages: list[StageRecord] = field(default_factory=list)
    further_mutation_prohibited: bool = False
    hosted_writes: int = 0
    journey_execution_reachable: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "marker": self.marker,
            "mode": self.mode,
            "live_authorized": self.live_authorized,
            "further_mutation_prohibited": self.further_mutation_prohibited,
            "hosted_writes": self.hosted_writes,
            "journey_execution_reachable": self.journey_execution_reachable,
            "stages": [asdict(s) for s in self.stages],
        }


def new_marker() -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"s17_jd_adapt_{stamp}_{secrets.token_hex(4)}"


def validate_marker(marker: str) -> None:
    if not JD_MARKER_RE.match(marker or ""):
        raise StagingGuardError("REFUSED: invalid Journey D fixture marker")
    if marker.startswith(RESERVED_MARKERS_PREFIXES):
        raise StagingGuardError("REFUSED: reserved Athlete D marker prefix")


def validate_jd_email(email: str, marker: str) -> None:
    if not JD_EMAIL_RE.match(email or ""):
        raise StagingGuardError(
            "REFUSED: Journey D email must be non-personal @example.invalid"
        )
    if not email.startswith(marker):
        raise StagingGuardError("REFUSED: Journey D email must embed fixture marker")


def reject_reserved_identity(value: str) -> None:
    text = value or ""
    if text in RESERVED_LINEAGES:
        raise StagingGuardError(f"REFUSED: reserved lineage {text}")
    for needle in RESERVED_SUBSTRINGS:
        if needle.lower() in text.lower():
            raise StagingGuardError(f"REFUSED: reserved identity material {needle!r}")


def live_flag_set() -> bool:
    return os.environ.get("S17_JD_LIVE_CREATE", "").strip() == "1"


def load_protocol_intent(root: Path) -> dict[str, Any]:
    path = root / PROTOCOL_INTENT_REL
    data = json.loads(path.read_text())
    if data["current_protocol"]["exercise_id"] != SOURCE_EXERCISE:
        raise StagingGuardError("REFUSED: protocol intent source exercise mismatch")
    if data["current_protocol"]["replacement_exercise_id"] != REPLACEMENT_EXERCISE:
        raise StagingGuardError("REFUSED: protocol intent replacement mismatch")
    if data["available_equipment"] != AVAILABLE_EQUIPMENT:
        raise StagingGuardError("REFUSED: available_equipment contract mismatch")
    if data["lineage_code"] != LINEAGE_CODE:
        raise StagingGuardError("REFUSED: lineage_code mismatch")
    protocols = data.get("protocols")
    if not isinstance(protocols, list) or len(protocols) < 2:
        raise StagingGuardError("REFUSED: protocol intent protocols must be non-empty")
    symbolic = [p.get("symbolic_session_lineage_id") for p in protocols]
    if symbolic != list(SYMBOLIC_LINEAGES):
        raise StagingGuardError("REFUSED: symbolic lineage plan mismatch")
    if any(not str(p.get("protocol_id", "")).startswith("PROT-S17-JD-ADAPT-") for p in protocols):
        raise StagingGuardError("REFUSED: non-fixture protocol in intent")
    return data


def load_package_yaml_text(root: Path) -> str:
    path = root / PACKAGE_REL
    if not path.is_file():
        raise StagingGuardError(f"REFUSED: missing package fixture {path}")
    text = path.read_text()
    if LINEAGE_CODE not in text:
        raise StagingGuardError("REFUSED: package missing fixture lineage")
    if "substitute_approved_equipment" not in text:
        raise StagingGuardError("REFUSED: package missing equipment permission")
    if "athlete_agreement_required: true" not in text:
        raise StagingGuardError("REFUSED: package missing athlete agreement")
    if "W1D1S1" not in text or "W1D2S1" not in text:
        raise StagingGuardError("REFUSED: package must contain current + later slots")
    for symbolic in SYMBOLIC_LINEAGES:
        if symbolic not in text:
            raise StagingGuardError(
                f"REFUSED: package missing symbolic lineage {symbolic}"
            )
    if any(x in text for x in ("PROG-S15A", "PROG-S13-ELIG", "Athlete C", "Athlete D")):
        raise StagingGuardError("REFUSED: package references reserved fixture identity")
    return text


def build_empty_ledger(marker: str, mode: str, live_authorized: bool) -> WriteLedger:
    ledger = WriteLedger(marker=marker, mode=mode, live_authorized=live_authorized)
    for name in STAGE_ORDER:
        ledger.stages.append(
            StageRecord(
                name=name,
                canonical_interface=STAGE_INTERFACES[name],
                status="not_started",
                mutating=name in MUTATING_STAGES,
            )
        )
    return ledger


def mark_stage(
    ledger: WriteLedger,
    name: str,
    status: str,
    detail: str = "",
) -> None:
    for stage in ledger.stages:
        if stage.name == name:
            stage.status = status
            stage.detail = detail
            return
    raise StagingGuardError(f"REFUSED: unknown stage {name}")


def fail_closed(ledger: WriteLedger, failed_stage: str, detail: str) -> WriteLedger:
    mark_stage(ledger, failed_stage, "failed", detail)
    seen = False
    for stage in ledger.stages:
        if stage.name == failed_stage:
            seen = True
            continue
        if seen:
            stage.status = "not_started"
            stage.detail = "blocked_by_prior_failure"
    ledger.further_mutation_prohibited = True
    return ledger


def ambiguous_stop(ledger: WriteLedger, stage_name: str, detail: str) -> WriteLedger:
    mark_stage(ledger, stage_name, "unknown", detail)
    seen = False
    for stage in ledger.stages:
        if stage.name == stage_name:
            seen = True
            continue
        if seen:
            stage.status = "not_started"
            stage.detail = "blocked_by_ambiguous_prior_result"
    ledger.further_mutation_prohibited = True
    return ledger


def planned_operation_counts(ledger: WriteLedger) -> dict[str, int]:
    mutating_planned = sum(1 for s in ledger.stages if s.mutating)
    return {
        "stages_total": len(ledger.stages),
        "mutating_stages_planned": mutating_planned,
        "hosted_writes_executed": ledger.hosted_writes,
        "athletes_targeted": 1,
        "programmes_targeted": 1,
        "journeys_enabled": 0,
    }


def build_intended_write_manifest(
    *,
    marker: str,
    staging: dict[str, Any],
    mode: str,
    live_authorized: bool,
) -> dict[str, Any]:
    email = f"{marker}.athlete.jd@example.invalid"
    return {
        "status": "dry_run_ok" if mode == "dry_run" else "live_plan",
        "mode": mode,
        "live_authorized": live_authorized,
        "hosted_write": False if mode == "dry_run" else live_authorized,
        "fixture_marker": marker,
        "display_name": "S17 Journey D Adaptation Athlete",
        "email_redacted": redact_email(email),
        "lineage_code": LINEAGE_CODE,
        "package_path": PACKAGE_REL,
        "protocol_intent_path": PROTOCOL_INTENT_REL,
        "staging": {
            "name": staging["name"],
            "ref_prefix": staging["ref_prefix"],
            "region": staging["region"],
            "status": staging["status"],
        },
        "production_rejected": True,
        "targets": {
            "synthetic_athletes": 1,
            "dedicated_programmes": 1,
            "reserved_athlete_c": False,
            "reserved_athlete_d": False,
            "reserved_s15a": False,
            "reserved_s13": False,
        },
        "available_equipment": AVAILABLE_EQUIPMENT,
        "substitution": {
            "source_exercise_id": SOURCE_EXERCISE,
            "replacement_exercise_id": REPLACEMENT_EXERCISE,
            "substitution_rule_id": SUBSTITUTION_RULE,
        },
        "intended_writes": [
            {
                "stage": "create_synthetic_athlete",
                "interface": STAGE_INTERFACES["create_synthetic_athlete"],
                "objects": ["auth_user", "athlete_profile"],
                "planned_count": 1,
            },
            {
                "stage": "publish_fixture_protocol_current",
                "interface": STAGE_INTERFACES["publish_fixture_protocol_current"],
                "objects": [
                    "session_lineage",
                    "performance_protocol",
                    "protocol_steps",
                    "session_blocks",
                ],
                "protocol_id": "PROT-S17-JD-ADAPT-CURRENT",
                "symbolic_session_lineage_id": "SL-S17-JD-ADAPT-CURRENT",
                "planned_count": 1,
                "depends_on": ["create_synthetic_athlete"],
            },
            {
                "stage": "publish_fixture_protocol_later",
                "interface": STAGE_INTERFACES["publish_fixture_protocol_later"],
                "objects": [
                    "session_lineage",
                    "performance_protocol",
                    "protocol_steps",
                    "session_blocks",
                ],
                "protocol_id": "PROT-S17-JD-ADAPT-LATER",
                "symbolic_session_lineage_id": "SL-S17-JD-ADAPT-LATER",
                "planned_count": 1,
                "depends_on": ["publish_fixture_protocol_current"],
            },
            {
                "stage": "rebind_validate_package_for_import",
                "interface": STAGE_INTERFACES["rebind_validate_package_for_import"],
                "objects": ["rebound_plan_package"],
                "planned_count": 1,
                "depends_on": [
                    "publish_fixture_protocol_current",
                    "publish_fixture_protocol_later",
                ],
                "note": (
                    "Typed rebind of sessions[].session_lineage_id only; "
                    "symbolic lineages must not reach import."
                ),
            },
            {
                "stage": "import_programme_version_and_permissions",
                "interface": STAGE_INTERFACES["import_programme_version_and_permissions"],
                "objects": [
                    "programme_lineage",
                    "programme_version",
                    "programme_version_adaptation_permissions",
                    "programme_version_weeks_days_slots",
                ],
                "planned_count": 1,
                "depends_on": ["rebind_validate_package_for_import"],
                "requires_validated_rebound_package": True,
            },
            {
                "stage": "publish_approve_staging_fixture_version",
                "interface": STAGE_INTERFACES["publish_approve_staging_fixture_version"],
                "objects": ["staging_fixture_publication_only"],
                "planned_count": 1,
                "note": (
                    "Staging-project publish/approve solely to enable catalogue "
                    "enrol RPC; never production/customer catalogue. "
                    "Import itself creates an unpublished draft."
                ),
            },
            {
                "stage": "enrol_assignment",
                "interface": STAGE_INTERFACES["enrol_assignment"],
                "objects": ["programme_assignment"],
                "planned_count": 1,
            },
            {
                "stage": "materialise_schedule",
                "interface": STAGE_INTERFACES["materialise_schedule"],
                "objects": ["materialised_occurrences"],
                "planned_count": 1,
            },
        ],
        "operation_order": list(STAGE_ORDER),
        "rebind_path": REBIND_PATH_STATUS,
        "symbolic_lineages": list(SYMBOLIC_LINEAGES),
        "journeys_enabled": [],
        "journey_d_execution": "disabled",
        "retry": False,
        "compensation": False,
        "deletion": False,
        "repair": False,
        "resume": False,
        "automatic_retry": False,
        "cleanup": False,
    }


def run_dry_run(
    *,
    root: Path,
    projects_raw: str,
    marker: str | None = None,
    existing_markers: set[str] | None = None,
) -> dict[str, Any]:
    ensure_confirmation()
    projects = parse_projects_json(projects_raw)
    staging = select_staging_project(projects)

    marker = marker or new_marker()
    validate_marker(marker)
    reject_reserved_identity(marker)
    reject_reserved_identity(LINEAGE_CODE)
    email = f"{marker}.athlete.jd@example.invalid"
    validate_jd_email(email, marker)

    if existing_markers and marker in existing_markers:
        raise StagingGuardError(
            "REFUSED: fixture marker already exists — no overwrite/resume/repair"
        )

    load_package_yaml_text(root)
    load_protocol_intent(root)

    live_authorized = live_flag_set()
    # Dry-run path always zero-write even if live flag is present.
    mode = "dry_run"
    ledger = build_empty_ledger(marker, mode, live_authorized=False)

    mark_stage(ledger, "validate_environment", "applied", "staging allowlist ok")
    mark_stage(ledger, "validate_inputs_and_marker", "applied", marker)
    mark_stage(
        ledger,
        "compile_validate_package_local",
        "applied",
        "package yaml structural contract ok; Dart PlanPackageCompiler covered by tests",
    )
    mark_stage(
        ledger,
        "resolve_substitution_local",
        "applied",
        f"{SOURCE_EXERCISE}→{REPLACEMENT_EXERCISE} contract present; "
        "KnowledgeGraphReader proof in Dart tests",
    )
    mark_stage(ledger, "emit_intended_write_manifest", "applied")
    mark_stage(
        ledger,
        "check_marker_uniqueness_readonly",
        "applied",
        "dry-run: uniqueness deferred to live pre-write probe",
    )
    # All mutating stages remain not_started — including publish/rebind.
    # Dry-run must never call ProtocolBuilderService.publishDraft.
    mark_stage(
        ledger,
        "stop_without_journey_d",
        "applied",
        "Journey D execution unreachable from creator",
    )

    manifest = build_intended_write_manifest(
        marker=marker,
        staging=staging,
        mode=mode,
        live_authorized=False,
    )
    counts = planned_operation_counts(ledger)
    return {
        "ok": True,
        "classification": "B4D20_DRY_RUN_OK",
        "rebind_path": REBIND_PATH_STATUS,
        "publish_draft_invoked": False,
        "fabricated_hosted_uuids": False,
        "manifest": manifest,
        "ledger": ledger.to_dict(),
        "operation_counts": counts,
        "staging_ref_prefix": staging["ref_prefix"],
        "production_ref_prefix": staging.get("production_ref_prefix"),
    }


def refuse_live_without_flag() -> None:
    if not live_flag_set():
        raise StagingGuardError(
            "REFUSED: live creation requires S17_JD_LIVE_CREATE=1 in addition to "
            "CONFIRM_COHORT_STAGING=1"
        )


def require_explicit_live_marker(marker: str | None) -> str:
    """Live mode must consume exactly one caller-supplied marker (never new_marker)."""
    if marker is None or not str(marker).strip():
        raise StagingGuardError(
            "REFUSED: --live requires --marker <fixture-marker>"
        )
    explicit = str(marker).strip()
    validate_marker(explicit)
    reject_reserved_identity(explicit)
    return explicit


def run_live_gate_check() -> None:
    """Legacy gate used by older callers — prefer [run_live_create]."""
    ensure_confirmation()
    refuse_live_without_flag()


def _mutation_backend_mode() -> str:
    return os.environ.get("S17_JD_LIVE_MUTATION_BACKEND", "hosted").strip() or "hosted"


def _synthetic_live_result(
    *,
    marker: str,
    staging: dict[str, Any],
    fail_at: str | None = None,
) -> dict[str, Any]:
    """Local-only synthetic mutation outcomes for creator tests. Never hosted."""
    ledger = build_empty_ledger(marker, "live", live_authorized=True)
    mark_stage(ledger, "validate_environment", "applied", "staging allowlist ok")
    mark_stage(ledger, "validate_inputs_and_marker", "applied", marker)
    mark_stage(
        ledger,
        "compile_validate_package_local",
        "applied",
        f"pre_rebind_hash={EXPECTED_PRE_REBIND_HASH}",
    )
    mark_stage(ledger, "resolve_substitution_local", "applied")
    mark_stage(ledger, "emit_intended_write_manifest", "applied")
    mark_stage(
        ledger,
        "check_marker_uniqueness_readonly",
        "applied",
        "UNIQUE_synthetic",
    )

    mutating_seq = [
        "create_synthetic_athlete",
        "publish_fixture_protocol_current",
        "publish_fixture_protocol_later",
        "rebind_validate_package_for_import",
        "import_programme_version_and_permissions",
        "publish_approve_staging_fixture_version",
        "enrol_assignment",
        "materialise_schedule",
    ]
    synthetic_mutations = 0
    publish_draft_invocations = 0
    for name in mutating_seq:
        if fail_at == name:
            fail_closed(ledger, name, f"synthetic_fail:{name}")
            break
        mark_stage(ledger, name, "applied", "synthetic_ok")
        if name != "rebind_validate_package_for_import":
            synthetic_mutations += 1
        if name in (
            "publish_fixture_protocol_current",
            "publish_fixture_protocol_later",
        ):
            publish_draft_invocations += 1
    else:
        mark_stage(ledger, "stop_prepare_ready", "applied")
        mark_stage(
            ledger,
            "stop_without_journey_d",
            "applied",
            "Journey D execution unreachable from creator",
        )

    ok = fail_at is None and not ledger.further_mutation_prohibited
    manifest = build_intended_write_manifest(
        marker=marker,
        staging=staging,
        mode="live",
        live_authorized=True,
    )
    return {
        "ok": ok,
        "classification": (
            "B4D21D1_LIVE_CREATE_OK_SYNTHETIC" if ok else "B4D21D1_LIVE_CREATE_FAILED_SYNTHETIC"
        ),
        "rebind_path": REBIND_PATH_STATUS,
        "publish_draft_invoked": publish_draft_invocations > 0,
        "publish_draft_invocations": publish_draft_invocations,
        "fabricated_hosted_uuids": False,
        "synthetic_mutations": synthetic_mutations,
        "hosted_writes_executed": 0,
        "hosted_contact": False,
        "mutation_backend": "synthetic",
        "fixture_marker": marker,
        "manifest": manifest,
        "ledger": ledger.to_dict(),
        "operation_counts": planned_operation_counts(ledger),
        "staging_ref_prefix": staging["ref_prefix"],
        "retry": False,
        "resume": False,
        "cleanup": False,
        "compensation": False,
        "deletion": False,
        "repair": False,
        "journey_d_executed": False,
        "new_marker_called": False,
    }


def run_live_create(
    *,
    root: Path,
    projects_raw: str,
    marker: str | None,
    preflight: Any | None = None,
    mutation_runner: Any | None = None,
) -> dict[str, Any]:
    """Guarded live creation entry: consumes exact [marker], never new_marker().

    Default mutation backend is ``hosted`` (dart live entrypoint). Local tests
    must set ``S17_JD_LIVE_MUTATION_BACKEND=synthetic_ok`` (or synthetic_fail:STAGE)
    so no hosted contact occurs.
    """
    ensure_confirmation()
    refuse_live_without_flag()
    explicit = require_explicit_live_marker(marker)
    # Explicit marker path — never generate a replacement.
    if explicit != marker.strip():
        raise StagingGuardError("REFUSED: marker normalised unexpectedly")

    projects = parse_projects_json(projects_raw)
    staging = select_staging_project(projects)
    load_package_yaml_text(root)
    load_protocol_intent(root)

    email = f"{explicit}.athlete.jd@example.invalid"
    validate_jd_email(email, explicit)

    mode = _mutation_backend_mode()
    if mutation_runner is not None:
        return mutation_runner(
            root=root,
            staging=staging,
            marker=explicit,
            preflight=preflight,
        )

    if mode == "synthetic_ok":
        return _synthetic_live_result(marker=explicit, staging=staging)
    if mode.startswith("synthetic_fail:"):
        fail_at = mode.split(":", 1)[1]
        return _synthetic_live_result(
            marker=explicit, staging=staging, fail_at=fail_at
        )
    if mode != "hosted":
        raise StagingGuardError(
            f"REFUSED: unknown S17_JD_LIVE_MUTATION_BACKEND={mode!r}"
        )

    # Hosted path: invoke repository-owned Dart live entrypoint once.
    import subprocess
    import tempfile

    request = {
        "marker": explicit,
        "root": str(root),
        "package_rel": PACKAGE_REL,
        "protocol_intent_rel": PROTOCOL_INTENT_REL,
        "expected_pre_rebind_hash": EXPECTED_PRE_REBIND_HASH,
        "lineage_code": LINEAGE_CODE,
        "api_env_path": os.environ.get("S17_API_ENV", "/tmp/s13b_api.env"),
        "staging_ref_prefix": staging["ref_prefix"],
        "mutation_backend": "hosted",
    }
    with tempfile.TemporaryDirectory(prefix="cohort_s17_jd_live.") as tmp:
        req_path = Path(tmp) / "live_request.json"
        out_path = Path(tmp) / "live_result.json"
        req_path.write_text(json.dumps(request))
        runner = root / "tool/staging/run_s17_journey_d_live_dart.sh"
        if not runner.is_file():
            raise StagingGuardError(
                "REFUSED: missing tool/staging/run_s17_journey_d_live_dart.sh"
            )
        env = os.environ.copy()
        env["S17_JD_LIVE_REQUEST_FILE"] = str(req_path)
        env["S17_JD_LIVE_RESULT_FILE"] = str(out_path)
        env["S17_ROOT"] = str(root)
        completed = subprocess.run(
            ["bash", str(runner)],
            cwd=str(root),
            env=env,
            capture_output=True,
            text=True,
            timeout=600,
        )
        if completed.returncode != 0 and not out_path.is_file():
            detail = (completed.stderr or completed.stdout or "").strip()
            raise StagingGuardError(
                "REFUSED: hosted live dart entrypoint failed: "
                + (detail[:400] if detail else f"exit={completed.returncode}")
            )
        if not out_path.is_file():
            raise StagingGuardError(
                "REFUSED: hosted live dart entrypoint produced no result file"
            )
        result = json.loads(out_path.read_text())
        result.setdefault("mutation_backend", "hosted")
        result.setdefault("fixture_marker", explicit)
        result.setdefault("new_marker_called", False)
        result.setdefault("rebind_path", REBIND_PATH_STATUS)
        return result


def post_create_verifier_checklist() -> list[str]:
    return [
        "dedicated_staging_fixture",
        "unique_fixture_marker",
        "fixture_only_programme_identity",
        "unpublished_fixture_version",
        "active_assignment",
        "materialised",
        "authoritative_cursor",
        "suitable_current_occurrence",
        "prepared_session_ready",
        "adaptation_permissions_nonempty",
        "equipment_adaptation_allowed",
        "athlete_agreement_required",
        "policy_change_kinds_allowed",
        "available_equipment_matches_contract",
        "deterministic_curated_substitution",
        "acceptable_proposal_preconditions",
        "accepted_adaptation_absent",
        "proposal_consumed_false",
        "unaffected_occurrence_baseline_available",
        "existing_fixture_identities_not_reused",
        "hosted_writes_match_manifest",
    ]
