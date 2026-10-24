#!/usr/bin/env bash
# LOCAL DISPOSABLE FIXTURES ONLY. No real producer, artifact or hosted capability.
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
(cd "$REPO_ROOT/server/trusted_plan_package_import" && dart compile exe bin/server.dart -o "$SPRINT12_WORKDIR/trusted-plan-import")
for pass in fresh repeat; do
 if [[ "$pass" == repeat ]]; then supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null; fi
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$REPO_ROOT/docs/checkpoints/hyrox_authoritative_start/POSTCHECK.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/helpers.sql"
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/hyrox_authoritative_fixture.sql"
 python3 "$TESTS_DIR/v3_publication_http.py" "$SPRINT12_WORKDIR" "$REPO_ROOT" "$pass"
 echo "V3_PUBLICATION_HTTP_${pass}=PASS"
done
