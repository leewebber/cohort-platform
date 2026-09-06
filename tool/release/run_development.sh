#!/usr/bin/env bash
# Launch Development from repo .env without rewriting that file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${COHORT_DEV_ENV_FILE:-$ROOT/.env}"
DRY_RUN=0
DEFINES_DIR=""

cleanup() {
  if [[ -n "${DEFINES_DIR}" && -d "${DEFINES_DIR}" ]]; then
    rm -rf "${DEFINES_DIR}"
  fi
}
trap cleanup EXIT INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown argument" >&2; exit 2 ;;
  esac
done

[[ -f "$ENV_FILE" ]] || {
  echo "development env file is missing" >&2
  exit 2
}

DEFINES_DIR="$(mktemp -d /tmp/cohort-dev-defines.XXXXXX)"
DEFINES_FILE="${DEFINES_DIR}/defines.json"
COMMIT="$(git -C "$ROOT" rev-parse --short=7 HEAD)"

python3 - <<'PY' "$ENV_FILE" "$DEFINES_FILE" "$COMMIT"
from pathlib import Path
import json, sys
from urllib.parse import urlparse
env_path, dest, commit = sys.argv[1:4]
values = {}
for raw in Path(env_path).read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip()
url = values.get("SUPABASE_URL") or values.get("COHORT_SUPABASE_URL") or ""
key = values.get("SUPABASE_ANON_KEY") or values.get("COHORT_SUPABASE_ANON_KEY") or ""
if not url or not key:
    raise SystemExit("development env file is missing URL or anon key")
if "service_role" in key.lower():
    raise SystemExit("service_role material is not allowed in client config")
parsed = urlparse(url)
host = (parsed.hostname or "").lower()
allowed = {
    ("http", "127.0.0.1"),
    ("http", "localhost"),
    ("http", "::1"),
    ("https", "otnhhdxstdnwccehacku.supabase.co"),
    ("https", "tsbadngzgvsyfqjupkng.supabase.co"),
}
if (parsed.scheme, host) not in allowed:
    raise SystemExit("development config host class rejected")
Path(dest).write_text(json.dumps({
    "COHORT_BUILD_ENV": "development",
    "COHORT_SUPABASE_URL": url,
    "COHORT_SUPABASE_ANON_KEY": key,
    "COHORT_GIT_COMMIT": commit,
    "COHORT_APP_VERSION": "1.0.0",
    "COHORT_BUILD_NUMBER": "1",
}))
print("ENV=development")
print("DEFINES_READY=true")
PY

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY_RUN=true"
  echo "FLUTTER_CMD=flutter run --dart-define-from-file=<redacted>"
  exit 0
fi

cd "$ROOT"
flutter run --dart-define-from-file="$DEFINES_FILE"
