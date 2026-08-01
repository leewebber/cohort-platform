#!/usr/bin/env bash
# Validate Sprint 1.3 synthetic catalogue fixtures on positively confirmed Cohort Staging.
#
# Does NOT create users, credentials, payments, or athlete plans.
# Does NOT embed tokens, passwords, URLs, or project secrets.
#
# Usage:
#   CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh
#   CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh --dry-run
#
# Fail-closed: refuses to run unless linked CLI project name is exactly "Cohort Staging".

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" ]]; then
  echo "REFUSED: set CONFIRM_COHORT_STAGING=1 after positively confirming Cohort Staging." >&2
  exit 2
fi

if ! command -v supabase >/dev/null 2>&1; then
  echo "REFUSED: supabase CLI not found." >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "REFUSED: python3 not found." >&2
  exit 2
fi

python3 - <<'PY'
import json, subprocess, sys

raw = subprocess.check_output(["supabase", "projects", "list", "-o", "json"], text=True)
ps = json.loads(raw)
if isinstance(ps, dict) and "projects" in ps:
    ps = ps["projects"]
linked = [p for p in ps if p.get("linked")]
if len(linked) != 1:
    print("REFUSED: expected exactly one linked project.", file=sys.stderr)
    sys.exit(2)
p = linked[0]
name = p.get("name")
status = p.get("status") or ""
if name != "Cohort Staging":
    print(f"REFUSED: linked project is {name!r}, not Cohort Staging.", file=sys.stderr)
    sys.exit(2)
if "ACTIVE" not in status:
    print(f"REFUSED: Cohort Staging status is {status!r}.", file=sys.stderr)
    sys.exit(2)
# Production must not be the linked project (already enforced by name check).
print(f"STAGING_CONFIRMED name={name} region={p.get('region')} status={status}")
PY

if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY_RUN_OK: staging identity confirmed; no database queries executed."
  exit 0
fi

# Read-only fixture presence checks via linked SQL (no secrets in repo).
SQL=$(cat <<'SQL'
SELECT jsonb_build_object(
  'eligible_lineage', EXISTS(
    SELECT 1 FROM programme_lineages WHERE code = 'PROG-S13-ELIG'
  ),
  'draft_lineage', EXISTS(
    SELECT 1 FROM programme_lineages WHERE code = 'PROG-S13-DRAFT'
  ),
  'unapproved_lineage', EXISTS(
    SELECT 1 FROM programme_lineages WHERE code = 'PROG-S13-UNAPP'
  ),
  'private_lineage', EXISTS(
    SELECT 1 FROM programme_lineages WHERE code = 'PROG-S13-PRIV'
  ),
  'eligible_published_approved', EXISTS(
    SELECT 1
    FROM programme_versions v
    JOIN programme_lineages l ON l.id = v.lineage_id
    WHERE l.code = 'PROG-S13-ELIG'
      AND v.lifecycle_status = 'published'
      AND v.library_scope = 'cohort_global'
      AND COALESCE(v.approved_for_global, false) = true
      AND v.archived_at IS NULL
  ),
  'athlete_a_profile', EXISTS(
    SELECT 1 FROM profiles
    WHERE display_name = 'S13 Staging Athlete A'
      AND is_athlete = true
      AND COALESCE(is_coach, false) = false
  ),
  'athlete_b_profile', EXISTS(
    SELECT 1 FROM profiles
    WHERE display_name = 'S13 Staging Athlete B'
      AND is_athlete = true
      AND COALESCE(is_coach, false) = false
  )
) AS fixture_state;
SQL
)

OUT=$(supabase db query --linked "$SQL" -o json)
python3 - <<'PY' "$OUT"
import json, sys
raw = sys.argv[1]
data = json.loads(raw)
if isinstance(data, dict) and "rows" in data:
    row = data["rows"][0]
    payload = row.get("fixture_state", next(iter(row.values())))
elif isinstance(data, list):
    row = data[0]
    payload = row.get("fixture_state", next(iter(row.values()))) if isinstance(row, dict) else row
else:
    payload = data
if isinstance(payload, str):
    payload = json.loads(payload)
missing = [k for k, v in payload.items() if not v]
print("FIXTURE_STATE", json.dumps(payload, sort_keys=True))
if missing:
    print("MISSING", ",".join(missing), file=sys.stderr)
    sys.exit(1)
print("FIXTURE_VALIDATION_OK")
PY
