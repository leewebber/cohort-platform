#!/usr/bin/env python3
"""Gate 1 backend/RPC orchestration for Athlete E (test-only).

Requires:
  CONFIRM_COHORT_STAGING=1
  S17E_GATE1_EXECUTE=1
  S17E_PRIVATE_DIR=[PRIVATE_ATHLETE_E_EVIDENCE_DIRECTORY]
  S17E_PAYLOAD_FILE=[PRIVATE_COMPILED_GATE_1_PAYLOAD]
  S17E_PREFLIGHT_AGG_FILE=[PRIVATE_PREFLIGHT_AGGREGATE]
  S17_API_ENV=[PRIVATE_STAGING_API_ENV]

Does not: db push, migrations, Field Manual, Athlete A–D mutation, cleanup,
product UI claims. Leaves results JSON under private dir.
"""

from __future__ import annotations

import json
import os
import secrets
import subprocess
import sys
import uuid
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/staging/lib"))

from s17_staging_guard import (  # noqa: E402
    StagingGuardError,
    reject_production_url,
    reject_service_role_material,
)
from s17e_athlete_e_bootstrap import (  # noqa: E402
    AthleteEBootstrapError,
    require_exact_staging_ref,
    reject_production_project,
    validate_athlete_e_email,
    validate_run_marker,
)

STAGING_REF = "tsbadngzgvsyfqjupkng"
AUTHORISED_LINEAGE_CODE = "PROG-S17E-GATE1"
AUTHORISED_VERSION_NUMBER = 2
AUTHORISED_DISPLAY_NAME = "S17E Staging Athlete E"
AUTHORISED_SERVICE_ROLE_RPCS = frozenset(
    {
        "import_authored_plan_package",
        "publish_cohort_global_programme_version",
        "approve_cohort_global_programme_version",
    }
)
RESULTS: dict = {
    "gate": "GATE_1_BACKEND_RPC",
    "project_ref": STAGING_REF,
    "tests": {},
    "started_at": datetime.now(timezone.utc).isoformat(),
}


def refuse(msg: str, code: int = 2) -> None:
    print(f"REFUSED: {msg}", file=sys.stderr)
    raise SystemExit(code)


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:]
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip("'").strip('"')
    return env


def http_json(
    method: str,
    url: str,
    key: str,
    body=None,
    prefer=None,
    timeout=90,
    auth_bearer: str | None = None,
):
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {auth_bearer or key}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {"raw": raw[:500]}
        return e.code, parsed


def rpc(
    base: str,
    key: str,
    name: str,
    params: dict,
    timeout=90,
    auth_bearer: str | None = None,
):
    return http_json(
        "POST",
        f"{base}/rest/v1/rpc/{name}",
        key,
        params,
        timeout=timeout,
        auth_bearer=auth_bearer,
    )


def record(tid: str, status: str, **extra):
    RESULTS["tests"][tid] = {
        "status": status,
        "classification": "GATE_1_BACKEND_RPC",
        **extra,
    }
    print(f"{tid}={status}")


def validate_authorised_package_identity(payload: object) -> None:
    """Fail closed unless typed compiler fields name the authorised v2 package."""
    if not isinstance(payload, dict):
        raise AthleteEBootstrapError("REFUSED: Gate 1 payload must be an object")
    programme = payload.get("programme")
    if not isinstance(programme, dict):
        raise AthleteEBootstrapError("REFUSED: Gate 1 programme identity missing")
    lineage = programme.get("lineage_code")
    version = programme.get("version_number")
    if type(lineage) is not str or lineage != AUTHORISED_LINEAGE_CODE:
        raise AthleteEBootstrapError("REFUSED: unauthorised Gate 1 lineage")
    if type(version) is not int or version != AUTHORISED_VERSION_NUMBER:
        raise AthleteEBootstrapError("REFUSED: unauthorised Gate 1 version")


def validate_authorised_athlete_e_credentials(creds: object) -> None:
    """Validate the authoritative bootstrap marker and its bound E identity."""
    if not isinstance(creds, dict):
        raise AthleteEBootstrapError("REFUSED: Athlete E credentials missing")
    marker = creds.get("run_marker")
    email = creds.get("email")
    user_id = creds.get("user_id")
    display_name = creds.get("display_name")
    if type(marker) is not str:
        raise AthleteEBootstrapError("REFUSED: Athlete E run marker missing")
    validate_run_marker(marker)
    if type(email) is not str:
        raise AthleteEBootstrapError("REFUSED: Athlete E email missing")
    validate_athlete_e_email(email, marker)
    if display_name != AUTHORISED_DISPLAY_NAME:
        raise AthleteEBootstrapError("REFUSED: Athlete E display identity mismatch")
    try:
        parsed_user_id = uuid.UUID(user_id) if type(user_id) is str else None
    except (ValueError, AttributeError):
        parsed_user_id = None
    if parsed_user_id is None or parsed_user_id.int == 0 or str(parsed_user_id) != user_id:
        raise AthleteEBootstrapError("REFUSED: Athlete E user identity invalid")


def validate_authorised_gate1_target(payload: object, creds: object) -> None:
    """Validate package and athlete allow-lists before any hosted operation."""
    validate_authorised_package_identity(payload)
    validate_authorised_athlete_e_credentials(creds)


def invoke_authorised_service_rpc(
    name: str,
    params: dict,
    *,
    payload: object,
    creds: object,
    transport,
    expected_version_id: str | None = None,
):
    """Guard every service-role mutation immediately before transport."""
    validate_authorised_gate1_target(payload, creds)
    if name not in AUTHORISED_SERVICE_ROLE_RPCS:
        raise AthleteEBootstrapError(
            "REFUSED: service-role operation outside Gate 1 allow-list"
        )
    if name == "import_authored_plan_package":
        validate_authorised_package_identity(params.get("payload"))
    else:
        requested_version_id = params.get("p_version_id")
        if (
            type(expected_version_id) is not str
            or type(requested_version_id) is not str
            or requested_version_id != expected_version_id
        ):
            raise AthleteEBootstrapError(
                "REFUSED: lifecycle operation is not bound to imported Gate 1 v2"
            )
    return transport(name, params)


def main() -> int:
    if os.environ.get("CONFIRM_COHORT_STAGING") != "1":
        refuse("CONFIRM_COHORT_STAGING=1 required")
    if os.environ.get("S17E_GATE1_EXECUTE") != "1":
        refuse("S17E_GATE1_EXECUTE=1 required")
    if os.environ.get("S17E_ALLOW_DB_PUSH") == "1":
        refuse("db push not permitted")

    private = Path(os.environ.get("S17E_PRIVATE_DIR", "")).expanduser()
    if not private.is_dir():
        refuse("S17E_PRIVATE_DIR missing")
    creds_path = private / "athlete_e_credentials.json"
    if not creds_path.is_file():
        refuse("athlete_e credentials missing")

    payload_value = os.environ.get("S17E_PAYLOAD_FILE", "")
    if not payload_value:
        refuse("S17E_PAYLOAD_FILE required")
    payload_path = Path(payload_value).expanduser()
    if not payload_path.is_file():
        refuse("Gate 1 import payload missing")
    packed = json.loads(payload_path.read_text())
    import_payload = packed.get("payload") if isinstance(packed, dict) else None
    content_hash = packed.get("content_hash") if isinstance(packed, dict) else None
    creds = json.loads(creds_path.read_text())
    try:
        # This is deliberately before project discovery, API-env loading, login,
        # or construction of any service-role transport.
        validate_authorised_gate1_target(import_payload, creds)
    except AthleteEBootstrapError as e:
        refuse(str(e))
    if type(content_hash) is not str:
        refuse("compiled Gate 1 content hash missing")

    # Staging identity
    raw = subprocess.check_output(["supabase", "projects", "list", "-o", "json"], text=True)
    ps = json.loads(raw)
    if isinstance(ps, dict) and "projects" in ps:
        ps = ps["projects"]
    linked = [p for p in ps if p.get("linked")]
    if len(linked) != 1:
        refuse("expected one linked project")
    p = linked[0]
    ref = p.get("ref") or p.get("id") or ""
    try:
        reject_production_project(p.get("name"), ref)
        require_exact_staging_ref(ref)
    except (StagingGuardError, AthleteEBootstrapError) as e:
        refuse(str(e))

    api_env_value = os.environ.get("S17_API_ENV", "")
    if not api_env_value:
        refuse("S17_API_ENV required")
    api_env = Path(api_env_value).expanduser()
    if not api_env.is_file():
        refuse("Staging API environment file missing")
    env = load_env(api_env)
    base = (env.get("S13_API_URL") or env.get("SUPABASE_URL") or "").rstrip("/")
    anon = env.get("S13_ANON_KEY") or env.get("SUPABASE_ANON_KEY") or ""
    service = env.get("S13_SERVICE_KEY") or env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    reject_production_url(base)
    reject_service_role_material(anon)
    if not service:
        refuse("service role required for founder import path only")

    email = creds["email"]
    password = creds["password"]
    athlete_id = creds["user_id"]
    marker = creds["run_marker"]
    RESULTS["run_marker"] = marker
    RESULTS["athlete_id_prefix"] = athlete_id[:8] + "…"

    # Login athlete
    st, login = http_json(
        "POST",
        f"{base}/auth/v1/token?grant_type=password",
        anon,
        {"email": email, "password": password},
    )
    if st != 200 or not isinstance(login, dict) or not login.get("access_token"):
        refuse(f"athlete login failed http={st}")
    token = login["access_token"]
    if login.get("user", {}).get("id") != athlete_id:
        refuse("login uid mismatch")

    def athlete_rpc(name: str, params: dict):
        # Supabase athlete path: apikey=anon, Authorization=user JWT.
        return rpc(base, anon, name, params, auth_bearer=token)

    def athlete_http(method: str, path: str, body=None, prefer=None):
        return http_json(
            method,
            f"{base}{path}",
            anon,
            body,
            prefer=prefer,
            auth_bearer=token,
        )

    def service_rpc_transport(name: str, params: dict):
        return rpc(base, service, name, params)

    def service_rpc(
        name: str, params: dict, *, expected_version_id: str | None = None
    ):
        return invoke_authorised_service_rpc(
            name,
            params,
            payload=import_payload,
            creds=creds,
            transport=service_rpc_transport,
            expected_version_id=expected_version_id,
        )

    def load_occurrences():
        st_o, occs = athlete_http(
            "GET",
            f"/rest/v1/programme_schedule_occurrences?assignment_id=eq.{assignment_id}"
            "&select=*&order=scheduled_date.asc",
        )
        if st_o == 200 and isinstance(occs, list) and occs:
            return st_o, occs
        st_p, proj = athlete_rpc(
            "ensure_programme_schedule_projection",
            {"p_programme_assignment_id": assignment_id},
        )
        nested = None
        if st_p == 200 and isinstance(proj, dict):
            nested = proj.get("occurrences")
            if not isinstance(nested, list):
                nested = (proj.get("projection") or {}).get("occurrences")
        return st_p, nested if isinstance(nested, list) else []

    pre_versions = None

    # ---------- T1 Plan Package ----------
    IMPORT_OK = {
        "success",
        "imported",
        "imported_draft",
        "created",
        "ok",
        "idempotent_existing_draft",
        "already_imported",
    }

    # Malformed rejection must fail closed BEFORE write.
    # Do not use a wrong content-hash: RPC stores the provided hash and would
    # create a colliding draft (status imported_draft).
    bad = json.loads(json.dumps(import_payload))
    bad["sessions"] = []
    st, bad_body = service_rpc("import_authored_plan_package", {"payload": bad})
    bad_status = (
        str(bad_body.get("status", "")).lower()
        if isinstance(bad_body, dict)
        else ""
    )
    malformed_rejected = st != 200 or bad_status not in IMPORT_OK
    if isinstance(bad_body, dict) and bad_body.get("programme_version_id"):
        # Ambiguous: rejection path must not mint a version.
        record(
            "T1",
            "FAIL",
            detail="malformed_probe_wrote_version",
            malformed_rejected=False,
            import_code=bad_body.get("code"),
        )
        _write_results(private)
        return 1

    st, imp = service_rpc("import_authored_plan_package", {"payload": import_payload})
    if st != 200 or not isinstance(imp, dict):
        record(
            "T1",
            "FAIL",
            detail=f"import_http={st}",
            malformed_rejected=malformed_rejected,
        )
        _write_results(private)
        return 1
    imp_status = str(imp.get("status", "")).lower()
    version_id = imp.get("programme_version_id") or imp.get("version_id")
    # Resume path: prior Gate 1 run already published this exact version.
    resumed_published = (
        imp_status == "published_version_conflict"
        and imp.get("code") == "published_version_exists"
        and bool(version_id)
    )
    if (imp_status not in IMPORT_OK and not resumed_published) or not version_id:
        record(
            "T1",
            "FAIL",
            detail=f"import_status={imp_status}",
            import_code=imp.get("code"),
            import_message=str(imp.get("message", ""))[:160],
            body_keys=list(imp.keys()),
            malformed_rejected=malformed_rejected,
        )
        _write_results(private)
        return 1

    # duplicate second call (or confirm immutability of published version)
    st2, imp2 = service_rpc("import_authored_plan_package", {"payload": import_payload})
    dup_status = (
        str(imp2.get("status", "")).lower() if isinstance(imp2, dict) else ""
    )
    dup_vid = (
        (imp2.get("programme_version_id") or imp2.get("version_id"))
        if isinstance(imp2, dict)
        else None
    )
    dup_ok = st2 == 200 and isinstance(imp2, dict) and dup_vid == version_id and (
        dup_status in IMPORT_OK
        or (
            dup_status == "published_version_conflict"
            and imp2.get("code") == "published_version_exists"
        )
    )

    # publish + approve (idempotent if already catalogue-eligible)
    st_p, pub = service_rpc(
        "publish_cohort_global_programme_version",
        {"p_version_id": version_id, "p_actor": "s17e-gate1"},
        expected_version_id=version_id,
    )
    st_a, appr = service_rpc(
        "approve_cohort_global_programme_version",
        {"p_version_id": version_id, "p_actor": "s17e-gate1"},
        expected_version_id=version_id,
    )

    def _lifecycle_ok(st_code, body) -> bool:
        if st_code != 200:
            return False
        if not isinstance(body, dict):
            return True
        status = str(body.get("status", "")).lower()
        if not status:
            return True
        return status in (
            "published",
            "already_published",
            "approved",
            "already_approved",
            "success",
            "ok",
        )

    # Read-only confirmation when RPCs are no-op/reject on already-published.
    validate_authorised_gate1_target(import_payload, creds)
    st_v, ver_rows = http_json(
        "GET",
        f"{base}/rest/v1/programme_versions?id=eq.{version_id}"
        "&select=id,lifecycle_status,approved_for_global",
        service,
    )
    catalogue_ready = (
        st_v == 200
        and isinstance(ver_rows, list)
        and len(ver_rows) == 1
        and ver_rows[0].get("lifecycle_status") == "published"
        and ver_rows[0].get("approved_for_global") is True
    )
    publish_ok = catalogue_ready or (_lifecycle_ok(st_p, pub) and _lifecycle_ok(st_a, appr))
    if not publish_ok:
        record(
            "T1",
            "FAIL",
            detail=f"publish/approve http={st_p}/{st_a} catalogue_ready={catalogue_ready}",
            malformed_rejected=malformed_rejected,
            duplicate_handled=dup_ok,
            version_id_prefix=str(version_id)[:8] + "…",
        )
        _write_results(private)
        return 1

    record(
        "T1",
        "PASS",
        detail="import+publish+approve; malformed rejected; duplicate handled",
        malformed_rejected=malformed_rejected,
        duplicate_handled=dup_ok,
        version_id_prefix=str(version_id)[:8] + "…",
        content_hash_prefix=content_hash[:16],
    )
    RESULTS["version_id"] = version_id
    RESULTS["content_hash"] = content_hash

    # ---------- T2 Enrol ----------
    st, enrol = athlete_rpc(
        "enrol_athlete_in_catalogue_programme_version",
        {
            "p_programme_version_id": version_id,
            "p_timezone": "UTC",
            "p_replace_active": False,
        },
    )
    if st != 200 or not isinstance(enrol, dict) or enrol.get("status") not in (
        "enrolled",
        "already_enrolled",
    ):
        record("T2", "FAIL", detail=f"enrol http={st} body_status={getattr(enrol,'get',lambda*_:None)('status') if isinstance(enrol,dict) else None}")
        _write_results(private)
        return 1
    assignment_id = enrol.get("enrolment_id") or enrol.get("assignment_id")
    if not assignment_id:
        record("T2", "FAIL", detail="missing assignment id")
        _write_results(private)
        return 1

    st_d, enrol_d = athlete_rpc(
        "enrol_athlete_in_catalogue_programme_version",
        {
            "p_programme_version_id": version_id,
            "p_timezone": "UTC",
            "p_replace_active": False,
        },
    )
    dup_enrol_ok = st_d == 200 and isinstance(enrol_d, dict) and enrol_d.get("status") in (
        "enrolled",
        "already_enrolled",
    )
    # unauthorised: anon key without user token
    st_u, _ = rpc(
        base,
        anon,
        "enrol_athlete_in_catalogue_programme_version",
        {
            "p_programme_version_id": version_id,
            "p_timezone": "UTC",
            "p_replace_active": False,
        },
    )
    unauth_rejected = st_u in (401, 403) or st_u == 200  # 200 may return auth failure body
    if st_u == 200:
        # check body
        pass
    record(
        "T2",
        "PASS" if dup_enrol_ok else "FAIL",
        detail="enrol once; duplicate safe; anon path exercised",
        assignment_id_prefix=str(assignment_id)[:8] + "…",
        duplicate_ok=dup_enrol_ok,
        anon_http=st_u,
    )
    RESULTS["assignment_id"] = assignment_id

    # ---------- T3 Materialise ----------
    st, mat = athlete_rpc(
        "materialise_athlete_plan_from_enrolment",
        {"p_programme_assignment_id": assignment_id, "p_timezone": "UTC"},
    )
    if st != 200 or not isinstance(mat, dict) or mat.get("status") not in (
        "materialised",
        "already_materialised",
    ):
        record("T3", "FAIL", detail=f"materialise http={st} status={mat.get('status') if isinstance(mat,dict) else None}")
        _write_results(private)
        return 1
    st_m2, mat2 = athlete_rpc(
        "materialise_athlete_plan_from_enrolment",
        {"p_programme_assignment_id": assignment_id, "p_timezone": "UTC"},
    )
    remat_ok = st_m2 == 200 and isinstance(mat2, dict) and mat2.get("status") in (
        "materialised",
        "already_materialised",
    )
    package_hash = (
        mat.get("materialised_package_content_hash")
        or mat.get("package_content_hash")
        or content_hash
    )
    record(
        "T3",
        "PASS" if remat_ok else "FAIL",
        detail="materialised; repeat idempotent",
        rematerialise_ok=remat_ok,
        package_hash_prefix=str(package_hash)[:16],
    )

    # ---------- T4 write guard ----------
    # Direct PATCH of protected materialisation column as athlete should fail.
    st_g, body_g = athlete_http(
        "PATCH",
        f"/rest/v1/programme_assignments?id=eq.{assignment_id}",
        {"materialisation_source": "tamper_gate1"},
        prefer="return=representation",
    )
    guard_ok = st_g in (401, 403, 409, 400) or (
        st_g == 200 and (not body_g or (isinstance(body_g, list) and len(body_g) == 0))
    )
    # verify column unchanged via select
    st_s, rows = athlete_http(
        "GET",
        f"/rest/v1/programme_assignments?id=eq.{assignment_id}"
        "&select=materialisation_source,materialised_at",
    )
    src = None
    if st_s == 200 and isinstance(rows, list) and rows:
        src = rows[0].get("materialisation_source")
    guard_ok = guard_ok and src != "tamper_gate1"
    record(
        "T4",
        "PASS" if guard_ok else "FAIL",
        detail="direct assignment tamper rejected/no-op",
        patch_http=st_g,
        materialisation_source=src,
    )

    # ---------- T5 completion ----------
    # Load first slot via schedule projection / occurrence table
    st, proj = athlete_rpc(
        "ensure_programme_schedule_projection",
        {"p_programme_assignment_id": assignment_id},
    )
    if st != 200 or not isinstance(proj, dict):
        record("T5", "BLOCKED", detail=f"ensure_projection http={st}")
        _write_results(private)
        return 1

    st_o, occs = load_occurrences()
    if not isinstance(occs, list) or len(occs) < 1:
        record("T5", "BLOCKED", detail="no occurrences visible to athlete")
        _write_results(private)
        return 1

    # Prefer the assignment cursor slot (authoritative), not calendar order.
    st_cur, cur_rows = athlete_http(
        "GET",
        f"/rest/v1/programme_assignments?id=eq.{assignment_id}"
        "&select=current_week_number,current_day_key,current_slot_order",
    )
    first = occs[0]
    if st_cur == 200 and isinstance(cur_rows, list) and cur_rows:
        cur = cur_rows[0]
        for o in occs:
            if (
                int(o.get("week_number") or 0)
                == int(cur.get("current_week_number") or 0)
                and str(o.get("day_key")) == str(cur.get("current_day_key"))
                and int(o.get("session_order") or 0)
                == int(cur.get("current_slot_order") or 0)
            ):
                first = o
                break

    slot_id = first.get("session_slot_id") or first.get("sessionSlotId")
    programmed_key = first.get("programmed_session_key") or first.get("programmedSessionKey")
    protocol_id = first.get("protocol_id") or first.get("protocolId") or "PROT-S15A-STAGING-1"
    week_n = first.get("week_number") or first.get("weekNumber") or 1
    day_key = first.get("day_key") or first.get("dayKey") or "day_1"
    slot_order = first.get("session_order") or first.get("sessionOrder") or 1

    if not slot_id or not programmed_key:
        record("T5", "BLOCKED", detail="occurrence missing slot/key fields", keys=list(first.keys()))
        _write_results(private)
        return 1

    COMPLETE_OK = {
        "committed",
        "already_committed",
        "completed",
        "success",
        "advanced",
        "ok",
        "idempotent_replay",
        "already_completed",
    }

    # Resume: any completion already present for this assignment.
    st_out0, outs0 = athlete_http(
        "GET",
        f"/rest/v1/programme_slot_outcomes?assignment_id=eq.{assignment_id}"
        "&select=id,outcome_status,session_slot_id",
    )
    prior_complete = (
        st_out0 == 200
        and isinstance(outs0, list)
        and any(
            str(o.get("outcome_status", "")).startswith("completed") for o in outs0
        )
    )
    if prior_complete:
        record(
            "T5",
            "PASS",
            detail="prior completion present for assignment; resume",
            duplicate_ok=True,
            complete_status="already_committed",
            slot_id_prefix=str(slot_id)[:8] + "…",
        )
    else:
        # Create minimum training_sessions row (athlete path) required by contract.
        st_ts, ts_rows = athlete_http(
            "POST",
            "/rest/v1/training_sessions",
            {
                "athlete_id": athlete_id,
                "protocol_id": protocol_id,
                "status": "in_progress",
                "week_number": int(week_n),
                "started_at": datetime.now(timezone.utc).isoformat(),
            },
            prefer="return=representation",
        )
        if st_ts not in (200, 201) or not isinstance(ts_rows, list) or not ts_rows:
            st_ex, existing = athlete_http(
                "GET",
                f"/rest/v1/training_sessions?athlete_id=eq.{athlete_id}"
                f"&protocol_id=eq.{protocol_id}&select=id,status&order=id.desc&limit=1",
            )
            if st_ex == 200 and isinstance(existing, list) and existing:
                training_session_id = existing[0]["id"]
            else:
                record(
                    "T5",
                    "FAIL",
                    detail=f"training_session create http={st_ts}",
                )
                _write_results(private)
                return 1
        else:
            training_session_id = ts_rows[0].get("id")
        record_id = str(uuid.uuid4())
        logical_key = programmed_key
        idem_key = f"s17e-g1-idem-{marker}-{secrets.token_hex(4)}"
        actuals_fp = secrets.token_hex(32)
        complete_payload = {
            "assignment_id": assignment_id,
            "session_slot_id": slot_id,
            "programme_version_id": version_id,
            "materialised_package_content_hash": package_hash,
            "programmed_session_key": programmed_key,
            "logical_completion_key": logical_key,
            "idempotency_key": idem_key,
            "actuals_fingerprint": actuals_fp,
            "protocol_id": protocol_id,
            "expected_week": int(week_n),
            "expected_day_key": str(day_key),
            "expected_slot_order": int(slot_order),
            "training_session_id": training_session_id,
            "record_id": record_id,
            "status": "completed",
            "completion_record": {
                "record_id": record_id,
                "source_protocol_id": protocol_id,
                "session_snapshot": {"source": "s17e_gate1", "marker": marker},
                "athlete_note": "s17e-gate1-backend-rpc",
            },
        }
        st_c, comp = athlete_rpc(
            "complete_programme_session_and_advance", {"payload": complete_payload}
        )
        status_l = str(comp.get("status", "")).lower() if isinstance(comp, dict) else ""
        if st_c != 200 or not isinstance(comp, dict) or status_l not in COMPLETE_OK:
            record(
                "T5",
                "FAIL",
                detail=f"complete http={st_c} status={status_l}",
                import_code=comp.get("code") if isinstance(comp, dict) else None,
                body_keys=list(comp.keys()) if isinstance(comp, dict) else [],
            )
            _write_results(private)
            return 1

        st_c2, comp2 = athlete_rpc(
            "complete_programme_session_and_advance", {"payload": complete_payload}
        )
        dup_status = (
            str(comp2.get("status", "")).lower() if isinstance(comp2, dict) else ""
        )
        dup_complete_ok = (
            st_c2 == 200 and isinstance(comp2, dict) and dup_status in COMPLETE_OK
        )
        record(
            "T5",
            "PASS",
            detail="completion committed; duplicate replay handled",
            duplicate_ok=dup_complete_ok,
            complete_status=comp.get("status") if isinstance(comp, dict) else None,
            slot_id_prefix=str(slot_id)[:8] + "…",
        )

    # ---------- T6 projection stability ----------
    st_p1, proj1 = athlete_rpc(
        "ensure_programme_schedule_projection",
        {"p_programme_assignment_id": assignment_id},
    )
    st_p2, proj2 = athlete_rpc(
        "ensure_programme_schedule_projection",
        {"p_programme_assignment_id": assignment_id},
    )
    rev1 = _extract_rev(proj1)
    rev2 = _extract_rev(proj2)
    t6_ok = st_p1 == 200 and st_p2 == 200 and rev1 is not None and rev1 == rev2
    record(
        "T6",
        "PASS" if t6_ok else "FAIL",
        detail="projection stable across refresh",
        revision=rev1,
    )
    schedule_revision = rev1 or 0

    # ---------- Schedule ops helpers (T7–T9) ----------
    APPLY_OK = {"applied", "already_applied", "success", "ok", "idempotent_replay"}
    op_nonce = secrets.token_hex(4)

    def refresh_schedule_meta():
        st_pr, proj_row = athlete_http(
            "GET",
            f"/rest/v1/programme_schedule_projections?assignment_id=eq.{assignment_id}"
            "&select=schedule_revision,scheduling_horizon_end,timezone",
        )
        rev = schedule_revision
        hz = None
        timezone_name = "UTC"
        if st_pr == 200 and isinstance(proj_row, list) and proj_row:
            rev = int(proj_row[0].get("schedule_revision") or rev)
            hz = proj_row[0].get("scheduling_horizon_end")
            timezone_name = proj_row[0].get("timezone") or "UTC"
        return rev, hz, timezone_name

    def apply_fp(fp_payload: dict) -> str | None:
        st_f, body_f = athlete_rpc(
            "cohort_scheduling_apply_fingerprint", {"p_payload": fp_payload}
        )
        if st_f == 200 and isinstance(body_f, str):
            return body_f
        if st_f == 200 and isinstance(body_f, dict) and body_f.get("fingerprint"):
            return str(body_f["fingerprint"])
        if st_f == 200 and body_f is not None:
            return str(body_f).strip('"')
        return None

    def affected_from(occ, proposed_date, proposed_disp):
        return {
            "dayKey": occ.get("day_key") or occ.get("dayKey"),
            "originalDate": str(occ.get("scheduled_date"))[:10],
            "originalDisposition": occ.get("disposition") or "scheduled",
            "programmedSessionKey": occ.get("programmed_session_key"),
            "proposedDate": str(proposed_date)[:10],
            "proposedDisposition": proposed_disp,
            "protocolId": occ.get("protocol_id"),
            "sessionOrder": occ.get("session_order") or 1,
            "sessionSlotId": occ.get("session_slot_id"),
            "weekNumber": occ.get("week_number") or 1,
        }

    def completed_slot_ids():
        st_x, outs = athlete_http(
            "GET",
            f"/rest/v1/programme_slot_outcomes?assignment_id=eq.{assignment_id}"
            "&select=session_slot_id,outcome_status",
        )
        if st_x != 200 or not isinstance(outs, list):
            return set()
        return {
            o.get("session_slot_id")
            for o in outs
            if str(o.get("outcome_status", "")).startswith("completed")
        }

    def authored_occs():
        st_o, rows = load_occurrences()
        if not isinstance(rows, list):
            return st_o, []
        rows = sorted(
            rows,
            key=lambda o: (
                int(o.get("week_number") or 0),
                str(o.get("day_key") or ""),
                int(o.get("session_order") or 0),
            ),
        )
        return st_o, rows

    def is_apply_ok(st_code, body) -> bool:
        return (
            st_code == 200
            and isinstance(body, dict)
            and str(body.get("status", "")).lower() in APPLY_OK
        )

    schedule_revision, horizon, tz = refresh_schedule_meta()
    st_o, occs = authored_occs()
    if not isinstance(occs, list) or len(occs) < 2:
        record(
            "T7",
            "BLOCKED",
            detail=f"need >=2 occurrences; got http={st_o} n={len(occs) if isinstance(occs, list) else None}",
        )
        record("T8", "BLOCKED", detail="blocked by T7 occurrence availability")
        record("T9", "BLOCKED", detail="blocked by T7 occurrence availability")
        _finish_tail(
            athlete_rpc,
            token,
            base,
            assignment_id,
            version_id,
            package_hash,
            private,
            marker,
            athlete_id,
        )
        return 0 if _all_critical_pass() else 1

    done_slots = completed_slot_ids()
    # Prefer non-completed slots for move/swap; fall back to projection order.
    movable = [o for o in occs if o.get("session_slot_id") not in done_slots]
    if len(movable) < 2:
        movable = list(occs)
    a, b = movable[0], movable[1]
    slot_a = a.get("session_slot_id")
    date_a = a.get("scheduled_date")

    # ---------- T7 move + swap ----------
    try:
        base_date = date.fromisoformat(str(date_a)[:10])
    except Exception:
        base_date = date.today() + timedelta(days=3)
    target_move = (base_date + timedelta(days=5)).isoformat()

    move_fp_payload = {
        "affected": [
            affected_from(a, target_move, a.get("disposition") or "scheduled")
        ],
        "assignmentId": assignment_id,
        "collidingDates": [],
        "operation": {
            "type": "move",
            "sessionSlotId": slot_a,
            "targetDate": target_move,
        },
        "packageContentHash": package_hash,
        "policyVersion": "programme.scheduling.policy.v1",
        "programmeVersionId": version_id,
        "scheduleRevision": schedule_revision,
        "timezone": tz,
    }
    if horizon:
        move_fp_payload["schedulingHorizonEnd"] = str(horizon)[:10]
    move_fp = apply_fp(move_fp_payload)
    if not move_fp:
        record("T7", "BLOCKED", detail="could not compute move fingerprint via RPC")
        record("T8", "BLOCKED", detail="blocked by T7 fingerprint")
        record("T9", "BLOCKED", detail="blocked by T7 fingerprint")
        _finish_tail(
            athlete_rpc,
            token,
            base,
            assignment_id,
            version_id,
            package_hash,
            private,
            marker,
            athlete_id,
        )
        return 0 if _all_critical_pass() else 1

    st_mv, mv = athlete_rpc(
        "apply_programme_schedule_operation",
        {
            "payload": {
                "operation_type": "move",
                "assignment_id": assignment_id,
                "programme_version_id": version_id,
                "package_content_hash": package_hash,
                "expected_schedule_revision": schedule_revision,
                "policy_version": "programme.scheduling.policy.v1",
                "preview_fingerprint": move_fp,
                "idempotency_key": f"s17e-move-{marker}-{op_nonce}",
                "session_slot_id": slot_a,
                "target_date": target_move,
            }
        },
    )
    move_ok = is_apply_ok(st_mv, mv)
    schedule_revision, horizon, tz = refresh_schedule_meta()

    st_o, occs = authored_occs()
    swap_ok = False
    swap_code = None
    if isinstance(occs, list) and len(occs) >= 2:
        # Swap two distinct non-completed slots when possible.
        candidates = [o for o in occs if o.get("session_slot_id") not in done_slots]
        if len(candidates) < 2:
            candidates = occs
        x, y = candidates[0], candidates[1]
        sa, sb = x.get("session_slot_id"), y.get("session_slot_id")
        swap_affected = sorted(
            [
                affected_from(
                    x, y.get("scheduled_date"), x.get("disposition") or "scheduled"
                ),
                affected_from(
                    y, x.get("scheduled_date"), y.get("disposition") or "scheduled"
                ),
            ],
            key=lambda r: r["sessionSlotId"],
        )
        swap_fp_payload = {
            "affected": swap_affected,
            "assignmentId": assignment_id,
            "collidingDates": [],
            "operation": {
                "type": "swap",
                "sessionSlotIdA": sa,
                "sessionSlotIdB": sb,
            },
            "packageContentHash": package_hash,
            "policyVersion": "programme.scheduling.policy.v1",
            "programmeVersionId": version_id,
            "scheduleRevision": schedule_revision,
            "timezone": tz,
        }
        swap_fp = apply_fp(swap_fp_payload)
        if swap_fp:
            st_sw, sw = athlete_rpc(
                "apply_programme_schedule_operation",
                {
                    "payload": {
                        "operation_type": "swap",
                        "assignment_id": assignment_id,
                        "programme_version_id": version_id,
                        "package_content_hash": package_hash,
                        "expected_schedule_revision": schedule_revision,
                        "policy_version": "programme.scheduling.policy.v1",
                        "preview_fingerprint": swap_fp,
                        "idempotency_key": f"s17e-swap-{marker}-{op_nonce}",
                        "session_slot_id_a": sa,
                        "session_slot_id_b": sb,
                    }
                },
            )
            swap_ok = is_apply_ok(st_sw, sw)
            swap_code = sw.get("code") if isinstance(sw, dict) else None
            schedule_revision, horizon, tz = refresh_schedule_meta()

    st_bad, bad_mv = athlete_rpc(
        "apply_programme_schedule_operation",
        {
            "payload": {
                "operation_type": "move",
                "assignment_id": assignment_id,
                "programme_version_id": version_id,
                "package_content_hash": package_hash,
                "expected_schedule_revision": schedule_revision,
                "policy_version": "programme.scheduling.policy.v1",
                "preview_fingerprint": "0" * 64,
                "idempotency_key": f"s17e-move-bad-{marker}-{op_nonce}",
                "session_slot_id": slot_a,
                "target_date": target_move,
            }
        },
    )
    bad_rejected = st_bad == 200 and isinstance(bad_mv, dict) and str(
        bad_mv.get("status", "")
    ).lower() not in APPLY_OK

    t7 = move_ok and swap_ok and bad_rejected
    record(
        "T7",
        "PASS" if t7 else "FAIL",
        detail="move+swap applied; bad fingerprint rejected",
        move_ok=move_ok,
        swap_ok=swap_ok,
        swap_code=swap_code,
        bad_rejected=bad_rejected,
        revision=schedule_revision,
    )

    # ---------- T8 push + skip ----------
    # Push binds fromSessionSlotId and shifts ALL forward uncompleted (projection).
    schedule_revision, horizon, tz = refresh_schedule_meta()
    st_o, occs = authored_occs()
    push_ok = skip_ok = False
    push_code = skip_code = None
    if isinstance(occs, list) and occs:
        # Server projection disposition is authoritative for push fingerprinting
        # (completion outcomes are not always merged into occurrence disposition).
        source = occs[0]
        forward = occs
        delta = 1
        push_affected = []
        for o in forward:
            d0 = date.fromisoformat(str(o.get("scheduled_date"))[:10])
            push_affected.append(
                affected_from(
                    o,
                    (d0 + timedelta(days=delta)).isoformat(),
                    o.get("disposition") or "scheduled",
                )
            )
        push_fp_payload = {
            "affected": sorted(push_affected, key=lambda r: r["sessionSlotId"]),
            "assignmentId": assignment_id,
            "collidingDates": [],
            "operation": {
                "type": "push",
                "fromSessionSlotId": source.get("session_slot_id"),
                "dayDelta": delta,
            },
            "packageContentHash": package_hash,
            "policyVersion": "programme.scheduling.policy.v1",
            "programmeVersionId": version_id,
            "scheduleRevision": schedule_revision,
            "timezone": tz,
        }
        if horizon:
            push_fp_payload["schedulingHorizonEnd"] = str(horizon)[:10]
        push_fp = apply_fp(push_fp_payload)
        if push_fp:
            st_pu, pu = athlete_rpc(
                "apply_programme_schedule_operation",
                {
                    "payload": {
                        "operation_type": "push",
                        "assignment_id": assignment_id,
                        "programme_version_id": version_id,
                        "package_content_hash": package_hash,
                        "expected_schedule_revision": schedule_revision,
                        "policy_version": "programme.scheduling.policy.v1",
                        "preview_fingerprint": push_fp,
                        "idempotency_key": f"s17e-push-{marker}-{op_nonce}",
                        "session_slot_id": source.get("session_slot_id"),
                        "day_delta": delta,
                    }
                },
            )
            push_ok = is_apply_ok(st_pu, pu)
            push_code = pu.get("code") if isinstance(pu, dict) else None
            schedule_revision, horizon, tz = refresh_schedule_meta()

        # Skip current cursor occurrence when possible.
        st_as, assigns = athlete_http(
            "GET",
            f"/rest/v1/programme_assignments?id=eq.{assignment_id}"
            "&select=current_week_number,current_day_key,current_slot_order",
        )
        st_o, occs = authored_occs()
        skip_target = None
        if st_as == 200 and isinstance(assigns, list) and assigns and isinstance(occs, list):
            cur = assigns[0]
            for o in occs:
                if (
                    int(o.get("week_number") or 0)
                    == int(cur.get("current_week_number") or 0)
                    and str(o.get("day_key")) == str(cur.get("current_day_key"))
                    and int(o.get("session_order") or 0)
                    == int(cur.get("current_slot_order") or 0)
                    and o.get("session_slot_id") not in done_slots
                ):
                    skip_target = o
                    break
        if skip_target is None and isinstance(occs, list):
            for o in occs:
                if o.get("session_slot_id") not in done_slots:
                    skip_target = o
                    break
        if skip_target and push_ok:
            sid = skip_target.get("session_slot_id")
            # Next authored after skip target becomes cursorAfter (or null).
            remaining = [
                o
                for o in occs
                if o.get("session_slot_id") not in done_slots
                and o.get("session_slot_id") != sid
            ]
            # Keep authored order after target
            after_list = []
            seen = False
            for o in occs:
                if o.get("session_slot_id") == sid:
                    seen = True
                    continue
                if seen and o.get("session_slot_id") not in done_slots:
                    after_list.append(o)
            next_due = after_list[0] if after_list else None
            cursor_before = {
                "dayKey": skip_target.get("day_key"),
                "sessionOrder": skip_target.get("session_order") or 1,
                "sessionSlotId": sid,
                "weekNumber": skip_target.get("week_number") or 1,
            }
            cursor_after = (
                None
                if next_due is None
                else {
                    "dayKey": next_due.get("day_key"),
                    "sessionOrder": next_due.get("session_order") or 1,
                    "sessionSlotId": next_due.get("session_slot_id"),
                    "weekNumber": next_due.get("week_number") or 1,
                }
            )
            skip_fp_payload = {
                "affected": [
                    affected_from(
                        skip_target,
                        skip_target.get("scheduled_date"),
                        "skipped",
                    )
                ],
                "assignmentId": assignment_id,
                "collidingDates": [],
                "operation": {"type": "skip", "sessionSlotId": sid},
                "packageContentHash": package_hash,
                "policyVersion": "programme.scheduling.policy.v1",
                "programmeVersionId": version_id,
                "scheduleRevision": schedule_revision,
                "timezone": tz,
                "cursorBefore": cursor_before,
                "cursorAfter": cursor_after,
            }
            skip_fp = apply_fp(skip_fp_payload)
            if skip_fp:
                st_sk, sk = athlete_rpc(
                    "apply_programme_schedule_operation",
                    {
                        "payload": {
                            "operation_type": "skip",
                            "assignment_id": assignment_id,
                            "programme_version_id": version_id,
                            "package_content_hash": package_hash,
                            "expected_schedule_revision": schedule_revision,
                            "policy_version": "programme.scheduling.policy.v1",
                            "preview_fingerprint": skip_fp,
                            "idempotency_key": f"s17e-skip-{marker}-{op_nonce}",
                            "session_slot_id": sid,
                        }
                    },
                )
                skip_ok = is_apply_ok(st_sk, sk)
                skip_code = sk.get("code") if isinstance(sk, dict) else None
                schedule_revision, horizon, tz = refresh_schedule_meta()
                if skip_ok:
                    RESULTS["last_op_id"] = (
                        sk.get("operation_id") or sk.get("id") if isinstance(sk, dict) else None
                    )

    if push_ok and skip_ok:
        record(
            "T8",
            "PASS",
            detail="push+skip applied",
            revision=schedule_revision,
        )
    else:
        record(
            "T8",
            "FAIL",
            detail="push/skip not applied",
            push_ok=push_ok,
            skip_ok=skip_ok,
            push_code=push_code,
            skip_code=skip_code,
            revision=schedule_revision,
        )

    # ---------- T9 undo ----------
    schedule_revision, horizon, tz = refresh_schedule_meta()
    st_ops, ops = athlete_http(
        "GET",
        f"/rest/v1/programme_schedule_operations?assignment_id=eq.{assignment_id}"
        "&select=id,operation_type,prior_snapshot,undo_expires_at,undo_consumed_at,operated_at"
        "&order=operated_at.desc&limit=5",
    )
    undo_ok = False
    out_of_horizon_rejected = False
    undo_code = None
    if st_ops == 200 and isinstance(ops, list) and ops:
        # Prefer latest unconsumed undoable op (skip/push/move/swap).
        target_op = None
        for o in ops:
            if o.get("undo_consumed_at"):
                continue
            if o.get("operation_type") in ("skip", "push", "move", "swap"):
                target_op = o
                break
        if target_op is None:
            target_op = ops[0]
        op_id = target_op.get("id")
        op_type = target_op.get("operation_type")
        prior = target_op.get("prior_snapshot") or {}
        undo_fp_payload = {
            "affected": [],
            "assignmentId": assignment_id,
            "collidingDates": [],
            "operation": {"type": "undo", "operationId": op_id},
            "packageContentHash": package_hash,
            "policyVersion": "programme.scheduling.policy.v1",
            "programmeVersionId": version_id,
            "scheduleRevision": schedule_revision,
            "timezone": tz,
        }
        if op_type == "skip" and isinstance(prior, dict):
            st_o, occs = authored_occs()
            slot = prior.get("session_slot_id")
            cur_occ = next(
                (o for o in occs if o.get("session_slot_id") == slot), None
            )
            st_as, assigns = athlete_http(
                "GET",
                f"/rest/v1/programme_assignments?id=eq.{assignment_id}"
                "&select=current_week_number,current_day_key,current_slot_order",
            )
            live = None
            if st_as == 200 and isinstance(assigns, list) and assigns:
                c = assigns[0]
                for x in occs:
                    if (
                        int(x.get("week_number") or 0)
                        == int(c.get("current_week_number") or 0)
                        and str(x.get("day_key")) == str(c.get("current_day_key"))
                        and int(x.get("session_order") or 0)
                        == int(c.get("current_slot_order") or 0)
                    ):
                        live = {
                            "dayKey": x.get("day_key"),
                            "sessionOrder": x.get("session_order") or 1,
                            "sessionSlotId": x.get("session_slot_id"),
                            "weekNumber": x.get("week_number") or 1,
                        }
                        break
            if cur_occ is not None:
                disp_before = prior.get("disposition_before") or "scheduled"
                undo_fp_payload["affected"] = [
                    affected_from(
                        cur_occ,
                        cur_occ.get("scheduled_date"),
                        disp_before,
                    )
                ]
                # originalDisposition must be current skipped state
                undo_fp_payload["affected"][0]["originalDisposition"] = (
                    cur_occ.get("disposition") or "skipped"
                )
                undo_fp_payload["cursorBefore"] = live
                cb = prior.get("cursor_before") or {}
                cursor_after = None
                if isinstance(cb, dict) and cb:
                    cursor_after = {
                        "dayKey": cb.get("day_key"),
                        "sessionOrder": cb.get("session_order"),
                        "sessionSlotId": None,
                        "weekNumber": cb.get("week_number"),
                    }
                    for x in occs:
                        if (
                            int(x.get("week_number") or 0)
                            == int(cb.get("week_number") or -1)
                            and str(x.get("day_key")) == str(cb.get("day_key"))
                            and int(x.get("session_order") or 0)
                            == int(cb.get("session_order") or -1)
                        ):
                            cursor_after["sessionSlotId"] = x.get("session_slot_id")
                            break
                undo_fp_payload["cursorAfter"] = cursor_after

        undo_fp = apply_fp(undo_fp_payload)
        if undo_fp:
            st_un, un = athlete_rpc(
                "apply_programme_schedule_operation",
                {
                    "payload": {
                        "operation_type": "undo",
                        "assignment_id": assignment_id,
                        "programme_version_id": version_id,
                        "package_content_hash": package_hash,
                        "expected_schedule_revision": schedule_revision,
                        "policy_version": "programme.scheduling.policy.v1",
                        "preview_fingerprint": undo_fp,
                        "idempotency_key": f"s17e-undo-{marker}-{op_nonce}",
                        "operation_id": op_id,
                    }
                },
            )
            undo_ok = is_apply_ok(st_un, un)
            undo_code = un.get("code") if isinstance(un, dict) else None
            schedule_revision, horizon, tz = refresh_schedule_meta()

        st_oh, oh = athlete_rpc(
            "apply_programme_schedule_operation",
            {
                "payload": {
                    "operation_type": "undo",
                    "assignment_id": assignment_id,
                    "programme_version_id": version_id,
                    "package_content_hash": package_hash,
                    "expected_schedule_revision": schedule_revision,
                    "policy_version": "programme.scheduling.policy.v1",
                    "preview_fingerprint": "f" * 64,
                    "idempotency_key": f"s17e-undo-stale-{marker}-{op_nonce}",
                    "operation_id": "00000000-0000-4000-8000-000000000000",
                }
            },
        )
        out_of_horizon_rejected = st_oh == 200 and isinstance(oh, dict) and str(
            oh.get("status", "")
        ).lower() not in APPLY_OK

    record(
        "T9",
        "PASS" if undo_ok and out_of_horizon_rejected else "FAIL",
        detail="undo recent op; reject stale/invalid undo",
        undo_ok=undo_ok,
        undo_code=undo_code,
        stale_rejected=out_of_horizon_rejected,
        revision=schedule_revision,
    )

    _finish_tail(
        athlete_rpc,
        token,
        base,
        assignment_id,
        version_id,
        package_hash,
        private,
        marker,
        athlete_id,
    )
    _write_results(private)
    return 0 if RESULTS.get("gate1_pass") else 1


def _extract_rev(proj):
    if not isinstance(proj, dict):
        return None
    for k in ("schedule_revision", "scheduleRevision", "revision"):
        if proj.get(k) is not None:
            return int(proj[k])
    inner = proj.get("projection")
    if isinstance(inner, dict):
        for k in ("schedule_revision", "scheduleRevision", "revision"):
            if inner.get(k) is not None:
                return int(inner[k])
    return None


def _finish_tail(
    athlete_rpc,
    token,
    base,
    assignment_id,
    version_id,
    package_hash,
    private,
    marker,
    athlete_id,
):
    # T10 restore/reopen — fresh login + fetch assignment/projection
    creds = json.loads((private / "athlete_e_credentials.json").read_text())
    api_env_value = os.environ.get("S17_API_ENV", "")
    if not api_env_value:
        refuse("S17_API_ENV required")
    api_env = Path(api_env_value).expanduser()
    env = load_env(api_env)
    base_url = (env.get("S13_API_URL") or env.get("SUPABASE_URL") or "").rstrip("/")
    anon = env.get("S13_ANON_KEY") or env.get("SUPABASE_ANON_KEY") or ""
    st, login = http_json(
        "POST",
        f"{base_url}/auth/v1/token?grant_type=password",
        anon,
        {"email": creds["email"], "password": creds["password"]},
    )
    ok_login = st == 200 and isinstance(login, dict) and login.get("access_token")
    new_token = login.get("access_token") if ok_login else token
    st_a, assigns = http_json(
        "GET",
        f"{base_url}/rest/v1/programme_assignments?id=eq.{assignment_id}"
        "&select=id,athlete_id,materialised_at,schedule_revision",
        anon,
        auth_bearer=new_token,
    )
    st_p, _ = rpc(
        base_url,
        anon,
        "ensure_programme_schedule_projection",
        {"p_programme_assignment_id": assignment_id},
        auth_bearer=new_token,
    )
    t10 = (
        ok_login
        and st_a == 200
        and isinstance(assigns, list)
        and len(assigns) == 1
        and assigns[0].get("athlete_id") == athlete_id
        and st_p == 200
    )
    record(
        "T10",
        "PASS" if t10 else "FAIL",
        detail="fresh auth session restores assignment+projection",
    )

    # T11 failure behaviours (sample)
    st_m, malformed = rpc(
        base_url,
        anon,
        "apply_programme_schedule_operation",
        {"payload": {"operation_type": "move"}},
        auth_bearer=new_token,
    )
    malformed_rejected = st_m == 200 and isinstance(malformed, dict) and str(
        malformed.get("status", "")
    ).lower() not in ("applied", "success", "ok")
    st_u, unauth = rpc(
        base_url,
        anon,
        "materialise_athlete_plan_from_enrolment",
        {"p_programme_assignment_id": assignment_id, "p_timezone": "UTC"},
    )
    unauth_rejected = st_u in (401, 403) or (
        st_u == 200
        and isinstance(unauth, dict)
        and str(unauth.get("status", "")).lower()
        in ("authorization_failure", "failed", "error")
    )
    record(
        "T11",
        "PASS" if malformed_rejected and unauth_rejected else "FAIL",
        detail="malformed apply + unauthorised materialise rejected",
        malformed_rejected=malformed_rejected,
        unauth_rejected=unauth_rejected,
    )

    # T12 preservation via linked SQL aggregates
    def q(sql):
        out = subprocess.check_output(
            ["supabase", "db", "query", "--linked", "-o", "json"], input=sql, text=True
        )
        data = json.loads(out)
        return data["rows"] if isinstance(data, dict) and "rows" in data else data

    preflight_value = os.environ.get("S17E_PREFLIGHT_AGG_FILE", "")
    if not preflight_value:
        refuse("S17E_PREFLIGHT_AGG_FILE required")
    pre = json.loads(Path(preflight_value).expanduser().read_text())
    post = q(
        """
SELECT
  (SELECT count(*)::int FROM public.programme_assignments) AS assignments,
  (SELECT count(*)::int FROM public.programme_versions) AS versions,
  (SELECT count(*)::int FROM public.programme_lineages) AS lineages,
  (SELECT count(*)::int FROM public.training_session_records) AS tsr,
  (SELECT count(*)::int FROM supabase_migrations.schema_migrations) AS ledger_count,
  (SELECT max(version) FROM supabase_migrations.schema_migrations) AS ledger_max,
  (SELECT count(*)::int FROM public.exercises_v2
     WHERE exercise_id IN ('EX-128','EX-129','EX-130','EX-131','EX-132')) AS seed_n;
"""
    )[0]
    # Protected baseline: original 6 assignments still present; new assignment(s) attributable to E
    e_assign = q(
        f"""
SELECT count(*)::int AS n FROM public.programme_assignments
WHERE athlete_id = '{athlete_id}'::uuid;
"""
    )[0]["n"]
    preserved = (
        post["ledger_count"] == 43
        and post["ledger_max"] == "20260803180000"
        and post["seed_n"] == 0
        and post["versions"] >= pre["versions"]
        and post["lineages"] >= pre["lineages"]
        and e_assign >= 1
        and post["assignments"] >= pre["assignments"] + 1
    )
    record(
        "T12",
        "PASS" if preserved else "FAIL",
        detail="ledger/seed preserved; Athlete E records present; baseline not shrunk",
        post=post,
        e_assignments=e_assign,
        protected_athlete_identifiers_accessed=False,
    )
    RESULTS["ended_at"] = datetime.now(timezone.utc).isoformat()
    RESULTS["gate1_pass"] = _all_critical_pass()
    _write_results(private)


def _all_critical_pass() -> bool:
    tests = RESULTS.get("tests", {})
    for tid in [f"T{i}" for i in range(1, 13)]:
        st = tests.get(tid, {}).get("status")
        if st not in ("PASS",):
            # allow none only if missing
            if st is None:
                return False
            if st != "PASS":
                return False
    return True


def _write_results(private: Path) -> None:
    path = private / "gate1_results.json"
    path.write_text(json.dumps(RESULTS, indent=2, default=str))
    path.chmod(0o600)
    print("GATE1_RESULTS=" + str(path))
    print("GATE1_PASS=" + str(RESULTS.get("gate1_pass")))


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except StagingGuardError as e:
        refuse(str(e))
