import 'dart:io';

import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_rebind.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fresh Journey D fixture identity — local exact-email-flow proof.
void main() {
  final root = Directory.current.path;
  const retired = 's17_jd_adapt_20260805T012428Z_933d9364';

  test('retired marker is listed and refused on live helper', () {
    expect(retiredLiveJourneyDMarkers, contains(retired));
    expect(
      () => rejectRetiredLiveMarker(retired),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('retired/poisoned'),
        ),
      ),
    );
  });

  test('canonical email is identical for uniqueness/create/verify derivation', () {
    const marker = 's17_jd_adapt_20260805T120000Z_abcdef12';
    final email = journeyDFixtureEmail(marker);
    expect(email, '$marker.athlete.jd@example.invalid');
    expect(journeyDNormalizedFixtureEmail(marker), email.toLowerCase());
    // Same helper used by hosted uniqueness + creator + execute ports.
    final livePorts = File(
      '$root/lib/staging_tooling/journey_d/journey_d_hosted_live_ports.dart',
    ).readAsStringSync();
    final creator = File(
      '$root/lib/staging_tooling/journey_d/journey_d_live_fixture_creator.dart',
    ).readAsStringSync();
    final execute = File(
      '$root/lib/staging_tooling/journey_d/journey_d_hosted_execute_ports.dart',
    ).readAsStringSync();
    final pyReadonly = File(
      '$root/tool/staging/lib/s17_journey_d_hosted_readonly.py',
    ).readAsStringSync();
    expect(livePorts, contains('journeyDFixtureEmail(marker)'));
    expect(creator, contains('journeyDFixtureEmail(marker)'));
    expect(execute, contains('journeyDFixtureEmail(marker)'));
    expect(pyReadonly, contains('jd_fixture_email(marker)'));
    expect(livePorts, isNot(contains("\$marker.athlete.jd@example.invalid")));
    expect(creator, isNot(contains("\$marker.athlete.jd@example.invalid")));
  });

  test('fresh marker differs from retired and keeps coaching semantics', () {
    final py = Process.runSync('python3', [
      '-c',
      '''
import secrets, sys
from datetime import datetime, timezone
from pathlib import Path
sys.path.insert(0, "tool/staging/lib")
from s17_journey_d_fixture import (
  RETIRED_LIVE_MARKERS, jd_fixture_email, jd_normalized_fixture_email,
  new_marker, reject_retired_live_marker, validate_marker, validate_jd_email,
  LINEAGE_CODE, SOURCE_EXERCISE, REPLACEMENT_EXERCISE, load_protocol_intent,
)
retired = "s17_jd_adapt_20260805T012428Z_933d9364"
assert retired in RETIRED_LIVE_MARKERS
m = new_marker()
validate_marker(m)
assert m != retired
assert m not in RETIRED_LIVE_MARKERS
email = jd_fixture_email(m)
assert email != jd_fixture_email(retired)
assert jd_normalized_fixture_email(m) == email.lower()
validate_jd_email(email, m)
try:
  reject_retired_live_marker(retired)
  raise SystemExit("retired not refused")
except Exception as e:
  assert "retired/poisoned" in str(e)
intent = load_protocol_intent(Path("."))
assert intent["current_protocol"]["exercise_id"] == SOURCE_EXERCISE
assert intent["current_protocol"]["replacement_exercise_id"] == REPLACEMENT_EXERCISE
assert LINEAGE_CODE == "PROG-S17-JD-ADAPT"
print("MARKER=" + m)
print("EMAIL_FP=" + email.split("@")[0][:12] + "…@" + email.split("@")[1])
print("PROOF_OK")
''',
    ], workingDirectory: root);
    expect(py.exitCode, 0, reason: '${py.stdout}\n${py.stderr}');
    expect(py.stdout.toString(), contains('PROOF_OK'));
  });

  test('CURRENT and LATER still validate structured_strength', () {
    final intentJson = File(
      '$root/tool/staging/fixtures/journey_d/protocol_intent.json',
    ).readAsStringSync();
    final yaml = File(
      '$root/tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
    ).readAsStringSync();
    final compile = const PlanPackageCompiler().compile(yaml);
    expect(compile.isValid, isTrue);
    expect(
      compile.contentHashSha256,
      '156dfe8cf262e43f4e7e47cab070a37f466d3271fe26b29ca80e5c5e49e8a7d7',
    );
    final plan = const JourneyDPublicationPlanBuilder().build(
      protocolIntentJson: intentJson,
      packageManifest: compile.manifest!,
    );
    final service = ProtocolBuilderService();
    for (final intent in plan.intents) {
      final draft = ProtocolBuilderJourneyDPublisher.draftFor(intent);
      expect(draft.sessionFormat, 'structured_strength');
      service.validateDraft(draft);
    }
    expect(plan.intents[0].exerciseId, 'cohort.exercise.back_squat');
    expect(plan.intents[1].exerciseId, 'cohort.exercise.push_up');
    expect(yaml, contains('substitute_approved_equipment'));
    expect(yaml, contains('athlete_agreement_required: true'));
  });

  test('shell refuses retired marker on live create', () async {
    final creator =
        '$root/tool/staging/create_s17_journey_d_adaptation_fixture.sh';
    final r = await Process.run('bash', [
      '-c',
      'cd "$root" && CONFIRM_COHORT_STAGING=1 S17_JD_LIVE_CREATE=1 '
          'S17_PROJECTS_JSON_FILE="test/staging/fixtures/s17_projects_list.json" '
          '"$creator" --live --marker $retired',
    ]);
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}${r.stdout}', contains('retired/poisoned'));
  });
}
