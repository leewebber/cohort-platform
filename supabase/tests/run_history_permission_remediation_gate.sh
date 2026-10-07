#!/usr/bin/env bash
# Disposable local role/RPC proof. Never links or consumes hosted credentials.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup() {
  local ec=$?
  set +e
  [[ "$STARTED" -eq 0 ]] || supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1
  [[ -z "$SPRINT12_WORKDIR" ]] || rm -rf "$SPRINT12_WORKDIR"
  exit "$ec"
}
trap cleanup EXIT
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
MIGRATION="$REPO_ROOT/supabase/migrations/20261007120000_history_read_permission_remediation.sql"
DART_SUPPRESS_ANALYTICS=true FLUTTER_SUPPRESS_ANALYTICS=true dart --packages="$REPO_ROOT/.dart_tool/package_config.json" \
  "$TESTS_DIR/fixtures/c2_programme_publication_fixture.dart" "$SPRINT12_WORKDIR/payload.sql"
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" \
  --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check >/dev/null
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
psql_file() { docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$1"; }
psql_file "$TESTS_DIR/sql/gate_c2_coherent_history_read.sql"
psql_file "$SPRINT12_WORKDIR/payload.sql"
psql_file "$TESTS_DIR/sql/gate_c2_programme_attribution.sql"
export SPRINT12_DB_CONTAINER SPRINT12_PROJECT_ID
python3 "$TESTS_DIR/concurrency/gate_c2_history_read.py"
python3 "$TESTS_DIR/concurrency/gate_c2_programme_read.py"
psql_file "$TESTS_DIR/sql/history_permission_remediation_fixture.sql"
psql_file "$MIGRATION"
psql_file "$TESTS_DIR/sql/gate_history_permission_remediation.sql"
psql_file "$MIGRATION"
psql_file "$TESTS_DIR/sql/history_permission_remediation_preservation.sql"
# Unknown permissive policies must reject remediation atomically, never coexist.
docker exec "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c 'CREATE POLICY history_permission_unknown ON public.training_sessions FOR SELECT TO authenticated USING (true)' >/dev/null
if psql_file "$MIGRATION" > "$SPRINT12_WORKDIR/guard.log" 2>&1; then
  sprint12_die 'unknown session policy unexpectedly accepted'
fi
rg -q 'unreviewed_training_sessions_policy' "$SPRINT12_WORKDIR/guard.log"
docker exec "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c 'DROP POLICY history_permission_unknown ON public.training_sessions' >/dev/null
psql_file "$TESTS_DIR/sql/gate_history_permission_remediation.sql"
psql_file "$TESTS_DIR/sql/history_permission_remediation_preservation.sql"
echo 'HISTORY_PERMISSION_UNKNOWN_POLICY_FAIL_CLOSED=PASS'
python3 "$TESTS_DIR/history_permission_remediation_http.py" "$SPRINT12_WORKDIR"
DART_SUPPRESS_ANALYTICS=true FLUTTER_SUPPRESS_ANALYTICS=true dart --packages="$REPO_ROOT/.dart_tool/package_config.json" \
  "$TESTS_DIR/fixtures/history_permission_decode.dart" "$SPRINT12_WORKDIR/history-wires.json"
echo 'HISTORY_PERMISSION_TABLE_REMEDIATION_LOCAL_GATE=PASS'
# Canonical completion must independently reject a foreign session ID. This is
# deliberately last: a failure is a release blocker, never an invitation to grant.
psql_file "$TESTS_DIR/sql/helpers.sql"
psql_file "$TESTS_DIR/sql/gate_q_programme_training_session_start.sql"
psql_file "$TESTS_DIR/sql/gate_history_permission_completion_owner.sql"
echo 'HISTORY_PERMISSION_REMEDIATION_LOCAL_GATE=PASS'
