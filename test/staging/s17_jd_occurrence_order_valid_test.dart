import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regresses occurrence_order_valid=false when Prefer count used Range:0-0.
///
/// Exact hosted shape: Content-Range total=2 but body truncated to one row.
/// Persisted ensure evidence already proved CURRENT/day_1 before LATER/day_2.
void main() {
  final root = Directory.current.path;
  const marker = 's17_jd_adapt_20260808T065203Z_cbe6b6cf';
  const athleteId = '9404925f-1111-4111-8111-111111111111';
  const lineageId = 'aaaaaaaa-1111-4111-8111-111111111111';
  const versionId = 'd060803c-2222-4222-8222-222222222222';
  const assignmentId = 'd7535200-3333-4333-8333-333333333333';

  test('Range 0-0 count probe must not decide occurrence_order_valid', () async {
    final r = await Process.run('python3', [
      '-c',
      '''
import json, os, sys
from pathlib import Path
root = Path(${jsonEncode(root)})
sys.path.insert(0, str(root / "tool/staging/lib"))
os.environ["CONFIRM_COHORT_STAGING"] = "1"
os.environ["S17_JD_HOSTED_READONLY"] = "1"
from s17_journey_d_hosted_readonly import (
    ReadOnlyHttpClient,
    journey_d_occurrence_order_valid,
    run_hosted_readonly,
)

# Pure contract on ensure-observed shape (reversed array still valid).
ensure_shape = [
    {
        "protocol_id": "PROT-S17-JD-ADAPT-LATER",
        "week_number": 1,
        "day_key": "day_2",
        "session_order": 1,
    },
    {
        "protocol_id": "PROT-S17-JD-ADAPT-CURRENT",
        "week_number": 1,
        "day_key": "day_1",
        "session_order": 1,
    },
]
assert journey_d_occurrence_order_valid(ensure_shape) is True

reversed_days = [
    {
        "protocol_id": "PROT-S17-JD-ADAPT-CURRENT",
        "week_number": 1,
        "day_key": "day_2",
        "session_order": 1,
    },
    {
        "protocol_id": "PROT-S17-JD-ADAPT-LATER",
        "week_number": 1,
        "day_key": "day_1",
        "session_order": 1,
    },
]
assert journey_d_occurrence_order_valid(reversed_days) is False

# Hosted Range:0-0 defect: count=2, body only first row → previously false.
seen_ranges = []
def fake(path, headers):
    if path.startswith("/auth/v1/admin/users/"):
        return 200, json.dumps({
            "id": "$athleteId",
            "email": "s17_jd_adapt_20260808t065203z_cbe6b6cf.athlete.jd@example.invalid",
            "user_metadata": {"run_id": "$marker"},
        }), {}
    if path.startswith("/auth/v1/admin/users"):
        return 200, json.dumps({"users":[{
            "id": "$athleteId",
            "email": "s17_jd_adapt_20260808t065203z_cbe6b6cf.athlete.jd@example.invalid",
            "user_metadata": {"run_id": "$marker"},
        }]}), {}
    if path.startswith("/rest/v1/profiles"):
        return 200, json.dumps([{"id": "$athleteId", "display_name": "x"}]), {"content-range": "0-0/1"}
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
        return 200, json.dumps([{"id": "$lineageId", "code": "PROG-S17-JD-ADAPT"}]), {"content-range": "0-0/1"}
    if path.startswith("/rest/v1/programme_versions"):
        return 200, json.dumps([{
            "id": "$versionId",
            "version_number": 1,
            "lifecycle_status": "published",
            "approved_for_global": True,
        }]), {"content-range": "0-0/1"}
    if path.startswith("/rest/v1/programme_assignments"):
        return 200, json.dumps([{
            "id": "$assignmentId",
            "programme_version_id": "$versionId",
            "athlete_id": "$athleteId",
        }]), {"content-range": "0-0/1"}
    if path.startswith("/rest/v1/programme_schedule_occurrences"):
        seen_ranges.append(headers.get("Range") or headers.get("range"))
        assert "order=" in path, path
        # Exact prior defect: Range 0-0 + Content-Range */2 + single-row body.
        if (headers.get("Range") or headers.get("range")) == "0-0":
            return 206, json.dumps([{
                "id": "o1",
                "protocol_id": "PROT-S17-JD-ADAPT-CURRENT",
                "week_number": 1,
                "day_key": "day_1",
                "session_order": 1,
                "programmed_session_key": "prog:x",
            }]), {"content-range": "0-0/2"}
        # Repaired fetch: Range 0-1 returns both authored rows (array order reversed).
        assert (headers.get("Range") or headers.get("range")) == "0-1", headers
        return 206, json.dumps([
            {
                "id": "o2",
                "protocol_id": "PROT-S17-JD-ADAPT-LATER",
                "week_number": 1,
                "day_key": "day_2",
                "session_order": 1,
                "programmed_session_key": "prog:y",
            },
            {
                "id": "o1",
                "protocol_id": "PROT-S17-JD-ADAPT-CURRENT",
                "week_number": 1,
                "day_key": "day_1",
                "session_order": 1,
                "programmed_session_key": "prog:x",
            },
        ]), {"content-range": "0-1/2"}
    return 200, "[]", {"content-range": "*/0"}

projects = Path(root / "test/staging/fixtures/s17_projects_list.json").read_text()
api = Path("/tmp/s17_jd_occurrence_order.env")
api.write_text(
    "S13_API_URL=https://tsbadngzgvsyfqjupkng.supabase.co\\n"
    "S13_ANON_KEY=anon\\nS13_SERVICE_KEY=service\\n"
)
client = ReadOnlyHttpClient(base_url="https://example.test", api_key="service", get_impl=fake)
result = run_hosted_readonly(
    root=root,
    projects_raw=projects,
    marker="$marker",
    api_env_path=api,
    client=client,
)
assert result["occurrence_count"] == 2, result
assert result["occurrence_order_valid"] is True, result
assert result["fixture_state"] == "complete", result
assert result["fixture_eligible"] is True, result
assert "0-1" in seen_ranges, seen_ranges
assert "0-0" not in seen_ranges, seen_ranges
print("OCCURRENCE_ORDER_VALID_REPAIR_OK")
'''
    ], workingDirectory: root);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout.toString(), contains('OCCURRENCE_ORDER_VALID_REPAIR_OK'));
  });

  test('source uses widened occurrence Range and day ordinal helper', () {
    final src = File(
      '$root/tool/staging/lib/s17_journey_d_hosted_readonly.py',
    ).readAsStringSync();
    expect(src, contains('journey_d_occurrence_order_valid'));
    expect(src, contains('range_header="0-1"'));
    expect(src, contains('day_1'));
    expect(src, contains('day_2'));
  });
}
