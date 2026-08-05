import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_live_entrypoint.dart';
import 'package:flutter_test/flutter_test.dart';

/// B4d.21d.3 — entrypoint repair + hosted read-only verifier (local fakes only).
void main() {
  final root = Directory.current.path;
  final projectsFixture = File(
    '$root/test/staging/fixtures/s17_projects_list.json',
  );
  final creator =
      '$root/tool/staging/create_s17_journey_d_adaptation_fixture.sh';
  final diagnose =
      '$root/tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh';
  final launcher = '$root/tool/staging/run_s17_journey_d_live_dart.sh';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('b4d21d3_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Map<String, String> req({String? marker}) {
    final f = File('${tmp.path}/req.json');
    f.writeAsStringSync(
      jsonEncode({
        'marker': marker ?? stableMarker,
        'root': root,
        'package_rel':
            'tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
        'protocol_intent_rel':
            'tool/staging/fixtures/journey_d/protocol_intent.json',
        'api_env_path': '${tmp.path}/missing_api.env',
      }),
    );
    return {
      'S17_JD_LIVE_REQUEST_FILE': f.path,
      'S17_JD_LIVE_RESULT_FILE': '${tmp.path}/out.json',
    };
  }

  group('entrypoint regression', () {
    test('1 original dart run boundary still crashes before main', () async {
      final files = req();
      final r = await Process.run(
        'dart',
        ['run', 'tool/staging/bin/create_s17_journey_d_live.dart'],
        environment: {
          ...Platform.environment,
          ...files,
          'CONFIRM_COHORT_STAGING': '1',
          'S17_JD_LIVE_CREATE': '1',
        },
        workingDirectory: root,
      );
      expect(r.exitCode, isNot(0));
      final err = '${r.stderr}\n${r.stdout}';
      expect(
        err.contains('Crash when compiling') ||
            err.contains('InvalidType') ||
            err.contains('NativeCallable'),
        isTrue,
        reason: err,
      );
      expect(File(files['S17_JD_LIVE_RESULT_FILE']!).existsSync(), isFalse);
    });

    test('2-5 repaired launcher reaches main and fake orchestration', () async {
      final launcherSrc = File(launcher).readAsStringSync();
      expect(launcherSrc, contains('flutter test'));
      expect(launcherSrc, isNot(contains('exec dart run')));

      final files = req();
      final r = await Process.run(
        launcher,
        [],
        environment: {
          ...Platform.environment,
          ...files,
          'CONFIRM_COHORT_STAGING': '1',
          'S17_JD_LIVE_CREATE': '1',
          'S17_JD_LIVE_PORTS': 'fake',
          'S17_JD_ALLOW_FAKE_PORTS': '1',
          'S17_ROOT': root,
        },
        workingDirectory: root,
      );
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      final out =
          jsonDecode(File(files['S17_JD_LIVE_RESULT_FILE']!).readAsStringSync())
              as Map<String, dynamic>;
      expect(out['reached_main'], isTrue);
      expect(out['ok'], isTrue);
      expect(out['fixture_marker'] ?? out['marker'], stableMarker);
      expect(out['ports_mode'], 'fake');
      expect(out['hosted_writes_executed'], 0);
      expect(out['publish_draft_invocations'], 2);
      expect(out['new_marker_called'] ?? false, isFalse);
    });

    test('6 missing marker fails before orchestration', () async {
      final files = req(marker: '');
      final code = await runJourneyDLiveEntrypoint(
        environment: {
          ...files,
          'S17_JD_LIVE_PORTS': 'fake',
          'S17_JD_ALLOW_FAKE_PORTS': '1',
        },
        ensureFlutterBinding: false,
      );
      expect(code, 2);
      final out =
          jsonDecode(File(files['S17_JD_LIVE_RESULT_FILE']!).readAsStringSync())
              as Map<String, dynamic>;
      expect(out['classification'], contains('MARKER'));
    });

    test('7 genuine hosted mode cannot silently use fakes', () async {
      final files = req();
      // fake ports without allow flag
      final code = await runJourneyDLiveEntrypoint(
        environment: {...files, 'S17_JD_LIVE_PORTS': 'fake'},
        ensureFlutterBinding: false,
      );
      expect(code, 2);
      final out =
          jsonDecode(File(files['S17_JD_LIVE_RESULT_FILE']!).readAsStringSync())
              as Map<String, dynamic>;
      expect(out['classification'], 'B4D21D3_FAKE_PORTS_REFUSED');

      // default hosted without API env fails closed (no silent fake)
      final code2 = await runJourneyDLiveEntrypoint(
        environment: {...files},
        ensureFlutterBinding: false,
      );
      expect(code2, 2);
      final out2 =
          jsonDecode(File(files['S17_JD_LIVE_RESULT_FILE']!).readAsStringSync())
              as Map<String, dynamic>;
      expect(out2['ports_mode'], 'hosted');
      expect(out2['classification'], 'B4D21D1_HOSTED_CONFIG_MISSING');
      expect(out2['reached_main'], isTrue);
    });

    test('8-9 compiler failure propagates non-zero; no hosted contact', () async {
      final files = req();
      final r = await Process.run(
        'dart',
        ['run', 'tool/staging/bin/create_s17_journey_d_live.dart'],
        environment: {
          ...Platform.environment,
          ...files,
          'CONFIRM_COHORT_STAGING': '1',
          'S17_JD_LIVE_CREATE': '1',
        },
        workingDirectory: root,
      );
      expect(r.exitCode, isNot(0));
      // No result file ⇒ cannot be misreported as a post-mutation stage failure.
      expect(File(files['S17_JD_LIVE_RESULT_FILE']!).existsSync(), isFalse);
    });
  });

  group('hosted verifier (fakes only)', () {
    test('10 help documents local-contract and hosted modes', () async {
      final r = await Process.run(diagnose, ['--help']);
      expect(r.exitCode, 0);
      final out = '${r.stdout}\n${r.stderr}';
      expect(out, contains('--local-contract'));
      expect(out, contains('--hosted'));
      expect(out, contains('S17_JD_HOSTED_READONLY=1'));
    });

    test('11-15 hosted guards and marker-before-target', () async {
      final noGuard = await Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            'env -u S17_JD_HOSTED_READONLY '
            '"$diagnose" $stableMarker --hosted',
      ]);
      expect(noGuard.exitCode, 2);
      expect(noGuard.stderr.toString(), contains('S17_JD_HOSTED_READONLY'));

      final badMarker = await Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 S17_JD_HOSTED_READONLY=1 '
            'env -u S17_PROJECTS_JSON_FILE '
            '"$diagnose" not-valid --hosted',
      ]);
      expect(badMarker.exitCode, 2);
      expect(badMarker.stderr.toString(), contains('invalid Journey D'));
      expect(
        badMarker.stderr.toString(),
        isNot(contains('S17_PROJECTS_JSON_FILE')),
      );

      final diagSrc = File(diagnose).readAsStringSync();
      expect(diagSrc, contains('s17_confirm_staging_identity'));
      // Prohibition comments may mention --linked; ensure no invocation.
      expect(diagSrc, isNot(contains('supabase --linked ')));
      expect(diagSrc, isNot(contains('supabase\n--linked')));
      expect(diagSrc.contains('Never uses') && diagSrc.contains('--linked'), isTrue);
      expect(diagSrc, contains('S17_JD_HOSTED_READONLY'));
    });

    test('16-34 fake snapshot eligibility matrix', () async {
      final py = await Process.run('python3', [
        '-c',
        '''
import json, os, sys
from pathlib import Path
sys.path.insert(0, r"$root/tool/staging/lib")
os.environ["CONFIRM_COHORT_STAGING"]="1"
os.environ["S17_JD_HOSTED_READONLY"]="1"
from s17_journey_d_hosted_readonly import (
    MutationAttemptError,
    ReadOnlyHttpClient,
    run_hosted_readonly,
)

root = Path(r"$root")
projects = Path(r"${projectsFixture.path}").read_text()
api = Path(r"${tmp.path}") / "api.env"
api.write_text(
    "S13_API_URL=https://tsbadngzgvsyfqjupkng.supabase.co\\n"
    "S13_ANON_KEY=test_anon\\n"
    "S13_SERVICE_KEY=test_service\\n"
)
marker = "$stableMarker"

def run(snap):
    # Injecting snapshot avoids network; client still enforces GET-only.
    client = ReadOnlyHttpClient(
        base_url="https://tsbadngzgvsyfqjupkng.supabase.co",
        api_key="test",
        get_impl=lambda path, headers: (_ for _ in ()).throw(
            AssertionError(f"unexpected network GET {path}")
        ),
    )
    return run_hosted_readonly(
        root=root,
        projects_raw=projects,
        marker=marker,
        api_env_path=api,
        client=client,
        fixture_snapshot=snap,
    )

absent = run({})
assert absent["fixture_state"] == "absent", absent
assert absent["fixture_eligible"] is False

complete = {
    "identity_count": 1,
    "profile_count": 1,
    "identity_profile_link_valid": True,
    "current_protocol_count": 1,
    "current_revision_count": 1,
    "later_protocol_count": 1,
    "later_revision_count": 1,
    "canonical_publication_attribution_valid": True,
    "programme_count": 1,
    "programme_version_count": 1,
    "programme_state_valid": True,
    "imported_lineages_canonical": True,
    "symbolic_lineage_count": 0,
    "assignment_count": 1,
    "occurrence_count": 2,
    "occurrence_order_valid": True,
    "adaptation_state_count": 0,
    "journey_d_execution_count": 0,
    "journey_i_execution_count": 0,
    "journey_j_execution_count": 0,
    "duplicates_found": False,
    "unrelated_objects_attributable": False,
}
ok = run(complete)
assert ok["fixture_state"] == "complete", ok
assert ok["fixture_eligible"] is True, ok

partial = dict(complete)
partial["assignment_count"] = 0
partial["occurrence_count"] = 0
partial["occurrence_order_valid"] = False
p = run(partial)
assert p["fixture_state"] == "partial", p
assert p["fixture_eligible"] is False

uncertain = dict(complete)
uncertain["unverified_claims"] = ["assignment_lookup"]
u = run(uncertain)
assert u["fixture_state"] == "uncertain", u
assert u["fixture_eligible"] is False

dup = dict(complete)
dup["identity_count"] = 2
dup["duplicates_found"] = True
d = run(dup)
assert d["fixture_eligible"] is False

bad_link = dict(complete)
bad_link["identity_profile_link_valid"] = False
assert run(bad_link)["fixture_eligible"] is False

bad_attr = dict(complete)
bad_attr["canonical_publication_attribution_valid"] = False
assert run(bad_attr)["fixture_eligible"] is False

sym = dict(complete)
sym["symbolic_lineage_count"] = 1
sym["imported_lineages_canonical"] = False
assert run(sym)["fixture_eligible"] is False

bad_state = dict(complete)
bad_state["programme_state_valid"] = False
assert run(bad_state)["fixture_eligible"] is False

bad_occ = dict(complete)
bad_occ["occurrence_count"] = 1
bad_occ["occurrence_order_valid"] = False
assert run(bad_occ)["fixture_state"] == "partial"

adapt = dict(complete)
adapt["adaptation_state_count"] = 1
assert run(adapt)["fixture_eligible"] is False

jd = dict(complete)
jd["journey_d_execution_count"] = 1
assert run(jd)["fixture_eligible"] is False

# Mutation interfaces unreachable
client = ReadOnlyHttpClient(base_url="https://tsbadngzgvsyfqjupkng.supabase.co", api_key="x")
for meth in ("post", "patch", "put", "delete"):
    try:
        getattr(client, meth)("/rest/v1/x")
        raise SystemExit(f"mutation {meth} reachable")
    except MutationAttemptError:
        pass

# Broad predicate rejected
try:
    client.get("/rest/v1/profiles?select=id", require_predicate="id=eq.x")
    raise SystemExit("broad query allowed")
except Exception as e:
    assert "broad" in str(e).lower() or "predicate" in str(e).lower()

# Production URL refused
try:
    bad_api = Path(r"${tmp.path}") / "prod.env"
    bad_api.write_text(
        "S13_API_URL=https://otnhhdxs.example.supabase.co\\n"
        "S13_ANON_KEY=x\\nS13_SERVICE_KEY=y\\n"
    )
    run_hosted_readonly(
        root=root,
        projects_raw=projects,
        marker=marker,
        api_env_path=bad_api,
        fixture_snapshot=complete,
    )
    raise SystemExit("production allowed")
except Exception as e:
    assert "production" in str(e).lower() or "REFUSED" in str(e)

# Redaction: synthetic email is truncated (ellipsis), credentials absent
er = str(ok.get("email_redacted", ""))
assert "…" in er or "..." in er, er
assert marker + ".athlete" not in er
assert "test_service" not in json.dumps(ok)
assert "test_anon" not in json.dumps(ok)
print("VERIFIER_MATRIX_OK")
''',
      ], workingDirectory: root);
      expect(py.exitCode, 0, reason: '${py.stdout}\n${py.stderr}');
      expect(py.stdout.toString(), contains('VERIFIER_MATRIX_OK'));
    });

    test('local-contract mode preserved', () async {
      final r = await Process.run(diagnose, [
        stableMarker,
        '--local-contract',
      ], workingDirectory: root);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(r.stdout.toString(), contains('JD_READONLY_LOCAL_CONTRACT_OK'));
      expect(r.stdout.toString(), contains('local_contract_read_only'));
    });
  });

  group('no hosted contact', () {
    test('shell live with synthetic backend still zero hosted', () async {
      final r = await Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 S17_JD_LIVE_CREATE=1 '
            'S17_JD_LIVE_MUTATION_BACKEND=synthetic_ok '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            '"$creator" --live --marker $stableMarker',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(r.stdout.toString(), contains('HOSTED_WRITES_EXECUTED=0'));
      expect(r.stdout.toString(), contains('MUTATION_BACKEND=synthetic'));
    });
  });
}
