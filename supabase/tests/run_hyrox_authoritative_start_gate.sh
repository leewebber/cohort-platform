#!/usr/bin/env bash
# Complete local prerequisite/new chain; synthetic identity/source authority only.
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
cat "$TESTS_DIR/sql/backfill_hosted_default_grants_fixture.sql" >> "$SPRINT12_WORKDIR/supabase/migrations/20260701000000_local_test_baseline_prereq.sql"
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check >/dev/null
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
export SPRINT12_DB_CONTAINER SPRINT12_PROJECT_ID
psql_file() { docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$1"; }
dart --packages="$REPO_ROOT/.dart_tool/package_config.json" "$REPO_ROOT/tool/hyrox_base/authoritative_definitions_fixture.dart" > "$SPRINT12_WORKDIR/definitions.sql"
dart --packages="$REPO_ROOT/.dart_tool/package_config.json" "$REPO_ROOT/tool/hyrox_base/sql_vectors.dart" > "$SPRINT12_WORKDIR/vectors.jsonl"
cmp "$SPRINT12_WORKDIR/vectors.jsonl" "$TESTS_DIR/fixtures/hyrox_base_calculation_vectors.jsonl"
for pass in fresh repeat; do
 supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
 supabase db lint --local --level error --fail-on error --workdir "$SPRINT12_WORKDIR"
 psql_file "$REPO_ROOT/docs/checkpoints/hyrox_authoritative_start/PREFLIGHT.sql"
 psql_file "$REPO_ROOT/docs/checkpoints/hyrox_authoritative_start/POSTCHECK.sql"
 psql_file "$TESTS_DIR/sql/helpers.sql"
 docker cp "$SPRINT12_WORKDIR/vectors.jsonl" "$SPRINT12_DB_CONTAINER:/tmp/hyrox_base_calculation_vectors.jsonl" >/dev/null
 psql_file "$TESTS_DIR/sql/gate_hyrox_base_evidence.sql"
 psql_file "$TESTS_DIR/sql/hyrox_authoritative_fixture.sql"
 # Dedicated capability stays unassigned. Only the local administrative fixture
 # actor simulates the separately authorised publication producer.
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "$SPRINT12_WORKDIR/definitions.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -At -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/hyrox_authoritative_inputs.sql" > "$SPRINT12_WORKDIR/inputs.json"
 dart --packages="$REPO_ROOT/server/trusted_plan_package_import/.dart_tool/package_config.json" "$REPO_ROOT/server/trusted_plan_package_import/tool/authoritative_fixture.dart" "$SPRINT12_WORKDIR/inputs.json" "$SPRINT12_WORKDIR/payload.sql"
 psql_file "$SPRINT12_WORKDIR/payload.sql"
 psql_file "$TESTS_DIR/sql/gate_v3_admission_consent_start.sql"
 psql_file "$TESTS_DIR/sql/gate_v3_security.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/gate_v3_retention.sql"
 psql_file "$TESTS_DIR/sql/gate_v3_rollback_history.sql"
 psql_file "$TESTS_DIR/sql/hyrox_athlete_app_fixture.sql"
 supabase status -o json --workdir "$SPRINT12_WORKDIR" 2>/dev/null > "$SPRINT12_WORKDIR/app-local.json"
 chmod 600 "$SPRINT12_WORKDIR/app-local.json"
 COHORT_LOCAL_V3_CONFIG="$SPRINT12_WORKDIR/app-local.json" flutter test --no-pub "$REPO_ROOT/test/hyrox_base/athlete_authoritative_local_test.dart"
 rm "$SPRINT12_WORKDIR/app-local.json"
 python3 "$TESTS_DIR/hyrox_authoritative_http.py" "$SPRINT12_WORKDIR"
 psql_file "$TESTS_DIR/sql/gate_q_programme_training_session_start.sql"
 bash "$TESTS_DIR/concurrency/gate_q_programme_training_session_start.sh"
 docker cp "$REPO_ROOT/packages/cohort_plan_package/test/fixtures/minimal_plan_package_v2.canonical.json" "$SPRINT12_DB_CONTAINER:/tmp/plan_package_v2.canonical.json" >/dev/null
 psql_file "$TESTS_DIR/sql/gate_bk_occurrence_running_target_snapshot.sql"
 psql_file "$TESTS_DIR/sql/gate_v3_unresolved_start.sql"
 bash "$TESTS_DIR/concurrency/gate_bk_occurrence_running_target_snapshot.sh"
 echo "AUTHORITATIVE_V3_${pass}=PASS"
done
