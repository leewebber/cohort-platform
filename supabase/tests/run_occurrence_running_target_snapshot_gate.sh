#!/usr/bin/env bash
# Disposable local B2 occurrence target snapshot gate. No hosted access.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}"
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
  if [[ "${STARTED}" -eq 1 && -n "${SPRINT12_WORKDIR}" ]]; then
    supabase stop --workdir "${SPRINT12_WORKDIR}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${SPRINT12_WORKDIR}" && -d "${SPRINT12_WORKDIR}" ]]; then
    rm -rf "${SPRINT12_WORKDIR}"
  fi
  exit "${ec}"
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
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "${SPRINT12_PROJECT_ID}")"
sprint12_assert_local_container "${SPRINT12_DB_CONTAINER}" "${SPRINT12_PROJECT_ID}"
export SPRINT12_PROJECT_ID SPRINT12_DB_CONTAINER

sprint12_assert_command_is_local "supabase db reset --local --no-seed --workdir ${SPRINT12_WORKDIR}"
supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"
docker cp "${TESTS_DIR}/sql/helpers.sql" \
  "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_helpers.sql"
docker cp "${TESTS_DIR}/sql/gate_bk_occurrence_running_target_snapshot.sql" \
  "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_bk.sql"
docker cp \
  "${REPO_ROOT}/packages/cohort_plan_package/test/fixtures/minimal_plan_package_v2.canonical.json" \
  "${SPRINT12_DB_CONTAINER}:/tmp/plan_package_v2.canonical.json"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_helpers.sql \
  -f /tmp/sprint12_gate_bk.sql

bash "${TESTS_DIR}/concurrency/gate_bk_occurrence_running_target_snapshot.sh"
echo "OCCURRENCE_RUNNING_TARGET_SNAPSHOT_GATE=PASS"
