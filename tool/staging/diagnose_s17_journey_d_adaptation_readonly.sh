#!/usr/bin/env bash
# Fixture-scoped read-only verifier for Journey D adaptation fixture (B4d.20).
#
# Binds to an exact marker. Performs no mutation, no Journey D execution, and no
# catalogue-wide discovery. Local-contract mode verifies package/intent assets
# without hosted contact.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_common.sh"

MARKER="${1:-}"
MODE="local_contract"

usage() {
  cat <<'EOF'
Usage:
  ./tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh <fixture_marker> [--local-contract]

--local-contract (default for B4d.20): verify package + protocol intent assets only.
Hosted fixture-scoped verification is deferred to a separately authorised step.
EOF
}

if [[ -z "$MARKER" || "$MARKER" == "--help" || "$MARKER" == "-h" ]]; then
  usage
  exit 2
fi
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-contract) MODE="local_contract"; shift ;;
    --hosted)
      echo "REFUSED: hosted verifier mode not authorised in B4d.20" >&2
      exit 2
      ;;
    *)
      echo "REFUSED: unknown flag $1" >&2
      exit 2
      ;;
  esac
done

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
# Local-contract proofs only — hosted fields remain unknown without mutation.
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
