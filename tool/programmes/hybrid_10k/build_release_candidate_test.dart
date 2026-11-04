import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_session_source.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/catalogue_operation_receipt.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';

const retained =
    'docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04';
const approved =
    'docs/programmes/hybrid_10k/d8_approved_integration_2026_11_04';
const candidate = 'docs/programmes/hybrid_10k/release_candidate_2026_11_04';
Map<String, String> sources(String dir) => {
  for (final n in [
    'SOURCE.json',
    'SCHEDULE_CANDIDATE.json',
    'STRENGTH_REVIEW_GRAPHS.json',
    'RUNNING_BODIES.json',
    'IDENTITY_INTAKE.json',
  ])
    n: File('$dir/$n').readAsStringSync(),
};
String digest(List<int> bytes) => sha256.convert(bytes).toString();
void main() {
  test(
    'one genuine Hybrid 10K candidate retains every prescription and approved explanation',
    () async {
      final wording =
          jsonDecode(File('$approved/ATHLETE_WORDING.json').readAsStringSync())
              as Map;
      final approval =
          jsonDecode(File('$approved/APPROVAL.json').readAsStringSync()) as Map;
      expect(
        approval['decisions'].every((d) => d['decision'] == 'APPROVED'),
        isTrue,
      );
      expect(
        digest(File('$approved/ATHLETE_WORDING.json').readAsBytesSync()),
        approval['decisions'][1]['wording_json_sha256'],
      );
      final bootstrap = GenuineWorkspace.fromSelectedSources(
        sources(hybridSourceDirectory),
        historicalSources: [sources(archivedHybridSourceDirectory)],
      );
      addTearDown(bootstrap.dispose);
      final operation = RetainedCatalogueOperation.read(
        {
          for (final n in [
            'receipt.json',
            'manifest.json',
            'seed.sql',
            'apply.json',
            'preflight.raw.json',
            'readback.raw.json',
          ])
            n: File('$retained/evidence/retained/$n').readAsStringSync(),
        },
        const CatalogueOperationTrust(
          receiptSha256:
              'f7261883ef7da25d35f09889f2706c9bd3d26bc33a853d8a0ff358b24fb21b62',
          auditReference:
              'supabase-cli-login:a5510f770d978a56-CGK:m11_live_0431d08_20261104',
        ),
      );
      bootstrap.installRetainedCatalogueOperation(operation);
      final base = bootstrap
          .prepareOpen(
            File('$retained/admitted/workspace.json').readAsStringSync(),
          )
          .candidate;
      addTearDown(base.dispose);
      final before = {
        for (final o in base.owners.values)
          for (final rev in o.revisions) rev.key: rev.source,
      };
      final baseGraphs = {
        for (final slot in base.occurrences)
          slot['slot_key'] as String: base
              .selected(slot['slot_key'] as String)
              .source,
      };
      final generate = Platform.environment['COHORT_H10K_GENERATE'] == '1';
      GenuineWorkspace c;
      if (generate) {
        expect(
          Directory(candidate).existsSync(),
          isFalse,
          reason:
              'Preserve a prepared candidate; do not overwrite its identities/artifacts',
        );
        Directory(candidate).createSync(recursive: true);
        c = base;
        for (final slot in List<Map<String, dynamic>>.from(c.occurrences)) {
          final id = slot['slot_key'] as String;
          final old = c.selected(id);
          final owner = c.ownerOf(old);
          final week =
              wording['weekly'].singleWhere(
                    (w) => w['week'] == slot['week'],
                  )['approved_text']
                  as String;
          final matches = (wording['session_applications'] as List).where(
            (s) => s['source_session_id'] == id,
          );
          final intro = matches.isEmpty
              ? null
              : matches.single['approved_text'] as String;
          c.begin(old);
          c.edit(owner, (graph) {
            final first = graph['blocks'][0] as Map;
            first['coach_notes'] = [
              if ((first['coach_notes'] ?? '').toString().trim().isNotEmpty)
                first['coach_notes'],
              week,
              ?intro,
            ].join('\n\n');
          });
          expect(c.freeze(owner), isTrue, reason: c.errors.join('; '));
          c.useRevision(owner.latest, [id], c.generation);
        }
        c.programme.editNativeArrangement((tree) {
          tree['programme']['description'] = wording['freshness_message'];
          for (final week in tree['weeks']) {
            week['coach_note'] = wording['weekly'].singleWhere(
              (w) => w['week'] == week['week_number'],
            )['approved_text'];
            for (final day in week['days']) {
              for (final slot in day['slots']) {
                final matches = (wording['session_applications'] as List).where(
                  (s) => s['source_session_id'] == slot['slot_key'],
                );
                if (matches.isNotEmpty) {
                  slot['coach_note'] = matches.single['approved_text'];
                }
              }
            }
          }
        });
        c.excludeUnusedSources();
        expect(await c.refreshReview(), isTrue, reason: c.errors.join('; '));
        File('$candidate/workspace.json').writeAsStringSync(c.save());
        final archive = NativeSourceBundle.prepare(c).transport.archiveBytes;
        File('$candidate/canonical-source.tar').writeAsBytesSync(archive);
        final files = NativeSourceBundle.verify(archive, c.catalogue);
        for (final n in [
          'programme.plan-package.yaml',
          'programme.canonical.json',
          'protocol-graphs.json',
          'source-index.json',
          'prescription-review.txt',
          'catalogue-evidence.json',
        ]) {
          File('$candidate/$n').writeAsStringSync(files[n]!);
        }
        final compile = const PlanPackageCompiler().compile(
          files['programme.plan-package.yaml']!,
        );
        final payload = const PlanPackageImportPayloadBuilder()
            .buildRetainedPublication(
              compileResult: compile,
              importedBy: 'hybrid10k-reviewed-release-candidate',
            );
        payload['protocol_graphs'] = const ReviewedProtocolGraphArtifact()
            .decode(
              compileResult: compile,
              source: files['protocol-graphs.json']!,
              expectedSha256: nativeDigest(files['protocol-graphs.json']!),
            );
        payload['publication_kind'] = 'private_exact_version';
        payload['library_scope'] = 'coach_private';
        File('$candidate/publication-core.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
        );
        File('$candidate/CANDIDATE.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({'status': 'PREPARED_LOCAL_NOT_PUBLISHED', 'base_commit': 'e676e31af15d9c5a31d573c8215ce008d1980526', 'approval_commit': '8be184ce8d21c36ae080ea41fe132655793b3ecc', 'proposed_programme_version_id': DatabaseUuid.newV4(), 'owner_id': null, 'package_sha256': compile.contentHashSha256, 'graphs_sha256': nativeDigest(files['protocol-graphs.json']!), 'source_archive_sha256': digest(archive), 'notes': 'Proposed immutable version identity only; fresh hosted absence/collision and actual authorised owner resolution required. No publication/activation event or recipient/assignment exists.'})}\n',
        );
      } else {
        c = bootstrap
            .prepareOpen(File('$candidate/workspace.json').readAsStringSync())
            .candidate;
        addTearDown(c.dispose);
      }
      var count = 0;
      for (final slot in c.occurrences) {
        final id = slot['slot_key'] as String;
        final old = jsonDecode(baseGraphs[id]!) as Map;
        final now = jsonDecode(c.selected(id).source) as Map;
        final oldNotes = old['blocks'][0]['coach_notes'];
        final notes = now['blocks'][0]['coach_notes'] as String;
        final week =
            wording['weekly'].singleWhere(
                  (w) => w['week'] == slot['week'],
                )['approved_text']
                as String;
        expect(notes, contains(week));
        if (oldNotes != null) expect(notes, startsWith(oldNotes as String));
        final matches = (wording['session_applications'] as List).where(
          (s) => s['source_session_id'] == id,
        );
        if (matches.isNotEmpty) {
          expect(notes, contains(matches.single['approved_text']));
        }
        for (final g in [old, now]) {
          g.remove('protocol_id');
          g.remove('revision_number');
          g['blocks'][0].remove('coach_notes');
        }
        expect(
          now,
          old,
          reason:
              'Only approved commentary/local revision identity may change: $id',
        );
        count += (now['blocks'] as List).fold<int>(
          0,
          (n, b) => n + (b['exercises'] as List).length,
        );
        expect(c.inspectRevision(c.selected(id)).admitted, isTrue);
      }
      expect(count, 105);
      expect(c.occurrences, hasLength(60));
      for (final o in c.owners.values) {
        for (final rev in o.revisions) {
          if (before.containsKey(rev.key)) expect(rev.source, before[rev.key]);
        }
      }
      expect(await c.refreshReview(), isTrue, reason: c.errors.join('; '));
      final reopened = c.prepareOpen(c.save()).candidate;
      addTearDown(reopened.dispose);
      expect(reopened.save(), c.save());
      expect(await reopened.refreshReview(), isTrue);
      final archive = File('$candidate/canonical-source.tar').readAsBytesSync();
      final files = NativeSourceBundle.verify(archive, c.catalogue);
      final opened = NativeSourceBundle.open(archive, c.catalogue);
      addTearDown(opened.dispose);
      expect(await opened.refreshReview(), isTrue);
      final compile = const PlanPackageCompiler().compile(
        files['programme.plan-package.yaml']!,
      );
      expect(compile.isValid, isTrue);
      expect(
        const ReviewedProtocolGraphArtifact().decode(
          compileResult: compile,
          source: files['protocol-graphs.json']!,
          expectedSha256: nativeDigest(files['protocol-graphs.json']!),
        ),
        hasLength(60),
      );
      final out = Platform.environment['COHORT_H10K_REPORT'];
      if (out != null) {
        File(out).writeAsStringSync(
          '${jsonEncode({'candidate_package_sha256': compile.contentHashSha256, 'all_60_graphs_admitted': true, 'all_105_strength_prescriptions_and_40_running_bodies_unchanged': true, 'all_old_revisions_preserved': true, 'approved_weekly_copy_count': 10, 'approved_session_introduction_count': 40, 'editable_and_archive_readback_reopen': true, 'publication': 'NOT_PERFORMED', 'Gate_A': 'OPEN'})}\n',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
