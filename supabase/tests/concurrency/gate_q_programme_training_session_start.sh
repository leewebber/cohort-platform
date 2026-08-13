#!/usr/bin/env bash
# Gate Q concurrency — two authenticated transactions start one occurrence.
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

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sprint12_gate_q.XXXXXX")"

psqlc() {
  docker exec -i "$DB_CONTAINER" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

ATHLETE_ID="$(psqlc -Atc \
  "SELECT athlete_id FROM sprint12_gate_q_fixture WHERE fixture_key='concurrency'")"
PAYLOAD="$(psqlc -Atc \
  "SELECT payload::text FROM sprint12_gate_q_fixture WHERE fixture_key='concurrency'")"

[[ -n "$ATHLETE_ID" && -n "$PAYLOAD" ]] \
  || sprint12_die "Gate Q concurrency fixture missing"

cat > "${WORKDIR}/q_a.sql" <<SQL
BEGIN;
SELECT set_config('request.jwt.claim.sub', '${ATHLETE_ID}', true);
SELECT set_config('role', 'authenticated', true);
SELECT public.create_or_resume_programme_training_session(
  '${PAYLOAD}'::jsonb
) AS result;
SELECT pg_sleep(0.5);
COMMIT;
SQL

cat > "${WORKDIR}/q_b.sql" <<SQL
BEGIN;
SELECT set_config('request.jwt.claim.sub', '${ATHLETE_ID}', true);
SELECT set_config('role', 'authenticated', true);
SELECT public.create_or_resume_programme_training_session(
  '${PAYLOAD}'::jsonb
) AS result;
COMMIT;
SQL

docker cp "${WORKDIR}/q_a.sql" "${DB_CONTAINER}:/tmp/gate_q_a.sql"
docker cp "${WORKDIR}/q_b.sql" "${DB_CONTAINER}:/tmp/gate_q_b.sql"

set +e
docker exec "$DB_CONTAINER" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_q_a.sql" \
  >"${WORKDIR}/q_a.out" 2>&1 &
PID_A=$!
docker exec "$DB_CONTAINER" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_q_b.sql" \
  >"${WORKDIR}/q_b.out" 2>&1 &
PID_B=$!
wait "$PID_A"
EC_A=$?
wait "$PID_B"
EC_B=$?
set -e

echo "--- Gate Q session A (exit=${EC_A}) ---"
cat "${WORKDIR}/q_a.out"
echo "--- Gate Q session B (exit=${EC_B}) ---"
cat "${WORKDIR}/q_b.out"

[[ "$EC_A" -eq 0 && "$EC_B" -eq 0 ]] \
  || sprint12_die "Gate Q concurrent subprocess failed"

STATUS_A="$(rg -o '"status": "[^"]+"' "${WORKDIR}/q_a.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"
STATUS_B="$(rg -o '"status": "[^"]+"' "${WORKDIR}/q_b.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"
ID_A="$(rg -o '"id": [0-9]+' "${WORKDIR}/q_a.out" \
  | head -1 | sed 's/.*: //')"
ID_B="$(rg -o '"id": [0-9]+' "${WORKDIR}/q_b.out" \
  | head -1 | sed 's/.*: //')"

PAIR="${STATUS_A}|${STATUS_B}"
[[ "$PAIR" == *"created"* && "$PAIR" == *"resumed"* ]] \
  || sprint12_die \
    "Gate Q expected created+resumed, got ${STATUS_A}+${STATUS_B}"
[[ -n "$ID_A" && "$ID_A" == "$ID_B" ]] \
  || sprint12_die "Gate Q session ids differ (${ID_A}, ${ID_B})"

ASSIGNMENT_ID="$(psqlc -Atc \
  "SELECT payload->>'assignment_id' FROM sprint12_gate_q_fixture WHERE fixture_key='concurrency'")"
SLOT_ID="$(psqlc -Atc \
  "SELECT payload->>'session_slot_id' FROM sprint12_gate_q_fixture WHERE fixture_key='concurrency'")"
COUNTS="$(psqlc -Atc "
  SELECT
    (SELECT count(*) FROM programme_slot_outcomes
      WHERE assignment_id='${ASSIGNMENT_ID}'::uuid
        AND session_slot_id='${SLOT_ID}'::uuid),
    (SELECT count(*) FROM training_sessions WHERE id=${ID_A});
")"
[[ "$COUNTS" == "1|1" ]] \
  || sprint12_die "Gate Q expected one link and one session, got ${COUNTS}"

echo "Gate Q concurrency PASSED (stable training_session_id=${ID_A})"
