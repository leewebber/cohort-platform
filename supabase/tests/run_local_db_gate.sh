#!/usr/bin/env bash
# Sprint 1.2 disposable local DB gate orchestrator (uncommitted test infrastructure).
# Does NOT authorise staging. Never contacts hosted projects.
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"
# shellcheck source=lib/target_guard.sh
source "${TESTS_DIR}/lib/target_guard.sh"
# shellcheck source=lib/prepare_disposable_workdir.sh
source "${TESTS_DIR}/lib/prepare_disposable_workdir.sh"

MODE="${1:-full}"
SPRINT12_WORKDIR=""
SPRINT12_PROJECT_ID=""
SPRINT12_DB_CONTAINER=""
STARTED=0

cleanup() {
  local ec=$?
  set +e
  if [[ "$STARTED" -eq 1 && -n "${SPRINT12_WORKDIR}" ]]; then
    echo "Stopping disposable stack for workdir (no --all)..."
    supabase stop --workdir "${SPRINT12_WORKDIR}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${SPRINT12_WORKDIR}" && -d "${SPRINT12_WORKDIR}" ]]; then
    # Ensure baseline never remains in repo migrations (it never was copied there).
    rm -rf "${SPRINT12_WORKDIR}"
    echo "Removed disposable workdir."
  fi
  exit "$ec"
}
trap cleanup EXIT

sprint12_assert_no_hosted_intent "$@"

case "$MODE" in
  guard-invalid)
    # Prove invalid/non-local target exits before DB work.
    if SPRINT12_DB_CONTAINER="supabase_db_not_a_real_project" \
       SPRINT12_PROJECT_ID="cohort_s12gate_expected" \
       bash "${TESTS_DIR}/concurrency/gate_g.sh"; then
      sprint12_die "guard-invalid expected non-zero exit"
    fi
    echo "guard-invalid PASSED (non-local/unexpected container rejected)"
    exit 0
    ;;
  url-invalid)
    set +e
    ( sprint12_assert_loopback_url "postgresql://postgres:postgres@db.example.supabase.co:5432/postgres" )
    local_ec=$?
    set -e
    [[ "$local_ec" -ne 0 ]] || sprint12_die "url-invalid unexpectedly accepted hosted URL"
    echo "url-invalid PASSED"
    exit 0
    ;;
  container-missing)
    # Exact project container missing → fail before any SQL / docker exec.
    # Subshell required: sprint12_die uses exit (must not tear down the orchestrator).
    set +e
    (
      sprint12_resolve_exact_db_container "s12g_missing_exact_does_not_exist"
    ) >/tmp/sprint12_container_missing.out 2>&1
    local_ec=$?
    set -e
    [[ "$local_ec" -ne 0 ]] || sprint12_die "container-missing unexpectedly succeeded"
    rg -q "missing or ambiguous" /tmp/sprint12_container_missing.out \
      || sprint12_die "container-missing did not report exact-resolve failure"
    # Prove no SQL was attempted (resolve-only path; no docker exec/psql in output).
    rg -q "docker exec|psql|import_authored" /tmp/sprint12_container_missing.out \
      && sprint12_die "container-missing unexpectedly reached SQL"
    echo "container-missing PASSED (exact container absent rejected before SQL)"
    exit 0
    ;;
  container-cross)
    # Two prepared disposable project identities cannot resolve each other's container.
    # Does not start stacks; proves resolve is exact-name-only (no s12g* fuzzy match).
    sprint12_prepare_disposable_workdir
    PID_A="$SPRINT12_PROJECT_ID"
    WD_A="$SPRINT12_WORKDIR"
    SPRINT12_WORKDIR=""
    sprint12_prepare_disposable_workdir
    PID_B="$SPRINT12_PROJECT_ID"
    WD_B="$SPRINT12_WORKDIR"
    [[ "$PID_A" != "$PID_B" ]] || sprint12_die "container-cross: project ids not unique"
    EXPECT_A="supabase_db_${PID_A}"
    EXPECT_B="supabase_db_${PID_B}"
    # Neither container is running yet → exact resolve must fail for both (not pick the other).
    set +e
    OUT_A="$(sprint12_resolve_exact_db_container "$PID_A" 2>&1)"
    EC_A=$?
    OUT_B="$(sprint12_resolve_exact_db_container "$PID_B" 2>&1)"
    EC_B=$?
    set -e
    [[ "$EC_A" -ne 0 && "$EC_B" -ne 0 ]] || sprint12_die "container-cross: resolve succeeded without running containers"
    [[ "$OUT_A" != *"$EXPECT_B"* ]] || sprint12_die "container-cross: resolve A selected B"
    [[ "$OUT_B" != *"$EXPECT_A"* ]] || sprint12_die "container-cross: resolve B selected A"
    rm -rf "$WD_A" "$WD_B"
    SPRINT12_WORKDIR=""
    echo "container-cross PASSED (exact resolve; no cross-project selection; pid_a=${PID_A} pid_b=${PID_B})"
    exit 0
    ;;
  token-invalid)
    set +e
    (
      # Token value must never be printed by the guard.
      export SUPABASE_ACCESS_TOKEN="sprint12-test-token-must-not-appear-in-logs"
      sprint12_assert_no_hosted_intent
    )
    local_ec=$?
    set -e
    [[ "$local_ec" -ne 0 ]] || sprint12_die "token-invalid unexpectedly accepted SUPABASE_ACCESS_TOKEN"
    echo "token-invalid PASSED (access token rejected; value not logged by harness)"
    exit 0
    ;;
esac

echo "=== Prepare isolated disposable Supabase project ==="
sprint12_prepare_disposable_workdir
# prepare exports SPRINT12_* into current shell via assignment in function — ensure globals set
: "${SPRINT12_WORKDIR:?}"
: "${SPRINT12_PROJECT_ID:?}"
: "${SPRINT12_DB_CONTAINER:?}"

# Prove production migrations remain clean.
if compgen -G "${TESTS_DIR}/../migrations/20260701000000_*" >/dev/null; then
  sprint12_die "Production supabase/migrations still contains test bootstrap"
fi

echo "=== Start disposable local stack ==="
sprint12_assert_command_is_local "supabase start --workdir ${SPRINT12_WORKDIR}"
supabase start \
  --workdir "${SPRINT12_WORKDIR}" \
  --exclude edge-runtime,imgproxy,inbucket,realtime,storage,studio,vector \
  --ignore-health-check
STARTED=1

# Reconcile project_id if CLI auto-fixed config project_id (still exact-only thereafter).
ACTUAL_PROJECT_ID="$(rg -n '^project_id\s*=' "${SPRINT12_WORKDIR}/supabase/config.toml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [[ -n "$ACTUAL_PROJECT_ID" && "$ACTUAL_PROJECT_ID" != "$SPRINT12_PROJECT_ID" ]]; then
  echo "NOTE: CLI adjusted project_id ${SPRINT12_PROJECT_ID} -> ${ACTUAL_PROJECT_ID}"
  SPRINT12_PROJECT_ID="$ACTUAL_PROJECT_ID"
fi
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
sprint12_assert_local_container "$SPRINT12_DB_CONTAINER" "$SPRINT12_PROJECT_ID"

echo "=== Fresh reset (no seed; local only) ==="
sprint12_assert_command_is_local "supabase db reset --local --no-seed --workdir ..."
supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"

echo "=== Lint (before helpers) ==="
supabase db lint --local --level error --fail-on error --workdir "${SPRINT12_WORKDIR}"

echo "=== Load helpers + Gates C–I ==="
docker cp "${TESTS_DIR}/sql/helpers.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_helpers.sql"
docker cp "${TESTS_DIR}/sql/gates_c_to_i.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gates.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_helpers.sql \
  -f /tmp/sprint12_gates.sql

echo "=== Repeat run (db reset + fresh helpers/gates; no stale dependence) ==="
sprint12_assert_command_is_local "supabase db reset --local --no-seed --workdir ..."
supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"
docker cp "${TESTS_DIR}/sql/helpers.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_helpers.sql"
docker cp "${TESTS_DIR}/sql/gates_c_to_i.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gates.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_helpers.sql \
  -f /tmp/sprint12_gates.sql

echo "=== Negative control: deliberate failing assertion must exit non-zero ==="
set +e
docker exec -i "${SPRINT12_DB_CONTAINER}" psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'
TRUNCATE sprint12_gate_results;
SELECT sprint12_record('NEG','deliberate','expected','actual', NULL, FALSE, 'negative control');
SELECT sprint12_fail_if_any_failed();
SQL
NEG_EC=$?
set -e
[[ "$NEG_EC" -ne 0 ]] || sprint12_die "SQL negative control unexpectedly exited 0"
echo "SQL negative control PASSED (exit=${NEG_EC})"

echo "=== Gate G concurrency ==="
export SPRINT12_DB_CONTAINER SPRINT12_PROJECT_ID
bash "${TESTS_DIR}/concurrency/gate_g.sh"

echo "=== Gate G isolated negative control ==="
set +e
SPRINT12_G_NEGATIVE=1 bash "${TESTS_DIR}/concurrency/gate_g.sh"
GNEG_EC=$?
set -e
[[ "$GNEG_EC" -ne 0 ]] || sprint12_die "Gate G negative control unexpectedly exited 0"
echo "Gate G isolated negative control PASSED (exit=${GNEG_EC})"

echo "=== PostgREST privilege denial without temporary grants ==="
# Use status from disposable workdir only.
STATUS_JSON="$(supabase status -o json --workdir "${SPRINT12_WORKDIR}")"
API="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["API_URL"])' <<<"$STATUS_JSON")"
ANON="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["ANON_KEY"])' <<<"$STATUS_JSON")"
# Redact: do not print keys
echo "TARGET: api=${API} (local disposable; keys redacted)"
[[ "$API" == http://127.0.0.1:* || "$API" == http://localhost:* ]] || sprint12_die "API not loopback"
CODE="$(curl -sS -o /tmp/sprint12_http.json -w '%{http_code}' \
  "${API}/rest/v1/programme_versions?select=id&limit=1" \
  -H "apikey: ${ANON}" -H "Authorization: Bearer ${ANON}")"
echo "HTTP catalogue without migration SELECT grant: http=${CODE}"
[[ "$CODE" == "401" || "$CODE" == "403" ]] || sprint12_die "Expected privilege failure HTTP, got ${CODE}"

echo "=== Final production migrations integrity ==="
if compgen -G "${TESTS_DIR}/../migrations/20260701000000_*" >/dev/null; then
  sprint12_die "Bootstrap leaked into production migrations"
fi
echo "Production migrations clean of test bootstrap."

echo "ALL LOCAL DB GATE CHECKS PASSED"
echo "This harness does NOT authorise staging or production deployment."
