import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Eligibility verifier must query the same canonical IDs/columns the creator
/// persists. Local fake-HTTP only — no hosted contact.
void main() {
  final root = Directory.current.path;
  const marker = 's17_jd_adapt_20260808T065203Z_cbe6b6cf';
  const athleteId = '9404925f-1111-4111-8111-111111111111';
  const lineageId = 'aaaaaaaa-1111-4111-8111-111111111111';
  const versionId = 'd060803c-2222-4222-8222-222222222222';
  const assignmentId = 'd7535200-3333-4333-8333-333333333333';

  test('verifier uses lineage_id/lifecycle_status and normalized Auth email',
      () async {
    final r = await Process.run('python3', [
      '-c',
      '''
import json, os, sys
from pathlib import Path
root = Path(${jsonEncode(root)})
sys.path.insert(0, str(root / "tool/staging/lib"))
os.environ["CONFIRM_COHORT_STAGING"] = "1"
os.environ["S17_JD_HOSTED_READONLY"] = "1"
from s17_journey_d_fixture import jd_fixture_email, jd_normalized_fixture_email
from s17_journey_d_hosted_readonly import ReadOnlyHttpClient, run_hosted_readonly

marker = "$marker"
athlete_id = "$athleteId"
lineage_id = "$lineageId"
version_id = "$versionId"
assignment_id = "$assignmentId"
mixed = jd_fixture_email(marker)
normalized = jd_normalized_fixture_email(marker)
assert mixed != normalized  # T/Z case differs
assert normalized == mixed.lower()

seen = []
def fake(path, headers):
    seen.append(path)
    if path.startswith("/auth/v1/admin/users/"):
        # Exact user fetch for metadata after list filter.
        return 200, json.dumps({
            "id": athlete_id,
            "email": normalized,
            "user_metadata": {"run_id": marker},
        }), {}
    if path.startswith("/auth/v1/admin/users"):
        assert "filter=" in path
        assert not any(p.startswith("email=") for p in path.split("?",1)[-1].split("&"))
        return 200, json.dumps({"users":[{"id": athlete_id, "email": normalized, "user_metadata": {"run_id": marker}}]}), {}
    if path.startswith("/rest/v1/profiles"):
        assert f"id=eq.{athlete_id}" in path
        return 200, json.dumps([{"id": athlete_id, "display_name": "x"}]), {"content-range": "0-0/1"}
    if "PROT-S17-JD-ADAPT-CURRENT" in path:
        return 200, json.dumps([{
            "protocol_id": "PROT-S17-JD-ADAPT-CURRENT",
            "session_lineage_id": "11111111-1111-4111-8111-111111111111",
            "revision_number": 1,
            "lifecycle_status": "published",
        }]), {"content-range": "0-0/1"}
    if "PROT-S17-JD-ADAPT-LATER" in path:
        return 200, json.dumps([{
            "protocol_id": "PROT-S17-JD-ADAPT-LATER",
            "session_lineage_id": "22222222-2222-4222-8222-222222222222",
            "revision_number": 1,
            "lifecycle_status": "published",
        }]), {"content-range": "0-0/1"}
    if path.startswith("/rest/v1/programme_lineages"):
        return 200, json.dumps([{"id": lineage_id, "code": "PROG-S17-JD-ADAPT"}]), {"content-range": "0-0/1"}
    if path.startswith("/rest/v1/programme_versions"):
        # Exact creator-aligned filter keys.
        assert "lineage_id=eq." in path, path
        assert "programme_lineage_id=" not in path, path
        assert "lifecycle_status" in path, path
        assert "lifecycle_state" not in path, path
        assert "version_number=eq.1" in path, path
        return 200, json.dumps([{
            "id": version_id,
            "version_number": 1,
            "lifecycle_status": "published",
            "approved_for_global": True,
        }]), {"content-range": "0-0/1"}
    if path.startswith("/rest/v1/programme_assignments"):
        assert f"athlete_id=eq.{athlete_id}" in path
        assert f"programme_version_id=eq.{version_id}" in path
        return 200, json.dumps([{
            "id": assignment_id,
            "programme_version_id": version_id,
            "athlete_id": athlete_id,
        }]), {"content-range": "0-0/1"}
    if path.startswith("/rest/v1/programme_schedule_occurrences"):
        assert "assignment_id=eq." in path, path
        assert "programme_assignment_id=" not in path, path
        assert "protocol_id" in path, path
        assert "order=" in path, path
        assert (headers.get("Range") or headers.get("range")) == "0-1", headers
        # Forbid legacy select columns (allow programmed_session_key).
        assert "select=id,session_key,sequence" not in path
        assert "&sequence=" not in path
        return 200, json.dumps([
            {
                "id": "o1",
                "protocol_id": "PROT-S17-JD-ADAPT-CURRENT",
                "week_number": 1,
                "day_key": "day_1",
                "session_order": 1,
                "programmed_session_key": "prog:x",
            },
            {
                "id": "o2",
                "protocol_id": "PROT-S17-JD-ADAPT-LATER",
                "week_number": 1,
                "day_key": "day_2",
                "session_order": 1,
                "programmed_session_key": "prog:y",
            },
        ]), {"content-range": "0-1/2"}
    if "session_adaptation_proposals" in path:
        return 200, "[]", {"content-range": "*/0"}
    return 200, "[]", {"content-range": "*/0"}

projects = Path(root / "test/staging/fixtures/s17_projects_list.json").read_text()
api = Path("/tmp/s17_jd_elig_lookup_repair.env")
api.write_text(
    "S13_API_URL=https://tsbadngzgvsyfqjupkng.supabase.co\\n"
    "S13_ANON_KEY=anon\\nS13_SERVICE_KEY=service\\n"
)
client = ReadOnlyHttpClient(base_url="https://example.test", api_key="service", get_impl=fake)
result = run_hosted_readonly(
    root=root,
    projects_raw=projects,
    marker=marker,
    api_env_path=api,
    client=client,
)
assert result["identity_count"] == 1, result
assert result["profile_count"] == 1, result
assert result["programme_count"] == 1, result
assert result["programme_version_count"] == 1, result
assert result["assignment_count"] == 1, result
assert result["occurrence_count"] == 2, result
assert result["occurrence_order_valid"] is True, result
assert result["fixture_state"] == "complete", result
assert result["fixture_eligible"] is True, result
assert result["all_required_lookups"] == "verified", result
assert "programme_version_lookup" not in (result.get("unverified_claims") or [])
# Public result redacts IDs; prove verifier queried creator canonical keys.
joined = "\\n".join(seen)
assert f"lineage_id=eq.{lineage_id}" in joined
assert f"athlete_id=eq.{athlete_id}" in joined
assert f"programme_version_id=eq.{version_id}" in joined
assert f"assignment_id=eq.{assignment_id}" in joined
assert "programme_lineage_id=" not in joined
assert "programme_assignment_id=" not in joined
assert "lifecycle_state" not in joined
assert result.get("user_id_redacted")
assert result.get("assignment_id_redacted")
print("ELIGIBILITY_LOOKUP_REPAIR_OK")
print("CANONICAL_IDS_MATCH=true")
''',
    ], workingDirectory: root);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout.toString(), contains('ELIGIBILITY_LOOKUP_REPAIR_OK'));
    expect(r.stdout.toString(), contains('CANONICAL_IDS_MATCH=true'));
  });

  test('poisoned legacy version filter is refused by schema contract proof',
      () async {
    final src = File(
      '$root/tool/staging/lib/s17_journey_d_hosted_readonly.py',
    ).readAsStringSync();
    expect(src, contains('lineage_id=eq.'));
    expect(src, contains('lifecycle_status'));
    expect(src, contains('assignment_id=eq.'));
    expect(src, contains('jd_normalized_fixture_email'));
    expect(src, isNot(contains('programme_lineage_id=eq.')));
    expect(src, isNot(contains('programme_assignment_id=eq.')));
    expect(src, isNot(contains('select=id,version_number,status,lifecycle_state')));
    final exec = File(
      '$root/lib/staging_tooling/journey_d/journey_d_hosted_execute_ports.dart',
    ).readAsStringSync();
    expect(exec, contains('journeyDNormalizedFixtureEmail(marker)'));
    expect(exec, contains('assignment_id=eq.'));
    expect(exec, contains('protocol_id'));
    expect(exec, isNot(contains('programme_assignment_id=eq.')));
    expect(exec, isNot(contains('session_key,sequence')));
  });
}
