import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_export/canonical_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_intake/canonical_source_intake.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_source_guard.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_yaml_writer.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_review_bridge.dart';
import 'four_week_schedule_test.dart' show setup, choices;
import 'synthetic_strength_lineages_test.dart'
    show createB, DeferredLineageCompiler;

/// Standard system TAR creates independent headers/metadata, rather than using
/// the production writer to manufacture every successful reader fixture.
Uint8List packSourceFiles(Map<String, String> files) {
  final dir = Directory.systemTemp.createTempSync('cohort-source-intake-');
  try {
    for (final e in files.entries) {
      final f = File('${dir.path}/${e.key}');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(e.value);
    }
    final output = '${dir.path}/sources.tar';
    final result = Process.runSync('tar', [
      '--format',
      'ustar',
      '-cf',
      output,
      '-C',
      dir.path,
      ...(files.keys.toList()..sort()),
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return File(output).readAsBytesSync();
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void refreshFileClaims(Map<String, String> files) {
  final index = jsonDecode(files['source-index.json']!) as Map;
  final programme = files['programme.plan-package.yaml']!;
  final hash = const PlanPackageCompiler().compile(programme).contentHashSha256;
  index['programme']['source_digest'] = d2SourceDigest(programme);
  if (hash != null) index['programme']['package_hash'] = hash;
  final review = jsonDecode(files['review.json']!) as Map;
  review['programme_yaml'] = programme;
  if (hash != null) review['package_hash'] = hash;
  files['review.json'] = jsonEncode(review);
  index['files_sha256'] = {
    for (final p in files.keys.where(
      (p) => p != 'source-index.json' && p != 'README.md',
    ))
      p: d2SourceDigest(files[p]!),
  };
  files['source-index.json'] = jsonEncode(index);
}

Uint8List headerChange(
  Uint8List source,
  void Function(Uint8List) change, {
  bool checksum = true,
}) {
  final bytes = Uint8List.fromList(source);
  change(bytes);
  if (checksum) {
    bytes.fillRange(148, 156, 32);
    final sum = bytes.take(512).fold<int>(0, (s, b) => s + b);
    bytes.setRange(
      148,
      156,
      ascii.encode('${sum.toRadixString(8).padLeft(6, '0')}\x00 '),
    );
  }
  return bytes;
}

void main() {
  Future<SyntheticCompositionController> fixture({
    DeferredLineageCompiler? compiler,
  }) async {
    final c = SyntheticCompositionController(compiler: compiler);
    await c.ready;
    addTearDown(c.dispose);
    c.session.createDraft();
    c.session.cancelDraft(); // missing A2
    c.session.createDraft();
    c.session.editExercise(0, 'reps', '6');
    expect(await c.session.freeze(), true);
    expect(await c.admit(c.session.revisions.last), true);
    await createB(c);
    await setup(c);
    final use = (await c.prepareUseVersion(
      'W3D1S1',
      c.session.revisions.last,
    ))!;
    expect(await c.usePreparedVersion(use), true);
    expect(await c.validate(), true);
    return c;
  }

  Future<CanonicalSourceBundle> bundle() async =>
      CanonicalSourceBundle.fromReview((await fixture()).current!);

  test(
    'source ownership is new, lossless and inventory-local; omitted history is never fabricated',
    () async {
      final original = await fixture();
      final before = choices(original), source = original.programme.draftSource;
      final packageHash = original.current!.packageHash;
      // This private A4 is omitted, so a new source workspace cannot know it.
      original.session.createDraft();
      original.session.editExercise(0, 'reps', '7');
      expect(await original.session.freeze(), true);
      expect(await original.validate(), true);
      final archive = CanonicalSourceBundle.fromReview(original.current!);
      final c = await SyntheticCompositionController.fromCanonicalSources(
        archive.archiveBytes,
      );
      addTearDown(c.dispose);
      expect(c.current, null);
      expect(c.reconstructed, null);
      expect(c.workspaceSaveRequested, false);
      expect(choices(c), before);
      expect(c.programme.draftSource, source);
      expect(c.session.revisions.map((r) => r.identity.revisionNumber), [1, 3]);
      expect(c.session.sourceImportHighWater, 3);
      final initial = jsonDecode(c.workspaceContents);
      expect(initial['version'], 3);
      final catalogue = initial['owners'][0]['catalogue'];
      expect(catalogue['source_import'], {
        'high_water': 3,
        'revision_numbers': [1, 3],
      });
      expect(catalogue['abandoned_ranges'], isEmpty);
      expect(
        (catalogue['frozen'] as List).every((r) => r['parent'] == null),
        true,
      );
      for (final r in c.session.revisions) {
        expect(c.session.isImportedSnapshot(r.identity.revisionNumber), true);
        expect(
          r.source,
          original.session.revisions
              .singleWhere(
                (s) => s.identity.revisionNumber == r.identity.revisionNumber,
              )
              .source,
        );
      }
      // Ordinary live admission remains tied to genuine owner objects.
      expect(await original.admit(c.session.revisions.last), false);
      expect(await c.admit(original.session.revisions.last), false);
      expect(await c.validate(), true);
      expect(c.current!.packageHash, packageHash);
      expect(CanonicalSourceBundle.fromReview(c.current!).files, archive.files);
      c.session.openRevision(3);
      c.session.createDraft();
      expect(c.session.activeIdentity.revisionNumber, 4);
      c.session.cancelDraft();
      c.session.createDraft();
      expect(c.session.activeIdentity.revisionNumber, 5);
      c.session.editExercise(0, 'reps', 'bad reps');
      final saved = (await c.saveEditableWorkspace())!;
      final reopened =
          await SyntheticCompositionController.restoreEditableWorkspace(saved);
      addTearDown(reopened.dispose);
      expect(reopened.workspaceContents, saved);
      expect(reopened.session.source, contains('bad reps'));
      expect(reopened.session.isImportedSnapshot(3), true);
      reopened.session.editExercise(0, 'reps', '9');
      expect(await reopened.session.freeze(), true);
      expect(reopened.session.isImportedSnapshot(5), false);
      final local = jsonDecode(
        reopened.workspaceContents,
      )['owners'][0]['catalogue'];
      expect(local['frozen'].last['parent'], 3);
      expect(local['abandoned_ranges'], [
        {'first': 4, 'last': 4},
      ]);
      expect(choices(reopened), before);
      final use = (await reopened.prepareUseVersion(
        'W4D1S1',
        reopened.session.revisions.last,
      ))!;
      expect(await reopened.usePreparedVersion(use), true);
      expect(choices(reopened)['W1D1S1'], before['W1D1S1']);
      expect(await reopened.exportHandoff(), isNotNull);
    },
  );
  test(
    'imported four-week edit survives editable and both export round trips without changing earlier prescriptions',
    () async {
      final initial = await bundle();
      final c = await SyntheticCompositionController.fromCanonicalSources(
        initial.archiveBytes,
      );
      addTearDown(c.dispose);
      final before = choices(c), locked = c.programme.tree!;
      c.session.openRevision(3);
      c.session.createDraft();
      c.session.editExercise(0, 'reps', '7');
      expect(await c.session.freeze(), true);
      expect(choices(c), before); // Save never selects.
      final pending = (await c.prepareUseVersion(
        'W4D1S1',
        c.session.revisions.last,
      ))!;
      expect(choices(c), before); // Consent is still required.
      expect(await c.usePreparedVersion(pending), true);
      final after = choices(c);
      for (final key in before.keys.where((k) => k != 'W4D1S1')) {
        expect(after[key], before[key], reason: key);
      }
      final saved = (await c.saveEditableWorkspace())!;
      final reopened =
          await SyntheticCompositionController.restoreEditableWorkspace(saved);
      addTearDown(reopened.dispose);
      expect(reopened.current, null);
      expect(reopened.workspaceContents, saved);
      expect(choices(reopened), after);
      reopened.secondSession.createDraft();
      reopened.secondSession.editExercise(0, 'reps', '10');
      expect(await reopened.secondSession.freeze(), true);
      expect(
        choices(reopened),
        after,
      ); // Continued private editing stays private.
      expect(await reopened.validate(), true);
      final receipt = reopened.current!;
      expect(receipt.slotBindings.length, 8);
      final output = CanonicalSourceBundle.fromReview(receipt);
      for (final e in initial.files.entries.where(
        (e) => e.key.startsWith('sessions/'),
      )) {
        expect(output.files[e.key], e.value, reason: e.key);
      }
      for (final key in [
        'phases',
        'adaptation_permissions',
        'protected_invariants',
        'assessments',
        'performance_evidence_requirements',
        'comparison_identities',
      ]) {
        expect(reopened.programme.tree![key], locked[key], reason: key);
      }
      final packet = (await reopened.exportHandoff())!;
      final liveState = reopened.workspaceContents;
      expect(output.files['review.json'], packet);
      expect(await reopened.reopen(packet), true);
      expect(reopened.reconstructedExport(), packet);
      expect(reopened.reconstructed!.slotBindings, receipt.slotBindings);
      expect(
        reopened.workspaceContents,
        liveState,
      ); // Review never replaces owners.
      final reimported =
          await SyntheticCompositionController.fromCanonicalSources(
            output.archiveBytes,
          );
      addTearDown(reimported.dispose);
      expect(reimported.session.isImportedSnapshot(4), true);
      expect(
        reimported.secondSession.revisions.length,
        1,
      ); // Private B2 was omitted.
      expect(await reimported.validate(), true);
      expect(
        CanonicalSourceBundle.fromReview(reimported.current!).files,
        output.files,
      );
      final imported = jsonDecode(
        reimported.workspaceContents,
      )['owners'][0]['catalogue'];
      expect(
        (imported['frozen'] as List).every((r) => r['parent'] == null),
        true,
      );
    },
  );
  test(
    'independently packed USTAR and harmless programme formatting/order preserve exact sources and meaning',
    () async {
      final files = Map<String, String>.of((await bundle()).files);
      final original = const PlanPackageCompiler().compile(
        files['programme.plan-package.yaml']!,
      );
      // YAML comments/indentation are retained without becoming hash authority.
      files['programme.plan-package.yaml'] =
          '# Retained author formatting\n${files['programme.plan-package.yaml']}';
      refreshFileClaims(files);
      final c = await SyntheticCompositionController.fromCanonicalSources(
        packSourceFiles(files),
      );
      addTearDown(c.dispose);
      expect(c.programme.draftSource, files['programme.plan-package.yaml']);
      expect(await c.validate(), true);
      expect(c.current!.packageHash, original.contentHashSha256);
      expect(c.programme.meaningChanged, false);
      expect(c.programme.originalSource, files['programme.plan-package.yaml']);
      final saved = (await c.saveEditableWorkspace())!;
      final reopened =
          await SyntheticCompositionController.restoreEditableWorkspace(saved);
      addTearDown(reopened.dispose);
      expect(
        reopened.programme.draftSource,
        files['programme.plan-package.yaml'],
      );
      reopened.programme.editProgramme('name', 'Synthetic deliberate edit');
      expect(await reopened.validate(), true);
      expect(reopened.current!.packageHash, isNot(original.contentHashSha256));
      expect(
        reopened.current!.sessions.map((s) => s.source),
        c.current!.sessions.map((s) => s.source),
      );
    },
  );
  test(
    'v1 index A-only legacy archive remains supported with empty B and v3 ownership',
    () async {
      final original = SyntheticCompositionController();
      await original.ready;
      addTearDown(original.dispose);
      expect(await original.validate(), true);
      final c = await SyntheticCompositionController.fromCanonicalSources(
        CanonicalSourceBundle.fromReview(original.current!).archiveBytes,
      );
      addTearDown(c.dispose);
      expect(c.secondSession.canCreateRoot, true);
      expect(c.admitted.length, 1);
      expect(await c.validate(), true);
      expect(await c.saveEditableWorkspace(), isNotNull);
    },
  );

  test(
    'equal-meaning imported versions have no invented no-op parent, while new local freezes still reject no-op',
    () async {
      final original = await fixture();
      final old = original.admitted.singleWhere(
        (s) => s.identity.revisionNumber == 3,
      );
      final tree = const FounderStrengthSourceGuard().canonicalTree(
        old.source,
        importKey: 'syn-d2-strength-r3',
      );
      FounderStrengthSourceGuard.exerciseRows(
        tree,
      ).first['prescription']['reps'] = 5;
      final compiler = SyntheticStrengthSessionCompiler(
        allowSecondLineage: true,
      );
      final same = await compiler.compileExact(
        const FounderStrengthYamlWriter().write(tree),
        old.identity,
      );
      expect(
        same.semanticJson,
        original.session.revisions.first.compiled.semanticJson,
      );
      final reviewed = reviewComposition(original.programme.draftSource, [
        for (final s in original.admitted) identical(s, old) ? same : s,
      ]);
      final c = await SyntheticCompositionController.fromCanonicalSources(
        CanonicalSourceBundle.fromReview(reviewed).archiveBytes,
      );
      addTearDown(c.dispose);
      expect(c.session.isImportedSnapshot(3), true);
      c.session.openRevision(3);
      c.session.createDraft();
      expect(await c.session.freeze(), false);
      expect(c.session.revisions.length, 2);
    },
  );

  test(
    'maximum imported revision preserves unknown gaps and refuses allocation without wrapping or reuse',
    () async {
      final original = await fixture();
      final old = original.admitted.singleWhere(
        (s) => s.identity.revisionNumber == 3,
      );
      final identity = original.session.lineage.identity(1000000);
      final tree = const FounderStrengthSourceGuard().canonicalTree(
        old.source,
        importKey: 'syn-d2-strength-r3',
      );
      tree['programme']['import_key'] = 'syn-d2-strength-r1000000';
      final compiler = SyntheticStrengthSessionCompiler(
        allowSecondLineage: true,
      );
      final largest = await compiler.compileExact(
        const FounderStrengthYamlWriter().write(tree),
        identity,
      );
      final programme = original.programme.draftSource
          .replaceAll(old.identity.protocolId, identity.protocolId)
          .replaceAll('SYN-D2-STRENGTH-R3', 'SYN-D2-STRENGTH-R1000000')
          .replaceAll('revision_number: 3', 'revision_number: 1000000');
      final reviewed = reviewComposition(programme, [
        for (final s in original.admitted) identical(s, old) ? largest : s,
      ]);
      final c = await SyntheticCompositionController.fromCanonicalSources(
        CanonicalSourceBundle.fromReview(reviewed).archiveBytes,
      );
      addTearDown(c.dispose);
      c.session.openRevision(1000000);
      final before = c.workspaceContents;
      c.session.createDraft();
      expect(c.session.isEditing, false);
      expect(c.session.errors.join(), contains('revision_limit'));
      expect(c.workspaceContents, before);
      expect(await c.saveEditableWorkspace(), isNotNull);
    },
  );

  test(
    'invalid UTF-8 and nonzero body padding refuse before source reconstruction',
    () async {
      final source = (await bundle()).archiveBytes;
      final invalid = Uint8List.fromList(source)..[512] = 255;
      expect(() => readCanonicalArchive(invalid), throwsFormatException);
      final size = int.parse(ascii.decode(source.sublist(124, 135)), radix: 8);
      expect(size % 512, isNot(0));
      final padding = Uint8List.fromList(source)..[512 + size] = 1;
      expect(() => readCanonicalArchive(padding), throwsFormatException);
    },
  );

  final headerAttacks = <String, Uint8List Function(Uint8List)>{
    'checksum': (b) => headerChange(b, (h) => h[0] ^= 1, checksum: false),
    'absolute path': (b) => headerChange(b, (h) => h[0] = 47),
    'parent path': (b) => headerChange(b, (h) {
      h.fillRange(0, 100, 0);
      h.setRange(0, 6, ascii.encode('../bad'));
    }),
    'symlink': (b) => headerChange(b, (h) => h[156] = 50),
    'hard link': (b) => headerChange(b, (h) => h[156] = 49),
    'PAX extension': (b) => headerChange(b, (h) => h[156] = 120),
    'directory': (b) => headerChange(b, (h) => h[156] = 53),
    'future container': (b) => headerChange(b, (h) => h[263] = 49),
    'prefixed path': (b) => headerChange(b, (h) => h[345] = 120),
    'hidden path suffix': (b) => headerChange(b, (h) => h[99] = 120),
    'binary size': (b) => headerChange(b, (h) => h[124] = 128),
    'huge body': (b) => headerChange(
      b,
      (h) => h.setRange(124, 136, ascii.encode('77777777777\x00')),
    ),
    'missing terminator': (b) =>
        Uint8List.fromList(b.sublist(0, b.length - 1024)),
    'truncated header': (b) => Uint8List.fromList(b.sublist(0, b.length - 1)),
    'trailing data': (b) =>
        Uint8List.fromList([...b, ...List.filled(511, 0), 1]),
    'size bound': (_) => Uint8List(canonicalArchiveMaxBytes + 512),
    'duplicate entry': (b) {
      final size = int.parse(ascii.decode(b.sublist(124, 135)), radix: 8);
      final end = 512 + ((size + 511) ~/ 512) * 512;
      return Uint8List.fromList([
        ...b.sublist(0, b.length - 1024),
        ...b.sublist(0, end),
        ...List.filled(1024, 0),
      ]);
    },
  };
  for (final attack in headerAttacks.entries) {
    test('untrusted archive refuses ${attack.key}', () async {
      final archive = await bundle();
      expect(
        () => readCanonicalArchive(attack.value(archive.archiveBytes)),
        throwsFormatException,
      );
    });
  }
  final sourceAttacks = <String, void Function(Map<String, String>)>{
    'missing required file': (f) => f.remove('review.json'),
    'missing declared session': (f) =>
        f.remove('sessions/session-a-v3.founder.yaml'),
    'extra source': (f) => f['sessions/session-a-v99.founder.yaml'] =
        f['sessions/session-a-v3.founder.yaml']!,
    'unknown index version': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['version'] = 99;
      f['source-index.json'] = jsonEncode(m);
    },
    'duplicate index keys': (f) =>
        f['source-index.json'] = f['source-index.json']!.replaceFirst(
          '"version": 1',
          '"version": 1, "\\u0076ersion": 1',
        ),
    'index extra authority': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['approved'] = true;
      f['source-index.json'] = jsonEncode(m);
    },
    'digest claim': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['files_sha256']['programme.plan-package.yaml'] = '0' * 64;
      f['source-index.json'] = jsonEncode(m);
    },
    'foreign protocol': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['sessions'][0]['identity']['protocol_id'] = 'foreign';
      f['source-index.json'] = jsonEncode(m);
    },
    'foreign lineage': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['sessions'][0]['identity']['session_lineage_id'] = 'foreign';
      f['source-index.json'] = jsonEncode(m);
    },
    'duplicate revision': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['sessions'].add(m['sessions'][0]);
      f['source-index.json'] = jsonEncode(m);
    },
    'exercise binding': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['sessions'][0]['exercise_bindings'] = {
        'cohort.exercise.d2_fixture_a': 'EX-9001@9',
      };
      f['source-index.json'] = jsonEncode(m);
    },
    'profile': (f) {
      final m = jsonDecode(f['source-index.json']!);
      m['sessions'][0]['profile_fingerprint'] = 'foreign';
      f['source-index.json'] = jsonEncode(m);
    },
    'unsupported session field with fresh file claims': (f) {
      f['sessions/session-a-v3.founder.yaml'] =
          '${f['sessions/session-a-v3.founder.yaml']}unsupported: true\n';
      refreshFileClaims(f);
    },
    'unsupported representation with fresh file claims': (f) {
      f['sessions/session-a-v3.founder.yaml'] =
          f['sessions/session-a-v3.founder.yaml']!.replaceFirst(
            '"strength"',
            '"circuit"',
          );
      refreshFileClaims(f);
    },
    'unsupported programme field': (f) {
      f['programme.plan-package.yaml'] =
          '${f['programme.plan-package.yaml']}unsupported: true\n';
      refreshFileClaims(f);
    },
    'duplicate YAML keys': (f) {
      f['programme.plan-package.yaml'] =
          '${f['programme.plan-package.yaml']}package_schema_version: 1\n';
      refreshFileClaims(f);
    },
    'locked assessment retarget with coherent hash': (f) {
      f['programme.plan-package.yaml'] = f['programme.plan-package.yaml']!
          .replaceFirst('slot_ref: "W1D1S1"', 'slot_ref: "W2D1S1"');
      refreshFileClaims(f);
    },
    'forged review success': (f) {
      final m = jsonDecode(f['review.json']!);
      m['approved'] = true;
      f['review.json'] = jsonEncode(m);
      final i = jsonDecode(f['source-index.json']!);
      i['files_sha256']['review.json'] = d2SourceDigest(f['review.json']!);
      f['source-index.json'] = jsonEncode(i);
    },
    'future review version': (f) {
      final m = jsonDecode(f['review.json']!);
      m['version'] = 99;
      f['review.json'] = jsonEncode(m);
      final i = jsonDecode(f['source-index.json']!);
      i['files_sha256']['review.json'] = d2SourceDigest(f['review.json']!);
      f['source-index.json'] = jsonEncode(i);
    },
  };
  for (final attack in sourceAttacks.entries) {
    test(
      'complete source validation refuses ${attack.key} atomically',
      () async {
        final live = await fixture();
        final before = live.workspaceContents,
            owner = live.session,
            receipt = live.current;
        final files = Map<String, String>.of(
          CanonicalSourceBundle.fromReview(receipt!).files,
        );
        attack.value(files);
        await expectLater(
          live.prepareCanonicalSources(packSourceFiles(files)),
          throwsFormatException,
        );
        expect(live.workspaceContents, before);
        expect(live.session, same(owner));
        expect(live.current, same(receipt));
      },
    );
  }
  test(
    'preparation/cancel preserves all work and successful install resets receipts without restoring supplied history',
    () async {
      final live = await fixture();
      final archive = CanonicalSourceBundle.fromReview(live.current!);
      final before = live.workspaceContents,
          owner = live.session,
          receipt = live.current;
      final cancelled = (await live.prepareCanonicalSources(
        archive.archiveBytes,
      ))!;
      expect(cancelled.canonicalSources, true);
      expect(cancelled.importedVersions, 3);
      expect(live.workspaceContents, before);
      expect(live.current, same(receipt));
      cancelled.dispose();
      expect(await live.replaceEditableWorkspace(cancelled), false);
      final p = (await live.prepareCanonicalSources(archive.archiveBytes))!;
      expect(await live.replaceEditableWorkspace(p), true);
      expect(live.session, isNot(same(owner)));
      expect(live.current, null);
      expect(live.session.hasImportedSnapshots, true);
      expect(live.workspaceSaveRequested, false);
      expect(await live.validate(), true);
    },
  );
  for (final change in ['edit', 'reset', 'dispose', 'new transfer']) {
    test(
      'pending intake rejects stale $change without replacing owners',
      () async {
        final compiler = DeferredLineageCompiler();
        final live = await fixture(compiler: compiler);
        final archive = CanonicalSourceBundle.fromReview(live.current!);
        compiler.pauseLineage = live.session.lineage.id;
        final pending = live.prepareCanonicalSources(archive.archiveBytes);
        while (compiler.gate == null) {
          await Future<void>.delayed(Duration.zero);
        }
        if (change == 'edit') {
          live.programme.editProgramme('description', 'Synthetic pending edit');
        }
        if (change == 'reset') await live.reset();
        if (change == 'dispose') live.dispose();
        if (change == 'new transfer') {
          final p = (await live.prepareEditableWorkspace(
            live.workspaceContents,
          ))!;
          p.dispose();
        }
        final owner = live.session, source = live.programme.draftSource;
        compiler.gate!.complete();
        expect(await pending, null);
        expect(live.session, same(owner));
        expect(live.programme.draftSource, source);
      },
    );
  }
  for (final tamper in [
    'parent',
    'lower high-water',
    'missing snapshot',
    'forged abandoned history',
    'future format',
  ]) {
    test('v3 rejects inconsistent imported origin $tamper', () async {
      final archive = await bundle();
      final c = await SyntheticCompositionController.fromCanonicalSources(
        archive.archiveBytes,
      );
      addTearDown(c.dispose);
      final m = jsonDecode(c.workspaceContents);
      final s = m['owners'][0]['catalogue'];
      switch (tamper) {
        case 'parent':
          s['frozen'][1]['parent'] = 1;
        case 'lower high-water':
          s['highest_reserved'] = 1;
        case 'missing snapshot':
          s['source_import']['revision_numbers'] = [1, 2, 3];
        case 'forged abandoned history':
          s['abandoned_ranges'] = [
            {'first': 2, 'last': 2},
          ];
        case 'future format':
          m['version'] = 4;
      }
      final before = c.workspaceContents;
      await expectLater(
        c.prepareEditableWorkspace(jsonEncode(m)),
        throwsFormatException,
      );
      expect(c.workspaceContents, before);
    });
  }
}
