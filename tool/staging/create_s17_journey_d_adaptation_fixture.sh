#!/usr/bin/env bash
# Create / dry-run Cohort Staging Journey D adaptation fixture (B4d.20 tooling).
#
# Fail-closed:
#   CONFIRM_COHORT_STAGING=1 required
#   Linked/selected project must be Cohort Staging (tsbadngz…, eu-west-2)
#   Production (otnhhdxs… / Cohort Field Manual) rejected
#   Live mutation requires separate S17_JD_LIVE_CREATE=1
#   Default is zero-write dry-run
#
# Modes:
#   --dry-run   (default) identity + package contract + write manifest; no hosted write
#   --live      requires S17_JD_LIVE_CREATE=1; B4d.20 refuses hosted mutation (tooling only)
#   --help
#
# Never reuses Athlete C/D, S15A, or S13. Never executes Journey D.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

MODE="dry_run"
SHOW_HELP=0

usage() {
  cat <<'EOF'
Usage:
  CONFIRM_COHORT_STAGING=1 ./tool/staging/create_s17_journey_d_adaptation_fixture.sh [--dry-run]
  CONFIRM_COHORT_STAGING=1 S17_JD_LIVE_CREATE=1 \
    ./tool/staging/create_s17_journey_d_adaptation_fixture.sh --live

Creates (future live) or plans (dry-run) one Journey D adaptation fixture matching
the B4d.19 equipment contract (back_squat → goblet_squat).

Options:
  --dry-run   Zero hosted writes; emit redacted intended-write manifest (default)
  --live      Requires S17_JD_LIVE_CREATE=1; B4d.20 tooling refuses actual mutation
  --help      Show this help

Environment:
  CONFIRM_COHORT_STAGING=1   Required
  S17_JD_LIVE_CREATE=1       Required for --live (still refused in B4d.20)
  S17_PROJECTS_JSON_FILE     Required projects list (use test fixture; no hosted default)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry_run"; shift ;;
    --live) MODE="live"; shift ;;
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
s17_require_commands python3

# Never default to a hosted management target. B4d.20 is local tooling only.
if [[ -z "${S17_PROJECTS_JSON_FILE:-}" ]]; then
  echo "REFUSED: S17_PROJECTS_JSON_FILE required (no default hosted target)." >&2
  echo "Hint: test/staging/fixtures/s17_projects_list.json" >&2
  exit 2
fi

s17_confirm_staging_identity

PRIVATE_DIR="$(mktemp -d "/tmp/cohort_s17_jd_adapt.XXXXXXXX")"
chmod 700 "$PRIVATE_DIR"
PRIVATE_DIR="$(cd "$PRIVATE_DIR" && pwd -P)"
s17_assert_outside_worktrees "$PRIVATE_DIR"

MANIFEST_FILE="${PRIVATE_DIR}/redacted_manifest.json"
LEDGER_FILE="${PRIVATE_DIR}/write_ledger.json"
RESULT_FILE="${PRIVATE_DIR}/result.json"

if [[ "$MODE" == "live" ]]; then
  python3 - <<PY
import json, os, sys
from pathlib import Path
sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_journey_d_fixture import StagingGuardError, run_live_gate_check
try:
    run_live_gate_check()
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    Path("${RESULT_FILE}").write_text(json.dumps({
        "ok": False,
        "mode": "live",
        "classification": "B4D20_LIVE_REFUSED_TOOLING_ONLY",
        "hosted_writes": 0,
        "detail": str(e),
    }, indent=2))
    raise SystemExit(2)
PY
fi

# Dry-run path (default)
python3 - <<PY
import json, os, sys
from pathlib import Path

sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_journey_d_fixture import StagingGuardError, run_dry_run
from s17_staging_guard import parse_projects_json

root = Path("${ROOT}")
fixture = os.environ.get("S17_PROJECTS_JSON_FILE", "").strip()
if not fixture:
    print("REFUSED: missing S17_PROJECTS_JSON_FILE", file=sys.stderr)
    raise SystemExit(2)
projects_raw = Path(fixture).read_text()
# Prove parse before run
parse_projects_json(projects_raw)

try:
    result = run_dry_run(root=root, projects_raw=projects_raw)
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    Path("${RESULT_FILE}").write_text(json.dumps({
        "ok": False,
        "mode": "dry_run",
        "hosted_writes": 0,
        "detail": str(e),
    }, indent=2))
    raise SystemExit(2)

Path("${MANIFEST_FILE}").write_text(json.dumps(result["manifest"], indent=2))
Path("${MANIFEST_FILE}").chmod(0o600)
Path("${LEDGER_FILE}").write_text(json.dumps(result["ledger"], indent=2))
Path("${LEDGER_FILE}").chmod(0o600)
Path("${RESULT_FILE}").write_text(json.dumps(result, indent=2))
Path("${RESULT_FILE}").chmod(0o600)

print("DRY_RUN_OK: Journey D adaptation fixture not created; no hosted write.")
print("FIXTURE_MARKER=" + result["manifest"]["fixture_marker"])
print("LINEAGE=" + result["manifest"]["lineage_code"])
print("STAGING_REF_PREFIX=" + result["staging_ref_prefix"])
print("HOSTED_WRITES=0")
print("JOURNEY_D_EXECUTION=disabled")
print("REBIND_PATH=" + result.get("rebind_path", "REBIND_PATH_UNKNOWN"))
print("PUBLISH_DRAFT_INVOKED=" + str(result.get("publish_draft_invoked", False)).lower())
print("REDACTED_MANIFEST=${MANIFEST_FILE}")
print("WRITE_LEDGER=${LEDGER_FILE}")
print("OPERATION_COUNTS=" + json.dumps(result["operation_counts"], separators=(",", ":")))
PY
