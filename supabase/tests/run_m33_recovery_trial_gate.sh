#!/usr/bin/env bash
# Real GoTrue/PostgREST journey against a checked, disposable Supabase project.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
cleanup() {
  local result=0
  supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1 || result=$?
  rm -rf "$SPRINT12_WORKDIR"
  return "$result"
}
trap cleanup EXIT
umask 077
cd "$REPO_ROOT"
# Separately deferred HYROX publisher; same baseline as the M3.2 trial gate.
rm "$SPRINT12_WORKDIR/supabase/migrations/20261026120000_durable_publication_approval_events.sql"
migration=20261113120000_approved_strength_recovery_option.sql
mv "$SPRINT12_WORKDIR/supabase/migrations/$migration" "$SPRINT12_WORKDIR/$migration"
cat >> "$SPRINT12_WORKDIR/supabase/config.toml" <<'LOCAL_AUTH'
[auth.email]
enable_signup = true
enable_confirmations = false
max_frequency = "0s"
LOCAL_AUTH

M31_LOCAL_PAYLOAD="$SPRINT12_WORKDIR/equipment.json" M32_LOCAL_PAYLOAD="$SPRINT12_WORKDIR/time.json" \
  M33_LOCAL_PAYLOAD="$SPRINT12_WORKDIR/recovery.json" \
  flutter test --no-pub --reporter expanded test/application/adaptation/{m31_trial_candidate,m32_trial_candidate,m33_trial_candidate}_test.dart
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check > "$SPRINT12_WORKDIR/start.log" 2>&1 || {
  # Show only the failing SQL migration and diagnostic; status can include keys.
  rg -i '^Applying migration|^ERROR:|^At statement|^failed|^Stopping|^Starting|^Waiting|^Cannot|^Try rerunning|^Error status' "$SPRINT12_WORKDIR/start.log" | tail -16
  exit 1
}
db="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$db" "$SPRINT12_PROJECT_ID"
mv "$SPRINT12_WORKDIR/$migration" "$SPRINT12_WORKDIR/supabase/migrations/$migration"
supabase db push --local --workdir "$SPRINT12_WORKDIR" --dry-run > "$SPRINT12_WORKDIR/preview.log" 2>&1 || {
  rg -i '^failed|^error|^cannot|^try rerunning' "$SPRINT12_WORKDIR/preview.log"
  exit 1
}
rg -F "$migration" "$SPRINT12_WORKDIR/preview.log"
test "$(rg -c '[0-9]{14}_[^[:space:]]+\.sql' "$SPRINT12_WORKDIR/preview.log")" -eq 1
supabase db push --local --workdir "$SPRINT12_WORKDIR" --yes > "$SPRINT12_WORKDIR/apply.log" 2>&1 || {
  rg '^Applying migration|^ERROR:|^At statement' "$SPRINT12_WORKDIR/apply.log"
  exit 1
}
supabase db push --local --workdir "$SPRINT12_WORKDIR" --dry-run > "$SPRINT12_WORKDIR/after.log" 2>&1
rg -F 'Local database is up to date.' "$SPRINT12_WORKDIR/after.log"
{
  python3 "$TESTS_DIR/fixtures/seed_m32_trial_gate.py" "$SPRINT12_WORKDIR/equipment.json" "$SPRINT12_WORKDIR/time.json"
  cat "$TESTS_DIR/sql/gate_m31_approved_equipment_substitutions.sql" "$TESTS_DIR/sql/gate_m32_strength_time_option.sql"
} | docker exec -i "$db" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1
supabase status -o json --workdir "$SPRINT12_WORKDIR" > "$SPRINT12_WORKDIR/status.json" 2>/dev/null
python3 - "$SPRINT12_WORKDIR/status.json" "$db" <<'PY'
from pathlib import Path
import json
import sys
path = Path(sys.argv[1])
status = json.loads(path.read_text())
path.write_text(json.dumps({**status, "CONTAINER": sys.argv[2]}))
PY
# Record authentic Time completions before the Recovery version is published.
M31_LOCAL_CONFIG="$SPRINT12_WORKDIR/status.json" \
  flutter test --no-pub --reporter expanded test/application/adaptation/m31_thursday_trial_local_test.dart
M33_LOCAL_CONFIG="$SPRINT12_WORKDIR/status.json" M33_LOCAL_PAYLOAD="$SPRINT12_WORKDIR/recovery.json" \
  flutter test --no-pub --reporter expanded test/application/adaptation/m33_recovery_trial_local_test.dart
