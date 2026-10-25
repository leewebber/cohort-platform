#!/usr/bin/env bash
# LOCAL FIXTURES ONLY. Never links to hosted or claims genuine producer events.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup() {
 local ec=$?
 set +e
 [[ "$STARTED" -eq 0 ]] || supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1
 [[ -z "$SPRINT12_WORKDIR" ]] || rm -f "$SPRINT12_WORKDIR/app-local.json"
 exit "$ec"
}
trap cleanup EXIT
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
cat "$TESTS_DIR/sql/backfill_hosted_default_grants_fixture.sql" >> "$SPRINT12_WORKDIR/supabase/migrations/20260701000000_local_test_baseline_prereq.sql"
COHORT_PUBLICATION_REHEARSAL_DIR="$SPRINT12_WORKDIR/rehearsal" flutter test --no-pub "$REPO_ROOT/tool/hyrox_base/prepare_publication_sources.dart"
python3 "$REPO_ROOT/tool/hyrox_base/publication_fixture_sql.py" "$SPRINT12_WORKDIR/rehearsal"
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check >/dev/null
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
psql_file() { docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$1"; }
for pass in fresh repeat; do
 supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
 psql_file "$TESTS_DIR/sql/helpers.sql"
 psql_file "$SPRINT12_WORKDIR/rehearsal/setup.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -At -v ON_ERROR_STOP=1 > "$SPRINT12_WORKDIR/rehearsal/dependencies.json" <<'SQL'
SELECT jsonb_agg(to_jsonb(d) ORDER BY kind) FROM public.hyrox_prescription_dependencies d;
SQL
 dart --packages="$REPO_ROOT/server/trusted_plan_package_import/.dart_tool/package_config.json" "$REPO_ROOT/server/trusted_plan_package_import/tool/hyrox_publication_fixture.dart" "$SPRINT12_WORKDIR/rehearsal"
 psql_file "$SPRINT12_WORKDIR/rehearsal/payload.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'
DO $$ DECLARE p jsonb;r jsonb;BEGIN SELECT document INTO p FROM public.local_hyrox_ops_data WHERE key='payload';PERFORM set_config('role','service_role',true);r:=public.publish_private_exact_programme_version_v3(p);PERFORM set_config('role','none',true);PERFORM public.local_hyrox_assert(r->>'status'='validation_failure','unresolved sources never admitted');PERFORM public.local_hyrox_assert(NOT EXISTS(SELECT 1 FROM public.cohort_v3_publication_claims),'failed admission no claim');END $$;
SQL
 # Dedicated role is assumed only inside this disposable administrative fixture.
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "$SPRINT12_WORKDIR/rehearsal/deliver.sql"
 psql_file "$SPRINT12_WORKDIR/rehearsal/register.sql"
 psql_file "$TESTS_DIR/sql/gate_hyrox_publication_operations.sql"
 supabase status -o json --workdir "$SPRINT12_WORKDIR" 2>/dev/null > "$SPRINT12_WORKDIR/app-local.json"
 chmod 600 "$SPRINT12_WORKDIR/app-local.json"
 COHORT_LOCAL_V3_CONFIG="$SPRINT12_WORKDIR/app-local.json" flutter test --no-pub "$REPO_ROOT/test/hyrox_base/publication_operations_local_test.dart"
 rm "$SPRINT12_WORKDIR/app-local.json"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/gate_hyrox_operations_history.sql"
 echo "LOCAL_HYROX_PUBLICATION_OPERATIONS_${pass}=PASS"
done
