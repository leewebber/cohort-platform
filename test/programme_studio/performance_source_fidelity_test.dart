import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_session_source.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/prescription_presentation.dart';
import 'package:cohort_platform/domain/running_workout/running_workout_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'genuine_workspace_test.dart' show selectedWorkspace, sourceFiles;

void main() {
  test(
    'all 40 selected, reopened and actual TAR bodies preserve the supplied independent reference',
    () async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final expected =
          (jsonDecode(
                File(
                  'docs/checkpoints/m11_run_source_reconciliation/ALL_40_RUNS.json',
                ).readAsStringSync(),
              )['rows']
              as List);
      void check(GenuineWorkspace candidate) {
        for (final row in expected) {
          final graph = jsonDecode(
            candidate.selected(row['session_id'] as String).source,
          );
          final workout =
              graph['blocks'][0]['timer_config']['running_workout'] as Map;
          final actual = [
            for (final step in workout['steps'])
              {
                'role': step['role'],
                'seconds':
                    (step['duration']['milliseconds'] as int? ?? 0) ~/ 1000,
                'distance_metres':
                    (step['duration']['millimetres'] as int? ?? 0) ~/ 1000,
                'target': switch (step['target']['kind']) {
                  'none' => 'authored_effort',
                  'heart_rate_zone_ref' => 'zone_2',
                  _ => step['target']['category'],
                },
              },
          ];
          expect(
            actual,
            row['reference_semantic_steps_AUDIT_ONLY'],
            reason: row['session_id'] as String,
          );
          expect(
            runningTotals(workout).seconds,
            row['reference_timed_seconds'],
          );
        }
      }

      check(c);
      final backup = File('/private/tmp/m11_performance_verified_full_v4.json')
        ..writeAsStringSync(c.save());
      final reopened = c.prepareOpen(backup.readAsStringSync()).candidate;
      addTearDown(reopened.dispose);
      expect(reopened.save(), backup.readAsStringSync());
      check(reopened);
      for (var w = 0; w < 10; w++) {
        reopened.rest(w, 0);
        reopened.rest(w, 3);
      }
      reopened.excludeUnusedSources();
      expect(
        await reopened.refreshReview(),
        isTrue,
        reason: reopened.errors.join('\n'),
      );
      final bundle = NativeSourceBundle.prepare(reopened);
      final file = File('/private/tmp/m11_performance_verified_all_40.tar')
        ..writeAsBytesSync(bundle.transport.archiveBytes);
      final imported = NativeSourceBundle.open(
        file.readAsBytesSync(),
        c.catalogue,
      );
      addTearDown(imported.dispose);
      check(imported);
      expect(imported.policy.graphs, reopened.policy.graphs);
      final restored = imported.prepareOpen(imported.save()).candidate;
      addTearDown(restored.dispose);
      check(restored);
      expect(
        c.owners.values.map((o) => c.inspect(o)).where((r) => r.admitted),
        hasLength(40),
      );
      expect(await c.refreshReview(), isFalse);
      expect(
        c.errors.where((e) => e.contains('Unresolved exercise setup')),
        hasLength(28),
      );
    },
  );
  test(
    'archived native v4 intent reopens with original 33-minute test, without upgrading sources',
    () {
      final current = selectedWorkspace();
      addTearDown(current.dispose);
      final old = GenuineWorkspace.fromSelectedSources(
        sourceFiles(archivedHybridSourceDirectory),
      );
      addTearDown(old.dispose);
      File(
        '/private/tmp/m11_performance_legacy_clean_v4.json',
      ).writeAsStringSync(old.save());
      final monday = old.selected('LW10K-W01-D01');
      old.begin(monday);
      old.edit(
        old.ownerOf(monday),
        (g) => g['blocks'][1]['exercises'][0]['prescription']['sets'] =
            'pending invalid intent',
      );
      final file = File('/private/tmp/m11_performance_archived_v4_backup.json')
        ..writeAsStringSync(old.save());
      final opened = current.prepareOpen(file.readAsStringSync()).candidate;
      addTearDown(opened.dispose);
      expect(opened.save(), file.readAsStringSync());
      expect(opened.isArchivedRunningSource, isTrue);
      Map workout(GenuineWorkspace c) =>
          jsonDecode(
                c.selected('LW10K-W10-D07').source,
              )['blocks'][0]['timer_config']['running_workout']
              as Map;
      expect(runningTotals(workout(opened)).seconds, 1980);
      expect(runningTotals(workout(current)).seconds, 1200);
      final back = opened.prepareOpen(current.save()).candidate;
      addTearDown(back.dispose);
      expect(back.isArchivedRunningSource, isFalse);
      expect(back.save(), current.save());
      final tamper = jsonDecode(file.readAsStringSync());
      final root = tamper['owners'][0]['revisions'][0];
      final raw = jsonDecode(root['source'] as String);
      raw['blocks'][0]['content'] = 'Rewritten archived snapshot';
      root['source'] = jsonEncode(raw);
      root['sha256'] = nativeDigest(root['source'] as String);
      expect(
        () => current.prepareOpen(jsonEncode(tamper)),
        throwsFormatException,
      );
    },
  );
  test(
    'short-5K is distinct; selected final duration guard refuses arbitrary retiming',
    () {
      expect(
        runTarget(const RunningTarget.qualityPaceRef('short_5k')),
        'Personalised short-5K pace',
      );
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final finalGraph = jsonDecode(c.selected('LW10K-W10-D07').source);
      final workout =
          finalGraph['blocks'][0]['timer_config']['running_workout'] as Map;
      workout['steps'][0]['duration']['milliseconds'] = 601000;
      expect(() => runningTotals(workout), throwsFormatException);
      for (final week in [6, 7, 8, 9]) {
        final graph = jsonDecode(c.selected('LW10K-W0$week-D05').source);
        final phases =
            graph['blocks'][0]['timer_config']['running_workout']['steps']
                as List;
        final quality = phases.where(
          (s) => s['target']['kind'] == 'alpha_quality_pace_v1',
        );
        expect(quality.map((s) => s['target']['category']).toSet(), {
          'short_5k',
        });
        expect(phases.last['role'], 'cool_down');
        expect(phases[phases.length - 2]['role'], 'work');
      }
    },
  );
}
