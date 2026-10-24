#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup() {
 local ec=$?
 set +e
 [[ "$STARTED" -eq 0 ]] || supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1
 # Keep task evidence/config private in the task-owned temporary directory.
 exit "$ec"
}
trap cleanup EXIT
sprint12_assert_no_hosted_intent
sprint12_prepare_disposable_workdir
cat "$TESTS_DIR/sql/backfill_hosted_default_grants_fixture.sql" >> "$SPRINT12_WORKDIR/supabase/migrations/20260701000000_local_test_baseline_prereq.sql"
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check >/dev/null
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
psql_file() { docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$1"; }
dart --packages="$REPO_ROOT/.dart_tool/package_config.json" "$REPO_ROOT/tool/hyrox_base/authoritative_definitions_fixture.dart" > "$SPRINT12_WORKDIR/definitions.sql"
for pass in fresh repeat; do
 supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
 psql_file "$TESTS_DIR/sql/helpers.sql"
 psql_file "$TESTS_DIR/sql/hyrox_authoritative_fixture.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "$SPRINT12_WORKDIR/definitions.sql"
 # First prove existing unchanged v3 admission/consent/start/security paths.
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -At -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/hyrox_authoritative_inputs.sql" > "$SPRINT12_WORKDIR/inputs.json"
 dart --packages="$REPO_ROOT/server/trusted_plan_package_import/.dart_tool/package_config.json" "$REPO_ROOT/server/trusted_plan_package_import/tool/authoritative_fixture.dart" "$SPRINT12_WORKDIR/inputs.json" "$SPRINT12_WORKDIR/payload.sql"
 psql_file "$SPRINT12_WORKDIR/payload.sql"
 psql_file "$TESTS_DIR/sql/gate_v3_admission_consent_start.sql"
 psql_file "$TESTS_DIR/sql/gate_v3_security.sql"
 psql_file "$TESTS_DIR/sql/gate_v3_rollback_history.sql"
 # Reset the same disposable project, then test new source semantics independently.
 supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
 psql_file "$TESTS_DIR/sql/helpers.sql"
 psql_file "$TESTS_DIR/sql/hyrox_authoritative_fixture.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "$SPRINT12_WORKDIR/definitions.sql"
 psql_file "$TESTS_DIR/sql/source_duration_fixture.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -At -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/hyrox_authoritative_inputs.sql" > "$SPRINT12_WORKDIR/inputs-duration.json"
 dart --packages="$REPO_ROOT/server/trusted_plan_package_import/.dart_tool/package_config.json" "$REPO_ROOT/server/trusted_plan_package_import/tool/source_duration_fixture.dart" "$SPRINT12_WORKDIR/inputs-duration.json" "$SPRINT12_WORKDIR/payload-duration.sql"
 psql_file "$SPRINT12_WORKDIR/payload-duration.sql"
 psql_file "$TESTS_DIR/sql/gate_source_duration_choice.sql"
 echo "SOURCE_DURATION_${pass}=PASS"
done
