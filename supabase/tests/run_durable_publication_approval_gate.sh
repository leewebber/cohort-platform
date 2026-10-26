#!/usr/bin/env bash
# LOCAL DISPOSABLE AUTHENTICATION/PRODUCER PROOF ONLY. Never link a hosted project.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup(){ local ec=$?;set +e;[[ "$STARTED" -eq 0 ]] || supabase stop --workdir "$SPRINT12_WORKDIR" --no-backup >/dev/null 2>&1;[[ -z "$SPRINT12_WORKDIR" ]] || rm -rf "$SPRINT12_WORKDIR";exit "$ec";}
trap cleanup EXIT
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
cat "$TESTS_DIR/sql/backfill_hosted_default_grants_fixture.sql" >> "$SPRINT12_WORKDIR/supabase/migrations/20260701000000_local_test_baseline_prereq.sql"
STARTED=1
# CLI status/start can include local fixture secrets. Keep private and remove on exit.
umask 077
supabase start --workdir "$SPRINT12_WORKDIR" --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector --ignore-health-check >"$SPRINT12_WORKDIR/start-private.log" 2>&1
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
for pass in fresh repeat;do
 if [[ "$pass" == repeat ]];then supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >"$SPRINT12_WORKDIR/reset-private.log" 2>&1;fi
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/helpers.sql" >/dev/null
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/hyrox_authoritative_fixture.sql" >/dev/null
 ruby "$TESTS_DIR/prepare_publication_approval_fixture.rb" "$SPRINT12_WORKDIR" "$SPRINT12_DB_CONTAINER" "$SPRINT12_WORKDIR/private-proof.json"
 (cd "$REPO_ROOT/server/trusted_plan_package_import" && dart run tool/durable_publication_local_proof.dart "$SPRINT12_WORKDIR/private-proof.json")
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'REVOKE cohort_publication_approval_writer,cohort_publication_event_delivery,cohort_exercise_version_publisher FROM authenticator;' >/dev/null
 docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 < "$TESTS_DIR/sql/gate_durable_publication_approval.sql"
 echo "DURABLE_PUBLICATION_APPROVAL_${pass}=PASS"
done
