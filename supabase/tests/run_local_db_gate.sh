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

echo "=== Baseline fixture must not seed application data ==="
if rg -n '^COPY |^INSERT INTO ' "${TESTS_DIR}/fixtures/local_test_baseline_prereq.sql" >/dev/null; then
  sprint12_die "Baseline fixture contains COPY/INSERT (must be schema-only)"
fi
echo "Baseline fixture has no COPY/INSERT."

echo "=== Fresh reset (no seed; local only) ==="
sprint12_assert_command_is_local "supabase db reset --local --no-seed --workdir ..."
supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"

echo "=== Lint (before helpers) ==="
supabase db lint --local --level error --fail-on error --workdir "${SPRINT12_WORKDIR}"

echo "=== Baseline fidelity (separate from behavioural C–I totals) ==="
docker cp "${TESTS_DIR}/sql/baseline_fidelity.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_baseline_fidelity.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_baseline_fidelity.sql

echo "=== Load helpers + Gates C–I + J–O (enrolment through push/skip) ==="
docker cp "${TESTS_DIR}/sql/helpers.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_helpers.sql"
docker cp "${TESTS_DIR}/sql/gates_c_to_i.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gates.sql"
docker cp "${TESTS_DIR}/sql/gate_j_catalogue_enrolment.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_j.sql"
docker cp "${TESTS_DIR}/sql/gate_k_plan_materialisation.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_k.sql"
docker cp "${TESTS_DIR}/sql/gate_l_programme_completion_advancement.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_l.sql"
docker cp "${TESTS_DIR}/sql/gate_m_programme_schedule_projection.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_m.sql"
docker cp "${TESTS_DIR}/sql/gate_n_programme_schedule_move_swap.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_n.sql"
docker cp "${TESTS_DIR}/sql/gate_o_programme_schedule_push_skip.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_o.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_helpers.sql \
  -f /tmp/sprint12_gates.sql \
  -f /tmp/sprint12_gate_j.sql \
  -f /tmp/sprint12_gate_k.sql \
  -f /tmp/sprint12_gate_l.sql \
  -f /tmp/sprint12_gate_m.sql \
  -f /tmp/sprint12_gate_n.sql \
  -f /tmp/sprint12_gate_o.sql

echo "=== Repeat run (db reset + fidelity + fresh helpers/gates; no stale dependence) ==="
sprint12_assert_command_is_local "supabase db reset --local --no-seed --workdir ..."
supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"
docker cp "${TESTS_DIR}/sql/baseline_fidelity.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_baseline_fidelity.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_baseline_fidelity.sql
docker cp "${TESTS_DIR}/sql/helpers.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_helpers.sql"
docker cp "${TESTS_DIR}/sql/gates_c_to_i.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gates.sql"
docker cp "${TESTS_DIR}/sql/gate_j_catalogue_enrolment.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_j.sql"
docker cp "${TESTS_DIR}/sql/gate_k_plan_materialisation.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_k.sql"
docker cp "${TESTS_DIR}/sql/gate_l_programme_completion_advancement.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_l.sql"
docker cp "${TESTS_DIR}/sql/gate_m_programme_schedule_projection.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_m.sql"
docker cp "${TESTS_DIR}/sql/gate_n_programme_schedule_move_swap.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_n.sql"
docker cp "${TESTS_DIR}/sql/gate_o_programme_schedule_push_skip.sql" "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_gate_o.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/sprint12_helpers.sql \
  -f /tmp/sprint12_gates.sql \
  -f /tmp/sprint12_gate_j.sql \
  -f /tmp/sprint12_gate_k.sql \
  -f /tmp/sprint12_gate_l.sql \
  -f /tmp/sprint12_gate_m.sql \
  -f /tmp/sprint12_gate_n.sql \
  -f /tmp/sprint12_gate_o.sql

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

echo "=== PostgREST catalogue privilege controls (anon negative + auth positive) ==="
# Use status from disposable workdir only.
STATUS_JSON="$(supabase status -o json --workdir "${SPRINT12_WORKDIR}")"
API="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["API_URL"])' <<<"$STATUS_JSON")"
ANON="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["ANON_KEY"])' <<<"$STATUS_JSON")"
JWT_SECRET="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("JWT_SECRET") or "")' <<<"$STATUS_JSON")"
[[ -n "$JWT_SECRET" ]] || sprint12_die "Disposable stack JWT_SECRET missing from status"
# Mint a short-lived local authenticated JWT (no hosted credentials).
AUTH_JWT="$(JWT_SECRET="$JWT_SECRET" python3 - <<'PY'
import base64, hashlib, hmac, json, os, time
secret = os.environ["JWT_SECRET"].encode()

def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
now = int(time.time())
payload = b64url(json.dumps({
    "role": "authenticated",
    "iss": "supabase",
    "iat": now,
    "exp": now + 3600,
    "sub": "11111111-1111-4111-8111-111111111111",
    "aud": "authenticated",
}, separators=(",", ":")).encode())
sig = hmac.new(secret, f"{header}.{payload}".encode(), hashlib.sha256).digest()
print(f"{header}.{payload}.{b64url(sig)}")
PY
)"
echo "TARGET: api=${API} (local disposable; keys/tokens redacted)"
[[ "$API" == http://127.0.0.1:* || "$API" == http://localhost:* ]] || sprint12_die "API not loopback"

CATALOGUE_PATH="programme_versions?select=id,name,programme_lineages!inner(code)&approved_for_global=eq.true&lifecycle_status=eq.published"

# Anon negative: must not succeed as a catalogue read.
CODE="$(curl -sS -o /tmp/sprint12_http_anon.json -w '%{http_code}' \
  "${API}/rest/v1/${CATALOGUE_PATH}" \
  -H "apikey: ${ANON}" -H "Authorization: Bearer ${ANON}")"
echo "HTTP anon catalogue negative: http=${CODE}"
[[ "$CODE" == "401" || "$CODE" == "403" ]] || sprint12_die "Anon catalogue expected 401/403, got ${CODE}"
python3 - <<'PY'
import json
from pathlib import Path
raw = Path('/tmp/sprint12_http_anon.json').read_text().strip()
if raw:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        data = None
    if isinstance(data, list) and len(data) > 0:
        raise SystemExit('Anon catalogue negative returned data rows')
print('Anon catalogue negative: no data rows')
PY

# Authenticated positive: approved published + embedded lineage code.
CODE="$(curl -sS -o /tmp/sprint12_http_auth.json -w '%{http_code}' \
  "${API}/rest/v1/${CATALOGUE_PATH}" \
  -H "apikey: ${ANON}" -H "Authorization: Bearer ${AUTH_JWT}")"
echo "HTTP authenticated catalogue positive: http=${CODE}"
[[ "$CODE" == "200" ]] || {
  head -c 400 /tmp/sprint12_http_auth.json || true
  sprint12_die "Authenticated catalogue expected HTTP 200, got ${CODE}"
}
python3 - <<'PY'
import json
from pathlib import Path
rows = json.loads(Path('/tmp/sprint12_http_auth.json').read_text())
if not isinstance(rows, list) or len(rows) < 1:
    raise SystemExit('Authenticated catalogue returned no approved rows')
for row in rows:
    lineage = row.get('programme_lineages') or {}
    code = lineage.get('code') if isinstance(lineage, dict) else None
    if not row.get('id') or not row.get('name') or not code:
        raise SystemExit(f'Authenticated catalogue row missing id/name/lineage code: {row!r}')
print(f'Authenticated catalogue positive: rows={len(rows)} embed_ok')
PY

# Authenticated must not see drafts via Data API.
CODE="$(curl -sS -o /tmp/sprint12_http_auth_draft.json -w '%{http_code}' \
  "${API}/rest/v1/programme_versions?select=id&lifecycle_status=eq.draft&library_scope=eq.cohort_global" \
  -H "apikey: ${ANON}" -H "Authorization: Bearer ${AUTH_JWT}")"
[[ "$CODE" == "200" ]] || sprint12_die "Authenticated draft probe expected HTTP 200 (empty), got ${CODE}"
python3 - <<'PY'
import json
from pathlib import Path
rows = json.loads(Path('/tmp/sprint12_http_auth_draft.json').read_text())
if rows:
    raise SystemExit(f'Authenticated draft probe leaked {len(rows)} row(s)')
print('Authenticated draft probe: empty')
PY

# Authenticated must not see published-but-unapproved.
CODE="$(curl -sS -o /tmp/sprint12_http_auth_unapp.json -w '%{http_code}' \
  "${API}/rest/v1/programme_versions?select=id&lifecycle_status=eq.published&approved_for_global=eq.false&library_scope=eq.cohort_global" \
  -H "apikey: ${ANON}" -H "Authorization: Bearer ${AUTH_JWT}")"
[[ "$CODE" == "200" ]] || sprint12_die "Authenticated unapproved probe expected HTTP 200 (empty), got ${CODE}"
python3 - <<'PY'
import json
from pathlib import Path
rows = json.loads(Path('/tmp/sprint12_http_auth_unapp.json').read_text())
if rows:
    raise SystemExit(f'Authenticated unapproved probe leaked {len(rows)} row(s)')
print('Authenticated unapproved probe: empty')
PY
unset AUTH_JWT JWT_SECRET ANON

echo "=== Final production migrations integrity ==="
if compgen -G "${TESTS_DIR}/../migrations/20260701000000_*" >/dev/null; then
  sprint12_die "Bootstrap leaked into production migrations"
fi
echo "Production migrations clean of test bootstrap."

echo "ALL LOCAL DB GATE CHECKS PASSED"
echo "This harness does NOT authorise staging or production deployment."
