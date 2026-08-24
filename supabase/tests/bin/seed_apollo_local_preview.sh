#!/usr/bin/env bash
# Recreate the founder-preview Apollo state in an externally prepared,
# disposable local Supabase workdir. This intentionally reuses Gate AF rather
# than maintaining a parallel import/enrolment/materialisation seed dump.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "usage: $0 <external-disposable-supabase-workdir> [start-date] [iana-timezone]" >&2
  exit 64
fi

WORKDIR="$1"
START_DATE="${2:-2026-09-01}"
PROGRAMME_TIMEZONE="${3:-Atlantic/Canary}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

[[ "$START_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || {
  echo "invalid start date: $START_DATE" >&2
  exit 64
}
[[ "$PROGRAMME_TIMEZONE" =~ ^[A-Za-z_+-]+(/[A-Za-z0-9_+-]+)+$ ]] || {
  echo "invalid IANA timezone: $PROGRAMME_TIMEZONE" >&2
  exit 64
}

case "$WORKDIR" in
  /private/tmp/*|/var/folders/*) ;;
  *)
    echo "refusing non-disposable workdir: $WORKDIR" >&2
    exit 65
    ;;
esac

[[ -f "$WORKDIR/supabase/config.toml" ]] || {
  echo "missing Supabase config in $WORKDIR" >&2
  exit 66
}

supabase start \
  --workdir "$WORKDIR" \
  --exclude edge-runtime,imgproxy,inbucket,realtime,storage,studio,vector \
  --ignore-health-check
supabase db reset --local --no-seed --yes --workdir "$WORKDIR"

STATUS_JSON="$(supabase status -o json --workdir "$WORKDIR")"
API_URL="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["API_URL"])' <<<"$STATUS_JSON")"
case "$API_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "refusing non-loopback Supabase endpoint: $API_URL" >&2
    exit 67
    ;;
esac

PROJECT_ID="$(rg -n '^project_id\s*=' "$WORKDIR/supabase/config.toml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
[[ -n "$PROJECT_ID" ]] || { echo "missing local project id" >&2; exit 68; }
DB_CONTAINER="supabase_db_${PROJECT_ID}"
docker inspect "$DB_CONTAINER" >/dev/null

PAYLOAD="$(mktemp /private/tmp/apollo-preview-payload.XXXXXX.json)"
trap 'rm -f "$PAYLOAD"' EXIT
(cd "$ROOT_DIR" && dart run supabase/tests/bin/emit_apollo_import_payload.dart "$PAYLOAD")

docker cp "$ROOT_DIR/supabase/tests/sql/helpers.sql" "$DB_CONTAINER:/tmp/sprint12_helpers.sql"
docker cp "$ROOT_DIR/supabase/tests/sql/gate_af_apollo_import_replacement_materialisation.sql" "$DB_CONTAINER:/tmp/sprint12_gate_af.sql"
docker cp "$ROOT_DIR/supabase/tests/sql/gate_ak_apollo_structured_warmup.sql" "$DB_CONTAINER:/tmp/sprint12_gate_ak.sql"
docker cp "$ROOT_DIR/supabase/tests/sql/seed_apollo_calendar_preview.sql" "$DB_CONTAINER:/tmp/sprint12_seed_apollo_calendar_preview.sql"
docker cp "$PAYLOAD" "$DB_CONTAINER:/tmp/sprint12_apollo_import_payload.json"

docker exec -i "$DB_CONTAINER" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_helpers.sql \
  -f /tmp/sprint12_gate_af.sql \
  -f /tmp/sprint12_gate_ak.sql \
  -v preview_start_date="$START_DATE" \
  -v preview_timezone="$PROGRAMME_TIMEZONE" \
  -f /tmp/sprint12_seed_apollo_calendar_preview.sql

echo "Apollo local preview seed PASSED: api=$API_URL start=$START_DATE timezone=$PROGRAMME_TIMEZONE (loopback only)"
