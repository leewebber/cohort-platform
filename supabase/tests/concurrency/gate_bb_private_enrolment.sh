#!/usr/bin/env bash
# Gate BB concurrency — competing private enrols leave one active assignment.
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

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sprint12_gate_bb.XXXXXX")"

psqlc() {
  docker exec -i "$DB_CONTAINER" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

IFS='|' read -r ATHLETE VERSION <<<"$(psqlc -Atc \
  "SELECT athlete_id, programme_version_id
   FROM sprint12_gate_bb_fixture WHERE fixture_key='concurrency'")"

[[ -n "$ATHLETE" && -n "$VERSION" ]] \
  || sprint12_die "Gate BB concurrency fixture missing"

cat >"${WORKDIR}/bb_a.sql" <<SQL
BEGIN;
SELECT set_config('request.jwt.claim.sub', '${ATHLETE}', true);
SELECT set_config('role', 'authenticated', true);
SELECT public.enrol_athlete_in_private_programme_version(
  '${VERSION}'::uuid,
  'Asia/Makassar',
  FALSE
) AS result;
SELECT pg_sleep(0.5);
COMMIT;
SQL

cat >"${WORKDIR}/bb_b.sql" <<SQL
BEGIN;
SELECT set_config('request.jwt.claim.sub', '${ATHLETE}', true);
SELECT set_config('role', 'authenticated', true);
SELECT public.enrol_athlete_in_private_programme_version(
  '${VERSION}'::uuid,
  'Asia/Makassar',
  FALSE
) AS result;
COMMIT;
SQL

docker cp "${WORKDIR}/bb_a.sql" "${DB_CONTAINER}:/tmp/gate_bb_a.sql"
docker cp "${WORKDIR}/bb_b.sql" "${DB_CONTAINER}:/tmp/gate_bb_b.sql"

set +e
docker exec "$DB_CONTAINER" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_bb_a.sql" \
  >"${WORKDIR}/bb_a.out" 2>&1 &
PID_A=$!
docker exec "$DB_CONTAINER" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_bb_b.sql" \
  >"${WORKDIR}/bb_b.out" 2>&1 &
PID_B=$!
wait "$PID_A"
EC_A=$?
wait "$PID_B"
EC_B=$?
set -e

echo "--- Gate BB session A (exit=${EC_A}) ---"
cat "${WORKDIR}/bb_a.out"
echo "--- Gate BB session B (exit=${EC_B}) ---"
cat "${WORKDIR}/bb_b.out"

[[ "$EC_A" -eq 0 && "$EC_B" -eq 0 ]] \
  || sprint12_die "Gate BB concurrent subprocess failed"

STATUS_A="$(rg -o '"status": "[^"]+"' "${WORKDIR}/bb_a.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"
STATUS_B="$(rg -o '"status": "[^"]+"' "${WORKDIR}/bb_b.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"

PAIR="${STATUS_A}|${STATUS_B}"
[[ "$PAIR" == *"enrolled"* && "$PAIR" == *"already_enrolled"* ]] \
  || sprint12_die \
    "Gate BB expected enrolled+already_enrolled, got ${STATUS_A}+${STATUS_B}"

STATE="$(psqlc -Atc "
  SELECT count(*)
  FROM programme_assignments
  WHERE athlete_id='${ATHLETE}'::uuid AND status='active';
")"
[[ "$STATE" == "1" ]] \
  || sprint12_die "Gate BB expected one active assignment, got ${STATE}"

echo "Gate BB private enrolment concurrency PASSED"
