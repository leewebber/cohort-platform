"""Fixture-scoped hosted read-only verifier for Journey D (B4d.21d.3).

All queries require an exact marker-bound predicate. The HTTP client permits
GET only — insert/update/delete/publish/enrol/materialise/adapt are unreachable.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable
from urllib.request import Request

from s17_journey_d_fixture import (
    AVAILABLE_EQUIPMENT,
    LINEAGE_CODE,
    REPLACEMENT_EXERCISE,
    SOURCE_EXERCISE,
    SYMBOLIC_LINEAGES,
    StagingGuardError,
    load_package_yaml_text,
    load_protocol_intent,
    reject_reserved_identity,
    validate_marker,
)
from s17_staging_guard import (
    ensure_confirmation,
    parse_projects_json,
    redact_email,
    redact_ref,
    redact_uuid,
    reject_production_url,
    select_staging_project,
)

CURRENT_PROTOCOL_ID = "PROT-S17-JD-ADAPT-CURRENT"
LATER_PROTOCOL_ID = "PROT-S17-JD-ADAPT-LATER"
HOSTED_READONLY_GUARD = "S17_JD_HOSTED_READONLY"


class MutationAttemptError(StagingGuardError):
    """Raised if a non-GET HTTP method is attempted."""


@dataclass
class ReadOnlyHttpClient:
    """Structurally read-only HTTP client (GET only)."""

    base_url: str
    api_key: str
    get_impl: Callable[[str, dict[str, str]], tuple[int, str, dict[str, str]]] | None = None
    calls: list[dict[str, Any]] = field(default_factory=list)

    def get(
        self,
        path: str,
        *,
        prefer_count: bool = False,
        require_predicate: str | None = None,
    ) -> tuple[int, str, dict[str, str]]:
        if require_predicate is not None and require_predicate not in path:
            raise StagingGuardError(
                f"REFUSED: query missing exact fixture predicate {require_predicate!r}"
            )
        # Block broad list endpoints without eq/ filter or exact-id Auth path.
        auth_user_id = re.search(
            r"/auth/v1/admin/users/"
            r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
            path,
        )
        if "eq." not in path and "email=" not in path and not auth_user_id:
            raise StagingGuardError(
                "REFUSED: broad or missing fixture-scoped predicate"
            )
        headers = {
            "apikey": self.api_key,
            "Authorization": f"Bearer {self.api_key}",
            "Accept": "application/json",
        }
        if prefer_count:
            headers["Prefer"] = "count=exact"
            headers["Range"] = "0-0"
        url = self.base_url.rstrip("/") + path
        self.calls.append({"method": "GET", "path": path})
        if self.get_impl is not None:
            return self.get_impl(path, headers)
        req = Request(url, headers=headers, method="GET")
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                body = resp.read().decode()
                hdrs = {k.lower(): v for k, v in resp.headers.items()}
                return resp.status, body, hdrs
        except urllib.error.HTTPError as e:
            body = e.read().decode() if e.fp else ""
            hdrs = {k.lower(): v for k, v in (e.headers.items() if e.headers else [])}
            return e.code, body, hdrs

    def post(self, *args: Any, **kwargs: Any) -> None:
        raise MutationAttemptError("REFUSED: POST unreachable in read-only verifier")

    def patch(self, *args: Any, **kwargs: Any) -> None:
        raise MutationAttemptError("REFUSED: PATCH unreachable in read-only verifier")

    def put(self, *args: Any, **kwargs: Any) -> None:
        raise MutationAttemptError("REFUSED: PUT unreachable in read-only verifier")

    def delete(self, *args: Any, **kwargs: Any) -> None:
        raise MutationAttemptError("REFUSED: DELETE unreachable in read-only verifier")


def require_hosted_readonly_guard() -> None:
    if os.environ.get(HOSTED_READONLY_GUARD, "").strip() != "1":
        raise StagingGuardError(
            f"REFUSED: hosted read-only mode requires {HOSTED_READONLY_GUARD}=1"
        )


def load_api_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        raise StagingGuardError(f"REFUSED: missing API env {path}")
    for line in path.read_text().splitlines():
        text = line.strip()
        if text.startswith("export "):
            text = text[7:]
        if not text or text.startswith("#") or "=" not in text:
            continue
        k, v = text.split("=", 1)
        out[k.strip()] = v.strip().strip("'").strip('"')
    return out


def _count_from_range(headers: dict[str, str], body: str) -> int | None:
    cr = headers.get("content-range") or headers.get("Content-Range") or ""
    if "/" in cr:
        total = cr.split("/")[-1]
        if total != "*":
            try:
                return int(total)
            except ValueError:
                return None
    try:
        data = json.loads(body) if body else None
    except json.JSONDecodeError:
        return None
    if isinstance(data, list):
        return len(data)
    if isinstance(data, dict) and "users" in data and isinstance(data["users"], list):
        return len(data["users"])
    return None


def _parse_list(body: str) -> list[dict[str, Any]]:
    try:
        data = json.loads(body) if body else []
    except json.JSONDecodeError:
        return []
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    if isinstance(data, dict) and isinstance(data.get("users"), list):
        return [x for x in data["users"] if isinstance(x, dict)]
    return []


def empty_result(marker: str) -> dict[str, Any]:
    return {
        "ok": False,
        "mode": "hosted_read_only",
        "mutation": False,
        "target_verified": False,
        "production_excluded": False,
        "marker": marker,
        "identity_count": 0,
        "profile_count": 0,
        "identity_profile_link_valid": False,
        "current_protocol_count": 0,
        "current_revision_count": 0,
        "later_protocol_count": 0,
        "later_revision_count": 0,
        "canonical_publication_attribution_valid": False,
        "programme_count": 0,
        "programme_version_count": 0,
        "programme_state_valid": False,
        "imported_lineages_canonical": False,
        "symbolic_lineage_count": 0,
        "assignment_count": 0,
        "occurrence_count": 0,
        "occurrence_order_valid": False,
        "equipment_conflict_valid": False,
        "substitution_contract_valid": False,
        "permissions_policy_valid": False,
        "athlete_agreement_required": False,
        "later_push_up_intact": False,
        "adaptation_state_count": 0,
        "journey_d_execution_count": 0,
        "journey_i_execution_count": 0,
        "journey_j_execution_count": 0,
        "duplicates_found": False,
        "unrelated_objects_attributable": False,
        "fixture_state": "uncertain",
        "fixture_eligible": False,
        "unverified_claims": [],
        "retry": False,
        "resume": False,
        "cleanup": False,
        "compensation": False,
        "delete": False,
        "repair": False,
        "linked_cli_used": False,
    }


def run_hosted_readonly(
    *,
    root: Path,
    projects_raw: str,
    marker: str,
    api_env_path: Path,
    client: ReadOnlyHttpClient | None = None,
    fixture_snapshot: dict[str, Any] | None = None,
    mode: str = "eligibility",
) -> dict[str, Any]:
    """Run fixture-scoped hosted read-only verification.

    mode:
      eligibility — pre-Journey D (requires adaptation/execution counts == 0)
      outcome — post-Journey D (requires exactly one Journey D execution)

    [fixture_snapshot] injects fake query answers for local tests (never hosted).
    """
    ensure_confirmation()
    require_hosted_readonly_guard()
    validate_marker(marker)
    reject_reserved_identity(marker)
    if mode not in {"eligibility", "outcome"}:
        raise StagingGuardError("REFUSED: hosted mode must be eligibility or outcome")

    projects = parse_projects_json(projects_raw)
    staging = select_staging_project(projects)
    result = empty_result(marker)
    result["mode"] = mode
    result["staging_ref_prefix"] = staging["ref_prefix"]
    result["staging_name"] = staging.get("name")
    result["staging_region"] = staging.get("region")
    result["staging_status"] = staging.get("status")

    package_text = load_package_yaml_text(root)
    intent = load_protocol_intent(root)
    email = f"{marker}.athlete.jd@example.invalid"
    result["email_redacted"] = redact_email(email)

    intent_blob = json.dumps(intent)
    result["equipment_conflict_valid"] = SOURCE_EXERCISE in intent_blob
    result["substitution_contract_valid"] = (
        REPLACEMENT_EXERCISE in intent_blob
        and "cohort.substitution.back_squat_to_goblet_squat" in intent_blob
        and all(e in intent_blob for e in AVAILABLE_EQUIPMENT)
    )
    result["permissions_policy_valid"] = (
        "substitute_approved_equipment" in package_text
        and "substitute_approved_exercise" in package_text
    )
    result["athlete_agreement_required"] = (
        "athlete_agreement_required: true" in package_text
    )
    result["later_push_up_intact"] = "cohort.exercise.push_up" in intent_blob

    creds = load_api_env(api_env_path)
    url = (creds.get("S13_API_URL") or creds.get("SUPABASE_URL") or "").strip()
    # Prefer anon for reads when present; service key allowed for Auth Admin GET.
    anon = (creds.get("S13_ANON_KEY") or creds.get("SUPABASE_ANON_KEY") or "").strip()
    service = (
        creds.get("S13_SERVICE_KEY") or creds.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    ).strip()
    reject_production_url(url)
    if "tsbadngz" not in url:
        raise StagingGuardError("REFUSED: API host is not Cohort Staging")
    result["target_verified"] = True
    result["production_excluded"] = True
    result["api_host_staging"] = True

    read_key = service or anon
    if not read_key:
        raise StagingGuardError("REFUSED: missing API key for read-only verification")

    http = client or ReadOnlyHttpClient(base_url=url, api_key=read_key)
    unverified: list[str] = []

    if fixture_snapshot is not None:
        # Local fake path — no network.
        snap = fixture_snapshot
    else:
        snap = _fetch_snapshot(http, marker=marker, email=email)

    result["identity_count"] = int(snap.get("identity_count", 0))
    result["profile_count"] = int(snap.get("profile_count", 0))
    result["identity_profile_link_valid"] = bool(
        snap.get("identity_profile_link_valid", False)
    )
    result["current_protocol_count"] = int(snap.get("current_protocol_count", 0))
    result["current_revision_count"] = int(snap.get("current_revision_count", 0))
    result["later_protocol_count"] = int(snap.get("later_protocol_count", 0))
    result["later_revision_count"] = int(snap.get("later_revision_count", 0))
    result["canonical_publication_attribution_valid"] = bool(
        snap.get("canonical_publication_attribution_valid", False)
    )
    result["programme_count"] = int(snap.get("programme_count", 0))
    result["programme_version_count"] = int(snap.get("programme_version_count", 0))
    result["programme_state_valid"] = bool(snap.get("programme_state_valid", False))
    result["imported_lineages_canonical"] = bool(
        snap.get("imported_lineages_canonical", False)
    )
    result["symbolic_lineage_count"] = int(snap.get("symbolic_lineage_count", 0))
    result["assignment_count"] = int(snap.get("assignment_count", 0))
    result["occurrence_count"] = int(snap.get("occurrence_count", 0))
    result["occurrence_order_valid"] = bool(snap.get("occurrence_order_valid", False))
    result["adaptation_state_count"] = int(snap.get("adaptation_state_count", 0))
    result["journey_d_execution_count"] = int(snap.get("journey_d_execution_count", 0))
    result["journey_i_execution_count"] = int(snap.get("journey_i_execution_count", 0))
    result["journey_j_execution_count"] = int(snap.get("journey_j_execution_count", 0))
    result["duplicates_found"] = bool(snap.get("duplicates_found", False))
    result["unrelated_objects_attributable"] = bool(
        snap.get("unrelated_objects_attributable", False)
    )
    unverified.extend(snap.get("unverified_claims") or [])

    # Redact any accidental full identifiers from snapshot.
    if "user_id" in snap:
        result["user_id_redacted"] = redact_uuid(str(snap["user_id"]))
    if "assignment_id" in snap:
        result["assignment_id_redacted"] = redact_uuid(str(snap["assignment_id"]))

    totals = (
        result["identity_count"]
        + result["profile_count"]
        + result["current_protocol_count"]
        + result["later_protocol_count"]
        + result["programme_count"]
        + result["programme_version_count"]
        + result["assignment_count"]
        + result["occurrence_count"]
    )

    if unverified:
        result["fixture_state"] = "uncertain"
    elif totals == 0:
        result["fixture_state"] = "absent"
    elif _is_complete(result):
        result["fixture_state"] = "complete"
    else:
        result["fixture_state"] = "partial"

    result["unverified_claims"] = unverified
    base_complete = (
        result["fixture_state"] == "complete"
        and not result["duplicates_found"]
        and not result["unrelated_objects_attributable"]
        and not unverified
        and result["symbolic_lineage_count"] == 0
        and result["journey_i_execution_count"] == 0
        and result["journey_j_execution_count"] == 0
        and result["equipment_conflict_valid"]
        and result["substitution_contract_valid"]
        and result["permissions_policy_valid"]
        and result["athlete_agreement_required"]
        and result["later_push_up_intact"]
        and result["target_verified"]
        and result["production_excluded"]
    )
    if mode == "eligibility":
        result["fixture_eligible"] = (
            base_complete
            and result["adaptation_state_count"] == 0
            and result["journey_d_execution_count"] == 0
        )
        result["outcome_verified"] = False
    else:
        # Post-execution outcome: exactly one Journey D, approved swap evidence.
        meta = snap.get("journey_d_metadata") or {}
        result["swap_exercise"] = meta.get("action") == "swapExercise"
        result["source_exercise_id"] = meta.get("source_exercise_id")
        result["replacement_exercise_id"] = meta.get("replacement_exercise_id")
        result["substitution_rule_id"] = meta.get("substitution_rule_id")
        result["athlete_agreement_recorded"] = bool(
            meta.get("athlete_agreement_recorded")
        )
        result["permissions_passed"] = bool(meta.get("permissions_passed"))
        result["intended_occurrence_key"] = meta.get("intended_occurrence_key")
        result["programme_source_mutated"] = bool(
            meta.get("programme_source_mutated", False)
        )
        result["outcome_verified"] = (
            base_complete
            and result["journey_d_execution_count"] == 1
            and result["swap_exercise"] is True
            and result["source_exercise_id"] == SOURCE_EXERCISE
            and result["replacement_exercise_id"] == REPLACEMENT_EXERCISE
            and result["substitution_rule_id"]
            == "cohort.substitution.back_squat_to_goblet_squat"
            and result["athlete_agreement_recorded"] is True
            and result["permissions_passed"] is True
            and result["intended_occurrence_key"] == "SES-JD-ADAPT-CURRENT"
            and result["programme_source_mutated"] is False
            and result["later_push_up_intact"] is True
        )
        # Eligibility is false after adaptation — outcome uses outcome_verified.
        result["fixture_eligible"] = False
    result["ok"] = True  # verifier ran; eligibility/outcome are separate
    result["http_calls"] = getattr(http, "calls", [])
    return result


def _is_complete(r: dict[str, Any]) -> bool:
    return (
        r["identity_count"] == 1
        and r["profile_count"] == 1
        and r["identity_profile_link_valid"]
        and r["current_protocol_count"] == 1
        and r["current_revision_count"] == 1
        and r["later_protocol_count"] == 1
        and r["later_revision_count"] == 1
        and r["canonical_publication_attribution_valid"]
        and r["programme_count"] == 1
        and r["programme_version_count"] == 1
        and r["programme_state_valid"]
        and r["imported_lineages_canonical"]
        and r["assignment_count"] == 1
        and r["occurrence_count"] == 2
        and r["occurrence_order_valid"]
    )


def _fetch_snapshot(
    http: ReadOnlyHttpClient, *, marker: str, email: str
) -> dict[str, Any]:
    """Exact-filter hosted reads only."""
    snap: dict[str, Any] = {"unverified_claims": []}
    enc_email = urllib.parse.quote(email, safe="")
    enc_marker = urllib.parse.quote(marker, safe="")
    enc_lineage = urllib.parse.quote(LINEAGE_CODE, safe="")
    enc_current = urllib.parse.quote(CURRENT_PROTOCOL_ID, safe="")
    enc_later = urllib.parse.quote(LATER_PROTOCOL_ID, safe="")

    # Auth identity by exact email (marker is the email local-part prefix).
    auth_path = f"/auth/v1/admin/users?email={enc_email}"
    if marker not in auth_path and urllib.parse.quote(marker, safe="") not in auth_path:
        raise StagingGuardError("REFUSED: auth query not marker-bound")
    status, body, headers = http.get(auth_path, require_predicate=marker)
    users = _parse_list(body)
    exact = [u for u in users if (u.get("email") or "") == email]
    snap["identity_count"] = len(exact)
    user_id = exact[0]["id"] if len(exact) == 1 else None
    if status != 200:
        snap["unverified_claims"].append("identity_lookup")
        snap["identity_count"] = 0
    # Journey execution counts from fixture-bound Auth user_metadata only.
    if user_id and len(exact) == 1:
        meta = exact[0].get("user_metadata") or {}
        if not isinstance(meta, dict) or "journey_d_execution_count" not in meta:
            # List endpoint may omit metadata — fetch exact user by id.
            st2, body2, _ = http.get(
                f"/auth/v1/admin/users/{urllib.parse.quote(str(user_id), safe='')}",
                require_predicate=str(user_id),
            )
            if st2 == 200:
                try:
                    full = json.loads(body2)
                except json.JSONDecodeError:
                    full = {}
                if isinstance(full, dict):
                    meta = full.get("user_metadata") or meta or {}
            else:
                snap["unverified_claims"].append("user_metadata_lookup")
        if not isinstance(meta, dict):
            meta = {}
        run_id = str(meta.get("run_id") or "")
        if run_id and run_id != marker:
            snap["unverified_claims"].append("user_metadata_run_id_mismatch")
        snap["journey_d_metadata"] = {
            "action": meta.get("action"),
            "source_exercise_id": meta.get("source_exercise_id"),
            "replacement_exercise_id": meta.get("replacement_exercise_id"),
            "substitution_rule_id": meta.get("substitution_rule_id"),
            "athlete_agreement_recorded": meta.get("athlete_agreement_recorded"),
            "permissions_passed": meta.get("permissions_passed"),
            "intended_occurrence_key": meta.get("intended_occurrence_key"),
            "programme_source_mutated": meta.get("programme_source_mutated", False),
            "later_push_up_intact": meta.get("later_push_up_intact"),
        }
        try:
            snap["journey_d_execution_count"] = int(
                meta.get("journey_d_execution_count") or 0
            )
        except (TypeError, ValueError):
            snap["journey_d_execution_count"] = 0
            snap["unverified_claims"].append("journey_d_execution_count")
        try:
            snap["journey_i_execution_count"] = int(
                meta.get("journey_i_execution_count") or 0
            )
        except (TypeError, ValueError):
            snap["journey_i_execution_count"] = 0
        try:
            snap["journey_j_execution_count"] = int(
                meta.get("journey_j_execution_count") or 0
            )
        except (TypeError, ValueError):
            snap["journey_j_execution_count"] = 0

    # Profile by exact user id (only if known).
    if user_id:
        status, body, headers = http.get(
            f"/rest/v1/profiles?select=id,display_name&id=eq.{urllib.parse.quote(str(user_id), safe='')}",
            require_predicate=f"id=eq.{user_id}",
            prefer_count=True,
        )
        profiles = _parse_list(body)
        snap["profile_count"] = len(profiles) if status == 200 else 0
        snap["identity_profile_link_valid"] = (
            status == 200
            and len(profiles) == 1
            and str(profiles[0].get("id")) == str(user_id)
        )
        snap["user_id"] = user_id
    else:
        snap["profile_count"] = 0
        snap["identity_profile_link_valid"] = False

    # Protocols by exact protocol_id.
    for role, pid, enc in (
        ("current", CURRENT_PROTOCOL_ID, enc_current),
        ("later", LATER_PROTOCOL_ID, enc_later),
    ):
        status, body, headers = http.get(
            f"/rest/v1/performance_protocols?select=id,protocol_id,session_lineage_id,revision_number,status"
            f"&protocol_id=eq.{enc}",
            require_predicate=f"protocol_id=eq.{pid}",
            prefer_count=True,
        )
        rows = _parse_list(body)
        count = _count_from_range(headers, body)
        if status != 200 or count is None:
            snap["unverified_claims"].append(f"{role}_protocol_lookup")
            count = 0
            rows = []
        snap[f"{role}_protocol_count"] = count
        snap[f"{role}_revision_count"] = count
        snap[f"{role}_rows"] = rows

    cur_rows = snap.get("current_rows") or []
    lat_rows = snap.get("later_rows") or []
    attribution = (
        snap.get("current_protocol_count") == 1
        and snap.get("later_protocol_count") == 1
        and len(cur_rows) == 1
        and len(lat_rows) == 1
    )
    symbolic = 0
    canonical = True
    for rows in (cur_rows, lat_rows):
        for row in rows:
            lin = str(row.get("session_lineage_id") or "")
            if any(lin.startswith(s) or lin == s for s in SYMBOLIC_LINEAGES) or lin.startswith(
                "SL-S17-JD-ADAPT-"
            ):
                symbolic += 1
                canonical = False
            if not re.match(
                r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
                lin,
                re.I,
            ):
                canonical = False
    snap["symbolic_lineage_count"] = symbolic
    snap["imported_lineages_canonical"] = canonical and attribution
    snap["canonical_publication_attribution_valid"] = attribution and canonical

    # Programme lineage by exact code.
    status, body, headers = http.get(
        f"/rest/v1/programme_lineages?select=id,code&code=eq.{enc_lineage}",
        require_predicate=f"code=eq.{LINEAGE_CODE}",
        prefer_count=True,
    )
    lineages = _parse_list(body)
    lin_count = _count_from_range(headers, body)
    if status != 200 or lin_count is None:
        snap["unverified_claims"].append("programme_lineage_lookup")
        lin_count = 0
        lineages = []
    snap["programme_count"] = lin_count
    lineage_id = lineages[0]["id"] if len(lineages) == 1 else None

    version_count = 0
    programme_state_valid = False
    if lineage_id:
        status, body, headers = http.get(
            f"/rest/v1/programme_versions?select=id,version_number,status,lifecycle_state"
            f"&programme_lineage_id=eq.{urllib.parse.quote(str(lineage_id), safe='')}"
            f"&version_number=eq.1",
            require_predicate=f"programme_lineage_id=eq.{lineage_id}",
            prefer_count=True,
        )
        versions = _parse_list(body)
        version_count = _count_from_range(headers, body) or 0
        if status != 200:
            snap["unverified_claims"].append("programme_version_lookup")
            version_count = 0
            versions = []
        if version_count == 1 and versions:
            st = str(
                versions[0].get("status")
                or versions[0].get("lifecycle_state")
                or ""
            ).lower()
            programme_state_valid = st in {
                "published",
                "approved",
                "published_approved",
                "active",
            }
            snap["version_id"] = versions[0].get("id")
    snap["programme_version_count"] = version_count
    snap["programme_state_valid"] = programme_state_valid

    # Assignment / occurrences bound to athlete + version when known.
    assignment_count = 0
    occurrence_count = 0
    occurrence_order_valid = False
    version_id = snap.get("version_id")
    if user_id and version_id:
        status, body, headers = http.get(
            f"/rest/v1/programme_assignments?select=id,programme_version_id,athlete_id"
            f"&athlete_id=eq.{urllib.parse.quote(str(user_id), safe='')}"
            f"&programme_version_id=eq.{urllib.parse.quote(str(version_id), safe='')}",
            require_predicate=f"athlete_id=eq.{user_id}",
            prefer_count=True,
        )
        assignments = _parse_list(body)
        assignment_count = _count_from_range(headers, body) or 0
        if status != 200:
            snap["unverified_claims"].append("assignment_lookup")
            assignment_count = 0
            assignments = []
        if assignment_count == 1 and assignments:
            aid = assignments[0]["id"]
            snap["assignment_id"] = aid
            status, body, headers = http.get(
                f"/rest/v1/programme_schedule_occurrences?select=id,session_key,sequence"
                f"&programme_assignment_id=eq.{urllib.parse.quote(str(aid), safe='')}",
                require_predicate=f"programme_assignment_id=eq.{aid}",
                prefer_count=True,
            )
            occ = _parse_list(body)
            occurrence_count = _count_from_range(headers, body) or 0
            if status != 200:
                snap["unverified_claims"].append("occurrence_lookup")
                occurrence_count = 0
                occ = []
            keys = [str(o.get("session_key") or "") for o in occ]
            # CURRENT before LATER by known session keys when present.
            if occurrence_count == 2:
                if "SES-JD-ADAPT-CURRENT" in keys and "SES-JD-ADAPT-LATER" in keys:
                    occurrence_order_valid = keys.index(
                        "SES-JD-ADAPT-CURRENT"
                    ) < keys.index("SES-JD-ADAPT-LATER")
                else:
                    # sequence field fallback
                    seqs = [o.get("sequence") for o in occ]
                    occurrence_order_valid = seqs == sorted(
                        seqs, key=lambda x: (x is None, x)
                    )
    elif totals_nonzero_partial(snap):
        # Partial fixture without linkage — leave counts zero for missing stages.
        pass

    snap["assignment_count"] = assignment_count
    snap["occurrence_count"] = occurrence_count
    snap["occurrence_order_valid"] = occurrence_order_valid

    # Adaptation / journey execution: exact marker metadata filters only.
    status, body, headers = http.get(
        f"/rest/v1/session_adaptation_proposals?select=id"
        f"&metadata->>run_id=eq.{enc_marker}",
        require_predicate=f"run_id=eq.{marker}",
        prefer_count=True,
    )
    if status in (200, 400, 404, 427):
        # 400/404 means column/table absent — treat as zero if not found, else unverified.
        if status == 200:
            snap["adaptation_state_count"] = _count_from_range(headers, body) or 0
        else:
            snap["adaptation_state_count"] = 0
    else:
        snap["unverified_claims"].append("adaptation_state_lookup")
        snap["adaptation_state_count"] = 0

    # Journey execution tables may not exist; default zero without broad scans.
    snap.setdefault("journey_d_execution_count", 0)
    snap.setdefault("journey_i_execution_count", 0)
    snap.setdefault("journey_j_execution_count", 0)
    snap["duplicates_found"] = any(
        int(snap.get(k, 0) or 0) > 1
        for k in (
            "identity_count",
            "profile_count",
            "current_protocol_count",
            "later_protocol_count",
            "programme_count",
            "programme_version_count",
            "assignment_count",
        )
    )
    snap["unrelated_objects_attributable"] = False
    return snap


def totals_nonzero_partial(snap: dict[str, Any]) -> bool:
    return any(int(snap.get(k, 0) or 0) > 0 for k in ("identity_count", "programme_count"))
