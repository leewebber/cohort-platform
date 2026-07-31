#!/usr/bin/env bash
# Gate G — true multi-session concurrency (G1/G2 only).
# Sequential duplicate validation lives under Gate E (sql/gates_c_to_i.sql).
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/target_guard.sh
source "${TESTS_DIR}/lib/target_guard.sh"

DB_CONTAINER="${SPRINT12_DB_CONTAINER:-}"
PROJECT_ID="${SPRINT12_PROJECT_ID:-}"
HELPERS_SQL="${TESTS_DIR}/sql/helpers.sql"
WORKDIR=""
NEGATIVE="${SPRINT12_G_NEGATIVE:-0}"

cleanup() {
  if [[ -n "${WORKDIR}" && -d "${WORKDIR}" ]]; then
    rm -rf "${WORKDIR}"
  fi
}
trap cleanup EXIT

usage_die() { sprint12_die "$*"; }

[[ -n "$DB_CONTAINER" ]] || usage_die "SPRINT12_DB_CONTAINER unset"
[[ -n "$PROJECT_ID" ]] || usage_die "SPRINT12_PROJECT_ID unset"
sprint12_assert_no_hosted_intent "$@"
sprint12_assert_local_container "$DB_CONTAINER" "$PROJECT_ID"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sprint12_gate_g.XXXXXX")"

psqlc() {
  docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

echo "=== Gate G setup ==="
docker cp "$HELPERS_SQL" "${DB_CONTAINER}:/tmp/sprint12_helpers.sql"
psqlc -f /tmp/sprint12_helpers.sql >/dev/null
psqlc -c "SELECT sprint12_ensure_published_session('PROT-GATE-G-R1','33333333-3333-3333-3333-333333333333'::uuid,1,'Gate G Session');" >/dev/null

HASH_SAME="$(psqlc -Atc "SELECT encode(digest('gate-g-same','sha256'),'hex')")"
HASH_DIFF="$(psqlc -Atc "SELECT encode(digest('gate-g-diff','sha256'),'hex')")"

run_pair() {
  local label="$1" a_sql="$2" b_sql="$3"
  local a_out="${WORKDIR}/${label}_a.out" b_out="${WORKDIR}/${label}_b.out"
  local a_ec=0 b_ec=0

  docker cp "$a_sql" "${DB_CONTAINER}:/tmp/${label}_a.sql"
  docker cp "$b_sql" "${DB_CONTAINER}:/tmp/${label}_b.sql"

  set +e
  docker exec "$DB_CONTAINER" bash -lc "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/${label}_a.sql" >"$a_out" 2>&1 &
  local pid_a=$!
  docker exec "$DB_CONTAINER" bash -lc "psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/${label}_b.sql" >"$b_out" 2>&1 &
  local pid_b=$!
  wait "$pid_a"
  a_ec=$?
  wait "$pid_b"
  b_ec=$?
  set -e

  echo "--- ${label} session A (exit=${a_ec}) ---"
  cat "$a_out"
  echo "--- ${label} session B (exit=${b_ec}) ---"
  cat "$b_out"

  if [[ "$a_ec" -ne 0 || "$b_ec" -ne 0 ]]; then
    sprint12_die "${label}: subprocess failed (a=${a_ec} b=${b_ec})"
  fi

  local status_a status_b
  status_a="$(rg -o '"status": "[^"]+"' "$a_out" | head -1 | sed 's/.*"status": "//;s/"$//')"
  status_b="$(rg -o '"status": "[^"]+"' "$b_out" | head -1 | sed 's/.*"status": "//;s/"$//')"
  echo "${label}: status_a=${status_a} status_b=${status_b}"

  printf '%s\n' "$status_a" > "${WORKDIR}/${label}_a.status"
  printf '%s\n' "$status_b" > "${WORKDIR}/${label}_b.status"
  printf '%s\n' "$a_ec" > "${WORKDIR}/${label}_a.ec"
  printf '%s\n' "$b_ec" > "${WORKDIR}/${label}_b.ec"
}

# ---------------------------------------------------------------------------
# Isolated negative control: fresh lineage, clean state, invert one expectation.
# ---------------------------------------------------------------------------
if [[ "$NEGATIVE" == "1" ]]; then
  NEG_LINEAGE="PROG-GATE-G-NEG-$(date +%Y%m%d%H%M%S)-$(openssl rand -hex 3 2>/dev/null || printf '%04x' "$RANDOM")"
  echo "=== G-NEG isolated negative control lineage=${NEG_LINEAGE} ==="

  CLEAN="$(psqlc -Atc "SELECT count(*) FROM programme_lineages WHERE code='${NEG_LINEAGE}'")"
  [[ "$CLEAN" == "0" ]] || sprint12_die "G-NEG lineage not clean at start (count=${CLEAN})"

  cat > "${WORKDIR}/gneg_a.sql" <<SQL
BEGIN;
SELECT set_config('role','service_role', true);
SELECT pg_sleep(0.35);
SELECT public.import_authored_plan_package(
  sprint12_build_package(
    '${NEG_LINEAGE}', 1, '${HASH_SAME}',
    'PROT-GATE-G-R1', '33333333-3333-3333-3333-333333333333'::uuid
  )
) AS result;
COMMIT;
SQL

  cat > "${WORKDIR}/gneg_b.sql" <<SQL
BEGIN;
SELECT set_config('role','service_role', true);
SELECT public.import_authored_plan_package(
  sprint12_build_package(
    '${NEG_LINEAGE}', 1, '${HASH_SAME}',
    'PROT-GATE-G-R1', '33333333-3333-3333-3333-333333333333'::uuid
  )
) AS result;
COMMIT;
SQL

  run_pair gneg "${WORKDIR}/gneg_a.sql" "${WORKDIR}/gneg_b.sql"
  SA="$(cat "${WORKDIR}/gneg_a.status")"
  SB="$(cat "${WORKDIR}/gneg_b.status")"
  AEC="$(cat "${WORKDIR}/gneg_a.ec")"
  BEC="$(cat "${WORKDIR}/gneg_b.ec")"

  # Prove sessions succeeded (failure must not be SQL/subprocess).
  [[ "$AEC" == "0" && "$BEC" == "0" ]] || sprint12_die "G-NEG subprocess failure (not inverted-expectation proof)"

  # Prove not stale: must observe a true import+replay pair on the fresh lineage.
  PAIR="${SA}|${SB}"
  if [[ "$SA" == "$SB" ]]; then
    sprint12_die "G-NEG stale/non-concurrent outcome (identical statuses ${SA}); not inverted-expectation proof"
  fi
  if [[ "$PAIR" != *"imported_draft"* || "$PAIR" != *"idempotent_existing_draft"* ]]; then
    sprint12_die "G-NEG did not observe import+replay pair (a=${SA} b=${SB}); not inverted-expectation proof"
  fi
  ROWS="$(psqlc -Atc "SELECT count(*) FROM programme_versions pv JOIN programme_lineages pl ON pl.id=pv.lineage_id WHERE pl.code='${NEG_LINEAGE}'")"
  [[ "$ROWS" == "1" ]] || sprint12_die "G-NEG unexpected version count ${ROWS}"

  # Deliberately invert one expected outcome: require version_collision (wrong for same-hash).
  if [[ "$SA" == "version_collision" || "$SB" == "version_collision" ]]; then
    sprint12_die "G-NEG inverted expectation unexpectedly matched real outcome"
  fi
  sprint12_die "G-NEG inverted expectation rejected correct concurrent outcomes a=${SA} b=${SB} (not stale-state)"
fi

# ---------------------------------------------------------------------------
# Normal G1 / G2 paths
# ---------------------------------------------------------------------------

# G1 same hash — A sleeps to create overlap; advisory lock inside import serialises writers.
cat > "${WORKDIR}/g1_a.sql" <<SQL
BEGIN;
SELECT set_config('role','service_role', true);
SELECT pg_sleep(0.35);
SELECT public.import_authored_plan_package(
  sprint12_build_package(
    'PROG-GATE-G-SAME', 1, '${HASH_SAME}',
    'PROT-GATE-G-R1', '33333333-3333-3333-3333-333333333333'::uuid
  )
) AS result;
COMMIT;
SQL

cat > "${WORKDIR}/g1_b.sql" <<SQL
BEGIN;
SELECT set_config('role','service_role', true);
SELECT public.import_authored_plan_package(
  sprint12_build_package(
    'PROG-GATE-G-SAME', 1, '${HASH_SAME}',
    'PROT-GATE-G-R1', '33333333-3333-3333-3333-333333333333'::uuid
  )
) AS result;
COMMIT;
SQL

echo "=== G1 same lineage/version/hash concurrent ==="
run_pair g1 "${WORKDIR}/g1_a.sql" "${WORKDIR}/g1_b.sql"
SA="$(cat "${WORKDIR}/g1_a.status")"
SB="$(cat "${WORKDIR}/g1_b.status")"
# One imported_draft, one idempotent_existing_draft (order depends on winner).
if [[ "$SA" == "$SB" ]]; then
  sprint12_die "G1 both sessions returned identical status ${SA} (need import + replay pair)"
fi
if [[ ! ( "$SA" == "imported_draft" || "$SB" == "imported_draft" ) ]]; then
  sprint12_die "G1 missing imported_draft (a=${SA} b=${SB})"
fi
if [[ ! ( "$SA" == "idempotent_existing_draft" || "$SB" == "idempotent_existing_draft" ) ]]; then
  sprint12_die "G1 missing idempotent_existing_draft (a=${SA} b=${SB})"
fi

ROWS="$(psqlc -Atc "SELECT count(*) FROM programme_versions pv JOIN programme_lineages pl ON pl.id=pv.lineage_id WHERE pl.code='PROG-GATE-G-SAME'")"
[[ "$ROWS" == "1" ]] || sprint12_die "G1 expected 1 version row, got ${ROWS}"
COUNTS="$(psqlc -Atc "SELECT sprint12_package_counts(pv.id)::text FROM programme_versions pv JOIN programme_lineages pl ON pl.id=pv.lineage_id WHERE pl.code='PROG-GATE-G-SAME'")"
echo "G1 counts=${COUNTS}"
[[ "$COUNTS" == *'"slots": 1'* ]] || sprint12_die "G1 incomplete graph: ${COUNTS}"

# G2 different hash
cat > "${WORKDIR}/g2_a.sql" <<SQL
BEGIN;
SELECT set_config('role','service_role', true);
SELECT pg_sleep(0.35);
SELECT public.import_authored_plan_package(
  sprint12_build_package(
    'PROG-GATE-G-DIFF', 1, '${HASH_SAME}',
    'PROT-GATE-G-R1', '33333333-3333-3333-3333-333333333333'::uuid
  )
) AS result;
COMMIT;
SQL

cat > "${WORKDIR}/g2_b.sql" <<SQL
BEGIN;
SELECT set_config('role','service_role', true);
SELECT public.import_authored_plan_package(
  sprint12_build_package(
    'PROG-GATE-G-DIFF', 1, '${HASH_DIFF}',
    'PROT-GATE-G-R1', '33333333-3333-3333-3333-333333333333'::uuid
  )
) AS result;
COMMIT;
SQL

echo "=== G2 same lineage/version different hash concurrent ==="
run_pair g2 "${WORKDIR}/g2_a.sql" "${WORKDIR}/g2_b.sql"
SA="$(cat "${WORKDIR}/g2_a.status")"
SB="$(cat "${WORKDIR}/g2_b.status")"
# One imported_draft, one version_collision
PAIR="${SA}|${SB}"
if [[ "$PAIR" != *"imported_draft"* || "$PAIR" != *"version_collision"* ]]; then
  sprint12_die "G2 expected imported_draft + version_collision, got a=${SA} b=${SB}"
fi
ROWS="$(psqlc -Atc "SELECT count(*) FROM programme_versions pv JOIN programme_lineages pl ON pl.id=pv.lineage_id WHERE pl.code='PROG-GATE-G-DIFF'")"
[[ "$ROWS" == "1" ]] || sprint12_die "G2 expected 1 version row, got ${ROWS}"

echo "Gate G concurrency PASSED"
# Limitation: overlap uses pg_sleep + import advisory lock; not a custom barrier.
echo "NOTE: overlap coordination uses pg_sleep(0.35) plus production advisory xact lock inside import_authored_plan_package."
