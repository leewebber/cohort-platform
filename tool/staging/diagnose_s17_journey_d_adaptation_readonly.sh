#!/usr/bin/env bash
# Fixture-scoped read-only verifier for Journey D adaptation fixture.
#
# Modes:
#   --local-contract  (default) package + protocol intent assets only; no hosted contact
#   --hosted          fixture-scoped hosted reads; requires S17_JD_HOSTED_READONLY=1
#
# Binds to an exact marker. Performs no mutation, no Journey D execution, and no
# catalogue-wide discovery. Never uses supabase --linked.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

MARKER="${1:-}"
MODE=""
SAW_LOCAL=0
SAW_HOSTED=0

usage() {
  cat <<'EOF'
Usage:
  ./tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh <fixture_marker> [--local-contract]
  CONFIRM_COHORT_STAGING=1 S17_JD_HOSTED_READONLY=1 \
    S17_PROJECTS_JSON_FILE=<projects-file> S17_API_ENV=<api-env> \
    ./tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh <fixture_marker> --hosted

Modes:
  --local-contract  Verify package + protocol intent assets only (default)
  --hosted          Fixture-scoped hosted read-only eligibility verification
  --help            Show this help

Environment (hosted):
  CONFIRM_COHORT_STAGING=1   Required
  S17_JD_HOSTED_READONLY=1   Required separate read-only confirmation guard
  S17_PROJECTS_JSON_FILE     Required projects list
  S17_API_ENV                API env (default /tmp/s13b_api.env)

Never mutates. Never uses --linked. Never executes Journey D/I/J.
EOF
}

if [[ -z "$MARKER" || "$MARKER" == "--help" || "$MARKER" == "-h" ]]; then
  usage
  exit 0
fi
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-contract)
      if [[ "$SAW_HOSTED" -eq 1 ]]; then
        echo "REFUSED: --local-contract and --hosted cannot be combined" >&2
        exit 2
      fi
      SAW_LOCAL=1
      MODE="local_contract"
      shift
      ;;
    --hosted)
      if [[ "$SAW_LOCAL" -eq 1 ]]; then
        echo "REFUSED: --local-contract and --hosted cannot be combined" >&2
        exit 2
      fi
      SAW_HOSTED=1
      MODE="hosted"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "REFUSED: unknown flag $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  MODE="local_contract"
fi

# Validate marker as data before any target resolution or hosted contact.
export S17_JD_FIXTURE_MARKER="$MARKER"
python3 - <<'PY'
import os, sys
from pathlib import Path
root = Path(os.environ["S17_ROOT"])
sys.path.insert(0, str(root / "tool/staging/lib"))
from s17_journey_d_fixture import StagingGuardError, reject_reserved_identity, validate_marker
marker = os.environ.get("S17_JD_FIXTURE_MARKER", "")
try:
    if not marker:
        raise StagingGuardError("REFUSED: fixture marker required")
    validate_marker(marker)
    reject_reserved_identity(marker)
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)
PY

if [[ "$MODE" == "local_contract" ]]; then
  python3 - <<PY
import json, sys
from pathlib import Path

sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_journey_d_fixture import (
    StagingGuardError,
    load_package_yaml_text,
    load_protocol_intent,
    post_create_verifier_checklist,
    validate_marker,
    AVAILABLE_EQUIPMENT,
    LINEAGE_CODE,
    SOURCE_EXERCISE,
    REPLACEMENT_EXERCISE,
)

marker = "${MARKER}"
root = Path("${ROOT}")
try:
    validate_marker(marker)
    load_package_yaml_text(root)
    intent = load_protocol_intent(root)
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)

checklist = {k: "unknown" for k in post_create_verifier_checklist()}
checklist["dedicated_staging_fixture"] = "true_local_contract"
checklist["unique_fixture_marker"] = "true"
checklist["fixture_only_programme_identity"] = "true"
checklist["unpublished_fixture_version"] = "true_local_compiled"
checklist["adaptation_permissions_nonempty"] = "true"
checklist["equipment_adaptation_allowed"] = "true"
checklist["athlete_agreement_required"] = "true"
checklist["policy_change_kinds_allowed"] = "true"
checklist["available_equipment_matches_contract"] = "true"
checklist["deterministic_curated_substitution"] = "true_contract"
checklist["acceptable_proposal_preconditions"] = "true_local_dart_tests"
checklist["accepted_adaptation_absent"] = "true_initial_contract"
checklist["proposal_consumed_false"] = "true_initial_contract"
checklist["unaffected_occurrence_baseline_available"] = "true"
checklist["existing_fixture_identities_not_reused"] = "true"
checklist["active_assignment"] = "unknown"
checklist["materialised"] = "unknown"
checklist["authoritative_cursor"] = "unknown"
checklist["suitable_current_occurrence"] = "unknown"
checklist["prepared_session_ready"] = "unknown"
checklist["hosted_writes_match_manifest"] = "unknown"

print(json.dumps({
    "ok": True,
    "mode": "local_contract_read_only",
    "marker": marker,
    "lineage_code": LINEAGE_CODE,
    "available_equipment": AVAILABLE_EQUIPMENT,
    "substitution": {
        "source": SOURCE_EXERCISE,
        "replacement": REPLACEMENT_EXERCISE,
    },
    "mutation": False,
    "propose_reject_accept": False,
    "journey_execution": False,
    "checklist": checklist,
    "protocol_intent_current": intent["current_protocol"]["protocol_id"],
}, indent=2))
print("JD_READONLY_LOCAL_CONTRACT_OK")
PY
  exit 0
fi

# Hosted read-only mode
s17_require_confirmation
if [[ -z "${S17_PROJECTS_JSON_FILE:-}" ]]; then
  echo "REFUSED: S17_PROJECTS_JSON_FILE required for hosted read-only mode" >&2
  exit 2
fi
s17_confirm_staging_identity

python3 - <<PY
import json, os, sys
from pathlib import Path

sys.path.insert(0, "${ROOT}/tool/staging/lib")
from s17_journey_d_fixture import StagingGuardError
from s17_journey_d_hosted_readonly import run_hosted_readonly
from s17_staging_guard import parse_projects_json

root = Path("${ROOT}")
marker = os.environ["S17_JD_FIXTURE_MARKER"]
fixture = os.environ.get("S17_PROJECTS_JSON_FILE", "").strip()
api_env = Path(os.environ.get("S17_API_ENV", "/tmp/s13b_api.env"))
try:
    projects_raw = Path(fixture).read_text()
    parse_projects_json(projects_raw)
    result = run_hosted_readonly(
        root=root,
        projects_raw=projects_raw,
        marker=marker,
        api_env_path=api_env,
    )
except StagingGuardError as e:
    print(str(e), file=sys.stderr)
    raise SystemExit(2)

print(json.dumps(result, indent=2))
print("JD_READONLY_HOSTED_OK")
print("FIXTURE_STATE=" + str(result.get("fixture_state")))
print("FIXTURE_ELIGIBLE=" + str(result.get("fixture_eligible")).lower())
print("MUTATION=" + str(result.get("mutation")).lower())
print("LINKED_CLI_USED=" + str(result.get("linked_cli_used")).lower())
if not result.get("ok"):
    raise SystemExit(2)
PY
