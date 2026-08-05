import 'dart:io';

import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_rebind.dart';
import 'package:flutter_test/flutter_test.dart';

/// B4d.21b deterministic session-lineage UUID rebinding — local fakes only.
void main() {
  final root = Directory.current.path;
  late String packageYaml;
  late String protocolIntentJson;
  late PlanPackageCompileResult originalCompile;
  late JourneyDPublicationPlan plan;

  // Deterministic fake UUIDs (RFC-4122 shaped).
  const currentUuid = 'a1111111-1111-4111-8111-111111111111';
  const laterUuid = 'b2222222-2222-4222-8222-222222222222';

  setUpAll(() {
    packageYaml = File(
      '$root/tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
    ).readAsStringSync();
    protocolIntentJson = File(
      '$root/tool/staging/fixtures/journey_d/protocol_intent.json',
    ).readAsStringSync();
    originalCompile = const PlanPackageCompiler().compile(packageYaml);
    expect(
      originalCompile.isValid,
      isTrue,
      reason: '${originalCompile.issues}',
    );
    expect(
      originalCompile.contentHashSha256,
      '156dfe8cf262e43f4e7e47cab070a37f466d3271fe26b29ca80e5c5e49e8a7d7',
    );
    plan = const JourneyDPublicationPlanBuilder().build(
      protocolIntentJson: protocolIntentJson,
      packageManifest: originalCompile.manifest!,
    );
  });

  group('publication plan', () {
    test('1 exact protocol intents produce deterministic publication plan', () {
      expect(plan.count, 2);
      expect(plan.intents.map((i) => i.protocolId).toList(), [
        'PROT-S17-JD-ADAPT-CURRENT',
        'PROT-S17-JD-ADAPT-LATER',
      ]);
      expect(plan.intents.map((i) => i.symbolicSessionLineageId).toList(), [
        'SL-S17-JD-ADAPT-CURRENT',
        'SL-S17-JD-ADAPT-LATER',
      ]);
      expect(plan.intents.first.order, lessThan(plan.intents.last.order));
    });

    test('2 publication uses canonical repository interface type', () {
      expect(ProtocolBuilderJourneyDPublisher, isNotNull);
      // Interface contract: publishDraft pathway class exists in tooling.
      expect(
        File(
          '$root/lib/staging_tooling/journey_d/protocol_builder_journey_d_publisher.dart',
        ).readAsStringSync(),
        contains('ProtocolBuilderService'),
      );
      expect(
        File(
          '$root/lib/staging_tooling/journey_d/protocol_builder_journey_d_publisher.dart',
        ).readAsStringSync(),
        contains('publishDraft'),
      );
    });

    test('3 no direct SQL publication pathway is introduced', () {
      final stagingDart = Directory('$root/lib/staging_tooling/journey_d');
      for (final file in stagingDart.listSync().whereType<File>()) {
        final text = file.readAsStringSync().toLowerCase();
        expect(text.contains('insert into performance_protocols'), isFalse);
        expect(text.contains('insert into protocol_steps'), isFalse);
        expect(text.contains('supabase db query'), isFalse);
        expect(text.contains('db.query'), isFalse);
      }
      final publisher = File(
        '$root/lib/staging_tooling/journey_d/protocol_builder_journey_d_publisher.dart',
      ).readAsStringSync();
      expect(publisher, contains('publishDraft'));
      expect(publisher.contains('INSERT INTO'), isFalse);
    });
  });

  group('dry-run / live separation', () {
    test('4 dry-run never invokes protocol publication', () async {
      final result = await Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="$root/test/staging/fixtures/s17_projects_list.json" '
            './tool/staging/create_s17_journey_d_adaptation_fixture.sh --dry-run',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = '${result.stdout}\n${result.stderr}';
      expect(out, contains('DRY_RUN_OK'));
      expect(out, contains('HOSTED_WRITES=0'));
      expect(out, contains('REBIND_PATH_READY'));
      final py = await Process.run('python3', [
        '-c',
        "import sys,json,os\n"
            "sys.path.insert(0,r'$root/tool/staging/lib')\n"
            "from s17_journey_d_fixture import run_dry_run\n"
            "from pathlib import Path\n"
            "os.environ['CONFIRM_COHORT_STAGING']='1'\n"
            "r=run_dry_run(root=Path(r'$root'), projects_raw=Path(r'$root/test/staging/fixtures/s17_projects_list.json').read_text())\n"
            "assert r['publish_draft_invoked'] is False\n"
            "assert r['fabricated_hosted_uuids'] is False\n"
            "assert r['rebind_path']=='REBIND_PATH_READY'\n"
            "mutating=[s for s in r['ledger']['stages'] if s['mutating']]\n"
            "assert all(s['status']=='not_started' for s in mutating)\n"
            "print('DRY_RUN_REBIND_OK')\n",
      ], workingDirectory: root);
      expect(py.exitCode, 0, reason: '${py.stdout}\n${py.stderr}');
      expect(py.stdout.toString(), contains('DRY_RUN_REBIND_OK'));
    });

    test('5 live path remains behind staging and live-mode guards', () async {
      final result = await Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="$root/test/staging/fixtures/s17_projects_list.json" '
            './tool/staging/create_s17_journey_d_adaptation_fixture.sh --live',
      ]);
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('S17_JD_LIVE_CREATE'));
    });
  });

  group('mapping and fail-closed attribution', () {
    FakeJourneyDProtocolPublisher publisher({
      Map<String, String>? lineages,
      Set<String> fail = const {},
      Set<String> ambiguous = const {},
      Map<String, String> wrongProtocol = const {},
      Map<String, String> malformed = const {},
      Map<String, int> wrongRevision = const {},
    }) {
      return FakeJourneyDProtocolPublisher(
        lineageByProtocolId:
            lineages ??
            {
              'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
              'PROT-S17-JD-ADAPT-LATER': laterUuid,
            },
        failProtocolIds: fail,
        ambiguousProtocolIds: ambiguous,
        wrongProtocolIdReturns: wrongProtocol,
        malformedLineageByProtocolId: malformed,
        wrongRevisionByProtocolId: wrongRevision,
      );
    }

    Future<JourneyDRebindPipelineResult> runWith(
      FakeJourneyDProtocolPublisher fake,
    ) {
      return JourneyDRebindPipeline(publisher: fake).run(
        protocolIntentJson: protocolIntentJson,
        originalPackage: originalCompile.manifest!,
      );
    }

    test(
      '6 each successful fake publication returns a canonical UUID',
      () async {
        final fake = publisher();
        final result = await runWith(fake);
        expect(result.importReady, isTrue);
        for (final pub in result.publicationResults) {
          expect(pub.isApplied, isTrue);
          expect(
            DatabaseUuid.isValidDatabaseUuid(pub.returnedSessionLineageId),
            isTrue,
          );
        }
      },
    );

    test('7 complete one-to-one symbolic-to-UUID mapping succeeds', () async {
      final result = await runWith(publisher());
      expect(result.mapping!.count, 2);
      expect(
        result.mapping!.bySymbolicLineage['SL-S17-JD-ADAPT-CURRENT'],
        currentUuid,
      );
      expect(
        result.mapping!.bySymbolicLineage['SL-S17-JD-ADAPT-LATER'],
        laterUuid,
      );
      expect(result.mapping!.canonicalUuids.length, 2);
    });

    test(
      '8 mapping uses explicit intent attribution not display names',
      () async {
        final result = await runWith(publisher());
        // Attribution keys are symbolic lineage IDs from intent, not titles.
        expect(result.mapping!.bySymbolicLineage.keys.toSet(), {
          'SL-S17-JD-ADAPT-CURRENT',
          'SL-S17-JD-ADAPT-LATER',
        });
        expect(
          File(
            '$root/lib/staging_tooling/journey_d/journey_d_rebind_pipeline.dart',
          ).readAsStringSync(),
          contains('protocol intent identity'),
        );
      },
    );

    test('9 missing publication result fails closed', () async {
      final result = await runWith(
        publisher(lineages: {'PROT-S17-JD-ADAPT-CURRENT': currentUuid}),
      );
      expect(result.importReady, isFalse);
      expect(result.furtherMutationProhibited, isTrue);
      expect(result.rebound, isNull);
    });

    test('10 duplicate symbolic lineage fails closed at plan build', () {
      final badIntent = protocolIntentJson.replaceFirst(
        'SL-S17-JD-ADAPT-LATER',
        'SL-S17-JD-ADAPT-CURRENT',
      );
      expect(
        () => const JourneyDPublicationPlanBuilder().build(
          protocolIntentJson: badIntent,
          packageManifest: originalCompile.manifest!,
        ),
        throwsA(isA<JourneyDRebindException>()),
      );
    });

    test('11 duplicate returned UUID fails closed', () async {
      final result = await runWith(
        publisher(
          lineages: {
            'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
            'PROT-S17-JD-ADAPT-LATER': currentUuid,
          },
        ),
      );
      expect(result.importReady, isFalse);
      expect(result.furtherMutationProhibited, isTrue);
      expect(result.detail, contains('duplicate returned UUID'));
    });

    test('12 unexpected publication result fails closed', () async {
      final result = await runWith(
        publisher(fail: {'PROT-S17-JD-ADAPT-CURRENT'}),
      );
      expect(
        result.publicationResults.first.state,
        JourneyDPublicationStageState.failed,
      );
      expect(result.importReady, isFalse);
    });

    test('13 unattributable / missing lineage fails closed', () async {
      final result = await runWith(
        publisher(lineages: {'PROT-S17-JD-ADAPT-CURRENT': currentUuid}),
      );
      expect(
        result.publicationResults.any(
          (r) =>
              r.intent.protocolId == 'PROT-S17-JD-ADAPT-LATER' &&
              (r.state == JourneyDPublicationStageState.failed ||
                  r.state == JourneyDPublicationStageState.notStarted),
        ),
        isTrue,
      );
    });

    test('14 malformed or non-UUID returned lineage fails closed', () async {
      final result = await runWith(
        publisher(
          malformed: {'PROT-S17-JD-ADAPT-CURRENT': 'SL-S17-JD-ADAPT-CURRENT'},
        ),
      );
      expect(result.publicationResults.first.isApplied, isFalse);
      expect(result.importReady, isFalse);
    });

    test('15 wrong protocol identity fails closed', () async {
      final result = await runWith(
        publisher(wrongProtocol: {'PROT-S17-JD-ADAPT-CURRENT': 'PROT-OTHER'}),
      );
      expect(result.publicationResults.first.isApplied, isFalse);
    });

    test('16 wrong revision identity fails closed', () async {
      final result = await runWith(
        publisher(wrongRevision: {'PROT-S17-JD-ADAPT-CURRENT': 99}),
      );
      expect(result.publicationResults.first.isApplied, isFalse);
      expect(result.importReady, isFalse);
    });

    test('17 ambiguous publication result becomes unknown', () async {
      final result = await runWith(
        publisher(ambiguous: {'PROT-S17-JD-ADAPT-CURRENT'}),
      );
      expect(
        result.publicationResults.first.state,
        JourneyDPublicationStageState.unknown,
      );
      expect(result.furtherMutationProhibited, isTrue);
    });

    test('18 failure stops all later stages', () async {
      final result = await runWith(
        publisher(fail: {'PROT-S17-JD-ADAPT-CURRENT'}),
      );
      expect(
        result.publicationResults[0].state,
        JourneyDPublicationStageState.failed,
      );
      expect(
        result.publicationResults[1].state,
        JourneyDPublicationStageState.notStarted,
      );
      expect(result.rebound, isNull);
    });

    test('19 partial success preserved without inferred rollback', () async {
      final result = await runWith(
        publisher(fail: {'PROT-S17-JD-ADAPT-LATER'}),
      );
      expect(result.publicationResults[0].isApplied, isTrue);
      expect(
        result.publicationResults[0].returnedSessionLineageId,
        currentUuid,
      );
      expect(
        result.publicationResults[1].state,
        JourneyDPublicationStageState.failed,
      );
      expect(result.importReady, isFalse);
      // No cleanup/rollback implied — first result remains applied.
      expect(
        result.publicationResults[0].state,
        JourneyDPublicationStageState.applied,
      );
    });

    test('20-21 no retry/cleanup/compensation/delete/repair/resume', () {
      final src = File(
        '$root/lib/staging_tooling/journey_d/journey_d_rebind_pipeline.dart',
      ).readAsStringSync();
      expect(src.contains('def retry') || src.contains('void retry'), isFalse);
      expect(src.toLowerCase().contains('cleanup'), isFalse);
      expect(src.toLowerCase().contains('compensate'), isFalse);
      expect(src.toLowerCase().contains('delete'), isFalse);
      expect(src.toLowerCase().contains('repair'), isFalse);
      expect(src.toLowerCase().contains('resume'), isFalse);
    });
  });

  group('typed rebind and import gate', () {
    late JourneyDRebindPipelineResult success;

    setUp(() async {
      success =
          await JourneyDRebindPipeline(
            publisher: FakeJourneyDProtocolPublisher(
              lineageByProtocolId: {
                'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
                'PROT-S17-JD-ADAPT-LATER': laterUuid,
              },
            ),
          ).run(
            protocolIntentJson: protocolIntentJson,
            originalPackage: originalCompile.manifest!,
          );
      expect(success.importReady, isTrue);
    });

    test('22 only exact fixture session-lineage fields are rebound', () {
      final original = originalCompile.manifest!;
      final rebound = success.rebound!.manifest;
      for (var i = 0; i < original.sessions.length; i++) {
        expect(rebound.sessions[i].sessionKey, original.sessions[i].sessionKey);
        expect(rebound.sessions[i].protocolId, original.sessions[i].protocolId);
        expect(
          rebound.sessions[i].revisionNumber,
          original.sessions[i].revisionNumber,
        );
        expect(
          rebound.sessions[i].sessionLineageId,
          isNot(original.sessions[i].sessionLineageId),
        );
      }
    });

    test('23 broad textual replacement is not used', () {
      final rebinderSrc = File(
        '$root/lib/staging_tooling/journey_d/journey_d_session_lineage_rebinder.dart',
      ).readAsStringSync();
      expect(rebinderSrc.contains('replaceAll'), isFalse);
      expect(rebinderSrc.contains('.replace('), isFalse);
      expect(rebinderSrc, contains('PlanPackageSessionRevisionRef'));
    });

    test('24 every expected symbolic lineage is replaced', () {
      final lineages = success.rebound!.manifest.sessions
          .map((s) => s.sessionLineageId)
          .toSet();
      expect(lineages, {currentUuid, laterUuid});
      expect(lineages.any((id) => id.startsWith('SL-S17-JD-ADAPT-')), isFalse);
    });

    test('25 remaining symbolic lineage blocks import', () {
      expect(
        () => const JourneyDSessionLineageRebinder().rebind(
          original: originalCompile.manifest!,
          mapping: JourneyDLineageMapping({
            'SL-S17-JD-ADAPT-CURRENT': currentUuid,
            // Intentionally map later to another symbolic value via invalid UUID path
            'SL-S17-JD-ADAPT-LATER': 'SL-STILL-SYMBOLIC',
          }),
          plan: plan,
        ),
        throwsA(isA<JourneyDRebindException>()),
      );
    });

    test('26 any non-UUID import-relevant lineage blocks import', () {
      expect(
        () => const JourneyDImportGate().payloadForImport(
          pipelineResult: JourneyDRebindPipelineResult(
            plan: plan,
            publicationResults: const [],
            mapping: null,
            rebound: null,
            furtherMutationProhibited: true,
            importReady: false,
          ),
          importedBy: 'test',
        ),
        throwsA(isA<JourneyDRebindException>()),
      );
    });

    test('27-28 current/later ordering and protocol/revision preserved', () {
      final original = originalCompile.manifest!;
      final rebound = success.rebound!.manifest;
      expect(
        rebound.sessions.map((s) => s.sessionKey).toList(),
        original.sessions.map((s) => s.sessionKey).toList(),
      );
      expect(
        rebound.weeks.first.days.map((d) => d.dayKey).toList(),
        original.weeks.first.days.map((d) => d.dayKey).toList(),
      );
      final slots = [
        for (final d in rebound.weeks.first.days)
          for (final s in d.slots) s.slotKey,
      ];
      expect(slots, ['W1D1S1', 'W1D2S1']);
      for (var i = 0; i < original.sessions.length; i++) {
        expect(rebound.sessions[i].protocolId, original.sessions[i].protocolId);
        expect(
          rebound.sessions[i].revisionNumber,
          original.sessions[i].revisionNumber,
        );
      }
    });

    test('29-30 permissions unchanged and agreement required', () {
      final original = originalCompile.manifest!.adaptationPermissions;
      final rebound = success.rebound!.manifest.adaptationPermissions;
      expect(rebound.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(rebound[i].id, original[i].id);
        expect(rebound[i].changeKind, original[i].changeKind);
        expect(rebound[i].athleteAgreementRequired, isTrue);
        expect(
          AdaptationPolicyGate.allowed.contains(rebound[i].changeKind),
          isTrue,
        );
      }
    });

    test('31-33 equipment/exercise contract and later baseline unchanged', () {
      expect(
        protocolIntentJson,
        contains(JourneyDEquipmentAdaptationContract.sourceExerciseId),
      );
      expect(
        protocolIntentJson,
        contains(JourneyDEquipmentAdaptationContract.replacementExerciseId),
      );
      expect(protocolIntentJson, contains('cohort.exercise.push_up'));
      expect(
        success.rebound!.manifest.programme.lineageCode,
        'PROG-S17-JD-ADAPT',
      );
    });

    test(
      '34-36 rebound package recompiles/validates/hashes deterministically',
      () {
        expect(success.rebound!.isImportReady, isTrue);
        expect(success.rebound!.canonicalJson, isNotEmpty);
        expect(success.rebound!.contentHashSha256.length, 64);
        // Deterministic for these fake UUIDs — assert stability across recompute.
        final again = const JourneyDSessionLineageRebinder().rebind(
          original: originalCompile.manifest!,
          mapping: success.mapping!,
          plan: plan,
        );
        expect(again.contentHashSha256, success.rebound!.contentHashSha256);
        expect(
          success.rebound!.contentHashSha256,
          isNot(originalCompile.contentHashSha256),
        );
        // ignore: avoid_print
        print('REBOUND_HASH=${success.rebound!.contentHashSha256}');
      },
    );

    test('37 import receives only validated rebound package', () {
      final payload = const JourneyDImportGate().payloadForImport(
        pipelineResult: success,
        importedBy: 's17-jd-adapt-fixture',
      );
      final sessions = payload['sessions'] as List;
      for (final session in sessions) {
        final map = session as Map;
        final lineage = map['session_lineage_id'] as String;
        expect(DatabaseUuid.isValidDatabaseUuid(lineage), isTrue);
        expect(lineage.startsWith('SL-'), isFalse);
      }
      expect(
        payload['package_content_hash'],
        success.rebound!.contentHashSha256,
      );
    });

    test(
      '38-39 import/enrol/materialisation blocked when rebound fails',
      () async {
        final failed =
            await JourneyDRebindPipeline(
              publisher: FakeJourneyDProtocolPublisher(
                lineageByProtocolId: {'PROT-S17-JD-ADAPT-CURRENT': currentUuid},
                failProtocolIds: {'PROT-S17-JD-ADAPT-LATER'},
              ),
            ).run(
              protocolIntentJson: protocolIntentJson,
              originalPackage: originalCompile.manifest!,
            );
        expect(failed.importReady, isFalse);
        expect(
          () => const JourneyDImportGate().payloadForImport(
            pipelineResult: failed,
            importedBy: 'test',
          ),
          throwsA(isA<JourneyDRebindException>()),
        );
      },
    );

    test(
      '40 ledger-equivalent publication results report partial outcomes',
      () async {
        final failed =
            await JourneyDRebindPipeline(
              publisher: FakeJourneyDProtocolPublisher(
                lineageByProtocolId: {
                  'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
                  'PROT-S17-JD-ADAPT-LATER': laterUuid,
                },
                failProtocolIds: {'PROT-S17-JD-ADAPT-LATER'},
              ),
            ).run(
              protocolIntentJson: protocolIntentJson,
              originalPackage: originalCompile.manifest!,
            );
        expect(
          failed.publicationResults[0].redactedEvidence['state'],
          'applied',
        );
        expect(
          failed.publicationResults[1].redactedEvidence['state'],
          'failed',
        );
      },
    );

    test('41 private identifiers are redacted', () {
      final evidence = success.publicationResults.first.redactedEvidence;
      expect(evidence['returned_session_lineage_id_redacted'], 'a1111111…');
      expect(evidence.containsKey('returned_session_lineage_id'), isFalse);
    });

    test('42 Journey D remains unreachable from rebind tooling', () {
      final creator = File(
        '$root/tool/staging/create_s17_journey_d_adaptation_fixture.sh',
      ).readAsStringSync();
      expect(creator.contains('run_s17_flutter_staging_verify'), isFalse);
      expect(creator.contains('main_s17_staging_verify'), isFalse);
    });
  });

  group('creator continuity', () {
    test('43 dry-run reports REBIND_PATH_READY and updated stage order', () async {
      final py = await Process.run('python3', [
        '-c',
        "import sys,os\n"
            "sys.path.insert(0,r'$root/tool/staging/lib')\n"
            "from s17_journey_d_fixture import STAGE_ORDER, REBIND_PATH_STATUS, run_dry_run\n"
            "from pathlib import Path\n"
            "os.environ['CONFIRM_COHORT_STAGING']='1'\n"
            "assert REBIND_PATH_STATUS=='REBIND_PATH_READY'\n"
            "assert 'publish_fixture_protocol_current' in STAGE_ORDER\n"
            "assert 'rebind_validate_package_for_import' in STAGE_ORDER\n"
            "assert 'create_published_session_revisions' not in STAGE_ORDER\n"
            "r=run_dry_run(root=Path(r'$root'), projects_raw=Path(r'$root/test/staging/fixtures/s17_projects_list.json').read_text())\n"
            "assert r['manifest']['rebind_path']=='REBIND_PATH_READY'\n"
            "print('CREATOR_CONTINUITY_OK')\n",
      ], workingDirectory: root);
      expect(py.exitCode, 0, reason: '${py.stdout}\n${py.stderr}');
    });
  });
}
