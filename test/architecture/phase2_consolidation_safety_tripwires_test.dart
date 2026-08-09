import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 2.3 consolidation drift tripwires.
///
/// Protects architecture boundaries identified for Phase 2 consolidation —
/// not harmless filenames or import order. Local-only; no hosted contact.
void main() {
  final root = _repoRoot(Directory.current);

  group('Home dual-path authority freeze', () {
    test(
      'materialised programme Home path uses ProgrammeAdaptFlow, not HomeAdaptFlow',
      () {
        final home = File('$root/lib/features/home/home_screen.dart')
            .readAsStringSync();
        final today = File(
          '$root/lib/features/home/widgets/athlete_programme_today_section.dart',
        ).readAsStringSync();
        final programmeFlow = File(
          '$root/lib/features/home/services/programme_adapt_flow.dart',
        ).readAsStringSync();

        // Dual path remains temporarily: Plan Library active plan vs materialised.
        expect(home.contains('hasActivePlan'), isTrue);
        expect(home.contains('HomeAdaptFlow'), isTrue);
        expect(home.contains('AthleteProgrammeTodaySection'), isTrue);

        // Materialised branch must not open the Coach Brain / Plan Library adapt flow.
        final materialisedBranch = _sectionBetween(
          home,
          'else if (materialisedGate) ...[',
          '] else',
        );
        expect(
          materialisedBranch.contains('AthleteProgrammeTodaySection'),
          isTrue,
        );
        expect(materialisedBranch.contains('_openAdapt'), isFalse);
        expect(materialisedBranch.contains('HomeAdaptFlow'), isFalse);
        expect(materialisedBranch.contains('DailyBriefingSection'), isFalse);

        // Programme today owns Adapt via ProgrammeAdaptFlow only.
        expect(today.contains('ProgrammeAdaptFlow'), isTrue);
        expect(today.contains('HomeAdaptFlow'), isFalse);
        expect(programmeFlow.contains('ProgrammeAdaptationProposalService'), isTrue);
        expect(programmeFlow.contains('HomeAdaptFlow'), isFalse);
        expect(programmeFlow.contains('commitDayOfAdaptation'), isFalse);
      },
    );
  });

  group('staging harness isolation', () {
    test('product features/application must not import staging_tooling', () {
      final roots = [
        Directory('$root/lib/features'),
        Directory('$root/lib/application'),
        Directory('$root/lib/domain'),
        Directory('$root/lib/planning'),
        Directory('$root/lib/core'),
      ];
      final offenders = <String>[];
      for (final dir in roots) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          final imports = source
              .split('\n')
              .where((line) => line.trimLeft().startsWith('import '));
          for (final line in imports) {
            if (line.contains('staging_tooling') ||
                line.contains('/staging/') ||
                line.contains('package:cohort_platform/staging/')) {
              offenders.add(
                '${entity.path.substring(root.length + 1)}: $line',
              );
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'staging harness leaked into product runtime:\n'
            '${offenders.join('\n')}',
      );
    });

    test('Journey D staging entrypoints remain under lib/staging_tooling', () {
      for (final rel in const [
        'lib/staging_tooling/journey_d/journey_d_live_main.dart',
        'lib/staging_tooling/journey_d/journey_d_execute_main.dart',
        'lib/staging_tooling/journey_d/journey_d_non_test_runtime.dart',
      ]) {
        expect(File('$root/$rel').existsSync(), isTrue, reason: rel);
      }
      final runtime = File(
        '$root/lib/staging_tooling/journey_d/journey_d_non_test_runtime.dart',
      ).readAsStringSync();
      expect(runtime.contains('config_production_refused'), isTrue);
    });
  });

  group('connected-data privacy source freeze', () {
    test('connected_data_contracts forbids location/travel categories', () {
      final source = File(
        '$root/lib/core/privacy/connected_data_contracts.dart',
      ).readAsStringSync();
      const forbidden = [
        'liveLocation',
        'gpsRoute',
        'backgroundLocation',
        'homeLocation',
        'workLocation',
        'geofence',
        'travelDetection',
        'movementTracking',
      ];
      // Enum / field identifiers must not introduce prohibited categories.
      final enumBlock = _sectionBetween(
        source,
        'enum ConnectedPerformanceMetricKind {',
        '}',
      );
      for (final token in forbidden) {
        expect(
          enumBlock.contains(token),
          isFalse,
          reason: 'ConnectedPerformanceMetricKind must not include $token',
        );
        expect(
          RegExp('\\b$token\\b').hasMatch(
            source
                .split('\n')
                .where((l) => !l.trimLeft().startsWith('//'))
                .where((l) => !l.trimLeft().startsWith('*'))
                .join('\n'),
          ),
          isFalse,
          reason: 'non-comment source must not declare $token',
        );
      }
      expect(source.contains('class ConnectedPerformanceMetric'), isTrue);
      expect(source.contains('ProhibitedLocationData'), isTrue);
    });
  });

  group('completion / previous-performance authority freeze', () {
    test(
      'previous performance resolver reads athlete results, not prescription load',
      () {
        final source = File(
          '$root/lib/core/persistence/previous_performance_from_results.dart',
        ).readAsStringSync();
        expect(source.contains('ExerciseExecutionResult'), isTrue);
        expect(source.contains('StrengthExecutionResult'), isTrue);
        expect(source.contains('class PreviousPerformanceFromResults'), isTrue);
        // Must not invent next-load / rewrite programme via this descriptive path.
        expect(source.contains('recommendNextLoad'), isFalse);
        expect(source.contains('AthleteProgrammeGenerationService'), isFalse);
        expect(source.contains('commitDayOfAdaptation'), isFalse);
        expect(source.contains('SessionAdaptationPipeline'), isFalse);
      },
    );
  });
}

String _sectionBetween(String source, String start, String end) {
  final startIdx = source.indexOf(start);
  expect(startIdx, isNonNegative, reason: 'missing marker: $start');
  final after = startIdx + start.length;
  final endIdx = source.indexOf(end, after);
  expect(endIdx, isNonNegative, reason: 'missing end marker: $end');
  return source.substring(after, endIdx);
}

String _repoRoot(Directory start) {
  var dir = start;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    if (dir.parent.path == dir.path) return start.path;
    dir = dir.parent;
  }
}
