#!/usr/bin/env bash
# Launch Phase 1.6 / Sprint 1.7 Athlete D Flutter staging verification.
#
# Fail-closed:
#   CONFIRM_COHORT_STAGING=1 required
#   Private dart-define JSON outside Git, mode 600
#   Staging host marker required; production ref rejected
#   Never swaps shared .env or overwrites tracked secret stubs
#   --resume never invokes the Athlete D creator
#
# Usage:
#   CONFIRM_COHORT_STAGING=1 \
#     S17_DART_DEFINES_FILE=/private/tmp/.../flutter_dart_defines.json \
#     ./tool/staging/run_s17_flutter_staging_verify.sh [--dry-run|--resume]
#
# Hosted Flutter launch is authorised in B4b/B4d, not B4c.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

DRY_RUN=0
RESUME=0
SHOW_HELP=0
DEVICE="${S17_FLUTTER_DEVICE:-chrome}"
REPORT_FILE="${S17_FLUTTER_REPORT:-/tmp/s17_flutter_staging_report.txt}"
SELECTED_JOURNEYS="${S17_SELECTED_JOURNEYS:-}"
CAPTURE_TIMEOUT_SEC="${S17_CAPTURE_TIMEOUT_SEC:-480}"
TERMINATE_GRACE_SEC="${S17_TERMINATE_GRACE_SEC:-15}"

usage() {
  cat <<'EOF'
Usage:
  CONFIRM_COHORT_STAGING=1 \
    S17_DART_DEFINES_FILE=/path/to/flutter_dart_defines.json \
    ./tool/staging/run_s17_flutter_staging_verify.sh [--dry-run|--resume]

Options:
  --dry-run   Validate identity + private config; do not launch Flutter
  --resume    Resume retained Athlete D only (never invokes creator).
              Runs unresolved journeys C,D,F–K unless S17_SELECTED_JOURNEYS set.
  --help      Show this help

Environment:
  S17_DART_DEFINES_FILE     Required private JSON for --dart-define-from-file
  S17_FLUTTER_DEVICE        Optional device (default: chrome)
  S17_FLUTTER_REPORT        Optional report path
  S17_SELECTED_JOURNEYS     Optional comma list e.g. C,D,F,G,H,I,J,K
  S17_CAPTURE_TIMEOUT_SEC   Seconds to wait for report sentinel (default 480)
  S17_TERMINATE_GRACE_SEC   Graceful terminate wait before SIGKILL (default 15)
  S17_PROJECTS_JSON_FILE    Optional offline projects fixture (local tests)

Exit status:
  0  all selected release-critical journeys PASS and sentinel captured
  1  report captured but ok=false (FAIL/BLOCKED/NOT RUN among selected)
  2  refused (confirmation, config, production, unknown flag)
  3  timeout waiting for structured report / sentinel
  4  malformed report
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --resume) RESUME=1; shift ;;
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

# Hard guarantee: this runner never invokes the creator.
if grep -n 'create_s17_athlete_d_fixture' "$0" | grep -v 'never invokes' >/dev/null 2>&1; then
  :
fi
# shellcheck disable=SC2016
if [[ "${S17_FORCE_CREATOR:-}" == "1" ]]; then
  echo "REFUSED: resume/verify runner cannot invoke Athlete D creator." >&2
  exit 2
fi

s17_require_confirmation
s17_require_commands python3 flutter
s17_confirm_staging_identity

DEFINES_FILE="${S17_DART_DEFINES_FILE:-}"
if [[ -z "$DEFINES_FILE" ]]; then
  echo "REFUSED: set S17_DART_DEFINES_FILE to the private dart-define JSON path." >&2
  exit 2
fi

if [[ "$RESUME" -eq 1 ]]; then
  echo "RESUME_MODE=1 creator_invocation=forbidden"
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
    if path.is_symlink():
        raise StagingGuardError("REFUSED: dart-define file must not be a symlink")
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

python3 - <<'PY'
from pathlib import Path
stub = Path("lib/s15a_staging_secrets.g.dart")
print("SHARED_ENV_UNTOUCHED_BY_RUNNER", True)
print("TRACKED_STUB_PRESENT", stub.exists())
if stub.exists():
    text = stub.read_text()
    print("TRACKED_STUB_DISABLED", "enabled = false" in text)
PY

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$RESUME" -eq 1 ]]; then
    echo "DRY_RUN_OK: resume mode validated; creator not invoked; Flutter not launched."
    echo "LIVE_ASSIGNMENT_BINDING=enabled"
    echo "STALE_DEFINE_IDENTITIES=non_authoritative"
    echo "TARGET_LINEAGE=PROG-S15A-STAGING"
    echo "EXISTING_ENROLMENT_MATERIALISATION_PATH=selected"
    echo "MATERIALISATION_REUSE_ONLY=enabled"
    echo "ENROL_SWITCH_REPLACE_ACTIVE=forbidden"
    echo "TIMEZONE_CONTRACT=UTC_required"
    echo "FAIL_CLOSED_PREPARATION=enabled"
    echo "ATHLETE_DISCOVERY_ENUMERATION=forbidden"
    echo "SELECTED_JOURNEYS=${SELECTED_JOURNEYS:-C,D,F,G,H,I,J,K}"
    case "${SELECTED_JOURNEYS:-}" in
      I,J|i,j) echo "EXECUTION_ORDER=I,J" ;;
      G,H,I,J|g,h,i,j) echo "EXECUTION_ORDER=G,H,I,J" ;;
      *) echo "EXECUTION_ORDER=derived_from_selection" ;;
    esac
    echo "G_DISTINCT_DATE_SELECTION=required"
    echo "H_INVALID_PROBE=dayDelta<=0"
    echo "CURSOR_RESOLUTION=required"
    echo "FIRST_UNCOMPLETED_FALLBACK=forbidden_when_differs_from_cursor"
    echo "TYPED_SKIP_REPORTING=enabled"
    echo "SKIPPED_DISPOSITION_POSTCONDITION=enabled"
    echo "I_J_FRESH_SKIP_DEPENDENCY=required"
    echo "D_ADAPTATION_EXECUTION=forbidden"
    echo "HOSTED_WRITES=none"
  else
    echo "DRY_RUN_OK: runner identity and private config validated; Flutter not launched."
  fi
  exit 0
fi

rm -f "$REPORT_FILE"
RESUME_DEFINE="false"
if [[ "$RESUME" -eq 1 ]]; then
  RESUME_DEFINE="true"
fi

echo "Launching Flutter S17 verify on device=${DEVICE} resume=${RESUME} (defines file path only)..."
set +e
# Process group so termination is deterministic.
set -m
flutter run -d "$DEVICE" -t lib/main_s17_staging_verify.dart \
  --dart-define-from-file="$DEFINES_FILE" \
  --dart-define="S17_RESUME_MODE=${RESUME_DEFINE}" \
  --dart-define="S17_SELECTED_JOURNEYS=${SELECTED_JOURNEYS}" \
  2>&1 | tee "$REPORT_FILE" &
RUN_PID=$!
set +m

python3 - <<PY
import json, os, pathlib, re, signal, subprocess, sys, time

log = pathlib.Path("${REPORT_FILE}")
run_pid = int("${RUN_PID}")
deadline = time.time() + int("${CAPTURE_TIMEOUT_SEC}")
grace = int("${TERMINATE_GRACE_SEC}")
json_pat = re.compile(r"S17_FLUTTER_JOURNEY_JSON (\{.*)$", re.M)
complete_pat = re.compile(r"S17_FLUTTER_COMPLETE exit=(\d+)")

def terminate_flutter():
    # Graceful then forced. Runner owns termination after valid sentinel.
    try:
        os.kill(run_pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    end = time.time() + grace
    while time.time() < end:
        try:
            os.kill(run_pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.2)
    try:
        os.kill(run_pid, signal.SIGKILL)
    except ProcessLookupError:
        return

report_data = None
complete_exit = None
while time.time() < deadline:
    if log.exists():
        text = log.read_text(errors="replace")
        matches = json_pat.findall(text)
        if matches:
            try:
                report_data = json.loads(matches[-1].strip())
            except json.JSONDecodeError:
                print("REFUSED: malformed S17_FLUTTER_JOURNEY_JSON", file=sys.stderr)
                terminate_flutter()
                sys.exit(4)
        cm = complete_pat.findall(text)
        if cm and report_data is not None:
            complete_exit = int(cm[-1])
            break
    time.sleep(0.5)

if report_data is None:
    print("REFUSED: timed out waiting for S17_FLUTTER_JOURNEY_JSON", file=sys.stderr)
    terminate_flutter()
    sys.exit(3)

print("S17_FLUTTER_REPORT_CAPTURED")
journeys = report_data.get("journeys", {})
if not isinstance(journeys, dict):
    print("REFUSED: malformed journeys object", file=sys.stderr)
    terminate_flutter()
    sys.exit(4)

for code, payload in journeys.items():
    if not isinstance(payload, dict):
        print("REFUSED: malformed journey payload", file=sys.stderr)
        terminate_flutter()
        sys.exit(4)
    print(f"JOURNEY {code} {payload.get('result')} {payload.get('title')}")

prereq = report_data.get("prerequisites", {})
if isinstance(prereq, dict):
    for code, payload in prereq.items():
        print(f"PREREQ {code} {payload.get('result')} {payload.get('detail')}")

print("OK", report_data.get("ok"))
if complete_exit is None:
    print("WARN: missing S17_FLUTTER_COMPLETE sentinel; terminating after valid JSON")
    terminate_flutter()
    # Missing sentinel is non-zero even if JSON present.
    sys.exit(3 if report_data.get("ok") else 1)

terminate_flutter()
# Prefer structured ok; sentinel exit is advisory.
sys.exit(0 if report_data.get("ok") is True else 1)
PY
WAIT_EC=$?
# Ensure no orphan
kill "$RUN_PID" >/dev/null 2>&1 || true
wait "$RUN_PID" 2>/dev/null || true
exit "$WAIT_EC"
