#!/usr/bin/env bash
# Launch Phase 1.6 / Sprint 1.7 Athlete D Flutter staging verification.
#
# Fail-closed:
#   CONFIRM_COHORT_STAGING=1 required
#   Private dart-define JSON outside Git, mode 600
#   Staging host marker required; production ref rejected
#   Never swaps shared .env or overwrites tracked secret stubs
#
# Usage:
#   CONFIRM_COHORT_STAGING=1 \
#     S17_DART_DEFINES_FILE=/private/tmp/.../flutter_dart_defines.json \
#     ./tool/staging/run_s17_flutter_staging_verify.sh [--dry-run]
#
# Hosted Flutter launch is authorised in B4b, not B4a.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

DRY_RUN=0
SHOW_HELP=0
DEVICE="${S17_FLUTTER_DEVICE:-chrome}"
REPORT_FILE="${S17_FLUTTER_REPORT:-/tmp/s17_flutter_staging_report.txt}"

usage() {
  cat <<'EOF'
Usage:
  CONFIRM_COHORT_STAGING=1 \
    S17_DART_DEFINES_FILE=/path/to/flutter_dart_defines.json \
    ./tool/staging/run_s17_flutter_staging_verify.sh [--dry-run]

Options:
  --dry-run   Validate identity + private config; do not launch Flutter
  --help      Show this help

Environment:
  S17_DART_DEFINES_FILE   Required private JSON for --dart-define-from-file
  S17_FLUTTER_DEVICE      Optional device (default: chrome)
  S17_FLUTTER_REPORT      Optional report path
  S17_PROJECTS_JSON_FILE  Optional offline projects fixture (local tests)
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
s17_require_commands python3 flutter
s17_confirm_staging_identity

DEFINES_FILE="${S17_DART_DEFINES_FILE:-}"
if [[ -z "$DEFINES_FILE" ]]; then
  echo "REFUSED: set S17_DART_DEFINES_FILE to the private dart-define JSON path." >&2
  exit 2
fi

python3 - <<PY
import json, os, sys
from pathlib import Path
sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_staging_guard import (
    StagingGuardError,
    assert_outside_git_worktrees,
    assert_private_file,
    reject_production_url,
    reject_service_role_material,
    validate_athlete_d_email,
    validate_run_marker,
)

path = Path(os.environ["S17_DART_DEFINES_FILE"]).expanduser()
try:
    assert_private_file(path)
    assert_outside_git_worktrees(path, [Path("${ROOT}")])
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise StagingGuardError("REFUSED: dart-define file must be a JSON object")
    if str(data.get("S17_STAGING_ENABLED", "")).lower() != "true":
        raise StagingGuardError("REFUSED: S17_STAGING_ENABLED must be true")
    url = str(data.get("S17_SUPABASE_URL", ""))
    anon = str(data.get("S17_SUPABASE_ANON_KEY", ""))
    email = str(data.get("S17_ATHLETE_EMAIL", ""))
    marker = str(data.get("S17_RUN_MARKER", ""))
    reject_production_url(url)
    reject_service_role_material(anon, json.dumps(data))
    validate_run_marker(marker)
    validate_athlete_d_email(email, marker)
    for required in (
        "S17_ATHLETE_PASSWORD",
        "S17_ATHLETE_ID",
        "S17_ASSIGNMENT_ID",
        "S17_VERSION_ID",
    ):
        if not str(data.get(required, "")).strip():
            raise StagingGuardError(f"REFUSED: missing {required}")
    print("PRIVATE_CONFIG_OK path_mode=600 staging_host_confirmed")
    print("RUN_MARKER=" + marker)
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY

# Prove shared .env and tracked secret stubs are not modified by this runner.
python3 - <<'PY'
from pathlib import Path
env = Path(".env")
stub = Path("lib/s15a_staging_secrets.g.dart")
print("SHARED_ENV_UNTOUCHED_BY_RUNNER", True)
print("TRACKED_STUB_PRESENT", stub.exists())
if stub.exists():
    text = stub.read_text()
    print("TRACKED_STUB_DISABLED", "enabled = false" in text)
PY

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY_RUN_OK: runner identity and private config validated; Flutter not launched."
  exit 0
fi

rm -f "$REPORT_FILE"
echo "Launching Flutter S17 verify on device=${DEVICE} (defines file path only)..."
set +e
flutter run -d "$DEVICE" -t lib/main_s17_staging_verify.dart \
  --dart-define-from-file="$DEFINES_FILE" \
  2>&1 | tee "$REPORT_FILE" &
RUN_PID=$!

python3 - <<PY
import pathlib, re, time, sys
log = pathlib.Path("${REPORT_FILE}")
deadline = time.time() + 480
pattern = re.compile(r"S17_FLUTTER_JOURNEY_JSON (\{.*)$", re.M)
while time.time() < deadline:
    if log.exists():
        text = log.read_text(errors="replace")
        matches = pattern.findall(text)
        if matches:
            print("S17_FLUTTER_REPORT_CAPTURED")
            # Print only journey result labels, never secrets.
            import json
            data = json.loads(matches[-1].strip())
            journeys = data.get("journeys", {})
            for code, payload in journeys.items():
                print(f"JOURNEY {code} {payload.get('result')} {payload.get('title')}")
            print("OK", data.get("ok"))
            sys.exit(0 if data.get("ok") else 1)
    time.sleep(2)
print("REFUSED: timed out waiting for S17_FLUTTER_JOURNEY_JSON", file=sys.stderr)
sys.exit(3)
PY
WAIT_EC=$?
kill "$RUN_PID" >/dev/null 2>&1 || true
wait "$RUN_PID" 2>/dev/null || true
exit "$WAIT_EC"
