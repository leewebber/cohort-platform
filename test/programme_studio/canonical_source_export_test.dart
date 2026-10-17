import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_handoff.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_review_bridge.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_export/canonical_source_bundle.dart';
import 'programme_first_controller_test.dart' show changed;
import 'programme_first_screen_test.dart' show mount, tap;
import 'synthetic_composition_screen_test.dart' show ConsumptionRaceController;
import 'synthetic_strength_lineages_test.dart' show createB;

void main() {
  Future<SyntheticCompositionController> open() async {
    final c = SyntheticCompositionController();
    await c.ready;
    addTearDown(c.dispose);
    return c;
  }

  for (final withB in [false, true]) {
    test(
      'standard archive extraction recompiles exact canonical files and v${withB ? 2 : 1} review',
      () async {
        final c = await open();
        final root = c.session.revisions.single.source;
        await changed(c);
        c.session.createDraft();
        c.session.editSession('title', 'Séance Ω / ../same title');
        expect(await c.session.freeze(), true);
        final use = (await c.prepareUseVersion(
          'W1D1S1',
          c.session.revisions.last,
        ))!;
        expect(await c.usePreparedVersion(use), true);
        if (withB) {
          await createB(c);
          expect(await c.admit(c.secondSession.revisions.single), true);
        }
        final source = c.programme.draftSource, owners = c.owners;
        final packet = (await c.exportHandoff())!;
        final bundle = CanonicalSourceBundle.fromReview(c.current!);
        expect(
          bundle.files.containsKey('sessions/session-a-v2.founder.yaml'),
          false,
        ); // Private version.
        expect(bundle.files['sessions/session-a-v1.founder.yaml'], root);
        expect(
          bundle.files['sessions/session-a-v3.founder.yaml'],
          contains('Séance Ω'),
        );
        expect(bundle.files.keys.any((p) => p.contains('..')), false);
        if (withB) {
          expect(
            bundle.files['sessions/session-b-v1.founder.yaml'],
            c.secondSession.revisions.single.source,
          );
          expect(
            c.session.revisions.first.compiled.protocol.name,
            c.secondSession.revisions.first.compiled.protocol.name,
          );
        }
        expect(() => bundle.files['forged'] = 'x', throwsUnsupportedError);
        expect(() => bundle.archiveBytes[0] = 1, throwsUnsupportedError);
        final dir = Directory.systemTemp.createTempSync(
          'cohort-source-export-',
        );
        addTearDown(() => dir.deleteSync(recursive: true));
        final archive = File('${dir.path}/source.tar')
          ..writeAsBytesSync(bundle.archiveBytes);
        final extracted = Directory('${dir.path}/extracted')..createSync();
        // Independent standard reader, not a test parser mirroring the writer.
        final result = Process.runSync('tar', [
          '-xf',
          archive.path,
          '-C',
          extracted.path,
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          extracted.listSync(recursive: true).whereType<File>().length,
          bundle.files.length,
        );
        for (final file in bundle.files.entries) {
          expect(
            File('${extracted.path}/${file.key}').readAsBytesSync(),
            utf8.encode(file.value),
          );
        }
        final programme = File(
          '${extracted.path}/programme.plan-package.yaml',
        ).readAsStringSync();
        final compiled = const PlanPackageCompiler().compile(programme);
        expect(compiled.isValid, true);
        expect(compiled.contentHashSha256, c.current!.packageHash);
        final index = jsonDecode(bundle.files['source-index.json']!) as Map;
        for (final row in index['sessions'] as List) {
          final tuple = row['identity'];
          final identity =
              [SyntheticStrengthLineage.a, SyntheticStrengthLineage.b]
                  .singleWhere((l) => l.id == tuple['session_lineage_id'])
                  .identity(tuple['revision_number'] as int);
          expect(identity.protocolId, tuple['protocol_id']);
          final yaml = File(
            '${extracted.path}/${row['path']}',
          ).readAsStringSync();
          final session = await c.compiler.compileExact(yaml, identity);
          expect(session.sourceDigest, row['source_digest']);
          expect(session.profileFingerprint, row['profile_fingerprint']);
          expect(session.bindings, row['exercise_bindings']);
        }
        for (final e in (index['files_sha256'] as Map).entries) {
          expect(d2SourceDigest(bundle.files[e.key]!), e.value);
        }
        expect(bundle.files['review.json'], packet);
        final reopened = await const SyntheticCompositionHandoff().read(
          bundle.files['review.json']!,
          c.compiler,
        );
        expect(
          CanonicalSourceBundle.fromReview(reopened).archiveBytes,
          bundle.archiveBytes,
        );
        expect(jsonDecode(packet)['version'], withB ? 2 : 1);
        expect(c.programme.draftSource, source);
        expect(c.owners, owners);
      },
    );
  }

  test(
    'conflicting receipt claims cannot be wrapped as canonical sources',
    () async {
      final c = await open();
      expect(await c.validate(), true);
      final r = c.current!;
      final forged = CompositionReviewReceipt(
        programmeSource: r.programmeSource,
        canonicalJson: r.canonicalJson,
        packageHash: 'forged',
        entries: r.sessions,
        slots: r.slotBindings,
      );
      expect(
        () => CanonicalSourceBundle.fromReview(forged),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'author can download exact sources from summary and separately reopened review',
    (t) async {
      final downloads = <CanonicalSourceBundle>[];
      final c = await mount(t, downloadSources: downloads.add);
      await tap(t, find.text('Export complete review'));
      expect(
        find.textContaining('does not save an editable project'),
        findsOneWidget,
      );
      await tap(t, find.text('Download canonical sources'));
      expect(downloads.length, 1);
      expect(
        downloads.single.files['programme.plan-package.yaml'],
        c.programme.draftSource,
      );
      expect(find.textContaining('Source download requested.'), findsOneWidget);
      final source = c.programme.draftSource;
      await tap(t, find.text('Open exported review'));
      await t.enterText(
        find.widgetWithText(TextField, 'Paste review export'),
        downloads.single.files['review.json']!,
      );
      await tap(t, find.text('Open read-only review'));
      await tap(t, find.text('Copy review export'));
      await tap(t, find.text('Download canonical sources'));
      expect(downloads.length, 2);
      expect(downloads.first.archiveBytes, downloads.last.archiveBytes);
      expect(c.programme.draftSource, source);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'cross-owner edit at awaited download consumption writes nothing',
    (t) async {
      final c = ConsumptionRaceController();
      var downloads = 0;
      await mount(t, supplied: c, downloadSources: (_) => downloads++);
      await createB(c);
      await c.admit(c.secondSession.revisions.single);
      await t.pumpAndSettle();
      await tap(t, find.text('Export complete review'));
      c.queueEdit = true;
      c.queueSecondOwner = true;
      await tap(t, find.text('Download canonical sources'));
      expect(downloads, 0);
      expect(find.text('Review export changed'), findsOneWidget);
    },
  );

  testWidgets('reset during download callback cannot announce late success', (
    t,
  ) async {
    late SyntheticCompositionController c;
    c = await mount(
      t,
      downloadSources: (_) {
        c.reset();
      },
    );
    await tap(t, find.text('Export complete review'));
    await tap(t, find.text('Download canonical sources'));
    expect(find.textContaining('Source download requested.'), findsNothing);
    expect(find.text('Review export changed'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'unavailable platform download preserves copy recovery and workspace',
    (t) async {
      final c = await mount(
        t,
        downloadSources: (_) => throw UnsupportedError('test platform'),
      );
      final source = c.programme.draftSource;
      await tap(t, find.text('Export complete review'));
      await tap(t, find.text('Download canonical sources'));
      expect(find.text('Copy review export'), findsOneWidget);
      await tap(t, find.text('Close'));
      expect(
        find.textContaining('Source download could not start.'),
        findsOneWidget,
      );
      expect(c.programme.draftSource, source);
    },
  );
}
