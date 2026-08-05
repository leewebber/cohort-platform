#!/usr/bin/env bash
# Hosted Journey D live mutation entry (non-test runtime).
# Invoked only by run_live_create after Python guards + package preparation.
#
# Requires S17_JD_LIVE_REQUEST_FILE and S17_JD_LIVE_RESULT_FILE.
# Never uses --linked. Never executes Journey D.
#
# Runtime:
#   hosted / default → non-test Flutter executable (`flutter run --no-pub`)
#   fake + allow     → flutter test --no-pub (local contract only; no hosted traffic)
#
# Package resolution is forbidden here: callers must prepare via
# s17_jd_flutter_package_prepare; this launcher uses --no-pub only.

set -euo pipefail

ROOT="${S17_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fi
cd "$ROOT"
export S17_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_jd_flutter_package_gate.sh"
# shellcheck disable=SC1091
source "${ROOT}/tool/staging/lib/s17_jd_nontest_launch.sh"

if [[ -z "${S17_JD_LIVE_REQUEST_FILE:-}" || -z "${S17_JD_LIVE_RESULT_FILE:-}" ]]; then
  echo "REFUSED: S17_JD_LIVE_REQUEST_FILE and S17_JD_LIVE_RESULT_FILE required" >&2
  exit 2
fi

PORTS_MODE="${S17_JD_LIVE_PORTS:-hosted}"

if [[ "${S17_JD_LOOPBACK_PROOF:-}" == "1" ]]; then
  :
elif [[ "$PORTS_MODE" == "fake" && "${S17_JD_ALLOW_FAKE_PORTS:-}" == "1" ]]; then
  :
elif [[ "${CONFIRM_COHORT_STAGING:-}" != "1" || "${S17_JD_LIVE_CREATE:-}" != "1" ]]; then
  echo "REFUSED: CONFIRM_COHORT_STAGING=1 and S17_JD_LIVE_CREATE=1 required" >&2
  exit 2
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "REFUSED: flutter runtime required for Journey D live entrypoint" >&2
  exit 2
fi

s17_jd_flutter_package_require

# Fake-only local contract: flutter test is acceptable (no hosted traffic).
if [[ "$PORTS_MODE" == "fake" && "${S17_JD_ALLOW_FAKE_PORTS:-}" == "1" && "${S17_JD_LOOPBACK_PROOF:-}" != "1" ]]; then
  echo "JD_RUNTIME=flutter_test_fake_only"
  exec flutter test \
    --no-pub \
    --reporter expanded \
    test/staging/create_s17_journey_d_live_harness_test.dart
fi

# Hosted / loopback proof: non-test executable only.
echo "JD_RUNTIME=flutter_run_nontest"
s17_jd_nontest_flutter_run \
  "lib/staging_tooling/journey_d/journey_d_live_main.dart" \
  "S17_JD_LIVE_RESULT_FILE" \
  "live"
