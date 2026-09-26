#!/usr/bin/env bash
# Dedicated local disposable gate for assigned programme-graph reads.
# Does not contact hosted projects.
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"
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
supabase start \
  --workdir "${SPRINT12_WORKDIR}" \
  --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector \
  --ignore-health-check >/dev/null
STARTED=1
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"

run_bd() {
  supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"
  docker cp "${TESTS_DIR}/sql/helpers.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_helpers.sql"
  docker cp "${TESTS_DIR}/sql/gate_bd_assigned_programme_graph_read.sql" \
    "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_bd.sql"
  docker exec -i "${SPRINT12_DB_CONTAINER}" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -f /tmp/sprint12_helpers.sql \
    -f /tmp/sprint12_gate_bd.sql
}

echo "=== Assigned graph read gate pass 1 ==="
run_bd
echo "=== Assigned graph read gate pass 2 (reset/replay) ==="
run_bd
echo "ASSIGNED_PROGRAMME_GRAPH_READ_GATE=PASS"
