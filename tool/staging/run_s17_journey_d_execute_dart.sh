#!/usr/bin/env bash
# Journey D execute Dart entry (s17_jd_adapt_* / PROG-S17-JD-ADAPT).
# Invoked only by execute_s17_journey_d_adaptation.sh after eligibility.
#
# Requires:
#   S17_JD_EXECUTE_REQUEST_FILE
#   S17_JD_EXECUTE_RESULT_FILE
#   S17_JD_CREDENTIAL_FILE (except loopback proof)
#
# Runtime:
#   hosted / default → non-test Flutter executable (`flutter run --no-pub`)
#   fake + allow     → flutter test --no-pub (local contract only)

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

if [[ -z "${S17_JD_EXECUTE_REQUEST_FILE:-}" || -z "${S17_JD_EXECUTE_RESULT_FILE:-}" ]]; then
  echo "REFUSED: S17_JD_EXECUTE_REQUEST_FILE and S17_JD_EXECUTE_RESULT_FILE required" >&2
  exit 2
fi

PORTS_MODE="${S17_JD_EXECUTE_PORTS:-hosted}"

if [[ "${S17_JD_LOOPBACK_PROOF:-}" == "1" ]]; then
  :
elif [[ "$PORTS_MODE" == "fake" && "${S17_JD_ALLOW_FAKE_PORTS:-}" == "1" ]]; then
  :
else
  if [[ -z "${S17_JD_CREDENTIAL_FILE:-}" ]]; then
    echo "REFUSED: S17_JD_CREDENTIAL_FILE required" >&2
    exit 2
  fi
  if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" || "${S17_JD_EXECUTE:-}" != "1" ]]; then
    echo "REFUSED: CONFIRM_COHORT_STAGING=1 and S17_JD_EXECUTE=1 required" >&2
    exit 2
  fi
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "REFUSED: flutter runtime required for Journey D execute entrypoint" >&2
  exit 2
fi

s17_jd_flutter_package_require

if [[ "$PORTS_MODE" == "fake" && "${S17_JD_ALLOW_FAKE_PORTS:-}" == "1" && "${S17_JD_LOOPBACK_PROOF:-}" != "1" ]]; then
  echo "JD_RUNTIME=flutter_test_fake_only"
  # Harness suite is tagged and skipped by default (dart_test.yaml).
  exec flutter test \
    --no-pub \
    --reporter expanded \
    --tags harness \
    --run-skipped \
    test/staging/execute_s17_journey_d_harness_test.dart
fi

echo "JD_RUNTIME=flutter_run_nontest"
s17_jd_nontest_flutter_run \
  "lib/staging_tooling/journey_d/journey_d_execute_main.dart" \
  "S17_JD_EXECUTE_RESULT_FILE" \
  "execute"
