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
      'Home consumes canonical runtime authority; programme excludes HomeAdaptFlow',
      () {
        final home = File('$root/lib/features/home/home_screen.dart')
            .readAsStringSync();
        final authority = File(
          '$root/lib/features/home/services/athlete_home_runtime_authority.dart',
        ).readAsStringSync();
        final today = File(
          '$root/lib/features/home/widgets/athlete_programme_today_section.dart',
        ).readAsStringSync();
        final programmeFlow = File(
          '$root/lib/features/home/services/programme_adapt_flow.dart',
        ).readAsStringSync();

        // Phase 2.4: one typed decision owns classification.
        expect(home.contains('AthleteHomeRuntimeAuthorityResolver'), isTrue);
        expect(home.contains('AthleteHomeRuntimeAuthority'), isTrue);
        expect(authority.contains('legacyPlanCompatibility'), isTrue);
        expect(authority.contains('AthleteHomeRuntimeAuthority.programme'), isTrue);

        // Programme branch must not open Coach Brain / Plan Library adapt.
        final programmeBranch = _sectionBetween(
          home,
          'case AthleteHomeRuntimeAuthority.programme:',
          'case AthleteHomeRuntimeAuthority.legacyPlanCompatibility:',
        );
        expect(
          programmeBranch.contains('AthleteProgrammeTodaySection'),
          isTrue,
        );
        expect(programmeBranch.contains('_openLegacyAdapt'), isFalse);
        expect(programmeBranch.contains('HomeAdaptFlow'), isFalse);
        expect(programmeBranch.contains('DailyBriefingSection'), isFalse);

        final legacyBranch = _sectionBetween(
          home,
          'case AthleteHomeRuntimeAuthority.legacyPlanCompatibility:',
          'case AthleteHomeRuntimeAuthority.loading:',
        );
        expect(legacyBranch.contains('DailyBriefingSection'), isTrue);
        expect(legacyBranch.contains('_openLegacyAdapt'), isTrue);
        expect(legacyBranch.contains('AthleteProgrammeTodaySection'), isFalse);

        // Loading/unavailable must not activate legacy adapt.
        final loadingBranch = _sectionBetween(
          home,
          'case AthleteHomeRuntimeAuthority.loading:',
          'case AthleteHomeRuntimeAuthority.unavailable:',
        );
        expect(loadingBranch.contains('DailyBriefingSection'), isFalse);
        expect(loadingBranch.contains('_openLegacyAdapt'), isFalse);

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
