#!/usr/bin/env bash
# Controlled Sprint 1.4A Flutter verification against Cohort Staging.
#
# Requires:
#   CONFIRM_COHORT_STAGING=1
#   /tmp/s13b_dotenv_staging
#   /tmp/s13b_athlete_creds.json
#   /tmp/s13b_dotenv_prod_backup
#
# Never prints credentials. Restores .env and secrets stub on exit.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" ]]; then
  echo "REFUSED: set CONFIRM_COHORT_STAGING=1 after positively confirming Cohort Staging." >&2
  exit 2
fi

DOTENV_STAGING="${S14A_DOTENV_STAGING:-/tmp/s13b_dotenv_staging}"
DOTENV_BACKUP="${S14A_DOTENV_BACKUP:-/tmp/s13b_dotenv_prod_backup}"
CREDS_JSON="${S14A_ATHLETE_CREDS:-/tmp/s13b_athlete_creds.json}"
SECRETS_FILE="lib/s14a_staging_secrets.g.dart"
SECRETS_BACKUP="/tmp/s14a_secrets_stub_backup.dart"
REPORT_FILE="${S14A_FLUTTER_REPORT:-/tmp/s14a_flutter_staging_report.txt}"
DEVICE="${S14A_FLUTTER_DEVICE:-chrome}"

for f in "$DOTENV_STAGING" "$DOTENV_BACKUP" "$CREDS_JSON"; do
  if [[ ! -f "$f" ]]; then
    echo "REFUSED: missing required temp config $f" >&2
    exit 2
  fi
done

CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh --dry-run

cleanup() {
  if [[ -f "$DOTENV_BACKUP" ]]; then
    cp "$DOTENV_BACKUP" .env
  fi
  if [[ -f "$SECRETS_BACKUP" ]]; then
    cp "$SECRETS_BACKUP" "$SECRETS_FILE"
  fi
  python3 - <<'PY'
from pathlib import Path
env=Path('.env').read_text()
stub=Path('lib/s14a_staging_secrets.g.dart').read_text()
print('ENV_RESTORED_NON_STAGING', 'tsbadngzgvsyfqjupkng' not in env)
print('SECRETS_STUB_RESTORED', 'enabled = false' in stub)
if 'tsbadngzgvsyfqjupkng' in env:
    raise SystemExit('REFUSED: staging URL still in .env after restore')
if 'enabled = true' in stub:
    raise SystemExit('REFUSED: secrets stub still enabled after restore')
PY
}
trap cleanup EXIT

cp "$SECRETS_FILE" "$SECRETS_BACKUP"
cp "$DOTENV_STAGING" .env

python3 - <<'PY'
import json
from pathlib import Path
a=json.loads(Path("/tmp/s13b_athlete_creds.json").read_text())["a"]
env=Path(".env").read_text()
assert "tsbadngzgvsyfqjupkng" in env
assert "service_role" not in env.lower()
Path("lib/s14a_staging_secrets.g.dart").write_text(
f'''/// Temporary staging overwrite — restore after verification.
class S14AStagingSecrets {{
  static const bool enabled = true;
  static const String athleteAEmail = {json.dumps(a["email"])};
  static const String athleteAPassword = {json.dumps(a["password"])};
  static const String athleteAId = {json.dumps(a["user_id"])};
}}
'''
)
print("STAGING_ENV_AND_SECRETS_PREPARED")
PY

echo "Running flutter verify on device=$DEVICE..."
rm -f "$REPORT_FILE"
set +e
flutter run -d "$DEVICE" -t lib/main_s14a_staging_verify.dart \
  2>&1 | tee "$REPORT_FILE" &
RUN_PID=$!

python3 - <<'PY'
import json, pathlib, re, time, sys
log=pathlib.Path("/tmp/s14a_flutter_staging_report.txt")
deadline=time.time()+240
# Non-greedy object match; prefer last complete JSON line.
pattern=re.compile(r"S14A_FLUTTER_ASSERTIONS_JSON (\{.*?\})(?=\s*$|\s*S14A_|\s*Debug|\s*Another|\s*$)", re.M)
# Fallback: take JSON from marker to end of line.
line_pattern=re.compile(r"S14A_FLUTTER_ASSERTIONS_JSON (\{.*)$", re.M)
while time.time()<deadline:
    if log.exists():
        text=log.read_text(errors="replace")
        matches=line_pattern.findall(text)
        if matches:
            data=json.loads(matches[-1].strip())
            asserts=data.get("assertions",[])
            fails=[a for a in asserts if not a.get("pass")]
            print("ASSERTION_COUNT", len(asserts), flush=True)
            print("PASS_COUNT", len(asserts)-len(fails), flush=True)
            print("FAIL_COUNT", len(fails), flush=True)
            for a in asserts:
                mark="PASS" if a.get("pass") else "FAIL"
                detail=a.get("detail")
                if detail and len(str(detail))>180:
                    detail=str(detail)[:180]+"…"
                print(f"{mark} {a['name']}" + (f" | {detail}" if detail else ""), flush=True)
            pathlib.Path("/tmp/s14a_flutter_assertions.json").write_text(json.dumps(data, indent=2))
            if fails or not data.get("ok"):
                sys.exit(1)
            print("FLUTTER_STAGING_OK", flush=True)
            sys.exit(0)
        if "Could not find an option" in text or "BUILD FAILED" in text:
            print(text[-2000:], file=sys.stderr)
            sys.exit(2)
    time.sleep(1)
print("TIMEOUT waiting for Flutter assertion JSON", file=sys.stderr)
if log.exists():
    print(log.read_text(errors="replace")[-3000:], file=sys.stderr)
sys.exit(2)
PY
WAIT_STATUS=$?
kill "$RUN_PID" 2>/dev/null || true
pkill -f 'main_s14a_staging_verify' 2>/dev/null || true
wait "$RUN_PID" 2>/dev/null || true
set -e
exit "$WAIT_STATUS"
