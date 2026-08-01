#!/usr/bin/env bash
# Create Cohort Staging-only Self-Test 2 fixture (Athlete C + 3-slot package).
#
# Fail-closed:
#   CONFIRM_COHORT_STAGING=1 required
#   Linked project must be Cohort Staging (tsbadngz…)
#   Does not mutate Athlete A/B or PROG-S13-* packages
#   Credentials written only under /tmp (never committed)
#
# Lifecycle:
#   1) Admin Auth API → Athlete C + athlete-only profile
#   2) Linked SQL → three published protocols + protocol_steps
#   3) service_role SQL → import → publish → approve PROG-S15A-STAGING
#   4) Authenticated HTTP as Athlete C → enrol → materialise
#   5) Fixture gate (executable_count≥2, next_slot non-null)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ "${CONFIRM_COHORT_STAGING:-}" != "1" ]]; then
  echo "REFUSED: set CONFIRM_COHORT_STAGING=1 after positively confirming Cohort Staging." >&2
  exit 2
fi

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/supabase-config-home}"
API_ENV="${S15A_API_ENV:-/tmp/s13b_api.env}"
IDS_OUT="${S15A_IDS_OUT:-/tmp/s15a_ids.json}"
CREDS_OUT="${S15A_CREDS_OUT:-/tmp/s15a_athlete_creds.json}"
GATE_OUT="${S15A_GATE_OUT:-/tmp/s15a_fixture_gate.json}"
PRESERVE_OUT="${S15A_PRESERVE_OUT:-/tmp/s15a_preserve_ab_before.json}"

if [[ ! -f "$API_ENV" ]]; then
  echo "REFUSED: missing API env $API_ENV" >&2
  exit 2
fi

CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh --dry-run

python3 - <<'PY'
import json, subprocess, sys
ps = json.loads(subprocess.check_output(
    ['supabase', 'projects', 'list', '-o', 'json'], text=True))
if isinstance(ps, dict) and 'projects' in ps:
    ps = ps['projects']
linked = [p for p in ps if p.get('linked')]
assert len(linked) == 1, linked
p = linked[0]
assert p['name'] == 'Cohort Staging', p['name']
ref = p.get('ref') or p.get('id') or ''
assert ref.startswith('tsbadngz'), ref
assert p.get('region') == 'eu-west-2', p.get('region')
assert p.get('status') == 'ACTIVE_HEALTHY', p.get('status')
prod = [x for x in ps if (x.get('ref') or x.get('id') or '').startswith('otnhhdxs')]
assert prod and not prod[0].get('linked'), 'production unexpectedly linked'
print('STAGING_IDENTITY_OK', ref[:8], p['region'], p['status'])
PY

# Preserve Athlete A/B before any mutation.
CONFIRM_COHORT_STAGING=1 supabase db query --linked -o json <<'SQL' > "$PRESERVE_OUT"
SELECT jsonb_build_object(
  'athlete_a', (
    SELECT jsonb_build_object(
      'id_prefix', left(id::text, 8),
      'athlete_prefix', left(athlete_id::text, 8),
      'status', status,
      'version', programme_version_id,
      'hash_prefix', left(coalesce(materialised_package_content_hash, ''), 12),
      'started_at', started_at,
      'materialised_at', materialised_at,
      'source', materialisation_source,
      'cursor', current_week_number || '/' || current_day_key || '/' || current_slot_order,
      'outcomes', (SELECT count(*) FROM programme_slot_outcomes o WHERE o.assignment_id = a.id),
      'records', (SELECT count(*) FROM training_session_records r WHERE r.assignment_id = a.id)
    )
    FROM programme_assignments a
    WHERE id = 'dcb723e3-f0b1-4606-85d7-b446813b38d2'
  ),
  'athlete_b_active', (
    SELECT count(*) FROM programme_assignments
    WHERE athlete_id = '1e268186-281a-464a-b2a4-da2d2cde33ba' AND status = 'active'
  ),
  's15a_exists', EXISTS(SELECT 1 FROM programme_lineages WHERE code = 'PROG-S15A-STAGING')
) AS snapshot;
SQL
python3 - <<PY
import json
from pathlib import Path
raw = json.loads(Path("$PRESERVE_OUT").read_text())
snap = raw["rows"][0]["snapshot"]
print("PRESERVE_A_B", json.dumps(snap))
if snap.get("s15a_exists"):
    raise SystemExit("REFUSED: PROG-S15A-STAGING already exists — refuse silent reuse")
assert snap["athlete_a"]["status"] == "active"
assert snap["athlete_a"]["outcomes"] == 0
assert snap["athlete_a"]["records"] == 0
assert snap["athlete_b_active"] == 1
print("PRESERVE_OK")
PY

# 1) Create Athlete C via Admin Auth API (service role outside Flutter).
python3 - <<PY
import json, secrets, string, urllib.request, urllib.error
from pathlib import Path

def load_env(path):
    env = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:]
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip("'").strip('"')
    return env

env = load_env("$API_ENV")
URL = env["S13_API_URL"].rstrip("/")
SERVICE = env["S13_SERVICE_KEY"]
ANON = env["S13_ANON_KEY"]
assert "tsbadngzgvsyfqjupkng" in URL
assert "service_role" not in ANON  # anon must not be service
assert SERVICE and ANON and URL

run = "s15a_stage_20260801T120000Z"
alphabet = string.ascii_letters + string.digits
password = "".join(secrets.choice(alphabet) for _ in range(28)) + "!1aA"
email = f"{run}.athlete.c@example.invalid"
display = "S15A Staging Athlete C"

def req(method, path, body=None, key=SERVICE, prefer=None):
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = raw
        return e.code, parsed

status, body = req("POST", "/auth/v1/admin/users", {
    "email": email,
    "password": password,
    "email_confirm": True,
    "user_metadata": {
        "display_name": display,
        "purpose": "s15a_staging_self_test_2",
        "label": "S15A-STAGING-FIXTURE",
        "run_id": run,
        "roles": ["athlete"],
    },
})
if status not in (200, 201):
    print("CREATE_USER_FAIL", status, type(body).__name__)
    raise SystemExit(2)
user_id = body["id"]

st, pb = req("POST", "/rest/v1/profiles", {
    "id": user_id,
    "display_name": display,
    "is_coach": False,
    "is_athlete": True,
}, prefer="return=representation")
if st not in (200, 201):
    st2, pb2 = req("PATCH", f"/rest/v1/profiles?id=eq.{user_id}", {
        "display_name": display,
        "is_coach": False,
        "is_athlete": True,
    })
    if st2 not in (200, 204) and st not in (200, 201):
        print("PROFILE_FAIL", st, st2)
        raise SystemExit(3)

# Prove password login works with anon (no service role in athlete path).
st, login = req("POST", "/auth/v1/token?grant_type=password", {
    "email": email,
    "password": password,
}, key=ANON)
if st != 200 or not isinstance(login, dict) or not login.get("access_token"):
    print("LOGIN_FAIL", st)
    raise SystemExit(4)
if login.get("user", {}).get("id") != user_id:
    print("LOGIN_UID_MISMATCH")
    raise SystemExit(5)

ids = {
    "run": run,
    "label_namespace": "S15A-STAGING-FIXTURE",
    "athlete_c_email": email,
    "athlete_c_name": display,
    "athlete_c_id": user_id,
    "lineage_code": "PROG-S15A-STAGING",
    "protocols": [
        "PROT-S15A-STAGING-1",
        "PROT-S15A-STAGING-2",
        "PROT-S15A-STAGING-3",
    ],
}
Path("$IDS_OUT").write_text(json.dumps(ids, indent=2))
creds = {
    "c": {"email": email, "password": password, "user_id": user_id},
}
# Merge A/B from existing temp creds when present (for isolation probes only).
legacy = Path("/tmp/s13b_athlete_creds.json")
if legacy.exists():
    old = json.loads(legacy.read_text())
    if "a" in old:
        creds["a"] = old["a"]
    if "b" in old:
        creds["b"] = old["b"]
Path("$CREDS_OUT").write_text(json.dumps(creds))
Path("$CREDS_OUT").chmod(0o600)
print("ATHLETE_C_CREATED", user_id[:8])
print("ATHLETE_C_LOGIN_OK")
PY

# 2) Protocols + steps + 3) import/publish/approve via linked SQL (service_role for package RPCs).
python3 - <<'PY' > /tmp/s15a_package_setup.sql
import hashlib, json, uuid
from pathlib import Path

ids = json.loads(Path("/tmp/s15a_ids.json").read_text())
ns = uuid.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")
lineages = {
    "PROT-S15A-STAGING-1": str(uuid.uuid5(ns, "s15a-session-lineage-1")),
    "PROT-S15A-STAGING-2": str(uuid.uuid5(ns, "s15a-session-lineage-2")),
    "PROT-S15A-STAGING-3": str(uuid.uuid5(ns, "s15a-session-lineage-3")),
}
pkg_hash = hashlib.sha256(b"PROG-S15A-STAGING-v1-three-slot").hexdigest()
ids["session_lineages"] = lineages
ids["package_hash"] = pkg_hash
Path("/tmp/s15a_ids.json").write_text(json.dumps(ids, indent=2))

sessions = []
for i, pid in enumerate(ids["protocols"], start=1):
    sessions.append({
        "session_key": f"SES-{i}",
        "protocol_id": pid,
        "session_lineage_id": lineages[pid],
        "revision_number": 1,
        "title": f"S15A Staging Session {i}",
    })

slots = []
for i, pid in enumerate(ids["protocols"], start=1):
    slots.append({
        "slot_key": f"W1D1S{i}",
        "session_order": i,
        "session_key": f"SES-{i}",
        "time_of_day": "any",
        "is_optional": False,
        "completion_expectation": "required",
        "display_title": f"Slot {i}",
        "coach_note": "S15A staging fixture slot",
        "progression": {
            "prescription_summary": "3x5 @ RPE 7",
            "volume_note": "Quality sets",
            "intensity_note": "Submaximal",
            "coach_note": "S15A staging fixture progression",
        },
    })

payload = {
    "package_schema_version": 1,
    "package_content_hash": pkg_hash,
    "imported_by": "s15a-staging-fixture",
    "programme": {
        "lineage_code": "PROG-S15A-STAGING",
        "version_number": 1,
        "name": "S15A Staging PROG-S15A-STAGING",
        "description": "Synthetic staging Self-Test 2 programme — not production content",
        "coaching_intent": "Verify completion and authored cursor advancement on Cohort Staging",
        "duration_weeks": 1,
        "sessions_per_week": 3,
        "primary_goal": "strength",
    },
    "sessions": sessions,
    "phases": [{
        "phase_key": "PH1",
        "phase_order": 1,
        "title": "Foundation",
        "intent": "build",
        "coach_note": "S15A staging fixture phase",
    }],
    "weeks": [{
        "week_number": 1,
        "phase_key": "PH1",
        "title": "Week 1",
        "intent": "build",
        "coach_note": "S15A staging fixture week",
        "days": [{
            "day_key": "day_1",
            "day_order": 1,
            "day_type": "training",
            "title": "Day 1",
            "intent": "build",
            "coach_note": "S15A staging fixture day",
            "slots": slots,
        }],
    }],
    # No adaptation configuration for Self-Test 2.
    "adaptation_permissions": [],
    "protected_invariants": [],
    "assessments": [],
    "performance_evidence_requirements": [],
    "comparison_identities": [],
}

payload_sql = json.dumps(payload).replace("'", "''")

lines = ["BEGIN;"]
for pid, lid in lineages.items():
    name = f"S15A Staging Session {pid[-1]}"
    lines.append(f"""
INSERT INTO session_lineages (id, display_name)
VALUES ('{lid}'::uuid, '{name}')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

INSERT INTO performance_protocols (
  protocol_id, name, published, content_kind, authoring_scope, endorsement_status,
  session_lineage_id, revision_number, lifecycle_status, published_at, owner_id
) VALUES (
  '{pid}', '{name}', 'true', 'session', 'cohort_global', 'cohort_endorsed',
  '{lid}'::uuid, 1, 'published', NOW(), NULL
)
ON CONFLICT (protocol_id) DO UPDATE SET
  name = EXCLUDED.name,
  published = 'true',
  content_kind = 'session',
  authoring_scope = 'cohort_global',
  endorsement_status = 'cohort_endorsed',
  session_lineage_id = EXCLUDED.session_lineage_id,
  revision_number = EXCLUDED.revision_number,
  lifecycle_status = 'published',
  published_at = NOW(),
  owner_id = NULL;

INSERT INTO protocol_steps (
  protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata
)
SELECT v.protocol_id, v.step_order, v.section, v.step_type, v.display_style, v.exercise_id, v.title, v.notes, v.metadata
FROM (VALUES
  ('{pid}', 1, 'Main', 'exercise', 'standard', 'EX-073', 'Back Squat', NULL,
   '{{"sets": "3", "reps": "5", "rest": "2 min", "load": "Working weight"}}'::jsonb)
) AS v(protocol_id, step_order, section, step_type, display_style, exercise_id, title, notes, metadata)
WHERE NOT EXISTS (
  SELECT 1 FROM protocol_steps s WHERE s.protocol_id = '{pid}'
);
""")

lines.append(f"""
SELECT set_config('role', 'service_role', true);
SELECT public.import_authored_plan_package('{payload_sql}'::jsonb) AS import_s15a;

DO $$
DECLARE
  v_version UUID;
  v_pub JSONB;
  v_appr JSONB;
BEGIN
  SELECT pv.id INTO v_version
  FROM programme_versions pv
  JOIN programme_lineages pl ON pl.id = pv.lineage_id
  WHERE pl.code = 'PROG-S15A-STAGING' AND pv.version_number = 1;
  IF v_version IS NULL THEN
    RAISE EXCEPTION 'S15A import missing version';
  END IF;
  v_pub := public.publish_cohort_global_programme_version(v_version, 's15a-staging-fixture');
  IF (v_pub->>'status') IN ('validation_failure','authorization_failure','failed') THEN
    RAISE EXCEPTION 'publish failed: %', v_pub;
  END IF;
  v_appr := public.approve_cohort_global_programme_version(v_version, 's15a-staging-fixture');
  IF (v_appr->>'status') IN ('validation_failure','authorization_failure','failed') THEN
    RAISE EXCEPTION 'approve failed: %', v_appr;
  END IF;
END $$;
SELECT set_config('role', 'postgres', true);
COMMIT;
""")
print("\n".join(lines))
PY

CONFIRM_COHORT_STAGING=1 supabase db query --linked -o json < /tmp/s15a_package_setup.sql > /tmp/s15a_package_setup_out.json
python3 - <<'PY'
import json
from pathlib import Path
raw = Path('/tmp/s15a_package_setup_out.json').read_text()
# tolerate CLI chatter
start = raw.find('{')
data = json.loads(raw[start:]) if start >= 0 else {}
print('PACKAGE_SQL_APPLIED', 'rows' in data or 'message' in data)
PY

# Capture version id + authored slot order.
CONFIRM_COHORT_STAGING=1 supabase db query --linked -o json <<'SQL' > /tmp/s15a_version_slots.json
SELECT jsonb_build_object(
  'version_id', (
    SELECT pv.id
    FROM programme_versions pv
    JOIN programme_lineages pl ON pl.id = pv.lineage_id
    WHERE pl.code = 'PROG-S15A-STAGING' AND pv.version_number = 1
  ),
  'hash', (
    SELECT pv.package_content_hash
    FROM programme_versions pv
    JOIN programme_lineages pl ON pl.id = pv.lineage_id
    WHERE pl.code = 'PROG-S15A-STAGING' AND pv.version_number = 1
  ),
  'lifecycle', (
    SELECT pv.lifecycle_status
    FROM programme_versions pv
    JOIN programme_lineages pl ON pl.id = pv.lineage_id
    WHERE pl.code = 'PROG-S15A-STAGING' AND pv.version_number = 1
  ),
  'approved', (
    SELECT pv.approved_for_global
    FROM programme_versions pv
    JOIN programme_lineages pl ON pl.id = pv.lineage_id
    WHERE pl.code = 'PROG-S15A-STAGING' AND pv.version_number = 1
  ),
  'slots', (
    SELECT jsonb_agg(jsonb_build_object(
      'week', w.week_number,
      'day_key', d.day_key,
      'day_order', d.day_order,
      'slot_order', s.session_order,
      'protocol_id', s.protocol_id,
      'slot_id', s.id
    ) ORDER BY w.week_number, d.day_order, s.session_order)
    FROM programme_versions pv
    JOIN programme_lineages pl ON pl.id = pv.lineage_id
    JOIN programme_version_weeks w ON w.version_id = pv.id
    JOIN programme_version_days d ON d.week_id = w.id
    JOIN programme_version_session_slots s ON s.day_id = d.id
    WHERE pl.code = 'PROG-S15A-STAGING' AND pv.version_number = 1
  ),
  'adaptations', (
    SELECT count(*)
    FROM programme_version_adaptation_permissions a
    JOIN programme_versions pv ON pv.id = a.version_id
    JOIN programme_lineages pl ON pl.id = pv.lineage_id
    WHERE pl.code = 'PROG-S15A-STAGING'
  ),
  'protocol_step_counts', (
    SELECT jsonb_object_agg(protocol_id, cnt)
    FROM (
      SELECT protocol_id, count(*)::int AS cnt
      FROM protocol_steps
      WHERE protocol_id LIKE 'PROT-S15A-STAGING-%'
      GROUP BY protocol_id
    ) t
  )
) AS info;
SQL
python3 - <<'PY'
import json
from pathlib import Path
raw = json.loads(Path('/tmp/s15a_version_slots.json').read_text())
info = raw['rows'][0]['info']
assert info['lifecycle'] == 'published', info
assert info['approved'] is True, info
assert info['adaptations'] == 0, info
slots = info['slots']
assert len(slots) == 3, slots
assert [s['slot_order'] for s in slots] == [1, 2, 3], slots
assert [s['protocol_id'] for s in slots] == [
    'PROT-S15A-STAGING-1', 'PROT-S15A-STAGING-2', 'PROT-S15A-STAGING-3'
], slots
assert all(info['protocol_step_counts'].get(p, 0) >= 1 for p in [
    'PROT-S15A-STAGING-1', 'PROT-S15A-STAGING-2', 'PROT-S15A-STAGING-3'
]), info['protocol_step_counts']
ids = json.loads(Path('/tmp/s15a_ids.json').read_text())
assert info['hash'] == ids['package_hash']
ids['version_id'] = info['version_id']
ids['slots'] = slots
Path('/tmp/s15a_ids.json').write_text(json.dumps(ids, indent=2))
print('PACKAGE_PUBLISHED', info['version_id'][:8], 'slots', len(slots), 'hash_len', len(info['hash']))
PY

# 4) Enrol + materialise as Athlete C through authenticated product RPCs.
python3 - <<'PY'
import json, urllib.request, urllib.error
from pathlib import Path

def load_env(path):
    env = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:]
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip("'").strip('"')
    return env

env = load_env("/tmp/s13b_api.env")
URL = env["S13_API_URL"].rstrip("/")
ANON = env["S13_ANON_KEY"]
creds = json.loads(Path("/tmp/s15a_athlete_creds.json").read_text())["c"]
ids = json.loads(Path("/tmp/s15a_ids.json").read_text())

def req(method, path, body=None, token=None):
    headers = {
        "apikey": ANON,
        "Authorization": f"Bearer {token or ANON}",
        "Content-Type": "application/json",
    }
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = raw
        return e.code, parsed

st, login = req("POST", "/auth/v1/token?grant_type=password", {
    "email": creds["email"],
    "password": creds["password"],
})
assert st == 200 and login and login.get("access_token"), st
token = login["access_token"]
assert login["user"]["id"] == ids["athlete_c_id"]

st, enrol = req("POST", "/rest/v1/rpc/enrol_athlete_in_catalogue_programme_version", {
    "p_programme_version_id": ids["version_id"],
    "p_timezone": "UTC",
    "p_replace_active": False,
}, token=token)
print("ENROL_STATUS", st, enrol.get("status") if isinstance(enrol, dict) else type(enrol).__name__)
assert st == 200 and isinstance(enrol, dict), enrol
assert enrol.get("status") in ("enrolled", "already_enrolled"), enrol
assignment_id = enrol.get("enrolment_id") or enrol.get("assignment_id")
assert assignment_id
ids["assignment_id"] = assignment_id

st, mat = req("POST", "/rest/v1/rpc/materialise_athlete_plan_from_enrolment", {
    "p_programme_assignment_id": assignment_id,
    "p_timezone": "UTC",
}, token=token)
print("MATERIALISE_STATUS", st, mat.get("status") if isinstance(mat, dict) else type(mat).__name__)
assert st == 200 and isinstance(mat, dict), mat
assert mat.get("status") in ("materialised", "already_materialised"), mat
Path("/tmp/s15a_ids.json").write_text(json.dumps(ids, indent=2))
print("LIFECYCLE_OK", assignment_id[:8])
PY

# 5) Fixture validation gate (pre-migration: next slot from package query only).
python3 - <<'PY' > /tmp/s15a_fixture_gate.sql
import json
from pathlib import Path
ids = json.loads(Path('/tmp/s15a_ids.json').read_text())
preserve = json.loads(Path('/tmp/s15a_preserve_ab_before.json').read_text())['rows'][0]['snapshot']
aid = ids['assignment_id']
cid = ids['athlete_c_id']
vid = ids['version_id']
h = ids['package_hash']
a0 = preserve['athlete_a']
print(f"""
SELECT jsonb_build_object(
  'athlete_c_owns', EXISTS(
    SELECT 1 FROM programme_assignments
    WHERE id = '{aid}'::uuid AND athlete_id = '{cid}'::uuid
  ),
  'assignment', (
    SELECT jsonb_build_object(
      'id_prefix', left(id::text, 8),
      'status', status,
      'version', programme_version_id,
      'hash', materialised_package_content_hash,
      'started_at', started_at,
      'materialised_at', materialised_at,
      'source', materialisation_source,
      'week', current_week_number,
      'day_key', current_day_key,
      'slot_order', current_slot_order
    ) FROM programme_assignments WHERE id = '{aid}'::uuid
  ),
  'hash_match', EXISTS(
    SELECT 1 FROM programme_assignments a
    JOIN programme_versions v ON v.id = a.programme_version_id
    WHERE a.id = '{aid}'::uuid
      AND a.programme_version_id = '{vid}'::uuid
      AND a.materialised_package_content_hash = '{h}'
      AND v.package_content_hash = '{h}'
  ),
  'executable_slots', (
    SELECT jsonb_agg(jsonb_build_object(
      'week', w.week_number,
      'day_key', d.day_key,
      'day_order', d.day_order,
      'slot_order', s.session_order,
      'protocol_id', s.protocol_id
    ) ORDER BY w.week_number, d.day_order, s.session_order)
    FROM programme_version_weeks w
    JOIN programme_version_days d ON d.week_id = w.id
    JOIN programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = '{vid}'::uuid
      AND COALESCE(d.day_type, '') <> 'rest'
      AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
  ),
  'current_protocol', (
    SELECT s.protocol_id
    FROM programme_assignments a
    JOIN programme_version_weeks w ON w.version_id = a.programme_version_id
      AND w.week_number = a.current_week_number
    JOIN programme_version_days d ON d.week_id = w.id
      AND d.day_key = a.current_day_key
    JOIN programme_version_session_slots s ON s.day_id = d.id
      AND s.session_order = a.current_slot_order
    WHERE a.id = '{aid}'::uuid
  ),
  'next_slot', (
    SELECT jsonb_build_object(
      'week', n.week_number,
      'day_key', n.day_key,
      'slot_order', n.session_order,
      'protocol_id', n.protocol_id
    )
    FROM programme_assignments a
    JOIN LATERAL (
      SELECT w.week_number, d.day_key, d.day_order, s.session_order, s.protocol_id
      FROM programme_version_weeks w
      JOIN programme_version_days d ON d.week_id = w.id
      JOIN programme_version_session_slots s ON s.day_id = d.id
      JOIN programme_version_weeks cw ON cw.version_id = a.programme_version_id
        AND cw.week_number = a.current_week_number
      JOIN programme_version_days cd ON cd.week_id = cw.id
        AND cd.day_key = a.current_day_key
      WHERE w.version_id = a.programme_version_id
        AND COALESCE(d.day_type, '') <> 'rest'
        AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
        AND (
          w.week_number > a.current_week_number
          OR (w.week_number = a.current_week_number AND d.day_order > cd.day_order)
          OR (
            w.week_number = a.current_week_number
            AND d.day_order = cd.day_order
            AND s.session_order > a.current_slot_order
          )
        )
      ORDER BY w.week_number, d.day_order, s.session_order
      LIMIT 1
    ) n ON TRUE
    WHERE a.id = '{aid}'::uuid
  ),
  'outcomes', (SELECT count(*) FROM programme_slot_outcomes WHERE assignment_id = '{aid}'::uuid),
  'records', (SELECT count(*) FROM training_session_records WHERE assignment_id = '{aid}'::uuid),
  'adaptations_on_version', (
    SELECT count(*) FROM programme_version_adaptation_permissions WHERE version_id = '{vid}'::uuid
  ),
  'athlete_a_unchanged', (
    SELECT jsonb_build_object(
      'same_status', a.status = '{a0["status"]}',
      'same_version', a.programme_version_id::text = '{a0["version"]}',
      'same_hash_prefix', left(coalesce(a.materialised_package_content_hash,''),12) = '{a0["hash_prefix"]}',
      'same_started_at', a.started_at::text = '{a0["started_at"]}',
      'same_materialised_at', a.materialised_at IS NOT DISTINCT FROM '{a0["materialised_at"]}'::timestamptz,
      'same_source', a.materialisation_source = '{a0["source"]}',
      'same_cursor', (a.current_week_number||'/'||a.current_day_key||'/'||a.current_slot_order) = '{a0["cursor"]}',
      'outcomes', (SELECT count(*) FROM programme_slot_outcomes o WHERE o.assignment_id = a.id),
      'records', (SELECT count(*) FROM training_session_records r WHERE r.assignment_id = a.id)
    )
    FROM programme_assignments a
    WHERE a.id = 'dcb723e3-f0b1-4606-85d7-b446813b38d2'
  ),
  'athlete_b_active', (
    SELECT count(*) FROM programme_assignments
    WHERE athlete_id = '1e268186-281a-464a-b2a4-da2d2cde33ba' AND status = 'active'
  ),
  'commercial_absent', to_regclass('public.subscriptions') IS NULL
) AS gate;
""")
PY

CONFIRM_COHORT_STAGING=1 supabase db query --linked -o json < /tmp/s15a_fixture_gate.sql > "$GATE_OUT"
python3 - <<PY
import json
from pathlib import Path
raw = json.loads(Path("$GATE_OUT").read_text())
gate = raw["rows"][0]["gate"]
Path("$GATE_OUT").write_text(json.dumps(gate, indent=2))
print(json.dumps(gate, indent=2))
assert gate["athlete_c_owns"] is True
a = gate["assignment"]
assert a["status"] == "active"
assert a["source"] == "athlete_start_programme"
assert a["started_at"] is not None
assert a["materialised_at"] is not None
assert a["week"] == 1 and a["day_key"] == "day_1" and a["slot_order"] == 1
assert gate["hash_match"] is True
slots = gate["executable_slots"]
assert len(slots) >= 2
assert gate["current_protocol"] == "PROT-S15A-STAGING-1"
assert gate["next_slot"] is not None, "terminal fixture — refuse"
assert gate["next_slot"]["slot_order"] == 2
assert gate["next_slot"]["protocol_id"] == "PROT-S15A-STAGING-2"
assert gate["outcomes"] == 0
assert gate["records"] == 0
assert gate["adaptations_on_version"] == 0
au = gate["athlete_a_unchanged"]
assert all(au[k] is True for k in [
    "same_status","same_version","same_hash_prefix","same_started_at",
    "same_materialised_at","same_source","same_cursor"
]), au
assert au["outcomes"] == 0 and au["records"] == 0
assert gate["athlete_b_active"] == 1
assert gate["commercial_absent"] is True
print("FIXTURE_GATE_PASSED")
PY

echo "S15A_SELF_TEST_2_FIXTURE_READY"
