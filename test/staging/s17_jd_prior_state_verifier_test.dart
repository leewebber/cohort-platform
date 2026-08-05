import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Local-only prior-state verifier resolution acceptance.
///
/// Uses injected get_impl / snapshots only (no external network).
void main() {
  final root = Directory.current.path;
  final projects = '$root/test/staging/fixtures/s17_projects_list.json';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';

  Future<ProcessResult> runPy(String code) {
    return Process.run('python3', ['-c', code], workingDirectory: root);
  }

  test('protocol lookup classification + fail-closed absence proofs', () async {
    final r = await runPy('''
import json, os, sys
from pathlib import Path

sys.path.insert(0, r"$root/tool/staging/lib")
os.environ["CONFIRM_COHORT_STAGING"] = "1"
os.environ["S17_JD_HOSTED_READONLY"] = "1"

from s17_journey_d_hosted_readonly import (
    CURRENT_PROTOCOL_ID,
    LATER_PROTOCOL_ID,
    ReadOnlyHttpClient,
    classify_counted_rest_lookup,
    run_hosted_readonly,
)

root = Path(r"$root")
projects = Path(r"$projects").read_text()
api = Path("/tmp/s17_jd_prior_state_api.env")
# Staging-shaped host required by target guard; get_impl never dials network.
api.write_text(
    "S13_API_URL=https://tsbadngzgvsyfqjupkng.supabase.co\\n"
    "S13_ANON_KEY=test_anon\\n"
    "S13_SERVICE_KEY=test_service\\n"
)
marker = "$stableMarker"
base = "https://tsbadngzgvsyfqjupkng.supabase.co"

# --- unit classify ---
absent = classify_counted_rest_lookup(
    status=206, body="[]", headers={"content-range": "*/0"}, visibility_proven=True,
)
assert absent["state"] == "absent", absent
present = classify_counted_rest_lookup(
    status=200,
    body=json.dumps([{"protocol_id": CURRENT_PROTOCOL_ID}]),
    headers={"content-range": "0-0/1"},
    visibility_proven=True,
)
assert present["state"] == "present", present
dup = classify_counted_rest_lookup(
    status=200,
    body=json.dumps([{"protocol_id": "a"}, {"protocol_id": "b"}]),
    headers={"content-range": "0-0/2"},
    visibility_proven=True,
)
assert dup["state"] == "duplicated", dup
assert classify_counted_rest_lookup(
    status=403, body="{}", headers={}, visibility_proven=True,
)["state"] == "visibility_unproven"
assert classify_counted_rest_lookup(
    status=400, body='{"message":"column status does not exist"}', headers={},
    visibility_proven=True,
)["state"] == "lookup_failed"
assert classify_counted_rest_lookup(
    status=200, body="{not-json", headers={"content-range": "*/0"},
    visibility_proven=True,
)["state"] == "uncertain"
assert classify_counted_rest_lookup(
    status=200, body="[]", headers={}, visibility_proven=True,
)["state"] == "uncertain"
assert classify_counted_rest_lookup(
    status=200, body="[]", headers={"content-range": "*/0"},
    visibility_proven=False,
)["state"] == "visibility_unproven"
assert classify_counted_rest_lookup(
    status=503, body="{}", headers={}, visibility_proven=True,
)["state"] == "lookup_failed"

def empty_world(path, headers):
    # Legacy bad select must remain a hard failure in this harness.
    q = path.split("?", 1)[-1] if "?" in path else ""
    if "performance_protocols" in path:
        sel = ""
        for part in q.split("&"):
            if part.startswith("select="):
                sel = part[len("select="):]
        if "status" in sel.split(",") or sel.startswith("id,") or ",id," in f",{sel},":
            return 400, '{"message":"column does not exist"}', {}
        return 206, "[]", {"content-range": "*/0"}
    if path.startswith("/auth/v1/admin/users"):
        return 200, '{"users":[]}', {}
    return 200, "[]", {"content-range": "*/0"}

seen_paths = []
def empty_world_tracked(path, headers):
    seen_paths.append(path)
    return empty_world(path, headers)

client = ReadOnlyHttpClient(base_url=base, api_key="test_service", get_impl=empty_world_tracked)
result = run_hosted_readonly(
    root=root, projects_raw=projects, marker=marker, api_env_path=api, client=client,
)
assert result["fixture_state"] == "absent", result
assert result["fixture_objects_found"] == 0, result
assert result["all_required_lookups"] == "verified", result
assert result["current_protocol_lookup"] == "absent", result
assert result["later_protocol_lookup"] == "absent", result
assert result["visibility_proven"] is True
# GoTrue admin listUsers requires filter=; email= is ignored.
auth_paths = [p for p in seen_paths if p.startswith("/auth/v1/admin/users")]
assert auth_paths, seen_paths
auth_q = auth_paths[0].split("?", 1)[-1]
parts = auth_q.split("&")
assert any(part.startswith("filter=") for part in parts), auth_paths[0]
assert not any(part.startswith("email=") for part in parts), auth_paths[0]
blob = json.dumps(result)
assert "test_service" not in blob
assert "password" not in blob.lower()
assert "S13_SERVICE_KEY" not in blob
assert "Bearer " not in blob
assert "…" in result.get("email_redacted", "")
# Full synthetic email local-part (marker + athlete suffix) must not appear.
assert f"{marker}.athlete" not in blob
for c in result.get("http_calls") or []:
    assert "path" not in c
    assert "@" not in json.dumps(c)

def present_current(path, headers):
    if "PROT-S17-JD-ADAPT-CURRENT" in path:
        return 200, json.dumps([{
            "protocol_id": CURRENT_PROTOCOL_ID,
            "session_lineage_id": "11111111-1111-1111-1111-111111111111",
            "revision_number": 1,
            "lifecycle_status": "published",
        }]), {"content-range": "0-0/1"}
    return empty_world(path, headers)

present_r = run_hosted_readonly(
    root=root, projects_raw=projects, marker=marker, api_env_path=api,
    client=ReadOnlyHttpClient(base_url=base, api_key="s", get_impl=present_current),
)
assert present_r["fixture_state"] != "absent", present_r
assert present_r["current_protocol_lookup"] == "present", present_r
assert present_r["fixture_objects_found"] >= 1

def dup_current(path, headers):
    if "PROT-S17-JD-ADAPT-CURRENT" in path:
        return 200, "[]", {"content-range": "0-0/2"}
    return empty_world(path, headers)

dup_r = run_hosted_readonly(
    root=root, projects_raw=projects, marker=marker, api_env_path=api,
    client=ReadOnlyHttpClient(base_url=base, api_key="s", get_impl=dup_current),
)
assert dup_r["current_protocol_lookup"] == "duplicated", dup_r
assert dup_r["duplicates_found"] is True
assert dup_r["fixture_state"] == "duplicated", dup_r

def fail_later(path, headers):
    if "PROT-S17-JD-ADAPT-LATER" in path:
        return 503, '{"ok":false}', {}
    return empty_world(path, headers)

failed = run_hosted_readonly(
    root=root, projects_raw=projects, marker=marker, api_env_path=api,
    client=ReadOnlyHttpClient(base_url=base, api_key="s", get_impl=fail_later),
)
assert failed["fixture_state"] == "uncertain", failed
assert failed["later_protocol_lookup"] == "lookup_failed", failed
assert failed["all_required_lookups"] == "unverified"

def forbid(path, headers):
    if "performance_protocols" in path:
        return 403, "{}", {}
    return empty_world(path, headers)

forb = run_hosted_readonly(
    root=root, projects_raw=projects, marker=marker, api_env_path=api,
    client=ReadOnlyHttpClient(base_url=base, api_key="s", get_impl=forbid),
)
assert forb["fixture_state"] == "uncertain", forb
assert forb["current_protocol_lookup"] == "visibility_unproven", forb

# Production refused before client use
try:
    bad = Path("/tmp/s17_jd_prior_state_prod.env")
    bad.write_text(
        "S13_API_URL=https://otnhhdxsXXXX.supabase.co\\n"
        "S13_ANON_KEY=x\\nS13_SERVICE_KEY=y\\n"
    )
    run_hosted_readonly(
        root=root, projects_raw=projects, marker=marker, api_env_path=bad,
        fixture_snapshot={},
    )
    raise SystemExit("production allowed")
except Exception as e:
    assert "production" in str(e).lower() or "REFUSED" in str(e)

# Marker mismatch fails before network
try:
    run_hosted_readonly(
        root=root, projects_raw=projects, marker="not-a-valid-marker",
        api_env_path=api, fixture_snapshot={},
    )
    raise SystemExit("bad marker allowed")
except Exception as e:
    assert "REFUSED" in str(e) or "marker" in str(e).lower()

# Fake snapshot path makes no network contact
net = {"hits": 0}
def boom(path, headers):
    net["hits"] += 1
    raise AssertionError("network")
snap_r = run_hosted_readonly(
    root=root, projects_raw=projects, marker=marker, api_env_path=api,
    client=ReadOnlyHttpClient(base_url=base, api_key="s", get_impl=boom),
    fixture_snapshot={},
)
assert snap_r["fixture_state"] == "absent", snap_r
assert net["hits"] == 0
assert snap_r["current_protocol_lookup"] == "absent"
assert snap_r["later_protocol_lookup"] == "absent"

# Ambiguous projects list refused
try:
    bad_projects = json.dumps([
        {"name":"Cohort Staging","ref":"tsbadngzgvsyfqjupkng","region":"eu-west-2","status":"ACTIVE_HEALTHY"},
        {"name":"Cohort Staging","ref":"tsbadngzAAAAAAAAAAAAAAAA","region":"eu-west-2","status":"ACTIVE_HEALTHY"},
    ])
    run_hosted_readonly(
        root=root, projects_raw=bad_projects, marker=marker, api_env_path=api,
        fixture_snapshot={},
    )
    raise SystemExit("ambiguous allowed")
except Exception as e:
    assert "REFUSED" in str(e) or "ambiguous" in str(e).lower() or "staging" in str(e).lower()

print("PRIOR_STATE_VERIFIER_OK")
''');
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout.toString(), contains('PRIOR_STATE_VERIFIER_OK'));
  });

  test('legacy bad select columns are not used by committed verifier', () {
    final src = File(
      '$root/tool/staging/lib/s17_journey_d_hosted_readonly.py',
    ).readAsStringSync();
    expect(src, contains('lifecycle_status'));
    expect(src, contains('_PROTOCOL_SELECT'));
    expect(src, isNot(contains('revision_number,status')));
    expect(src, contains('classify_counted_rest_lookup'));
    expect(src, contains('visibility_unproven'));
  });
}
