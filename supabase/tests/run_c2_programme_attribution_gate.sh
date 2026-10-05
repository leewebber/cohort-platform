#!/usr/bin/env bash
# Local-only disposable publication/read authority proof. No linked metadata.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup() {
 local ec=$?
 set +e
 [[ "$STARTED" -eq 0 ]] || supabase stop --workdir "$SPRINT12_WORKDIR" >/dev/null 2>&1
 [[ -z "$SPRINT12_WORKDIR" ]] || rm -rf "$SPRINT12_WORKDIR"
 exit "$ec"
}
trap cleanup EXIT
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
# Compiler fixture built before any local DB operation; SDK uses existing deps.
DART_SUPPRESS_ANALYTICS=true FLUTTER_SUPPRESS_ANALYTICS=true dart --packages="$REPO_ROOT/.dart_tool/package_config.json" \
 "$TESTS_DIR/fixtures/c2_programme_publication_fixture.dart" "$SPRINT12_WORKDIR/payload.sql"
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check >/dev/null
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
psql_file() { docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$1"; }
psql_file "$TESTS_DIR/sql/gate_c2_coherent_history_read.sql"
psql_file "$SPRINT12_WORKDIR/payload.sql"
psql_file "$TESTS_DIR/sql/gate_c2_programme_attribution.sql"
export SPRINT12_DB_CONTAINER SPRINT12_PROJECT_ID
python3 "$TESTS_DIR/concurrency/gate_c2_programme_read.py"
echo 'C2_PROGRAMME_ATTRIBUTION_LOCAL_DB_GATE=PASS'
