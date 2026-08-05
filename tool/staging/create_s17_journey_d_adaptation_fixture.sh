#!/usr/bin/env bash
# Create / dry-run Cohort Staging Journey D adaptation fixture (B4d.20–B4d.21d.1).
#
# Fail-closed:
#   CONFIRM_COHORT_STAGING=1 required
#   Linked/selected project must be Cohort Staging (tsbadngz…, eu-west-2)
#   Production (otnhhdxs… / Cohort Field Manual) rejected
#   Live mutation requires S17_JD_LIVE_CREATE=1 and --marker <fixture-marker>
#   Default is zero-write dry-run
#
# Modes:
#   --dry-run   (default) identity + package contract + write manifest; no hosted write
#   --live      requires S17_JD_LIVE_CREATE=1 and --marker; guarded hosted creation
#   --marker <fixture-marker>  required for --live; optional for dry-run
#   --help
#
# Never reuses Athlete C/D, S15A, or S13. Never executes Journey D.
# Never uses supabase --linked.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

MODE=""
SHOW_HELP=0
MARKER_SET=0
EXPLICIT_MARKER=""
SAW_DRY=0
SAW_LIVE=0

usage() {
  cat <<'EOF'
Usage:
  CONFIRM_COHORT_STAGING=1 ./tool/staging/create_s17_journey_d_adaptation_fixture.sh [--dry-run] [--marker <fixture-marker>]
  CONFIRM_COHORT_STAGING=1 S17_JD_LIVE_CREATE=1 \
    ./tool/staging/create_s17_journey_d_adaptation_fixture.sh \
      --live --marker <fixture-marker>

Creates (live) or plans (dry-run) one Journey D adaptation fixture matching
the B4d.19 equipment contract (back_squat → goblet_squat).

Options:
  --dry-run   Zero hosted writes; emit redacted intended-write manifest (default)
  --marker <fixture-marker>
              Bind an explicit fixture marker (validated before target resolution).
              Required for --live. When omitted in dry-run, a fresh marker is generated.
  --live      Requires S17_JD_LIVE_CREATE=1 and --marker; one guarded hosted create
  --help      Show this help

Environment:
  CONFIRM_COHORT_STAGING=1   Required
  S17_JD_LIVE_CREATE=1       Required for --live
  S17_PROJECTS_JSON_FILE     Required projects list (use test fixture; no hosted default)
  S17_API_ENV                Hosted API env for --live (default /tmp/s13b_api.env)
  S17_JD_LIVE_MUTATION_BACKEND
              hosted (default) | synthetic_ok | synthetic_fail:<stage>
              Tests must use synthetic_*; never contact staging from unit tests.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      if [[ "$SAW_LIVE" -eq 1 ]]; then
        echo "REFUSED: --dry-run and --live cannot be combined" >&2
        exit 2
      fi
      SAW_DRY=1
      MODE="dry_run"
      shift
      ;;
    --live)
      if [[ "$SAW_DRY" -eq 1 ]]; then
        echo "REFUSED: --dry-run and --live cannot be combined" >&2
        exit 2
      fi
      SAW_LIVE=1
      MODE="live"
      shift
      ;;
    --marker)
      if [[ "$MARKER_SET" -eq 1 ]]; then
        echo "REFUSED: --marker may be supplied only once" >&2
        usage >&2
        exit 2
      fi
      if [[ $# -lt 2 || -z "${2:-}" || "${2:0:2}" == "--" ]]; then
        echo "REFUSED: --marker requires exactly one non-empty value" >&2
        usage >&2
        exit 2
      fi
      EXPLICIT_MARKER="$2"
      MARKER_SET=1
      shift 2
      ;;
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

if [[ -z "$MODE" ]]; then
  MODE="dry_run"
fi

s17_require_confirmation
s17_require_commands python3

# Validate explicit marker as data before any target resolution or hosted contact.
if [[ "$MARKER_SET" -eq 1 ]]; then
  export S17_JD_FIXTURE_MARKER="$EXPLICIT_MARKER"
  python3 - <<'PY'
import os
import sys
from pathlib import Path

root = Path(os.environ["S17_ROOT"])
sys.path.insert(0, str(root / "tool/staging/lib"))
from s17_journey_d_fixture import (
    StagingGuardError,
    reject_reserved_identity,
    validate_marker,
)

marker = os.environ.get("S17_JD_FIXTURE_MARKER", "")
try:
    if not marker:
        raise StagingGuardError(
            "REFUSED: --marker requires exactly one non-empty value"
        )
    validate_marker(marker)
    reject_reserved_identity(marker)
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY
else
  unset S17_JD_FIXTURE_MARKER || true
fi

if [[ "$MODE" == "live" && "$MARKER_SET" -ne 1 ]]; then
  echo "REFUSED: --live requires --marker <fixture-marker>" >&2
  usage >&2
  exit 2
fi

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
from s17_journey_d_fixture import StagingGuardError, run_live_create
from s17_staging_guard import parse_projects_json

root = Path("${ROOT}")
fixture = os.environ.get("S17_PROJECTS_JSON_FILE", "").strip()
if not fixture:
    print("REFUSED: missing S17_PROJECTS_JSON_FILE", file=sys.stderr)
    raise SystemExit(2)
projects_raw = Path(fixture).read_text()
parse_projects_json(projects_raw)

marker = os.environ.get("S17_JD_FIXTURE_MARKER")
try:
    result = run_live_create(
        root=root,
        projects_raw=projects_raw,
        marker=marker,
    )
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    Path("${RESULT_FILE}").write_text(json.dumps({
        "ok": False,
        "mode": "live",
        "classification": "B4D21D1_LIVE_REFUSED",
        "hosted_writes_executed": 0,
        "publish_draft_invocations": 0,
        "detail": str(e),
    }, indent=2))
    raise SystemExit(2)

Path("${MANIFEST_FILE}").write_text(json.dumps(result.get("manifest", {}), indent=2))
Path("${MANIFEST_FILE}").chmod(0o600)
Path("${LEDGER_FILE}").write_text(json.dumps(result.get("ledger", {}), indent=2))
Path("${LEDGER_FILE}").chmod(0o600)
Path("${RESULT_FILE}").write_text(json.dumps(result, indent=2))
Path("${RESULT_FILE}").chmod(0o600)

print("LIVE_CREATE_" + ("OK" if result.get("ok") else "FAILED"))
print("FIXTURE_MARKER=" + str(result.get("fixture_marker") or marker))
print("MUTATION_BACKEND=" + str(result.get("mutation_backend", "unknown")))
print("HOSTED_WRITES_EXECUTED=" + str(result.get("hosted_writes_executed", 0)))
print("SYNTHETIC_MUTATIONS=" + str(result.get("synthetic_mutations", 0)))
print("PUBLISH_DRAFT_INVOCATIONS=" + str(result.get("publish_draft_invocations", 0)))
print("REBIND_PATH=" + str(result.get("rebind_path", "REBIND_PATH_UNKNOWN")))
print("JOURNEY_D_EXECUTED=" + str(result.get("journey_d_executed", False)).lower())
print("CLASSIFICATION=" + str(result.get("classification", "")))
print("REDACTED_MANIFEST=${MANIFEST_FILE}")
print("WRITE_LEDGER=${LEDGER_FILE}")
if not result.get("ok"):
    raise SystemExit(2)
PY
  exit 0
fi

# Dry-run path (default). Marker is read from env as data — not interpolated.
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
parse_projects_json(projects_raw)

dry_kwargs = {"root": root, "projects_raw": projects_raw}
if "S17_JD_FIXTURE_MARKER" in os.environ:
    dry_kwargs["marker"] = os.environ["S17_JD_FIXTURE_MARKER"]

try:
    result = run_dry_run(**dry_kwargs)
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
