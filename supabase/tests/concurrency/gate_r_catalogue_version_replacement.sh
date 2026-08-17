#!/usr/bin/env bash
# Gate R concurrency — competing catalogue replacements leave one winner.
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/target_guard.sh
source "${TESTS_DIR}/lib/target_guard.sh"

DB_CONTAINER="${SPRINT12_DB_CONTAINER:-}"
PROJECT_ID="${SPRINT12_PROJECT_ID:-}"
WORKDIR=""

cleanup() {
  if [[ -n "${WORKDIR}" && -d "${WORKDIR}" ]]; then
    rm -rf "${WORKDIR}"
  fi
}
trap cleanup EXIT

[[ -n "$DB_CONTAINER" ]] || sprint12_die "SPRINT12_DB_CONTAINER unset"
[[ -n "$PROJECT_ID" ]] || sprint12_die "SPRINT12_PROJECT_ID unset"
sprint12_assert_no_hosted_intent "$@"
sprint12_assert_local_container "$DB_CONTAINER" "$PROJECT_ID"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sprint12_gate_r.XXXXXX")"

psqlc() {
  docker exec -i "$DB_CONTAINER" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

IFS='|' read -r RETIRING REPLACEMENT_A REPLACEMENT_B <<<"$(psqlc -Atc \
  "SELECT retiring_version_id, replacement_a_id, replacement_b_id
   FROM sprint12_gate_r_fixture WHERE fixture_key='concurrency'")"

[[ -n "$RETIRING" && -n "$REPLACEMENT_A" && -n "$REPLACEMENT_B" ]] \
  || sprint12_die "Gate R concurrency fixture missing"

cat >"${WORKDIR}/r_a.sql" <<SQL
BEGIN;
SELECT set_config('role', 'service_role', true);
SELECT public.replace_approved_cohort_global_programme_version(
  '${RETIRING}'::uuid,
  '${REPLACEMENT_A}'::uuid,
  'gate-r-concurrency-a'
) AS result;
SELECT pg_sleep(0.5);
COMMIT;
SQL

cat >"${WORKDIR}/r_b.sql" <<SQL
BEGIN;
SELECT set_config('role', 'service_role', true);
SELECT public.replace_approved_cohort_global_programme_version(
  '${RETIRING}'::uuid,
  '${REPLACEMENT_B}'::uuid,
  'gate-r-concurrency-b'
) AS result;
COMMIT;
SQL

docker cp "${WORKDIR}/r_a.sql" "${DB_CONTAINER}:/tmp/gate_r_a.sql"
docker cp "${WORKDIR}/r_b.sql" "${DB_CONTAINER}:/tmp/gate_r_b.sql"

set +e
docker exec "$DB_CONTAINER" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_r_a.sql" \
  >"${WORKDIR}/r_a.out" 2>&1 &
PID_A=$!
docker exec "$DB_CONTAINER" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_r_b.sql" \
  >"${WORKDIR}/r_b.out" 2>&1 &
PID_B=$!
wait "$PID_A"
EC_A=$?
wait "$PID_B"
EC_B=$?
set -e

echo "--- Gate R session A (exit=${EC_A}) ---"
cat "${WORKDIR}/r_a.out"
echo "--- Gate R session B (exit=${EC_B}) ---"
cat "${WORKDIR}/r_b.out"

[[ "$EC_A" -eq 0 && "$EC_B" -eq 0 ]] \
  || sprint12_die "Gate R concurrent subprocess failed"

STATUS_A="$(rg -o '"status": "[^"]+"' "${WORKDIR}/r_a.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"
STATUS_B="$(rg -o '"status": "[^"]+"' "${WORKDIR}/r_b.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"

PAIR="${STATUS_A}|${STATUS_B}"
[[ "$PAIR" == *"replaced"* && "$PAIR" == *"lifecycle_invariant_failure"* ]] \
  || sprint12_die \
    "Gate R expected replaced+invariant failure, got ${STATUS_A}+${STATUS_B}"

STATE="$(psqlc -Atc "
  WITH target AS (
    SELECT lineage_id FROM programme_versions WHERE id='${RETIRING}'::uuid
  )
  SELECT
    (SELECT count(*) FROM programme_versions, target
      WHERE programme_versions.lineage_id=target.lineage_id
        AND lifecycle_status='published'
        AND library_scope='cohort_global'
        AND owner_type='global'
        AND approved_for_global=TRUE
        AND archived_at IS NULL),
    (SELECT lifecycle_status || ':' || approved_for_global::text
      FROM programme_versions WHERE id='${RETIRING}'::uuid),
    (SELECT count(*) FROM programme_versions
      WHERE id IN ('${REPLACEMENT_A}'::uuid, '${REPLACEMENT_B}'::uuid)
        AND approved_for_global=TRUE);
")"
[[ "$STATE" == "1|archived:false|1" ]] \
  || sprint12_die "Gate R expected one winner and archived retiree, got ${STATE}"

# The final partial unique index independently rejects a second eligible row.
LOSER="$(psqlc -Atc "
  SELECT id FROM programme_versions
  WHERE id IN ('${REPLACEMENT_A}'::uuid, '${REPLACEMENT_B}'::uuid)
    AND approved_for_global=FALSE
  LIMIT 1;
")"
[[ -n "$LOSER" ]] || sprint12_die "Gate R losing replacement missing"

set +e
psqlc -c "
  UPDATE programme_versions
  SET approved_for_global=TRUE
  WHERE id='${LOSER}'::uuid;
" >"${WORKDIR}/r_unique.out" 2>&1
UNIQUE_EC=$?
set -e
[[ "$UNIQUE_EC" -ne 0 ]] \
  || sprint12_die "Gate R unique index allowed a second eligible version"
rg -q "idx_programme_versions_one_catalogue_eligible_per_lineage" \
  "${WORKDIR}/r_unique.out" \
  || sprint12_die "Gate R second approval did not fail at lineage uniqueness"

echo "Gate R concurrency PASSED (one catalogue winner; identity redacted)"
