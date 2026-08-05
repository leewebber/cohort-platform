#!/usr/bin/env bash
# Hosted Journey D live mutation entry (B4d.21d.1 / B4d.21d.3).
# Invoked only by run_live_create after Python guards.
#
# Requires S17_JD_LIVE_REQUEST_FILE and S17_JD_LIVE_RESULT_FILE.
# Never uses --linked. Never executes Journey D.
#
# Runtime: Flutter test harness — required because the entrypoint is
# Flutter-bound (WidgetsFlutterBinding / supabase_flutter / ProtocolBuilder).
# Plain `dart run` crashes during FFI NativeCallable compilation
# (InvalidType / NativeCallable) before main().

set -euo pipefail

ROOT="${S17_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fi
cd "$ROOT"

if [[ -z "${S17_JD_LIVE_REQUEST_FILE:-}" || -z "${S17_JD_LIVE_RESULT_FILE:-}" ]]; then
  echo "REFUSED: S17_JD_LIVE_REQUEST_FILE and S17_JD_LIVE_RESULT_FILE required" >&2
  exit 2
fi

if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" || "${S17_JD_LIVE_CREATE:-}" != "1" ]]; then
  echo "REFUSED: CONFIRM_COHORT_STAGING=1 and S17_JD_LIVE_CREATE=1 required" >&2
  exit 2
fi

# Resolve flutter from PATH; never fall back to plain dart run for this entry.
if ! command -v flutter >/dev/null 2>&1; then
  echo "REFUSED: flutter runtime required for Journey D live entrypoint" >&2
  exit 2
fi

# One supported path: Flutter test harness → runJourneyDLiveEntrypoint.
exec flutter test \
  --reporter expanded \
  test/staging/create_s17_journey_d_live_harness_test.dart
