#!/usr/bin/env bash
# Journey D execute Dart entry (s17_jd_adapt_* / PROG-S17-JD-ADAPT).
# Invoked only by execute_s17_journey_d_adaptation.sh after eligibility.
#
# Requires:
#   S17_JD_EXECUTE_REQUEST_FILE
#   S17_JD_EXECUTE_RESULT_FILE
#   S17_JD_CREDENTIAL_FILE
#
# Runtime: Flutter test harness (Flutter-bound graph; plain dart run crashes).

set -euo pipefail

ROOT="${S17_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fi
cd "$ROOT"

if [[ -z "${S17_JD_EXECUTE_REQUEST_FILE:-}" || -z "${S17_JD_EXECUTE_RESULT_FILE:-}" ]]; then
  echo "REFUSED: S17_JD_EXECUTE_REQUEST_FILE and S17_JD_EXECUTE_RESULT_FILE required" >&2
  exit 2
fi
if [[ -z "${S17_JD_CREDENTIAL_FILE:-}" ]]; then
  echo "REFUSED: S17_JD_CREDENTIAL_FILE required" >&2
  exit 2
fi
if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" || "${S17_JD_EXECUTE:-}" != "1" ]]; then
  echo "REFUSED: CONFIRM_COHORT_STAGING=1 and S17_JD_EXECUTE=1 required" >&2
  exit 2
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "REFUSED: flutter runtime required for Journey D execute entrypoint" >&2
  exit 2
fi

exec flutter test \
  --reporter expanded \
  test/staging/execute_s17_journey_d_harness_test.dart
