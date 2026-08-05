#!/usr/bin/env bash
# Hosted Journey D live mutation entry (B4d.21d.1). Invoked only by run_live_create.
# Requires S17_JD_LIVE_REQUEST_FILE and S17_JD_LIVE_RESULT_FILE.
# Never uses --linked. Never executes Journey D.

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

# Prefer flutter dart from the SDK; never pass --linked to supabase CLI.
exec dart run tool/staging/bin/create_s17_journey_d_live.dart
