#!/usr/bin/env bash
# Build an isolated temporary Supabase project that includes:
#   1) test-only baseline (never from production migrations/)
#   2) read-only copies of real repository migrations in order
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/../.." && pwd)"
REPO_SUPABASE="${REPO_ROOT}/supabase"
REPO_MIGRATIONS="${REPO_SUPABASE}/migrations"
BASELINE_SRC="${TESTS_DIR}/fixtures/local_test_baseline_prereq.sql"

# shellcheck source=target_guard.sh
source "${SCRIPT_DIR}/target_guard.sh"

sprint12_prepare_disposable_workdir() {
  [[ -f "$BASELINE_SRC" ]] || sprint12_die "Missing test-only baseline fixture: $BASELINE_SRC"
  [[ -d "$REPO_MIGRATIONS" ]] || sprint12_die "Missing repository migrations: $REPO_MIGRATIONS"

  # Refuse if a test baseline still pollutes production migrations.
  if compgen -G "${REPO_MIGRATIONS}/20260701000000_*" >/dev/null; then
    sprint12_die "Test baseline must not exist under production supabase/migrations/."
  fi

  local stamp rand project_id workdir
  # Keep project_id short: Supabase CLI truncates/auto-fixes long ids, which breaks
  # container-name expectations.
  stamp="$(date +%m%d%H%M%S)"
  rand="$(openssl rand -hex 2 2>/dev/null || printf '%04x' "$RANDOM")"
  project_id="s12g${stamp}${rand}"
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/sprint12_gate.${project_id}.XXXXXX")"

  mkdir -p "${workdir}/supabase/migrations"

  # Unique local ports avoid colliding with any other local Supabase project.
  local api_port db_port shadow_port
  api_port=$((55000 + (RANDOM % 500) * 2))
  db_port=$((api_port + 1))
  shadow_port=$((api_port + 2))

  # Minimal local-only config. Do not copy repository .temp (may contain linked project metadata).
  cat > "${workdir}/supabase/config.toml" <<EOF
project_id = "${project_id}"

[api]
enabled = true
port = ${api_port}
schemas = ["public", "graphql_public"]
extra_search_path = ["public", "extensions"]
max_rows = 1000

[db]
port = ${db_port}
shadow_port = ${shadow_port}
major_version = 17

[db.pooler]
enabled = false

[db.migrations]
enabled = true
schema_paths = []

[db.seed]
enabled = false
sql_paths = []

[realtime]
enabled = false

[studio]
enabled = false

[storage]
enabled = false

[auth]
enabled = true
site_url = "http://127.0.0.1:3000"
additional_redirect_urls = ["http://127.0.0.1:3000"]
enable_signup = true

[edge_runtime]
enabled = false

[analytics]
enabled = false
EOF

  # Test-only baseline first (temporary workdir only).
  cp "$BASELINE_SRC" \
    "${workdir}/supabase/migrations/20260701000000_local_test_baseline_prereq.sql"

  # Copy real production migrations unchanged and in filename order.
  local f base
  while IFS= read -r f; do
    base="$(basename "$f")"
    # Skip any accidental bootstrap if present.
    if [[ "$base" == 20260701000000_* ]]; then
      sprint12_die "Refusing to copy bootstrap-named file from production migrations: $base"
    fi
    cp "$f" "${workdir}/supabase/migrations/${base}"
  done < <(ls -1 "${REPO_MIGRATIONS}"/*.sql | sort)

  # Prove production migrations dir still has no baseline.
  if compgen -G "${REPO_MIGRATIONS}/20260701000000_*" >/dev/null; then
    sprint12_die "Production migrations polluted during prepare."
  fi

  # Export for caller.
  SPRINT12_WORKDIR="$workdir"
  SPRINT12_PROJECT_ID="$project_id"
  SPRINT12_DB_CONTAINER="supabase_db_${project_id}"

  echo "Prepared disposable workdir=${workdir}"
  echo "project_id=${project_id}"
  echo "expected_container=${SPRINT12_DB_CONTAINER}"
  echo "NOTE: test-only baseline is derived from the authorised hosted schema-only dump for disposable Sprint 1.2 validation; see fixtures/local_test_baseline_prereq.sql header for accommodations."
}
