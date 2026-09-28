#!/usr/bin/env bash
# Gate BK concurrency — two starts freeze one occurrence snapshot.
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

[[ -n "${DB_CONTAINER}" ]] || sprint12_die "SPRINT12_DB_CONTAINER unset"
[[ -n "${PROJECT_ID}" ]] || sprint12_die "SPRINT12_PROJECT_ID unset"
sprint12_assert_no_hosted_intent "$@"
sprint12_assert_local_container "${DB_CONTAINER}" "${PROJECT_ID}"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sprint12_gate_bk.XXXXXX")"

psqlc() {
  docker exec -i "${DB_CONTAINER}" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

ATHLETE_ID="$(psqlc -Atc \
  "SELECT athlete_id FROM sprint12_gate_bk_concurrency_fixture WHERE fixture_key='concurrency'")"
OCCURRENCE_ID="$(psqlc -Atc \
  "SELECT occurrence_id FROM sprint12_gate_bk_concurrency_fixture WHERE fixture_key='concurrency'")"
[[ -n "${ATHLETE_ID}" && -n "${OCCURRENCE_ID}" ]] \
  || sprint12_die "Gate BK concurrency fixture missing"

for side in a b; do
  pause=""
  if [[ "${side}" == "a" ]]; then
    pause="SELECT pg_sleep(0.5);"
  fi
  cat >"${WORKDIR}/bk_${side}.sql" <<SQL
BEGIN;
SELECT set_config('request.jwt.claim.sub', '${ATHLETE_ID}', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('role', 'authenticated', true);
SELECT public.create_or_resume_fixed_programme_occurrence_session(
  '${OCCURRENCE_ID}'::uuid
) AS result;
${pause}
COMMIT;
SQL
  docker cp "${WORKDIR}/bk_${side}.sql" \
    "${DB_CONTAINER}:/tmp/gate_bk_${side}.sql" >/dev/null
done

set +e
docker exec "${DB_CONTAINER}" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_bk_a.sql" \
  >"${WORKDIR}/bk_a.out" 2>&1 &
PID_A=$!
docker exec "${DB_CONTAINER}" bash -lc \
  "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/gate_bk_b.sql" \
  >"${WORKDIR}/bk_b.out" 2>&1 &
PID_B=$!
wait "${PID_A}"
EC_A=$?
wait "${PID_B}"
EC_B=$?
set -e

cat "${WORKDIR}/bk_a.out"
cat "${WORKDIR}/bk_b.out"
[[ "${EC_A}" -eq 0 && "${EC_B}" -eq 0 ]] \
  || sprint12_die "Gate BK concurrent subprocess failed"

STATUS_A="$(rg -o '"status": "[^"]+"' "${WORKDIR}/bk_a.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"
STATUS_B="$(rg -o '"status": "[^"]+"' "${WORKDIR}/bk_b.out" \
  | head -1 | sed 's/.*"status": "//;s/"$//')"
PAIR="${STATUS_A}|${STATUS_B}"
[[ "${PAIR}" == *"created"* && "${PAIR}" == *"resumed"* ]] \
  || sprint12_die "Gate BK expected created+resumed, got ${PAIR}"

COUNTS="$(psqlc -Atc "
  SELECT
    (SELECT count(*) FROM programme_occurrence_running_target_snapshots
      WHERE occurrence_id='${OCCURRENCE_ID}'::uuid),
    (SELECT count(*) FROM programme_slot_outcomes outcome
      JOIN programme_schedule_occurrences occurrence
        ON occurrence.assignment_id = outcome.assignment_id
       AND occurrence.session_slot_id = outcome.session_slot_id
      WHERE occurrence.id='${OCCURRENCE_ID}'::uuid),
    (SELECT count(DISTINCT frozen.training_session_id)
      FROM programme_occurrence_running_target_snapshots frozen
      WHERE frozen.occurrence_id='${OCCURRENCE_ID}'::uuid),
    (SELECT snapshot#>>'{targets,0,state}'
      FROM programme_occurrence_running_target_snapshots
      WHERE occurrence_id='${OCCURRENCE_ID}'::uuid);
")"
[[ "${COUNTS}" == "1|1|1|intent_only" ]] \
  || sprint12_die "Gate BK expected one snapshot/link/session, got ${COUNTS}"

echo "Gate BK concurrency PASSED (one immutable occurrence snapshot)"
