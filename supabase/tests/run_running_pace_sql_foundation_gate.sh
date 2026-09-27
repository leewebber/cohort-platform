#!/usr/bin/env bash
# Disposable local gate for B2 SQL selection/calculation. No hosted access.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"
REPO_ROOT="$(cd "${TESTS_DIR}/../.." && pwd)"
# shellcheck source=lib/target_guard.sh
source "${TESTS_DIR}/lib/target_guard.sh"
# shellcheck source=lib/prepare_disposable_workdir.sh
source "${TESTS_DIR}/lib/prepare_disposable_workdir.sh"

SPRINT12_WORKDIR=""
SPRINT12_PROJECT_ID=""
SPRINT12_DB_CONTAINER=""
STARTED=0

cleanup() {
  local ec=$?
  set +e
  if [[ "$STARTED" -eq 1 && -n "${SPRINT12_WORKDIR}" ]]; then
    supabase stop --workdir "${SPRINT12_WORKDIR}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${SPRINT12_WORKDIR}" && -d "${SPRINT12_WORKDIR}" ]]; then
    rm -rf "${SPRINT12_WORKDIR}"
  fi
  exit "$ec"
}
trap cleanup EXIT

sprint12_assert_no_hosted_intent "$@"
sprint12_prepare_disposable_workdir
: "${SPRINT12_WORKDIR:?}"
: "${SPRINT12_PROJECT_ID:?}"

sprint12_assert_command_is_local "supabase start --workdir ${SPRINT12_WORKDIR}"
supabase start --workdir "${SPRINT12_WORKDIR}" \
  --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector \
  --ignore-health-check >/dev/null
STARTED=1
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"

sprint12_assert_command_is_local "supabase db reset --local --no-seed --workdir ${SPRINT12_WORKDIR}"
supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"
docker cp "${TESTS_DIR}/sql/helpers.sql" \
  "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_helpers.sql"
docker cp "${TESTS_DIR}/sql/gate_bj_running_pace_sql_foundation.sql" \
  "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_bj.sql"
docker cp \
  "${REPO_ROOT}/test/running_workout/fixtures/running_pace_b2_golden_vectors.json" \
  "${SPRINT12_DB_CONTAINER}:/tmp/running_pace_b2_golden_vectors.json"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_helpers.sql \
  -f /tmp/sprint12_gate_bj.sql

echo "RUNNING_PACE_SQL_FOUNDATION_GATE=PASS"
