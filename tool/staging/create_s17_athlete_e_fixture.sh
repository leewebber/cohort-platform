#!/usr/bin/env bash
# Test-only Athlete E bootstrap for Phase 1.2–1.7 Staging verification.
#
# Fail-closed:
#   CONFIRM_COHORT_STAGING=1 required
#   Project ref must be exactly tsbadngzgvsyfqjupkng
#   Cohort Field Manual rejected
#   Never reuses Athlete A/B/C/D
#   Never runs supabase db push / migration repair
#   No cleanup/delete mode
#
# Modes:
#   --dry-run   (default) plan + redacted manifest; NO hosted write
#   --hosted    requires S17E_HOSTED_CREATE=1; creates auth user + profile only
#
# Credentials (hosted only) are written under a private /tmp dir (700/600),
# never into the repository. Passwords/tokens are never printed.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

DRY_RUN=1
HOSTED=0
SHOW_HELP=0

usage() {
  cat <<'EOF'
Usage:
  CONFIRM_COHORT_STAGING=1 ./tool/staging/create_s17_athlete_e_fixture.sh [--dry-run]
  CONFIRM_COHORT_STAGING=1 S17E_HOSTED_CREATE=1 ./tool/staging/create_s17_athlete_e_fixture.sh --hosted

Creates (or dry-runs) one isolated Athlete E staging identity for Phase 1.2–1.7
Gate 1 verification. Test administration only — not general athlete onboarding.

Options:
  --dry-run   Default. Confirm staging identity; emit redacted plan; no hosted write
  --hosted    Hosted create (requires S17E_HOSTED_CREATE=1). Auth user + profile only.
  --help      Show this help

Does not modify shared .env, apply migrations, invoke db push, or delete records.
Does not enrol, materialise, complete, or schedule (those are Gate 1 workflow steps).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; HOSTED=0; shift ;;
    --hosted) HOSTED=1; DRY_RUN=0; shift ;;
    --help|-h) SHOW_HELP=1; shift ;;
    --cleanup|--delete|--purge)
      echo "REFUSED: cleanup/delete mode is not implemented" >&2
      exit 2
      ;;
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

if [[ "${S17E_ALLOW_DB_PUSH:-}" == "1" ]] || [[ "${S17E_APPLY_MIGRATIONS:-}" == "1" ]]; then
  echo "REFUSED: Athlete E bootstrap cannot apply migrations or db push" >&2
  exit 2
fi

if [[ "$HOSTED" -eq 1 && "${S17E_HOSTED_CREATE:-}" != "1" ]]; then
  echo "REFUSED: hosted Athlete E create requires S17E_HOSTED_CREATE=1" >&2
  exit 2
fi

s17_require_confirmation
s17_require_commands python3 supabase
s17_confirm_staging_identity

python3 - <<'PY'
import json, subprocess, sys
sys.path.insert(0, "tool/staging/lib")
from s17e_athlete_e_bootstrap import (
    AthleteEBootstrapError,
    require_exact_staging_ref,
    reject_production_project,
)

raw = subprocess.check_output(["supabase", "projects", "list", "-o", "json"], text=True)
ps = json.loads(raw)
if isinstance(ps, dict) and "projects" in ps:
    ps = ps["projects"]
linked = [p for p in ps if p.get("linked")]
if len(linked) != 1:
    raise SystemExit("REFUSED: expected exactly one linked project")
p = linked[0]
ref = p.get("ref") or p.get("id") or ""
try:
    reject_production_project(p.get("name"), ref)
    require_exact_staging_ref(ref)
except AthleteEBootstrapError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
print("STAGING_REF_OK", ref)
PY

RUN_MARKER="$(python3 - <<'PY'
from datetime import datetime, timezone
import secrets
stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
print(f"s17e_stage_{stamp}_{secrets.token_hex(4)}")
PY
)"

PRIVATE_DIR="$(mktemp -d "/tmp/cohort_s17e_athlete_e.${RUN_MARKER}.XXXXXXXX")"
chmod 700 "$PRIVATE_DIR"
PRIVATE_DIR="$(cd "$PRIVATE_DIR" && pwd -P)"
s17_assert_outside_worktrees "$PRIVATE_DIR"
MANIFEST_FILE="${PRIVATE_DIR}/redacted_manifest.json"
CREDS_FILE="${PRIVATE_DIR}/athlete_e_credentials.json"
STATE_FILE="${PRIVATE_DIR}/creation_state.json"

if [[ "$DRY_RUN" -eq 1 ]]; then
  python3 - <<PY
import json, sys
from pathlib import Path
sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17e_athlete_e_bootstrap import build_plan, redacted_manifest

plan = build_plan(
    run_marker="${RUN_MARKER}",
    project_ref="tsbadngzgvsyfqjupkng",
    dry_run=True,
)
manifest = redacted_manifest(plan)
manifest["private_dir"] = "${PRIVATE_DIR}"
Path("${MANIFEST_FILE}").write_text(json.dumps(manifest, indent=2))
Path("${MANIFEST_FILE}").chmod(0o600)
print("ATHLETE_E_DRY_RUN_OK run_marker=" + plan.run_marker)
print("PRIVATE_DIR=${PRIVATE_DIR}")
print("REDACTED_MANIFEST=${MANIFEST_FILE}")
print("HOSTED_WRITE=false")
print("ATHLETE_CREATED=false")
PY
  exit 0
fi

# -------- Hosted create (auth user + profile only) --------
API_ENV="${S17_API_ENV:-/tmp/s13b_api.env}"
if [[ ! -f "$API_ENV" ]]; then
  echo "REFUSED: missing API env $API_ENV (operator-local staging credentials)." >&2
  exit 2
fi

python3 - <<PY
import json, secrets, string, urllib.error, urllib.request
from pathlib import Path
import sys

sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_staging_guard import (
    StagingGuardError,
    reject_production_url,
    reject_service_role_material,
)
from s17e_athlete_e_bootstrap import (
    AthleteEBootstrapError,
    build_plan,
    redact_email,
    redact_uuid,
    redacted_manifest,
    reject_protected_namespaces,
    require_auth_admin_capability,
    validate_athlete_e_email,
    validate_run_marker,
)

PRIVATE = Path("${PRIVATE_DIR}")
API_ENV = Path("${API_ENV}")
RUN_MARKER = "${RUN_MARKER}"
STATE = Path("${STATE_FILE}")
CREDS = Path("${CREDS_FILE}")
MANIFEST = Path("${MANIFEST_FILE}")


def write_state(stage: str, **extra):
    payload = {"stage": stage, "run_marker": RUN_MARKER, **extra}
    STATE.write_text(json.dumps(payload, indent=2))
    STATE.chmod(0o600)


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
    plan = build_plan(
        run_marker=RUN_MARKER,
        project_ref="tsbadngzgvsyfqjupkng",
        dry_run=False,
    )
    env = load_env(API_ENV)
    url = env.get("S13_API_URL") or env.get("SUPABASE_URL") or ""
    anon = env.get("S13_ANON_KEY") or env.get("SUPABASE_ANON_KEY") or ""
    service = env.get("S13_SERVICE_KEY") or env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    reject_production_url(url)
    reject_service_role_material(anon)
    require_auth_admin_capability(bool(service))

    alphabet = string.ascii_letters + string.digits
    password = "".join(secrets.choice(alphabet) for _ in range(28)) + "!1aA"
    email = f"{RUN_MARKER}.athlete.e@example.invalid"
    validate_athlete_e_email(email, RUN_MARKER)
    reject_protected_namespaces(email, plan.display_name, RUN_MARKER)
    display = plan.display_name

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
    status, body = req(
        "POST",
        "/auth/v1/admin/users",
        {
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {
                "display_name": display,
                "purpose": "s17e_phase12_17_gate1",
                "label": "S17E-STAGING-ATHLETE-E",
                "run_id": RUN_MARKER,
                "roles": ["athlete"],
            },
        },
    )
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

    st, _ = req(
        "POST",
        "/rest/v1/profiles",
        {
            "id": user_id,
            "display_name": display,
            "is_coach": False,
            "is_athlete": True,
        },
        prefer="return=representation",
    )
    if st not in (200, 201):
        st2, _ = req(
            "PATCH",
            f"/rest/v1/profiles?id=eq.{user_id}",
            {
                "display_name": display,
                "is_coach": False,
                "is_athlete": True,
            },
        )
        if st2 not in (200, 204):
            write_state(
                "partial_profile_failed",
                classification="Partial migration state",
                athlete_created=True,
                athlete_id_prefix=redact_uuid(user_id),
            )
            raise SystemExit(4)

    st, login = req(
        "POST",
        "/auth/v1/token?grant_type=password",
        {"email": email, "password": password},
        key=anon,
    )
    if st != 200 or not isinstance(login, dict) or not login.get("access_token"):
        write_state(
            "partial_login_failed",
            classification="Staging configuration defect",
            athlete_created=True,
            athlete_id_prefix=redact_uuid(user_id),
        )
        raise SystemExit(5)
    if login.get("user", {}).get("id") != user_id:
        write_state("partial_login_uid_mismatch", athlete_created=True)
        raise SystemExit(6)

    # Persist credentials privately (never printed).
    CREDS.write_text(
        json.dumps(
            {
                "run_marker": RUN_MARKER,
                "email": email,
                "password": password,
                "user_id": user_id,
                "display_name": display,
                "supabase_url": url.rstrip("/"),
                "supabase_anon_key": anon,
            },
            indent=2,
        )
    )
    CREDS.chmod(0o600)

    manifest = redacted_manifest(plan)
    manifest.update(
        {
            "status": "hosted_created",
            "dry_run": False,
            "hosted_write": True,
            "athlete_created": True,
            "athlete_id_prefix": redact_uuid(user_id),
            "email_redacted": redact_email(email),
            "private_dir": str(PRIVATE),
            "proposed_records": ["auth_user", "athlete_profile"],
        }
    )
    MANIFEST.write_text(json.dumps(manifest, indent=2))
    MANIFEST.chmod(0o600)
    write_state(
        "complete",
        athlete_created=True,
        athlete_id_prefix=redact_uuid(user_id),
        records=["auth_user", "athlete_profile"],
    )

    # Redacted stdout only — never password/token.
    print("ATHLETE_E_HOSTED_CREATE_OK")
    print("RUN_MARKER=" + RUN_MARKER)
    print("ATHLETE_ID_PREFIX=" + redact_uuid(user_id))
    print("EMAIL_REDACTED=" + redact_email(email))
    print("PRIVATE_DIR=" + str(PRIVATE))
    print("REDACTED_MANIFEST=" + str(MANIFEST))
    print("HOSTED_WRITE=true")
    print("ATHLETE_CREATED=true")
    print("RECORDS=auth_user,athlete_profile")
except (StagingGuardError, AthleteEBootstrapError) as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY
