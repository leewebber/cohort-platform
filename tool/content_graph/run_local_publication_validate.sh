#!/usr/bin/env bash
# Disposable local publication of committed artifacts. Never Field Manual.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "${REPO}/supabase/tests/lib/prepare_disposable_workdir.sh"
sprint12_assert_no_hosted_intent
sprint12_prepare_disposable_workdir
STARTED=0
cleanup() {
  local ec=$?
  set +e
  if [[ "$STARTED" -eq 1 && -n "${SPRINT12_WORKDIR:-}" ]]; then
    supabase stop --workdir "${SPRINT12_WORKDIR}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${SPRINT12_WORKDIR:-}" && -d "${SPRINT12_WORKDIR}" ]]; then
    rm -rf "${SPRINT12_WORKDIR}"
  fi
  exit "$ec"
}
trap cleanup EXIT
supabase start \
  --workdir "${SPRINT12_WORKDIR}" \
  --exclude edge-runtime,imgproxy,mailpit,realtime,storage-api,studio,vector \
  --ignore-health-check >/dev/null
STARTED=1
ACTUAL_PROJECT_ID="$(rg -n '^project_id\s*=' "${SPRINT12_WORKDIR}/supabase/config.toml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
SPRINT12_PROJECT_ID="$ACTUAL_PROJECT_ID"
SPRINT12_DB_CONTAINER="$(sprint12_resolve_exact_db_container "$SPRINT12_PROJECT_ID")"
supabase db reset --local --no-seed --yes --workdir "${SPRINT12_WORKDIR}"
docker cp "${REPO}/supabase/manual/content_graph_bootstrap_cohort_global.sql" \
  "${SPRINT12_DB_CONTAINER}:/tmp/sprint12_content_graph_bootstrap.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "SELECT set_config('role','postgres',true)" \
  -f /tmp/sprint12_content_graph_bootstrap.sql
python3 - <<PY
import json
from pathlib import Path
root = Path("${REPO}/content/content_graph/v1")
out = Path("/tmp/m9_art_payloads.sql")
parts = [
    "CREATE TEMP TABLE m9_art_payloads (name text primary key, payload jsonb not null);"
]
for name, rel in (
    ("apollo", "cohort_global/apollo/2ba018bd-7dc2-4dfd-8d8e-e35823158920.publication.json"),
    ("spartan", "cohort_global/spartan/32986922-47d1-46b0-b391-a7931d73033e.publication.json"),
):
    raw = (root / rel).read_text()
    json.loads(raw)
    parts.append(
        "INSERT INTO m9_art_payloads VALUES ('%s', \$m9json\$%s\$m9json\$::jsonb);"
        % (name, raw)
    )
out.write_text("\n".join(parts))
PY
docker cp /tmp/m9_art_payloads.sql "${SPRINT12_DB_CONTAINER}:/tmp/m9_art_payloads.sql"
docker cp "${REPO}/tool/content_graph/local_publication_validate.sql" \
  "${SPRINT12_DB_CONTAINER}:/tmp/m9_art_validate.sql"
docker exec -i "${SPRINT12_DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/m9_art_payloads.sql \
  -f /tmp/m9_art_validate.sql
echo "LOCAL_PUBLICATION_VALIDATION_DONE"
