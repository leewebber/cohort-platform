#!/usr/bin/env bash
# Create isolated Cohort Staging Athlete D fixture for Phase 1.6 / Sprint 1.7.
#
# Fail-closed:
#   CONFIRM_COHORT_STAGING=1 required
#   Linked/selected project must be Cohort Staging (tsbadngz…, eu-west-2)
#   Production candidate (otnhhdxs… / Cohort Field Manual) rejected
#   Never enumerates, reuses, or mutates any existing athlete identity
#
# Modes:
#   --help
#   --dry-run   identity + plan only; no hosted write
#   (default)   create Athlete D + enrol into immutable PROG-S13-ELIG + materialise
#
# Credentials and dart-define config are written only under a private /tmp dir
# (mode 700 / files 600), never into the repository.
#
# B4a authorises local implementation only. Hosted create remains B4b.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

DRY_RUN=0
SHOW_HELP=0

usage() {
  cat <<'EOF'
Usage:
  CONFIRM_COHORT_STAGING=1 ./tool/staging/create_s17_athlete_d_fixture.sh [--dry-run]

Creates one isolated Athlete D staging identity and minimum fixture for Phase 1
journeys (catalogue enrol → materialise on immutable PROG-S13-ELIG).

Options:
  --dry-run   Confirm staging identity and print redacted plan; no hosted write
  --help      Show this help

Environment:
  CONFIRM_COHORT_STAGING=1   Required confirmation
  S17_API_ENV                Optional path to staging API env (URL + anon + service)
                             Default: /tmp/s13b_api.env (operator-local; never committed)

Does not modify shared .env, tracked secret stubs, existing athletes, or production.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) SHOW_HELP=1; shift ;;
    *)
      echo "REFUSED: unknown flag $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$SHOW_HELP" -eq 1 ]]; then
  usage
  exit 0
fi

s17_require_confirmation
s17_require_commands python3 supabase
s17_confirm_staging_identity

RUN_MARKER="$(python3 - <<'PY'
from datetime import datetime, timezone
import secrets
stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
print(f"s17_stage_{stamp}_{secrets.token_hex(4)}")
PY
)"

PRIVATE_DIR="$(mktemp -d "/tmp/cohort_s17_athlete_d.${RUN_MARKER}.XXXXXXXX")"
chmod 700 "$PRIVATE_DIR"
PRIVATE_DIR="$(cd "$PRIVATE_DIR" && pwd -P)"
s17_assert_outside_worktrees "$PRIVATE_DIR"

CREDS_FILE="${PRIVATE_DIR}/athlete_d_credentials.json"
DEFINES_FILE="${PRIVATE_DIR}/flutter_dart_defines.json"
MANIFEST_FILE="${PRIVATE_DIR}/redacted_manifest.json"
STATE_FILE="${PRIVATE_DIR}/creation_state.json"

python3 - <<PY
import json, sys
from pathlib import Path
sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_staging_guard import (
    StagingGuardError,
    assert_outside_git_worktrees,
    assert_private_dir,
    validate_run_marker,
)

root = Path("${ROOT}").resolve()
private = Path("${PRIVATE_DIR}").resolve()
marker = "${RUN_MARKER}"
validate_run_marker(marker)
assert_private_dir(private)
assert_outside_git_worktrees(private, [root])
plan = {
    "run_marker": marker,
    "display_name": "S17 Staging Athlete D",
    "email_pattern": f"{marker}.athlete.d@example.invalid",
    "programme_lineage_code": "PROG-S13-ELIG",
    "programme_version_id": "e9bd7e19-6eb9-4f7e-abf6-d08ac4368748",
    "fixture_scope": [
        "auth_user",
        "athlete_profile",
        "catalogue_enrolment",
        "plan_materialisation",
    ],
    "private_dir": str(private),
    "dry_run": ${DRY_RUN},
    "notes": [
        "Uses immutable published PROG-S13-ELIG; does not edit catalogue content.",
        "PROG-S13-ELIG is the Self-Test 1 one-slot package; schedule ops F-J require later Athlete D-owned multi-slot preparation (B4c/B4d resume).",
        "Never enumerates or mutates existing athlete identities.",
        "Credentials written only under private_dir modes 700/600.",
    ],
}
Path("${STATE_FILE}").write_text(json.dumps({"stage": "planned", "plan": plan}, indent=2))
Path("${STATE_FILE}").chmod(0o600)
print("ATHLETE_D_PLAN_OK run_marker=" + marker)
print("PRIVATE_DIR=" + str(private))
print("PROGRAMME=PROG-S13-ELIG")
print("DRY_RUN=${DRY_RUN}")
PY

if [[ "$DRY_RUN" -eq 1 ]]; then
  python3 - <<PY
import json
from pathlib import Path
plan = json.loads(Path("${STATE_FILE}").read_text())["plan"]
manifest = {
    "status": "dry_run_ok",
    "run_marker": plan["run_marker"],
    "display_name": plan["display_name"],
    "programme_lineage_code": plan["programme_lineage_code"],
    "programme_version_id_prefix": plan["programme_version_id"][:8] + "…",
    "hosted_write": False,
    "athlete_created": False,
    "private_dir": plan["private_dir"],
}
Path("${MANIFEST_FILE}").write_text(json.dumps(manifest, indent=2))
Path("${MANIFEST_FILE}").chmod(0o600)
print("DRY_RUN_OK: staging identity confirmed; Athlete D not created; no hosted write.")
print("REDACTED_MANIFEST=${MANIFEST_FILE}")
PY
  exit 0
fi

# -------- Hosted create path (B4b only; not executed during B4a) --------
API_ENV="${S17_API_ENV:-/tmp/s13b_api.env}"
if [[ ! -f "$API_ENV" ]]; then
  echo "REFUSED: missing API env $API_ENV (operator-local staging credentials)." >&2
  python3 - <<PY
import json
from pathlib import Path
Path("${STATE_FILE}").write_text(json.dumps({
  "stage": "blocked_missing_api_env",
  "classification": "Staging configuration defect",
  "athlete_created": False,
}, indent=2))
Path("${STATE_FILE}").chmod(0o600)
PY
  exit 2
fi

python3 - <<PY
import json, secrets, string, urllib.error, urllib.request
from datetime import datetime, timezone
from pathlib import Path
import sys

sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_staging_guard import (
    StagingGuardError,
    reject_production_url,
    reject_service_role_material,
    redact_email,
    redact_uuid,
    validate_athlete_d_email,
    validate_run_marker,
)

ROOT = Path("${ROOT}")
PRIVATE = Path("${PRIVATE_DIR}")
API_ENV = Path("${API_ENV}")
RUN_MARKER = "${RUN_MARKER}"
VERSION_ID = "e9bd7e19-6eb9-4f7e-abf6-d08ac4368748"

state_path = Path("${STATE_FILE}")

def write_state(stage: str, **extra):
    payload = {"stage": stage, "run_marker": RUN_MARKER, **extra}
    state_path.write_text(json.dumps(payload, indent=2))
    state_path.chmod(0o600)

def load_env(path: Path):
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:]
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip("'").strip('"')
    return env

try:
    validate_run_marker(RUN_MARKER)
    env = load_env(API_ENV)
    url = env.get("S13_API_URL") or env.get("SUPABASE_URL") or ""
    anon = env.get("S13_ANON_KEY") or env.get("SUPABASE_ANON_KEY") or ""
    service = env.get("S13_SERVICE_KEY") or env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    reject_production_url(url)
    reject_service_role_material(anon)
    if not service:
        raise StagingGuardError("REFUSED: missing service role for Admin Auth fixture setup only")

    alphabet = string.ascii_letters + string.digits
    password = "".join(secrets.choice(alphabet) for _ in range(28)) + "!1aA"
    email = f"{RUN_MARKER}.athlete.d@example.invalid"
    validate_athlete_d_email(email, RUN_MARKER)
    display = "S17 Staging Athlete D"

    def req(method, path, body=None, key=service, prefer=None):
        headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }
        if prefer:
            headers["Prefer"] = prefer
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(
            url.rstrip("/") + path, data=data, headers=headers, method=method
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as resp:
                raw = resp.read().decode()
                return resp.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            raw = e.read().decode()
            try:
                parsed = json.loads(raw)
            except Exception:
                parsed = {"raw_type": type(raw).__name__}
            return e.code, parsed

    write_state("creating_auth_user")
    status, body = req("POST", "/auth/v1/admin/users", {
        "email": email,
        "password": password,
        "email_confirm": True,
        "user_metadata": {
            "display_name": display,
            "purpose": "s17_phase1_staging_journey",
            "label": "S17-STAGING-FIXTURE",
            "run_id": RUN_MARKER,
            "roles": ["athlete"],
        },
    })
    if status not in (200, 201) or not isinstance(body, dict) or not body.get("id"):
        write_state(
            "partial_auth_create_failed",
            classification="Staging configuration defect",
            http_status=status,
            athlete_created=False,
        )
        raise SystemExit(3)
    user_id = body["id"]
    write_state("auth_user_created", athlete_id_prefix=redact_uuid(user_id))

    st, _ = req("POST", "/rest/v1/profiles", {
        "id": user_id,
        "display_name": display,
        "is_coach": False,
        "is_athlete": True,
    }, prefer="return=representation")
    if st not in (200, 201):
        st2, _ = req("PATCH", f"/rest/v1/profiles?id=eq.{user_id}", {
            "display_name": display,
            "is_coach": False,
            "is_athlete": True,
        })
        if st2 not in (200, 204):
            write_state(
                "partial_profile_failed",
                classification="Partial migration state",
                athlete_created=True,
                athlete_id_prefix=redact_uuid(user_id),
            )
            raise SystemExit(4)

    # Athlete-path login with anon only.
    st, login = req("POST", "/auth/v1/token?grant_type=password", {
        "email": email,
        "password": password,
    }, key=anon)
    if st != 200 or not isinstance(login, dict) or not login.get("access_token"):
        write_state(
            "partial_login_failed",
            classification="Staging configuration defect",
            athlete_created=True,
            athlete_id_prefix=redact_uuid(user_id),
        )
        raise SystemExit(5)
    token = login["access_token"]
    if login.get("user", {}).get("id") != user_id:
        write_state("partial_login_uid_mismatch", athlete_created=True)
        raise SystemExit(6)

    def athlete_req(method, path, body=None):
        headers = {
            "apikey": anon,
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(
            url.rstrip("/") + path, data=data, headers=headers, method=method
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as resp:
                raw = resp.read().decode()
                return resp.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            raw = e.read().decode()
            try:
                parsed = json.loads(raw)
            except Exception:
                parsed = {"raw_type": type(raw).__name__}
            return e.code, parsed

    write_state("enrolling", athlete_id_prefix=redact_uuid(user_id))
    st, enrol = athlete_req("POST", "/rest/v1/rpc/enrol_athlete_in_catalogue_programme_version", {
        "p_programme_version_id": VERSION_ID,
        "p_timezone": "UTC",
        "p_replace_active": False,
    })
    if st != 200 or not isinstance(enrol, dict):
        write_state(
            "partial_enrol_failed",
            classification="Partial migration state",
            athlete_created=True,
            athlete_id_prefix=redact_uuid(user_id),
            http_status=st,
        )
        raise SystemExit(7)
    if enrol.get("status") not in ("enrolled", "already_enrolled"):
        write_state(
            "partial_enrol_status",
            classification="Partial migration state",
            athlete_created=True,
            status=enrol.get("status"),
        )
        raise SystemExit(8)
    assignment_id = enrol.get("enrolment_id") or enrol.get("assignment_id")
    if not assignment_id:
        write_state("partial_enrol_missing_assignment", athlete_created=True)
        raise SystemExit(9)

    write_state("materialising", assignment_id_prefix=redact_uuid(assignment_id))
    st, mat = athlete_req("POST", "/rest/v1/rpc/materialise_athlete_plan_from_enrolment", {
        "p_programme_assignment_id": assignment_id,
        "p_timezone": "UTC",
    })
    if st != 200 or not isinstance(mat, dict):
        write_state(
            "partial_materialise_failed",
            classification="Partial migration state",
            athlete_created=True,
            assignment_id_prefix=redact_uuid(assignment_id),
            http_status=st,
        )
        raise SystemExit(10)
    if mat.get("status") not in ("materialised", "already_materialised"):
        write_state(
            "partial_materialise_status",
            athlete_created=True,
            status=mat.get("status"),
        )
        raise SystemExit(11)

    package_hash = (
        mat.get("materialised_package_content_hash")
        or mat.get("package_content_hash")
        or ""
    )

    creds = {
        "run_marker": RUN_MARKER,
        "email": email,
        "password": password,
        "user_id": user_id,
        "display_name": display,
        "assignment_id": assignment_id,
        "version_id": VERSION_ID,
        "package_hash": package_hash,
        "lineage_code": "PROG-S13-ELIG",
        "supabase_url": url.rstrip("/"),
        "supabase_anon_key": anon,
    }
    Path("${CREDS_FILE}").write_text(json.dumps(creds, indent=2))
    Path("${CREDS_FILE}").chmod(0o600)

    defines = {
        "S17_STAGING_ENABLED": "true",
        "S17_SUPABASE_URL": url.rstrip("/"),
        "S17_SUPABASE_ANON_KEY": anon,
        "S17_ATHLETE_EMAIL": email,
        "S17_ATHLETE_PASSWORD": password,
        "S17_ATHLETE_ID": user_id,
        "S17_ASSIGNMENT_ID": assignment_id,
        "S17_VERSION_ID": VERSION_ID,
        "S17_PACKAGE_HASH": package_hash,
        "S17_RUN_MARKER": RUN_MARKER,
        "S17_LINEAGE_CODE": "PROG-S13-ELIG",
    }
    Path("${DEFINES_FILE}").write_text(json.dumps(defines, indent=2))
    Path("${DEFINES_FILE}").chmod(0o600)

    manifest = {
        "status": "created",
        "run_marker": RUN_MARKER,
        "display_name": display,
        "email_redacted": redact_email(email),
        "athlete_id_prefix": redact_uuid(user_id),
        "assignment_id_prefix": redact_uuid(assignment_id),
        "version_id_prefix": redact_uuid(VERSION_ID),
        "lineage_code": "PROG-S13-ELIG",
        "private_dir": str(PRIVATE),
        "credentials_file": str(Path("${CREDS_FILE}")),
        "dart_defines_file": str(Path("${DEFINES_FILE}")),
        "hosted_write": True,
        "athlete_created": True,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    Path("${MANIFEST_FILE}").write_text(json.dumps(manifest, indent=2))
    Path("${MANIFEST_FILE}").chmod(0o600)
    write_state("complete", athlete_created=True, manifest="${MANIFEST_FILE}")
    print("ATHLETE_D_CREATED_OK run_marker=" + RUN_MARKER)
    print("REDACTED_MANIFEST=${MANIFEST_FILE}")
    print("DART_DEFINES_FILE=${DEFINES_FILE}")
except StagingGuardError as e:
    write_state("refused", classification="Staging configuration defect", error=str(e))
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY
