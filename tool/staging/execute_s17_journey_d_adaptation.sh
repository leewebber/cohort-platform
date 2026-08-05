#!/usr/bin/env bash
# Execute Journey D once against an eligible s17_jd_adapt_* fixture.
#
# Requires:
#   CONFIRM_COHORT_STAGING=1
#   S17_JD_EXECUTE=1
#   --marker <s17_jd_adapt_*>
#   --credential-file <private 0600 artifact>
#   S17_PROJECTS_JSON_FILE + S17_API_ENV for eligibility + hosted execute
#
# Runs eligibility first; consumes credential only when eligible.
# Never retries. Never executes Journey I/J. Never uses --linked.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

MARKER=""
CREDENTIAL_FILE=""
SHOW_HELP=0

usage() {
  cat <<'EOF'
Usage:
  CONFIRM_COHORT_STAGING=1 S17_JD_EXECUTE=1 \
    S17_PROJECTS_JSON_FILE=<projects> S17_API_ENV=<api-env> \
    ./tool/staging/execute_s17_journey_d_adaptation.sh \
      --marker <s17_jd_adapt_*> \
      --credential-file <private-credential-path>

Executes Journey D exactly once for PROG-S17-JD-ADAPT after eligibility.
Private credential is consumed only when fixture_eligible=true.
Credential artifact is shredded after the command completes.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --marker)
      [[ $# -ge 2 && -n "${2:-}" && "${2:0:2}" != "--" ]] || {
        echo "REFUSED: --marker requires a value" >&2; exit 2;
      }
      MARKER="$2"; shift 2 ;;
    --credential-file)
      [[ $# -ge 2 && -n "${2:-}" && "${2:0:2}" != "--" ]] || {
        echo "REFUSED: --credential-file requires a value" >&2; exit 2;
      }
      CREDENTIAL_FILE="$2"; shift 2 ;;
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

if [[ -z "$MARKER" || -z "$CREDENTIAL_FILE" ]]; then
  echo "REFUSED: --marker and --credential-file required" >&2
  usage >&2
  exit 2
fi

if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" ]]; then
  echo "REFUSED: CONFIRM_COHORT_STAGING=1 required" >&2
  exit 2
fi
if [[ "${S17_JD_EXECUTE:-}" != "1" ]]; then
  echo "REFUSED: S17_JD_EXECUTE=1 required" >&2
  exit 2
fi
if [[ ! -f "$CREDENTIAL_FILE" ]]; then
  echo "REFUSED: credential file missing" >&2
  exit 2
fi
if [[ -z "${S17_PROJECTS_JSON_FILE:-}" ]]; then
  echo "REFUSED: S17_PROJECTS_JSON_FILE required" >&2
  exit 2
fi

s17_require_confirmation
s17_confirm_staging_identity

# Validate marker (data) before hosted contact.
export S17_JD_FIXTURE_MARKER="$MARKER"
python3 - <<'PY'
import os, sys
from pathlib import Path
root = Path(os.environ["S17_ROOT"])
sys.path.insert(0, str(root / "tool/staging/lib"))
from s17_journey_d_fixture import (
    StagingGuardError,
    reject_reserved_identity,
    reject_retired_live_marker,
    validate_marker,
)
try:
    validate_marker(os.environ["S17_JD_FIXTURE_MARKER"])
    reject_reserved_identity(os.environ["S17_JD_FIXTURE_MARKER"])
    reject_retired_live_marker(os.environ["S17_JD_FIXTURE_MARKER"])
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY

PRIVATE_DIR="$(mktemp -d "/tmp/cohort_s17_jd_exec.XXXXXXXX")"
chmod 700 "$PRIVATE_DIR"
PRIVATE_DIR="$(cd "$PRIVATE_DIR" && pwd -P)"
s17_assert_outside_worktrees "$PRIVATE_DIR"
ELIG_FILE="${PRIVATE_DIR}/eligibility.json"
RESULT_FILE="${PRIVATE_DIR}/execute_result.json"
REQ_FILE="${PRIVATE_DIR}/execute_request.json"

# 1) Eligibility (hosted read-only) — must be conclusive before credential consume.
set +e
CONFIRM_COHORT_STAGING=1 S17_JD_HOSTED_READONLY=1 \
  S17_PROJECTS_JSON_FILE="${S17_PROJECTS_JSON_FILE}" \
  S17_API_ENV="${S17_API_ENV:-/tmp/s13b_api.env}" \
  ./tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh \
  "$MARKER" --hosted >"${PRIVATE_DIR}/eligibility_stdout.txt" 2>"${PRIVATE_DIR}/eligibility_stderr.txt"
ELIG_RC=$?
set -e

python3 - <<PY
import json, sys
from pathlib import Path
stdout = Path("${PRIVATE_DIR}/eligibility_stdout.txt").read_text()
# Extract last JSON object from verifier output.
blob = None
stack = []
start = None
for i, ch in enumerate(stdout):
    if ch == '{':
        if not stack:
            start = i
        stack.append(ch)
    elif ch == '}' and stack:
        stack.pop()
        if not stack and start is not None:
            blob = stdout[start:i+1]
text = blob or "{}"
try:
    data = json.loads(text)
except Exception:
    print("REFUSED: eligibility verifier output unparseable", file=sys.stderr)
    raise SystemExit(2)
Path("${ELIG_FILE}").write_text(json.dumps(data, indent=2))
Path("${ELIG_FILE}").chmod(0o600)
state = data.get("fixture_state")
eligible = data.get("fixture_eligible") is True
print("FIXTURE_STATE=" + str(state))
print("FIXTURE_ELIGIBLE=" + str(eligible).lower())
if state != "complete" or not eligible:
    print("REFUSED: fixture not eligible for Journey D execute", file=sys.stderr)
    raise SystemExit(2)
PY

# 2) Execute once via repository-owned Flutter harness.
python3 - <<PY
import json
from pathlib import Path
Path("${REQ_FILE}").write_text(json.dumps({
    "marker": "${MARKER}",
    "eligibility_passed": True,
    "lineage_code": "PROG-S17-JD-ADAPT",
    "api_env_path": "${S17_API_ENV:-/tmp/s13b_api.env}",
}, indent=2))
Path("${REQ_FILE}").chmod(0o600)
PY

export S17_JD_EXECUTE_REQUEST_FILE="$REQ_FILE"
export S17_JD_EXECUTE_RESULT_FILE="$RESULT_FILE"
export S17_JD_CREDENTIAL_FILE="$CREDENTIAL_FILE"
export S17_JD_FLUTTER_LOG_DIR="$PRIVATE_DIR"

# Prepare packages from lockfile before --no-pub execute harness.
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_jd_flutter_package_gate.sh"
s17_jd_flutter_package_prepare

set +e
bash "${ROOT}/tool/staging/run_s17_journey_d_execute_dart.sh"
EXEC_RC=$?
set -e

# Mandatory secret disposal if Dart did not shred (best effort).
if [[ -f "$CREDENTIAL_FILE" ]]; then
  python3 - <<PY
from pathlib import Path
p = Path("${CREDENTIAL_FILE}")
if p.is_file():
    try:
        data = p.read_bytes()
        p.write_bytes(b"\x00" * max(len(data), 64))
    except Exception:
        pass
    try:
        p.unlink()
    except Exception:
        pass
PY
fi

if [[ ! -f "$RESULT_FILE" ]]; then
  echo "JOURNEY_D_EXECUTION_FAILED"
  echo "DETAIL=no_result_file"
  echo "EXECUTE_RESULT=${RESULT_FILE}"
  echo "PRIVATE_DIR=${PRIVATE_DIR}"
  exit 2
fi

python3 - <<PY
import json, sys
from pathlib import Path
raw = Path("${RESULT_FILE}").read_text()
# Refuse if secrets leaked into result.
lower = raw.lower()
for banned in ("password", "@example.invalid"):
    # password key may appear as credential_consumed flags — check structured.
    pass
data = json.loads(raw)
for k in ("password", "athlete_password", "email", "access_token"):
    if k in data:
        print("REFUSED: secret key present in execute result", file=sys.stderr)
        raise SystemExit(2)
print("JOURNEY_D_EXECUTE_" + ("OK" if data.get("ok") else "FAILED"))
print("CLASSIFICATION=" + str(data.get("classification", "")))
print("JOURNEY_D_EXECUTED=" + str(data.get("journey_d_executed", False)).lower())
print("SWAP_EXERCISE=" + str(data.get("swap_exercise", False)).lower())
print("ATHLETE_AGREEMENT_RECORDED=" + str(data.get("athlete_agreement_recorded", False)).lower())
print("LATER_PUSH_UP_INTACT=" + str(data.get("later_push_up_intact", False)).lower())
print("JOURNEY_I_EXECUTION_COUNT=" + str(data.get("journey_i_execution_count", 0)))
print("JOURNEY_J_EXECUTION_COUNT=" + str(data.get("journey_j_execution_count", 0)))
print("CREDENTIAL_CONSUMED=" + str(data.get("credential_consumed", False)).lower())
print("CREDENTIAL_SHREDDED=" + str(data.get("credential_shredded", False)).lower())
print("EXECUTE_RESULT=${RESULT_FILE}")
print("ELIGIBILITY_RESULT=${ELIG_FILE}")
print("PRIVATE_DIR=${PRIVATE_DIR}")
if not data.get("ok"):
    raise SystemExit(2)
PY

exit "$EXEC_RC"
