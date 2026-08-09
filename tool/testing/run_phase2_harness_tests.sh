#!/usr/bin/env bash
# Phase 2.2 — explicit Journey D fake-harness test group.
#
# Not part of the default `flutter test` suite (tagged `harness`, skipped by
# dart_test.yaml). Prepares local request/result files and runs the fake-port
# entrypoint tests without hosted contact.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d "/tmp/phase2_harness.XXXXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

MARKER="s17_jd_adapt_20260809T120000Z_a1b2c3d4"
LIVE_REQ="$TMP/live_req.json"
LIVE_OUT="$TMP/live_out.json"
EXEC_REQ="$TMP/exec_req.json"
EXEC_OUT="$TMP/exec_out.json"

cat >"$LIVE_REQ" <<EOF
{
  "marker": "$MARKER",
  "root": "$ROOT",
  "package_rel": "tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml",
  "protocol_intent_rel": "tool/staging/fixtures/journey_d/protocol_intent.json",
  "api_env_path": "$TMP/missing.env"
}
EOF
echo '{}' >"$EXEC_REQ"

export S17_JD_LIVE_PORTS=fake
export S17_JD_EXECUTE_PORTS=fake
export S17_JD_ALLOW_FAKE_PORTS=1
export S17_JD_LIVE_REQUEST_FILE="$LIVE_REQ"
export S17_JD_LIVE_RESULT_FILE="$LIVE_OUT"
export S17_JD_EXECUTE_REQUEST_FILE="$EXEC_REQ"
export S17_JD_EXECUTE_RESULT_FILE="$EXEC_OUT"
export S17_JD_CREDENTIAL_FILE="$TMP/cred.json"

echo "PHASE2_HARNESS_GROUP=start"
flutter test --tags harness --run-skipped \
  test/staging/create_s17_journey_d_live_harness_test.dart \
  test/staging/execute_s17_journey_d_harness_test.dart
echo "PHASE2_HARNESS_GROUP=pass"
