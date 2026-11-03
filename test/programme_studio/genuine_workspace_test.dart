import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_session_source.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_form_fields.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_export/canonical_source_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> sourceFiles(String directory) => {
  for (final name in [
    'SOURCE.json',
    'SCHEDULE_CANDIDATE.json',
    'STRENGTH_REVIEW_GRAPHS.json',
    'RUNNING_BODIES.json',
    'IDENTITY_INTAKE.json',
  ])
    name: File('$directory/$name').readAsStringSync(),
};
GenuineWorkspace selectedWorkspace() => GenuineWorkspace.fromSelectedSources(
  sourceFiles(hybridSourceDirectory),
  historicalSources: [sourceFiles(archivedHybridSourceDirectory)],
);

void main() {
  test(
    'selected occurrence review never follows the newest owner revision implicitly',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final original = c.selected('LW10K-W01-D02'),
          bytes = c.selected('LW10K-W01-D02').source;
      c.place(0, 5, original);
      c.begin(original);
      final owner = c.ownerOf(original);
      c.edit(
        owner,
        (g) => g['blocks'][0]['content'] = 'Deliberate later source note',
      );
      expect(c.freeze(owner), isTrue, reason: c.errors.join('\n'));
      final later = owner.latest;
      c.useRevision(later, ['LW10K-W01-D02'], c.generation);
      expect(
        c.inspectRevision(c.selected('LW10K-W01-D02')).readable,
        contains('Deliberate later source note'),
      );
      final previousUse = c.occurrences.singleWhere((s) => s['day'] == 6);
      expect(
        c
            .inspectRevision(c.selected(previousUse['slot_key'] as String))
            .readable,
        isNot(contains('Deliberate later source note')),
      );
      expect(original.source, bytes);
      final token = c.generation;
      c.programme.editProgramme('name', 'Changed');
      expect(
        () => c.useRevision(original, ['LW10K-W01-D02'], token),
        throwsStateError,
      );
    },
  );
  test(
    'invalid strength input, lower-bound RIR, unknown draft keys and frozen source rewrite guards',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final monday = c.selected('LW10K-W01-D01');
      c.begin(monday);
      final owner = c.ownerOf(monday);
      c.edit(
        owner,
        (g) => g['blocks'][1]['exercises'][0]['prescription']['sets'] =
            'not a number',
      );
      expect(c.inspect(owner).issues.join('\n'), contains('Sets must be'));
      final text = c.save(), reopened = c.prepareOpen(c.save());
      addTearDown(reopened.candidate.dispose);
      expect(reopened.candidate.save(), text);
      final raw = jsonDecode(text) as Map;
      final draft =
          jsonDecode(raw['owners'][0]['draft']['source'] as String) as Map;
      draft['blocks'][1]['exercises'][0]['prescription']['unsupported_field'] =
          {};
      raw['owners'][0]['draft']['source'] = jsonEncode(draft);
      expect(() => c.prepareOpen(jsonEncode(raw)), throwsFormatException);
      final taper = c.inspectRevision(c.selected('LW10K-W10-D04'));
      expect(taper.readable, contains('at least 3'));
      final tampered = jsonDecode(c.save()) as Map;
      final root = tampered['owners'][0]['revisions'][0];
      final graph = jsonDecode(root['source'] as String);
      graph['blocks'][0]['content'] = 'rewritten';
      root['source'] = jsonEncode(graph);
      root['sha256'] = nativeDigest(root['source'] as String);
      expect(() => c.prepareOpen(jsonEncode(tampered)), throwsFormatException);
    },
  );
  test(
    'full selected source retains all 70 days/105 prescriptions; exact pending identity status and final distance',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      expect(c.occurrences, hasLength(60));
      expect(c.programme.tree!['weeks'], hasLength(10));
      expect(
        (c.programme.tree!['weeks'] as List)
            .expand((w) => w['days'] as List)
            .where((d) => d['day_type'] == 'rest'),
        hasLength(10),
      );
      File(
        '/private/tmp/m11_performance_full_selected_editable_workspace.json',
      ).writeAsStringSync(c.save());
      final receipts = [for (final o in c.owners.values) c.inspect(o)];
      expect(receipts.where((r) => r.admitted), hasLength(40));
      expect(receipts.expand((r) => r.issues), hasLength(28));
      expect(
        receipts.expand((r) => r.issues),
        everyElement(contains('Unresolved exercise setup')),
      );
      final graphs = c.owners.values.map((o) => jsonDecode(o.latest.source));
      expect(
        graphs
            .expand((g) => g['blocks'] as List)
            .expand((b) => b['exercises'] as List),
        hasLength(105),
      );
      final threshold = c.selected('LW10K-W04-D02');
      expect(c.sessionLabel(threshold), contains('Source week 4 Tuesday'));
      expect(c.sessionLabel(threshold), contains('Consolidation threshold'));
      final b = (jsonDecode(threshold.source)['blocks'] as List).single;
      expect(runningTotals(b['timer_config']['running_workout']), (
        seconds: 2550,
        metres: 0,
      ));
      final finalRun = c.selected('LW10K-W10-D07');
      final finalBlock = (jsonDecode(finalRun.source)['blocks'] as List).single;
      expect(runningTotals(finalBlock['timer_config']['running_workout']), (
        seconds: 1200,
        metres: 10000,
      ));
      expect(await c.refreshReview(), isFalse);
      expect(c.errors, hasLength(28));
    },
  );
  test(
    'actual editable round trip preserves every source byte, notes, invalid draft and stale-open guards',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final run = c.selected('LW10K-W04-D02');
      c.begin(run);
      final owner = c.ownerOf(run);
      c.edit(
        owner,
        (g) =>
            g['blocks'][0]['timer_config']['running_workout']['steps'][0]['duration']['milliseconds'] =
                'invalid',
      );
      final text = c.save();
      expect(utf8.encode(text).length, lessThan(2 * 1024 * 1024));
      final open = c.prepareOpen(text);
      addTearDown(open.candidate.dispose);
      expect(open.candidate.save(), text);
      expect(
        open.candidate.ownerOf(open.candidate.selected('LW10K-W04-D02')).draft,
        owner.draft,
      );
      expect(c.isCurrentOpen(open), isTrue);
      c.cancel(owner);
      expect(c.isCurrentOpen(open), isFalse);
      expect(
        () => c.prepareOpen(text.replaceFirst('"version": 4', '"version": 5')),
        throwsFormatException,
      );
      final tampered = jsonDecode(text) as Map;
      tampered['owners'][0]['revisions'][0]['sha256'] = 'changed';
      expect(() => c.prepareOpen(jsonEncode(tampered)), throwsFormatException);
    },
  );
  test(
    'repeat convenience emits between-only and last-recovery shapes distinctly',
    () {
      final work = nativePhase(
        seconds: 300,
        title: 'Threshold',
        target: {'kind': 'alpha_quality_pace_v1', 'category': 'threshold'},
      );
      final recovery = nativePhase(
        role: 'recovery',
        seconds: 90,
        title: 'Very easy',
      );
      final between = expandRepeat(
        work: work,
        recovery: recovery,
        count: 4,
        recoveryAfterLast: false,
      );
      expect(between, hasLength(7));
      expect(runningTotals({'steps': between}).seconds, 1470);
      expect(
        expandRepeat(
          work: work,
          recovery: recovery,
          count: 4,
          recoveryAfterLast: true,
        ),
        hasLength(8),
      );
    },
  );
  test(
    'async review cannot install stale results after source edits',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final hold = Completer<void>();
      final operation = c.refreshReview(beforeCommit: () => hold.future);
      c.programme.editNativeArrangement(
        (t) => t['programme']['name'] = 'Changed',
      );
      hold.complete();
      expect(await operation, isFalse);
      expect(c.reviewCurrent, isFalse);
    },
  );
  test(
    'observer edits during programme validation expire the joint review',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      c.setWeeks(1);
      c.rest(0, 0);
      c.rest(0, 3);
      c.excludeUnusedSources();
      var changed = false;
      c.programme.addListener(() {
        if (!changed && c.programme.isCurrent) {
          changed = true;
          c.programme.editProgramme('name', 'Observer changed source');
        }
      });
      expect(await c.refreshReview(), isFalse);
      expect(c.reviewCurrent, isFalse);
    },
  );
  test(
    'all forty running bodies export/reimport exactly, including selected threshold and final 10K',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      for (var w = 0; w < 10; w++) {
        c.rest(w, 0);
        c.rest(w, 3);
      }
      c.programme.editProgramme(
        'name',
        'Running-only source contract proof — incomplete Hybrid programme',
      );
      c.programme.editProgramme('sessions_per_week', '4');
      c.excludeUnusedSources();
      expect(await c.refreshReview(), isTrue, reason: c.errors.join('\n'));
      final export = NativeSourceBundle.prepare(c);
      final restored = NativeSourceBundle.open(
        export.transport.archiveBytes,
        c.catalogue,
      );
      addTearDown(restored.dispose);
      expect(restored.policy.graphs, c.policy.graphs);
      expect(restored.occurrences, hasLength(40));
      expect(
        restored.inspectRevision(restored.selected('LW10K-W04-D02')).readable,
        contains('42:30'),
      );
      expect(
        restored.inspectRevision(restored.selected('LW10K-W10-D07')).readable,
        contains('10000 m'),
      );
      expect(
        restored.inspectRevision(restored.selected('LW10K-W10-D07')).readable,
        contains('20:00'),
      );
      File(
        '/private/tmp/m11_performance_verified_all_running_sources.tar',
      ).writeAsBytesSync(export.transport.archiveBytes);
    },
  );
  test(
    'actual native TAR/package/body artifact reimport; independent edits expire export',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      c.setWeeks(1);
      c.rest(0, 0);
      c.rest(0, 3);
      c.excludeUnusedSources();
      expect(c.occurrences, hasLength(4));
      expect(await c.refreshReview(), isTrue, reason: c.errors.join('\n'));
      final bundle = NativeSourceBundle.prepare(c);
      final files = NativeSourceBundle.verify(
        bundle.transport.archiveBytes,
        c.catalogue,
      );
      final reopened = NativeSourceBundle.open(
        bundle.transport.archiveBytes,
        c.catalogue,
      );
      addTearDown(reopened.dispose);
      expect(
        await reopened.refreshReview(),
        isTrue,
        reason: reopened.errors.join('\n'),
      );
      expect(reopened.policy.graphs, c.policy.graphs);
      expect(reopened.programme.draftSource, c.programme.draftSource);
      final savedAgain = reopened.prepareOpen(reopened.save());
      addTearDown(savedAgain.candidate.dispose);
      expect(savedAgain.candidate.save(), reopened.save());
      File(
        '/private/tmp/m11_performance_verified_canonical_sources.tar',
      ).writeAsBytesSync(bundle.transport.archiveBytes);
      File(
        '/private/tmp/m11_performance_verified_editable_workspace.json',
      ).writeAsStringSync(c.save());
      final tampered = Map<String, String>.of(files);
      tampered['protocol-graphs.json'] = '[]';
      expect(
        () => NativeSourceBundle.verify(
          CanonicalSourceBundle.native(tampered).archiveBytes,
          c.catalogue,
        ),
        throwsFormatException,
      );
      c.programme.editProgramme('name', 'Changed source');
      expect(() => NativeSourceBundle.prepare(c), throwsFormatException);
    },
  );
}
