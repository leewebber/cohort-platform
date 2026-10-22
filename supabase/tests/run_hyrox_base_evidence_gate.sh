#!/usr/bin/env bash
# Local production-storage prerequisites only; no hosted contact or v3 enablement.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup() {
  local ec=$?
  set +e
  if [[ "$STARTED" -eq 1 ]]; then
    supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1
  fi
  [[ -z "$SPRINT12_WORKDIR" ]] || rm -rf "$SPRINT12_WORKDIR"
  exit "$ec"
}
trap cleanup EXIT
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
# Reproduce the already documented hosted role defaults in this local project,
# proving explicit revocation rather than relying on a restrictive local baseline.
cat "$TESTS_DIR/sql/backfill_hosted_default_grants_fixture.sql" >> \
  "$SPRINT12_WORKDIR/supabase/migrations/20260701000000_local_test_baseline_prereq.sql"
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" \
  --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check >/dev/null
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
export SPRINT12_DB_CONTAINER SPRINT12_PROJECT_ID
psql_file() { docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$1"; }
# Compare the committed vectors against fresh outputs from the actual Dart rules.
dart run "$REPO_ROOT/tool/hyrox_base/sql_vectors.dart" > "$SPRINT12_WORKDIR/vectors.jsonl"
cmp "$SPRINT12_WORKDIR/vectors.jsonl" "$TESTS_DIR/fixtures/hyrox_base_calculation_vectors.jsonl"
for pass in fresh repeat; do
  supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
  docker cp "$SPRINT12_WORKDIR/vectors.jsonl" "$SPRINT12_DB_CONTAINER:/tmp/hyrox_base_calculation_vectors.jsonl" >/dev/null
  psql_file "$REPO_ROOT/docs/checkpoints/hyrox_v3_canonical_storage/PREFLIGHT.sql"
  psql_file "$REPO_ROOT/docs/checkpoints/hyrox_v3_canonical_storage/POSTCHECK.sql"
  psql_file "$TESTS_DIR/sql/gate_hyrox_base_evidence.sql"
  python3 "$TESTS_DIR/hyrox_base_evidence_http.py" "$SPRINT12_WORKDIR"
  psql_file "$TESTS_DIR/sql/helpers.sql"
  docker cp "$REPO_ROOT/packages/cohort_plan_package/test/fixtures/minimal_plan_package_v2.canonical.json" \
    "$SPRINT12_DB_CONTAINER:/tmp/plan_package_v2.canonical.json" >/dev/null
  psql_file "$TESTS_DIR/sql/gate_bk_occurrence_running_target_snapshot.sql"
  psql_file "$TESTS_DIR/sql/gate_v3_unresolved_start.sql"
  bash "$TESTS_DIR/concurrency/gate_bk_occurrence_running_target_snapshot.sh"
  echo "HYROX_BASE_PREREQUISITES_${pass}=PASS"
done
