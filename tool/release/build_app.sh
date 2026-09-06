#!/usr/bin/env bash
# Build macOS or iOS with explicit environment and out-of-repo client config.
# Never rewrites repository .env. Never prints keys.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_NAME=""
CONFIG_PATH=""
TARGET="macos"
DRY_RUN=0
DEFINES_DIR=""

cleanup() {
  if [[ -n "${DEFINES_DIR}" && -d "${DEFINES_DIR}" ]]; then
    rm -rf "${DEFINES_DIR}"
  fi
}
trap cleanup EXIT INT TERM

usage() {
  cat <<'EOF'
Usage:
  tool/release/build_app.sh --env production|loopbackPreview|development \
    --config /absolute/path/to/client.defines.json \
    [--target macos|ios] [--dry-run]

The config file must live outside Git or be an untracked local file.
Required JSON keys: COHORT_SUPABASE_URL, COHORT_SUPABASE_ANON_KEY
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="${2:-}"; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument" >&2; exit 2 ;;
  esac
done

case "$ENV_NAME" in
  production|loopbackPreview|development) ;;
  *) echo "COHORT_BUILD_ENV must be production, loopbackPreview, or development" >&2; exit 2 ;;
esac
case "$TARGET" in
  macos|ios) ;;
  *) echo "target must be macos or ios" >&2; exit 2 ;;
esac
[[ -n "$CONFIG_PATH" && -f "$CONFIG_PATH" ]] || {
  echo "config file is required" >&2
  exit 2
}

DEFINES_DIR="$(mktemp -d /tmp/cohort-release-defines.XXXXXX)"
DEFINES_FILE="${DEFINES_DIR}/defines.json"
COMMIT="$(git -C "$ROOT" rev-parse --short=7 HEAD)"
VERSION_LINE="$(python3 - <<'PY' "$ROOT/pubspec.yaml"
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text().splitlines()
line = next(item for item in text if item.startswith("version:"))
print(line.split(":", 1)[1].strip())
PY
)"
APP_VERSION="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE##*+}"
[[ "$BUILD_NUMBER" != "$VERSION_LINE" ]] || BUILD_NUMBER="1"

python3 - <<'PY' "$CONFIG_PATH" "$ENV_NAME" "$DEFINES_FILE" "$COMMIT" "$APP_VERSION" "$BUILD_NUMBER"
import json, sys
from pathlib import Path
from urllib.parse import urlparse
src, env_name, dest, commit, version, build = sys.argv[1:7]
data = json.loads(Path(src).read_text())
if not isinstance(data, dict):
    raise SystemExit("config must be a JSON object")
url = str(data.get("COHORT_SUPABASE_URL", "")).strip()
key = str(data.get("COHORT_SUPABASE_ANON_KEY", "")).strip()
declared = str(data.get("COHORT_BUILD_ENV", env_name)).strip()
if declared != env_name:
    raise SystemExit("config COHORT_BUILD_ENV does not match --env")
if not url or not key:
    raise SystemExit("config is missing URL or anon key")
if "service_role" in key.lower():
    raise SystemExit("service_role material is not allowed in client config")
parsed = urlparse(url)
host = (parsed.hostname or "").lower()
if env_name == "production":
    if parsed.scheme != "https" or host != "otnhhdxstdnwccehacku.supabase.co":
        raise SystemExit("production config host class rejected")
elif env_name == "loopbackPreview":
    if parsed.scheme != "http" or host not in {"127.0.0.1", "localhost", "::1"}:
        raise SystemExit("loopbackPreview config host class rejected")
elif env_name == "development":
    allowed = {
        ("http", "127.0.0.1"),
        ("http", "localhost"),
        ("http", "::1"),
        ("https", "otnhhdxstdnwccehacku.supabase.co"),
        ("https", "tsbadngzgvsyfqjupkng.supabase.co"),
    }
    if (parsed.scheme, host) not in allowed:
        raise SystemExit("development config host class rejected")
merged = {
    "COHORT_BUILD_ENV": env_name,
    "COHORT_SUPABASE_URL": url,
    "COHORT_SUPABASE_ANON_KEY": key,
    "COHORT_GIT_COMMIT": commit,
    "COHORT_APP_VERSION": version,
    "COHORT_BUILD_NUMBER": build,
}
Path(dest).write_text(json.dumps(merged))
if parsed.hostname in {"127.0.0.1", "localhost", "::1"}:
    print("HOST_CLASS=loopback")
elif parsed.scheme == "https":
    print("HOST_CLASS=hosted_https")
else:
    print("HOST_CLASS=other")
PY

echo "ENV=${ENV_NAME}"
echo "TARGET=${TARGET}"
echo "COMMIT=${COMMIT}"
echo "DEFINES_READY=true"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY_RUN=true"
  echo "FLUTTER_CMD=flutter build ${TARGET} --release --dart-define-from-file=<redacted>"
  exit 0
fi

cd "$ROOT"
flutter build "$TARGET" --release --dart-define-from-file="$DEFINES_FILE"
echo "BUILD_OK=true"
