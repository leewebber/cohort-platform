#!/usr/bin/env bash
# C2: isolated local database/read coherence proof; never hosted or linked.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"
source "${TESTS_DIR}/lib/prepare_disposable_workdir.sh"
SPRINT12_WORKDIR=""
STARTED=0
cleanup() {
  local ec=$?
  set +e
  if [[ "$STARTED" -eq 1 ]]; then
    supabase stop --workdir "$SPRINT12_WORKDIR" >/dev/null 2>&1
  fi
  [[ -z "$SPRINT12_WORKDIR" ]] || rm -rf "$SPRINT12_WORKDIR"
  exit "$ec"
}
trap cleanup EXIT
sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
C2_MIGRATION=20261005130000_performance_tracking_coherent_history_read.sql
# Compare original permissions and policies before/after this one migration.
# Only the disposable copy is moved; repository migrations are untouched.
mv "$SPRINT12_WORKDIR/supabase/migrations/$C2_MIGRATION" "$SPRINT12_WORKDIR/c2-read.sql"
STARTED=1
supabase start --workdir "$SPRINT12_WORKDIR" \
  --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector \
  --ignore-health-check >/dev/null
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"
supabase db reset --local --no-seed --yes --workdir "$SPRINT12_WORKDIR" >/dev/null
fingerprint() {
  docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "
    SELECT md5(concat(
      (SELECT string_agg(concat(oid,relacl::text,relrowsecurity,relforcerowsecurity),',' ORDER BY oid)
       FROM pg_class WHERE relnamespace='public'::regnamespace),
      (SELECT string_agg(concat(oid,polrelid,polroles,polcmd,polpermissive,polqual::text,polwithcheck::text),',' ORDER BY oid) FROM pg_policy),
      (SELECT string_agg(pg_get_functiondef(oid),',' ORDER BY oid) FROM pg_proc
       WHERE pronamespace='public'::regnamespace AND prokind='f'
         AND proname <> 'read_performance_tracking_history_v1')));"
}
C2_BEFORE="$(fingerprint)"
docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < "$SPRINT12_WORKDIR/c2-read.sql"
[[ "$C2_BEFORE" == "$(fingerprint)" ]] || sprint12_die 'C2 changed existing ACL/RLS or helper/mutation functions'
echo 'C2_MIGRATION_EXISTING_AUTHORITY_UNCHANGED=PASS'
docker exec -i "$SPRINT12_DB_CONTAINER" psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < "${TESTS_DIR}/sql/gate_c2_coherent_history_read.sql"
export SPRINT12_DB_CONTAINER SPRINT12_PROJECT_ID
python3 "${TESTS_DIR}/concurrency/gate_c2_history_read.py"
echo 'C2_COHERENT_HISTORY_LOCAL_DB_GATE=PASS'
