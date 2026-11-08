#!/usr/bin/env bash
# Replay the private time trial and both M3.1 database regressions on loopback.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
trap 'supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1 || true; rm -rf "$SPRINT12_WORKDIR"' EXIT
umask 077
cd "$REPO_ROOT"
rm "$SPRINT12_WORKDIR/supabase/migrations/20261026120000_durable_publication_approval_events.sql"
migration=20261108130000_approved_strength_time_options.sql
mv "$SPRINT12_WORKDIR/supabase/migrations/$migration" "$SPRINT12_WORKDIR/$migration"
cat >> "$SPRINT12_WORKDIR/supabase/config.toml" <<'LOCAL_AUTH'
[auth.email]
enable_signup = true
enable_confirmations = false
max_frequency = "0s"
LOCAL_AUTH

M31_LOCAL_PAYLOAD="$SPRINT12_WORKDIR/equipment.json" M32_LOCAL_PAYLOAD="$SPRINT12_WORKDIR/time.json" \
  flutter test --no-pub --reporter expanded test/application/adaptation/{m31_trial_candidate,m32_trial_candidate}_test.dart
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check > "$SPRINT12_WORKDIR/start-private.log" 2>&1
db="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$db" "$SPRINT12_PROJECT_ID"
mv "$SPRINT12_WORKDIR/$migration" "$SPRINT12_WORKDIR/supabase/migrations/$migration"
supabase db push --local --workdir "$SPRINT12_WORKDIR" --dry-run > "$SPRINT12_WORKDIR/preview.log" 2>&1
grep -F "$migration" "$SPRINT12_WORKDIR/preview.log"
test "$(grep -Eoc '[0-9]{14}_[^[:space:]]+\.sql' "$SPRINT12_WORKDIR/preview.log")" -eq 1
supabase db push --local --workdir "$SPRINT12_WORKDIR" --yes > "$SPRINT12_WORKDIR/apply.log" 2>&1
supabase db push --local --workdir "$SPRINT12_WORKDIR" --dry-run > "$SPRINT12_WORKDIR/after.log" 2>&1
grep -F 'Local database is up to date.' "$SPRINT12_WORKDIR/after.log"
{
  python3 "$TESTS_DIR/fixtures/seed_m32_trial_gate.py" "$SPRINT12_WORKDIR/equipment.json" "$SPRINT12_WORKDIR/time.json"
  cat "$TESTS_DIR/sql/gate_m31_approved_equipment_substitutions.sql" "$TESTS_DIR/sql/gate_m32_strength_time_option.sql"
} | docker exec -i "$db" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1
supabase status -o json --workdir "$SPRINT12_WORKDIR" > "$SPRINT12_WORKDIR/status-private.json" 2>/dev/null
python3 - "$SPRINT12_WORKDIR/status-private.json" "$db" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
status = json.loads(path.read_text())
status["CONTAINER"] = sys.argv[2]
path.write_text(json.dumps(status))
PY
M31_LOCAL_CONFIG="$SPRINT12_WORKDIR/status-private.json" \
  flutter test --no-pub --reporter expanded test/application/adaptation/m31_thursday_trial_local_test.dart

docker exec -i "$db" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -At <<'SQL'
SELECT jsonb_build_object(
  'migration', (SELECT jsonb_build_object(
    'version',version,'name',name,'statement_count',cardinality(statements),
    'statement_array_sha256',encode(extensions.digest(convert_to(to_jsonb(statements)::text,'UTF8'),'sha256'),'hex')
  ) FROM supabase_migrations.schema_migrations WHERE version='20261108130000'),
  'trial', (SELECT jsonb_build_object('version',version_id,'package_hash',package_hash,'local_scope_seal_hash',scope_seal_hash)
    FROM public.programme_strength_time_approvals)
);
SQL
