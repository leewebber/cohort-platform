#!/usr/bin/env bash
# Read-only Athlete D staging diagnostic (B4d.2).
# Does NOT enrol, switch, materialise, prepare, project, complete, or adapt.
# Passes private dart-define path through guarded validation only — never prints secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage:
  CONFIRM_COHORT_STAGING=1 \\
    S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \\
    ./tool/staging/diagnose_s17_athlete_d_readonly.sh

Read-only. Never invokes creator. Never mutates hosted state.
EOF
  exit 0
fi

s17_require_confirmation
s17_require_commands python3
s17_confirm_staging_identity

DEFINES_FILE="${S17_DART_DEFINES_FILE:-}"
if [[ -z "$DEFINES_FILE" ]]; then
  echo "REFUSED: set S17_DART_DEFINES_FILE to the private dart-define JSON path." >&2
  exit 2
fi

export S17_DART_DEFINES_FILE
export S17_DIAG_ROOT="$ROOT"

python3 - <<'PY'
import json, os, sys, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(os.environ["S17_DIAG_ROOT"])
sys.path.insert(0, str(ROOT / "tool/staging/lib"))
from s17_staging_guard import (
    StagingGuardError,
    assert_outside_git_worktrees,
    assert_private_file,
    redact_uuid,
    reject_production_url,
    reject_service_role_material,
    validate_athlete_d_email,
    validate_run_marker,
)

path = Path(os.environ["S17_DART_DEFINES_FILE"]).expanduser()
try:
    if path.is_symlink():
        raise StagingGuardError("REFUSED: dart-define file must not be a symlink")
    assert_private_file(path)
    assert_outside_git_worktrees(path, [ROOT])
    data = json.loads(path.read_text())
    if str(data.get("S17_STAGING_ENABLED", "")).lower() != "true":
        raise StagingGuardError("REFUSED: S17_STAGING_ENABLED must be true")
    url = str(data.get("S17_SUPABASE_URL", "")).rstrip("/")
    anon = str(data.get("S17_SUPABASE_ANON_KEY", ""))
    email = str(data.get("S17_ATHLETE_EMAIL", ""))
    password = str(data.get("S17_ATHLETE_PASSWORD", ""))
    athlete_id = str(data.get("S17_ATHLETE_ID", ""))
    marker = str(data.get("S17_RUN_MARKER", ""))
    reject_production_url(url)
    reject_service_role_material(anon, json.dumps(data))
    validate_run_marker(marker)
    validate_athlete_d_email(email, marker)
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)

print("READONLY_DIAG mode=read_only creator_invocation=forbidden writes=none")


def http(method, path_suffix, body=None, token=None):
    headers = {
        "apikey": anon,
        "Content-Type": "application/json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    payload = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url + path_suffix, data=payload, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {"error": "http_error"}
        return e.code, parsed


st, login = http(
    "POST",
    "/auth/v1/token?grant_type=password",
    {"email": email, "password": password},
)
if st != 200 or not isinstance(login, dict) or not login.get("access_token"):
    print(json.dumps({"ok": False, "auth": "FAIL", "detail": "sign_in_failed"}))
    raise SystemExit(1)
token = login["access_token"]
uid = (login.get("user") or {}).get("id") or ""
auth_ok = uid == athlete_id

st, profile = http(
    "GET",
    f"/rest/v1/profiles?id=eq.{athlete_id}&select=is_coach,is_athlete",
    token=token,
)
is_coach = False
is_athlete = True
if st == 200 and isinstance(profile, list) and profile:
    is_coach = bool(profile[0].get("is_coach"))
    is_athlete = bool(profile[0].get("is_athlete", True))

st, rows = http(
    "GET",
    (
        f"/rest/v1/programme_assignments?athlete_id=eq.{athlete_id}"
        "&status=eq.active"
        "&select=id,lineage_code,programme_version_id,materialised_at,"
        "materialised_package_content_hash,timezone,status,started_at"
    ),
    token=token,
)
own = rows[0] if st == 200 and isinstance(rows, list) and rows else None

foreign_probe = None
stf, frows = http(
    "GET",
    (
        f"/rest/v1/programme_assignments?athlete_id=neq.{athlete_id}"
        "&select=id&limit=1"
    ),
    token=token,
)
if stf == 200 and isinstance(frows, list):
    foreign_probe = len(frows) > 0
else:
    foreign_probe = None

stc, cat = http(
    "GET",
    (
        "/rest/v1/programme_versions?lineage_code=eq.PROG-S15A-STAGING"
        "&lifecycle_status=eq.published"
        "&select=id,lineage_code,lifecycle_status,approved_for_global,"
        "library_scope,package_content_hash&limit=3"
    ),
    token=token,
)
catalogue_visible = False
catalogue_eligible = False
version_prefix = None
if stc == 200 and isinstance(cat, list) and cat:
    catalogue_visible = True
    row = cat[0]
    catalogue_eligible = (
        row.get("approved_for_global") is True
        and row.get("library_scope") == "cohort_global"
        and bool(row.get("package_content_hash"))
    )
    version_prefix = redact_uuid(str(row.get("id") or ""))

report = {
    "ok": True,
    "mode": "read_only",
    "creator_invocation": "forbidden",
    "writes": "none",
    "run_marker": marker,
    "auth": "PASS" if auth_ok else "FAIL",
    "profile": {"is_athlete": is_athlete, "is_coach": is_coach},
    "own_active_assignment": None
    if own is None
    else {
        "assignment_id_prefix": redact_uuid(str(own.get("id") or "")),
        "version_id_prefix": redact_uuid(
            str(own.get("programme_version_id") or "")
        ),
        "lineage_code": own.get("lineage_code"),
        "status": own.get("status"),
        "timezone_present": bool((own.get("timezone") or "").strip()),
        "materialised": own.get("materialised_at") is not None,
        "package_hash_present": bool(
            (own.get("materialised_package_content_hash") or "").strip()
        ),
        "started_at_present": own.get("started_at") is not None,
    },
    "isolation": {
        "auth": "PASS" if auth_ok else "FAIL",
        "own_row": (
            "PASS"
            if own is not None and not is_coach and is_athlete
            else ("UNSUPPORTED" if is_coach else "FAIL")
        ),
        "foreign_row_visible": foreign_probe,
        "foreign_denial": (
            "UNSUPPORTED"
            if is_coach
            else (
                "UNCERTAIN"
                if foreign_probe is None
                else ("FAIL" if foreign_probe else "PASS")
            )
        ),
    },
    "catalogue_prog_s15a": {
        "visible": catalogue_visible,
        "eligible_fields": catalogue_eligible,
        "version_id_prefix": version_prefix,
    },
    "notes": [
        "No enrol/switch/materialise/prepare/projection RPCs invoked",
        "Foreign probe reports presence only; ids never printed",
    ],
}
print(json.dumps(report, indent=2))
print("S17_READONLY_DIAG_COMPLETE")
raise SystemExit(0 if auth_ok else 1)
PY
