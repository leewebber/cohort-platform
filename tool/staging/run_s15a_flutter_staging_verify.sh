#!/usr/bin/env bash
# Controlled Sprint 1.5A Flutter Self-Test 2 against Cohort Staging (Athlete C).
#
# Requires:
#   CONFIRM_COHORT_STAGING=1
#   /tmp/s13b_dotenv_staging
#   /tmp/s13b_dotenv_prod_backup
#   /tmp/s15a_athlete_creds.json
#   /tmp/s15a_ids.json
#
# Never prints credentials. Restores .env and secrets stub on exit.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" ]]; then
  echo "REFUSED: set CONFIRM_COHORT_STAGING=1 after positively confirming Cohort Staging." >&2
  exit 2
fi

DOTENV_STAGING="${S15A_DOTENV_STAGING:-/tmp/s13b_dotenv_staging}"
DOTENV_BACKUP="${S15A_DOTENV_BACKUP:-/tmp/s13b_dotenv_prod_backup}"
CREDS_JSON="${S15A_ATHLETE_CREDS:-/tmp/s15a_athlete_creds.json}"
IDS_JSON="${S15A_IDS:-/tmp/s15a_ids.json}"
SECRETS_FILE="lib/s15a_staging_secrets.g.dart"
SECRETS_BACKUP="/tmp/s15a_secrets_stub_backup.dart"
REPORT_FILE="${S15A_FLUTTER_REPORT:-/tmp/s15a_flutter_staging_report.txt}"
DEVICE="${S15A_FLUTTER_DEVICE:-chrome}"

for f in "$DOTENV_STAGING" "$DOTENV_BACKUP" "$CREDS_JSON" "$IDS_JSON"; do
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
stub=Path('lib/s15a_staging_secrets.g.dart').read_text()
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
creds=json.loads(Path("/tmp/s15a_athlete_creds.json").read_text())
ids=json.loads(Path("/tmp/s15a_ids.json").read_text())
c=creds["c"]
a=creds.get("a", {"email":"","password":"","user_id":""})
b=creds.get("b", {"email":"","password":"","user_id":""})
env=Path(".env").read_text()
assert "tsbadngzgvsyfqjupkng" in env
assert "service_role" not in env.lower()
Path("lib/s15a_staging_secrets.g.dart").write_text(
f'''/// Temporary staging overwrite — restore after verification.
class S15AStagingSecrets {{
  static const bool enabled = true;
  static const String athleteCEmail = {json.dumps(c["email"])};
  static const String athleteCPassword = {json.dumps(c["password"])};
  static const String athleteCId = {json.dumps(c["user_id"])};
  static const String athleteAEmail = {json.dumps(a.get("email",""))};
  static const String athleteAPassword = {json.dumps(a.get("password",""))};
  static const String athleteAId = {json.dumps(a.get("user_id",""))};
  static const String athleteBEmail = {json.dumps(b.get("email",""))};
  static const String athleteBPassword = {json.dumps(b.get("password",""))};
  static const String athleteBId = {json.dumps(b.get("user_id",""))};
  static const String assignmentId = {json.dumps(ids["assignment_id"])};
  static const String versionId = {json.dumps(ids["version_id"])};
  static const String packageHash = {json.dumps(ids["package_hash"])};
  static const String slot1Id = {json.dumps(ids["slots"][0]["slot_id"])};
  static const String protocol1 = "PROT-S15A-STAGING-1";
  static const String protocol2 = "PROT-S15A-STAGING-2";
  static const String protocol3 = "PROT-S15A-STAGING-3";
}}
'''
)
print("STAGING_ENV_AND_SECRETS_PREPARED")
PY

echo "Running flutter Self-Test 2 on device=$DEVICE..."
rm -f "$REPORT_FILE"
set +e
flutter run -d "$DEVICE" -t lib/main_s15a_staging_verify.dart \
  2>&1 | tee "$REPORT_FILE" &
RUN_PID=$!

python3 - <<'PY'
import json, pathlib, re, time, sys
log=pathlib.Path("/tmp/s15a_flutter_staging_report.txt")
deadline=time.time()+420
line_pattern=re.compile(r"S15A_FLUTTER_ASSERTIONS_JSON (\{.*)$", re.M)
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
            pathlib.Path("/tmp/s15a_flutter_assertions.json").write_text(json.dumps(data, indent=2))
            if fails or not data.get("ok"):
                sys.exit(1)
            print("FLUTTER_STAGING_SELF_TEST_2_OK", flush=True)
            sys.exit(0)
        if "Could not find an option" in text or "BUILD FAILED" in text or "Error:" in text and "Compiling" in text:
            # keep waiting unless clearly fatal build
            if "BUILD FAILED" in text or "Could not find an option" in text:
                print(text[-2500:], file=sys.stderr)
                sys.exit(2)
    time.sleep(1)
print("TIMEOUT waiting for Flutter assertion JSON", file=sys.stderr)
if log.exists():
    print(log.read_text(errors="replace")[-4000:], file=sys.stderr)
sys.exit(2)
PY
WAIT_STATUS=$?
kill "$RUN_PID" 2>/dev/null || true
pkill -f 'main_s15a_staging_verify' 2>/dev/null || true
wait "$RUN_PID" 2>/dev/null || true
set -e
exit "$WAIT_STATUS"
