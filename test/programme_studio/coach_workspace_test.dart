import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_session_source.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_source_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'genuine_workspace_test.dart' show selectedWorkspace;

void main() {
  test(
    'independent strength copy retains pending intent and backup bytes without admission',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final original = c.selected('LW10K-W01-D01');
      final originalBytes = original.source;
      c.begin(original);
      final owner = c.ownerOf(original);
      c.edit(
        owner,
        (g) => g['blocks'][1]['exercises'][0]['prescription']['sets'] = 4,
      );
      final copy = c.copyToDay(original, 0, 5);
      final copiedOwner = c.ownerOf(copy);
      expect(copiedOwner.lineage, isNot(owner.lineage));
      expect(
        copiedOwner.draft!['blocks'][1]['exercises'][0]['prescription'],
        owner.draft!['blocks'][1]['exercises'][0]['prescription'],
      );
      c.edit(
        copiedOwner,
        (g) => g['blocks'][1]['exercises'][0]['prescription']['sets'] = 5,
      );
      expect(
        owner.draft!['blocks'][1]['exercises'][0]['prescription']['sets'],
        4,
      );
      expect(original.source, originalBytes);
      expect(c.freeze(copiedOwner), isFalse);
      expect(
        c.inspect(copiedOwner).issues,
        anyElement(contains('Unresolved exercise setup')),
      );
      final file = File(
        '/private/tmp/m11_performance_coach_strength_backup.json',
      )..writeAsStringSync(c.save());
      final reopened = c.prepareOpen(file.readAsStringSync()).candidate;
      addTearDown(reopened.dispose);
      expect(reopened.save(), file.readAsStringSync());
      expect(
        reopened
            .ownerOf(reopened.selected('LW10K-W01-D01'))
            .draft!['blocks'][1]['exercises'][0]['prescription']['sets'],
        4,
      );
      expect(
        reopened
            .owners[copiedOwner.lineage]
            .draft!['blocks'][1]['exercises'][0]['prescription']['sets'],
        5,
      );
    },
  );

  test(
    'week copies are independent per occurrence and retain notes and exact doses',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final monday = c.selected('LW10K-W01-D01');
      final dose = jsonDecode(
        monday.source,
      )['blocks'][1]['exercises'][0]['prescription'];
      c.copyWeekForCoach(0, 1);
      final copiedSlot = c.occurrences.singleWhere(
        (s) => s['week'] == 2 && s['day'] == 1,
      );
      final copy = c.selected(copiedSlot['slot_key'] as String);
      expect(
        copy.identity.sessionLineageId,
        isNot(monday.identity.sessionLineageId),
      );
      expect(
        jsonDecode(copy.source)['blocks'][1]['exercises'][0]['prescription'],
        dose,
      );
      c.begin(copy);
      c.edit(
        c.ownerOf(copy),
        (g) => g['blocks'][1]['exercises'][0]['prescription']['sets'] = 9,
      );
      expect(c.selected('LW10K-W01-D01').source, monday.source);
      expect(c.occurrences.where((s) => s['week'] == 2), hasLength(6));
      final before = c.save();
      expect(() => c.copyWeekForCoach(0, 0), throwsFormatException);
      expect(c.save(), before);
    },
  );

  test(
    'move preserves exact selection, slot identity and source day notes',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final r = c.selected('LW10K-W01-D02');
      c.moveOccurrence('LW10K-W01-D02', 0, 5);
      expect(c.selected('LW10K-W01-D02').source, r.source);
      final moved = c.occurrences.singleWhere(
        (s) => s['slot_key'] == 'LW10K-W01-D02',
      );
      expect(moved['day'], 6);
      expect(c.programme.tree!['weeks'][0]['days'][1]['day_type'], 'rest');
      expect(c.occurrences, hasLength(60));
      final before = c.save();
      expect(() => c.moveOccurrence('absent', 0, 5), throwsFormatException);
      expect(c.save(), before);
    },
  );

  test(
    'copied running edit exports and reopens actual exact artifact; original unchanged',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final original = c.selected('LW10K-W04-D02');
      final copy = c.copyToDay(original, 0, 5);
      final copiedSlot =
          c.occurrences.singleWhere(
                (s) => s['session_key'] == copy.key,
              )['slot_key']
              as String;
      c.begin(copy);
      final owner = c.ownerOf(copy);
      c.edit(
        owner,
        (g) => g['blocks'][0]['coach_notes'] = 'Independent copy coaching note',
      );
      expect(c.freeze(owner), isTrue, reason: c.errors.join('\n'));
      c.useRevision(owner.latest, [copiedSlot], c.generation);
      expect(c.selected('LW10K-W04-D02').source, original.source);
      c.setWeeks(1);
      for (var d = 0; d < 7; d++) {
        if (d != 5) c.rest(0, d);
      }
      c.excludeUnusedSources();
      expect(await c.refreshReview(), isTrue, reason: c.errors.join('\n'));
      final archive = NativeSourceBundle.prepare(c);
      final file = File(
        '/private/tmp/m11_performance_coach_verified_running.tar',
      )..writeAsBytesSync(archive.transport.archiveBytes);
      final reopened = NativeSourceBundle.open(
        file.readAsBytesSync(),
        c.catalogue,
      );
      addTearDown(reopened.dispose);
      final selected = reopened.selected(
        reopened.occurrences.single['slot_key'] as String,
      );
      final graph = jsonDecode(selected.source);
      final workout =
          graph['blocks'][0]['timer_config']['running_workout'] as Map;
      expect(runningTotals(workout), (seconds: 2550, metres: 0));
      // Compare all authored phase values independently of regenerated copy IDs.
      List<dynamic> phases(String source) =>
          (jsonDecode(
                    source,
                  )['blocks'][0]['timer_config']['running_workout']['steps']
                  as List)
              .map((s) => Map.of(s as Map)..remove('step_id'))
              .toList();
      expect(phases(selected.source), phases(original.source));
      expect(
        graph['blocks'][0]['coach_notes'],
        'Independent copy coaching note',
      );
    },
  );
  test(
    'newly authored running session validates and exports without its empty creation placeholder',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final fresh = c.createSession(running: true);
      c.place(0, 5, fresh);
      final slot =
          c.occurrences.singleWhere(
                (s) => s['session_key'] == fresh.key,
              )['slot_key']
              as String;
      c.begin(fresh);
      final owner = c.ownerOf(fresh);
      final steps = jsonDecode(
        c.selected('LW10K-W04-D02').source,
      )['blocks'][0]['timer_config']['running_workout'];
      c.edit(owner, (g) {
        g['blocks'][0]['timer_config']['running_workout'] = steps;
        g['blocks'][0]['timer_config']['durationSeconds'] = 2550;
      });
      expect(c.freeze(owner), isTrue, reason: c.errors.join('\n'));
      c.useRevision(owner.latest, [slot], c.generation);
      expect(c.policy.available, isNot(contains(fresh.key)));
      c.setWeeks(1);
      for (var d = 0; d < 7; d++) {
        if (d != 5) c.rest(0, d);
      }
      c.excludeUnusedSources();
      expect(await c.refreshReview(), isTrue, reason: c.errors.join('\n'));
      expect(NativeSourceBundle.prepare(c).transport.archiveBytes, isNotEmpty);
    },
  );
}
