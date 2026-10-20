import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/programme_studio/apollo_pilot/apollo_pilot.dart';
import 'package:cohort_platform/features/programme_studio/apollo_pilot/apollo_pilot_pin.dart';
import 'package:cohort_platform/features/programme_studio/projection/movement_prescription_review.dart';
import 'package:cohort_platform/features/programme_studio/workspace_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'protocol_authoring_isolation_test.dart' as traversal;

Map<String, String> pilotInputs() => {
  for (final p in ApolloPilotPin.files.keys) p: File(p).readAsStringSync(),
};
const mainKey = '${ApolloPilotSource.strengthBlock}/2/EX-079';
const lungeKey = '${ApolloPilotSource.strengthBlock}/3/EX-025';
const carryKey = '${ApolloPilotSource.strengthBlock}/5/EX-101';
void main() {
  late ApolloPilotSource source;
  setUpAll(() => source = ApolloPilotSource.read(pilotInputs()));
  ApolloPilotController create() => ApolloPilotController(source);
  test(
    'Apollo pilot remains separate from production and synthetic authoring trust',
    () {
      for (final entry in [
        'lib/main.dart',
        'lib/main_programme_studio_preview.dart',
        'lib/main_programme_studio_authoring_preview.dart',
        'lib/main_programme_studio_protocol_authoring_preview.dart',
        'lib/main_programme_studio_composition_preview.dart',
      ]) {
        expect(
          traversal
              .reachable(entry, strict: false)
              .where((p) => p.contains('/apollo_pilot/')),
          isEmpty,
          reason: entry,
        );
      }
      expect(
        traversal
            .reachable('lib/main_programme_studio_apollo_pilot.dart')
            .where(
              (p) =>
                  p.contains('/composition/') ||
                  p.contains('/protocol_authoring/') ||
                  p.contains('founder_programme_import_service') ||
                  p.contains('supabase_service'),
            ),
        isEmpty,
      );
    },
  );
  test('exact corrected source review includes all ten rows and guidance', () {
    expect(source.session.protocolId, ApolloPilotSource.originalProtocol);
    expect(source.session.blocks, hasLength(2));
    expect(
      source.session.blocks.first.coachNotes,
      'Then complete progressive trap-bar warm-up sets.',
    );
    expect(
      source.protocol.purpose,
      'Reduced-fatigue power and athletic strength.',
    );
    expect(
      source.protocol.coachingNotes,
      'All resistance work is approximately 3 RIR; no conditioning.',
    );
    expect(
      source.retainedDefaultGuidance,
      contains('controlled 3-second eccentric'),
    );
    expect(
      source.retainedDefaultGuidance,
      contains('no artificial tempo unless explicitly stated'),
    );
    expect(source.profileRows, hasLength(10));
    for (final b in source.session.blocks) {
      for (final m in b.movements) {
        final review = MovementPrescriptionReview.fromMovement(m);
        expect(review.complete, isTrue, reason: m.name);
      }
    }
    expect(
      source.movement(mainKey).rawPrescription,
      '{"sets":2,"reps":"4-6","rir":3,"rest_seconds":"150-180"}',
    );
    expect(source.sources, pilotInputs());
  });
  test('complete source/profile and immutable model cannot be mutated', () {
    expect(() => source.sources.clear(), throwsUnsupportedError);
    expect(() => source.profileRows.clear(), throwsUnsupportedError);
    expect(() => source.session.blocks.clear(), throwsUnsupportedError);
    expect(
      () => source.session.blocks.first.movements.clear(),
      throwsUnsupportedError,
    );
  });
  for (final path in ApolloPilotPin.files.keys) {
    test('changed pinned input refuses: $path', () {
      expect(
        () => ApolloPilotSource.read(
          pilotInputs()..[path] = '${pilotInputs()[path]} ',
        ),
        throwsFormatException,
      );
    });
  }
  test('missing and unknown inputs fail closed', () {
    expect(
      () => ApolloPilotSource.read(
        pilotInputs()..remove(ApolloPilotPin.files.keys.first),
      ),
      throwsFormatException,
    );
    expect(
      () => ApolloPilotSource.read(pilotInputs()..['unknown'] = 'x'),
      throwsFormatException,
    );
  });
  test(
    'full supported edit revision compare select save reopen source recompile workflow',
    () {
      final c = create();
      final original = c.saveWorkspace();
      c.edit(mainKey, 'sets', '4');
      c.edit(mainKey, 'reps', '5-7');
      c.edit(mainKey, 'rir', '2');
      c.edit(mainKey, 'rest_seconds', '160-190');
      c.edit(lungeKey, 'reps', '9/leg');
      c.edit(carryKey, 'sets', '3');
      final revision = c.freeze();
      expect(c.selected.number, 1, reason: 'Freeze does not select');
      final prepared = c.prepareUse(revision);
      expect(prepared.changes, hasLength(3));
      final changes = prepared.changes.firstWhere((v) => v.key == mainKey);
      expect(changes.before, contains('4-6 reps'));
      expect(changes.after, contains('5-7 reps'));
      expect(changes.after, contains('RIR (authored): 2'));
      c.confirmUse(prepared);
      final saved = c.saveWorkspace();
      final reopened = ApolloPilotController.reopen(saved);
      expect(reopened.saveWorkspace(), saved);
      expect(reopened.selected.digest, revision.digest);
      final exported = source.exportCanonical(revision);
      final (restored, compiled) = ApolloPilotSource.recompileCanonical(
        exported,
      );
      expect(restored.exportCanonical(compiled), exported);
      expect(compiled.digest, revision.digest);
      expect(restored.sources, pilotInputs());
      expect(ApolloPilotController.reopen(original).selected.number, 1);
      expect(source.movement(mainKey).rawPrescription, contains('"sets":2'));
      expect(
        readWorkspaceJson(
          restored
              .reviewedMovement(carryKey, compiled.patches)
              .rawPrescription!,
        )['distance_m'],
        30,
      );
      expect(
        restored.session.blocks.first.toJson(),
        source.session.blocks.first.toJson(),
      );
    },
  );
  test('exact and per-leg reps and range rest retain original types', () {
    final c = create();
    const box = '${ApolloPilotSource.strengthBlock}/1/EX-059';
    c.edit(box, 'reps', '4');
    c.edit(lungeKey, 'reps', '10/leg');
    c.edit(mainKey, 'rest_seconds', '120-150');
    c.edit(mainKey, 'rir', '0');
    expect(c.draft[box]!['reps'], isA<int>());
    expect(c.draft[lungeKey]!['reps'], '10/leg');
    expect(c.draft[mainKey]!['rest_seconds'], '120-150');
    expect(c.draft[mainKey]!['rir'], 0);
  });
  for (final (key, field, text) in [
    (mainKey, 'reps', '5'),
    (mainKey, 'reps', '7-4'),
    (mainKey, 'reps', '4–6'),
    (mainKey, 'rest_seconds', '180'),
    (mainKey, 'rest_seconds', '150-120'),
    (mainKey, 'sets', '0'),
    (mainKey, 'sets', '2.5'),
    (mainKey, 'sets', '02'),
    (mainKey, 'rir', '2-3'),
    (mainKey, 'rir', '-1'),
    (mainKey, 'rir', '101'),
    (lungeKey, 'reps', '8'),
    (lungeKey, 'reps', '8/side'),
    (carryKey, 'distance_m', '40'),
    (carryKey, 'reps', '10'),
    (mainKey, 'load', '50'),
    (mainKey, 'exercise_id', 'EX-059'),
    ('b1400014-0000-4000-8000-000000000014/1/EX-155', 'sets', '2'),
    ('${ApolloPilotSource.strengthBlock}/2/EX-025', 'sets', '4'),
  ]) {
    test('unsupported edit refuses atomically $key $field=$text', () {
      final c = create();
      final before = c.saveWorkspace();
      expect(() => c.edit(key, field, text), throwsFormatException);
      expect(c.saveWorkspace(), before);
    });
  }
  test(
    'no prescription change, exact identity matching and immutable receipts',
    () {
      final c = create();
      final next = c.freeze();
      final selection = c.prepareUse(next);
      expect(selection.changes, isEmpty);
      expect(() => next.patches[mainKey] = {'sets': 9}, throwsUnsupportedError);
      c.edit(mainKey, 'sets', '4');
      final r3 = c.freeze();
      c.edit(mainKey, 'sets', '5');
      expect(r3.patches[mainKey]!['sets'], 4);
      expect(() => r3.patches[mainKey]!['sets'] = 99, throwsUnsupportedError);
      c.startFrom(next);
      expect(c.draft, isEmpty);
      c.edit(mainKey, 'sets', '4');
      c.edit(mainKey, 'sets', '2');
      expect(c.draft, isEmpty);
    },
  );
  test(
    'preparation cancellation and stale or foreign consent leave state unchanged',
    () {
      final c = create();
      c.edit(mainKey, 'sets', '4');
      final revision = c.freeze();
      final before = c.saveWorkspace();
      final prepared = c.prepareUse(revision);
      expect(
        c.saveWorkspace(),
        before,
        reason: 'preparation/cancellation do not install anything',
      );
      c.edit(mainKey, 'rir', '2');
      final changed = c.saveWorkspace();
      expect(() => c.confirmUse(prepared), throwsFormatException);
      expect(c.saveWorkspace(), changed);
      final foreign = create();
      final owned = c.prepareUse(revision);
      expect(() => foreign.confirmUse(owned), throwsFormatException);
      c.confirmUse(owned);
      final used = c.saveWorkspace();
      expect(() => c.confirmUse(owned), throwsFormatException);
      expect(c.saveWorkspace(), used);
    },
  );
  test(
    'save/freeze races invalidate selection and local instances select independently',
    () {
      final a = create(), b = create();
      final rev = a.freeze();
      final prepared = a.prepareUse(rev);
      a.freeze();
      expect(() => a.confirmUse(prepared), throwsFormatException);
      a.confirmUse(a.prepareUse(rev));
      expect(a.selected.number, 2);
      expect(b.selected.number, 1);
    },
  );
  test('bounded revision failure and foreign freshness token are atomic', () {
    final c = create();
    final stamp = c.stamp();
    c.edit(mainKey, 'sets', '4');
    c.edit(mainKey, 'sets', '2');
    expect(() => c.requireFresh(stamp), throwsFormatException);
    expect(() => create().requireFresh(c.stamp()), throwsFormatException);
    for (var i = 1; i < 128; i++) {
      c.freeze();
    }
    final before = c.saveWorkspace();
    expect(() => c.freeze(), throwsFormatException);
    expect(c.saveWorkspace(), before);
  });
  test(
    'duplicate keys, wrong formats, unknown fields and source tampering refuse',
    () {
      final c = create();
      final saved = c.saveWorkspace();
      expect(
        () => ApolloPilotController.reopen(
          saved.replaceFirst('"selected": 1', '"selected": 1, "selected": 1'),
        ),
        throwsFormatException,
      );
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (m) => m['extra'] = true,
        (m) => m['kind'] = 'cohort.editable-workspace.v3',
        (m) => m['selected'] = 9,
        (m) =>
            (m['sources'] as Map)[ApolloPilotPin.files.keys.first] = 'changed',
        (m) => (m['revisions'] as List).first['patches'] = {
          mainKey: {'sets': 4},
        },
        (m) => m['draft'] = {
          mainKey: {'load': 100},
        },
        (m) => m['draft'] = {
          mainKey: {'sets': '4'},
        },
        (m) => m['draft'] = {
          mainKey: {'rir': 3},
        },
        (m) => (m['revisions'] as List).add((m['revisions'] as List).first),
      ]) {
        final file = readWorkspaceJson(saved);
        mutate(file);
        expect(
          () => ApolloPilotController.reopen(jsonEncode(file)),
          throwsFormatException,
        );
        expect(c.saveWorkspace(), saved);
      }
      final artifact = readWorkspaceJson(source.exportCanonical(c.selected))
        ..['digest'] = 'invalid';
      expect(
        () => ApolloPilotSource.recompileCanonical(jsonEncode(artifact)),
        throwsFormatException,
      );
      expect(
        () => ApolloPilotSource.recompileCanonical(saved),
        throwsFormatException,
      );
      expect(
        () => ApolloPilotController.reopen(source.exportCanonical(c.selected)),
        throwsFormatException,
      );
    },
  );
}
