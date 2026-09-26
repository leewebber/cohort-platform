import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/domain/programme_scheduling/authored_occurrence_date.dart';
import 'package:cohort_platform/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _packagePath = 'tool/programmes/bali_hybrid_base_v1.plan-package.yaml';
const _founderPath = 'tool/programmes/bali_hybrid_base_v1.founder.yaml';
const _manifestPath =
    'content/programmes/bali_hybrid_base/v1/source_manifest.json';
const _hashPath = 'content/programmes/bali_hybrid_base/v1/package.sha256';
const _publicationPath =
    'content/programmes/bali_hybrid_base/v1/bali_hybrid_base.publication.json';
const _expectedHash =
    'f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b';
const _apolloHash =
    '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83';

void main() {
  late Map<String, dynamic> manifest;
  late PlanPackageManifest package;
  late PlanPackageCompileResult compile;

  setUpAll(() {
    manifest =
        jsonDecode(File(_manifestPath).readAsStringSync()) as Map<String, dynamic>;
    compile = const PlanPackageCompiler().compile(
      File(_packagePath).readAsStringSync(),
    );
    expect(compile.isValid, isTrue, reason: compile.issues.toString());
    package = compile.manifest!;
  });

  test('programme totals match the source manifest', () {
    final sessions = (manifest['sessions'] as List).cast<Map<String, dynamic>>();
    expect(sessions, hasLength(71));
    expect(manifest['sessions_by_week'], {
      '1': 9,
      '2': 9,
      '3': 9,
      '4': 8,
      '5': 9,
      '6': 9,
      '7': 9,
      '8': 9,
    });
    expect(package.sessions, hasLength(71));
    final keys = sessions.map((item) => item['id']).toSet();
    expect(keys, hasLength(71));
    expect(
      package.sessions.map((item) => item.sessionKey).toSet(),
      keys,
    );
  });

  test('same-day AM precedes PM on the same authored date', () {
    final start = DateTime.utc(2026, 9, 26);
    for (final week in package.weeks) {
      for (final day in week.days) {
        if (day.slots.length < 2) {
          continue;
        }
        expect(day.slots, hasLength(2));
        expect(day.slots.first.timeOfDay, ProgrammeSessionTimeOfDay.morning);
        expect(day.slots.last.timeOfDay, ProgrammeSessionTimeOfDay.afternoon);
        expect(day.slots.first.sessionOrder, 1);
        expect(day.slots.last.sessionOrder, 2);
        expect(day.slots.first.sessionKey, isNot(day.slots.last.sessionKey));
        final date = AuthoredOccurrenceDate.occurrenceDate(
          startedAt: start,
          weekNumber: week.weekNumber,
          dayOrder: day.dayOrder,
        );
        expect(
          AuthoredOccurrenceDate.isoDate(date),
          AuthoredOccurrenceDate.isoDate(
            AuthoredOccurrenceDate.occurrenceDate(
              startedAt: start,
              weekNumber: week.weekNumber,
              dayOrder: day.dayOrder,
            ),
          ),
        );
      }
    }
  });

  test('Week 8 spillover keeps the eight-week label and 58-day span', () {
    expect(package.programme.durationWeeks, 8);
    expect(manifest['duration_weeks'], 8);
    expect(manifest['calendar_span_days'], 58);
    final week8 = package.weeks.singleWhere((week) => week.weekNumber == 8);
    expect(week8.days.map((day) => day.dayOrder).toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    final start = DateTime.utc(2026, 9, 26);
    expect(
      AuthoredOccurrenceDate.isoDate(
        AuthoredOccurrenceDate.occurrenceDate(
          startedAt: start,
          weekNumber: 8,
          dayOrder: 7,
        ),
      ),
      '2026-11-20',
    );
    expect(
      AuthoredOccurrenceDate.isoDate(
        AuthoredOccurrenceDate.occurrenceDate(
          startedAt: start,
          weekNumber: 8,
          dayOrder: 8,
        ),
      ),
      '2026-11-21',
    );
    expect(
      AuthoredOccurrenceDate.isoDate(
        AuthoredOccurrenceDate.occurrenceDate(
          startedAt: start,
          weekNumber: 8,
          dayOrder: 9,
        ),
      ),
      '2026-11-22',
    );
    expect(
      AuthoredOccurrenceDate.calendarOffsetDays(weekNumber: 8, dayOrder: 9) + 1,
      58,
    );
  });

  test('representative prescriptions remain source-faithful', () {
    final founder = const FounderProgrammeYamlParser().parse(
      File(_founderPath).readAsStringSync(),
    );
    String title(int week, int day, int session) {
      return founder.weeks
          .singleWhere((item) => item.weekNumber == week)
          .days
          .singleWhere((item) => item.dayNumber == day)
          .sessions[session - 1]
          .title;
    }

    String notes(int week, int day, int session) {
      return founder.weeks
          .singleWhere((item) => item.weekNumber == week)
          .days
          .singleWhere((item) => item.dayNumber == day)
          .sessions[session - 1]
          .coachNotes!;
    }

    String mainDuration(int week, int day, int session) {
      final blocks = founder.weeks
          .singleWhere((item) => item.weekNumber == week)
          .days
          .singleWhere((item) => item.dayNumber == day)
          .sessions[session - 1]
          .blocks;
      final main = blocks.firstWhere((block) => block.blockType != 'warm_up');
      return main.exercises.first.prescription?['duration']?.toString() ??
          main.coachNotes ??
          '';
    }

    expect(title(1, 1, 1), 'Strength A — Heavy Lower + Pull');
    expect(title(1, 2, 1), 'Long Aerobic — BikeErg');
    expect(mainDuration(1, 2, 1), contains('45 min continuous Z2'));
    expect(title(1, 3, 1), 'Threshold A — BikeErg');
    expect(mainDuration(1, 3, 1), contains('3 × 8'));
    expect(title(1, 3, 2), 'Muscular Endurance — Structural Capacity');
    expect(title(2, 3, 1), 'Threshold A — BikeErg');
    expect(mainDuration(2, 3, 1), contains('3 × 10'));
    expect(title(3, 5, 1), 'VO2max — BikeErg');
    expect(mainDuration(3, 5, 1), contains('5 × 4'));
    expect(title(4, 3, 1), contains('20-min'));
    expect(title(4, 5, 1), contains('2 km Row'));
    expect(title(4, 7, 1), contains('Aerobic Efficiency'));
    expect(title(5, 3, 1), 'Threshold A — BikeErg');
    expect(mainDuration(5, 3, 1), contains('2 × 15'));
    expect(title(5, 7, 1), 'Threshold B — RowErg');
    expect(mainDuration(5, 7, 1), contains('3 × 10'));
    expect(title(6, 3, 1), 'Threshold A — BikeErg');
    expect(mainDuration(6, 3, 1), contains('3 × 12'));
    expect(title(7, 3, 1), 'Threshold A — BikeErg');
    expect(mainDuration(7, 3, 1), contains('2 × 20'));
    expect(title(7, 7, 1), 'Threshold B — RowErg');
    expect(mainDuration(7, 7, 1), contains('3 × 15'));
    expect(title(8, 7, 1), contains('Relative-strength'));
    expect(title(8, 9, 1), contains('Aerobic Efficiency'));
    expect(notes(1, 1, 1), contains('Maximum / relative strength'));
  });

  test('progression tables stay distinct by week', () {
    final summaries = <String, String>{};
    for (final week in package.weeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          summaries['${week.weekNumber}-${day.dayOrder}-${slot.sessionOrder}'] =
              slot.progression.prescriptionSummary;
        }
      }
    }
    expect(summaries['1-2-1'], contains('60 min'));
    expect(summaries['2-2-1'], contains('70 min'));
    expect(summaries['3-2-1'], contains('80 min'));
    expect(summaries['5-2-1'], contains('85 min'));
    expect(summaries['6-2-1'], contains('95 min'));
    expect(summaries['7-2-1'], contains('105 min'));
    expect(summaries['1-3-1'], contains('3 × 8'));
    expect(summaries['2-3-1'], contains('3 × 10'));
    expect(summaries['3-3-1'], contains('3 × 12'));
    expect(summaries['5-3-1'], contains('2 × 15'));
    expect(summaries['6-3-1'], contains('3 × 12'));
    expect(summaries['7-3-1'], contains('2 × 20'));
    expect(summaries['1-5-1'], contains('4 × 4'));
    expect(summaries['3-5-1'], contains('5 × 4'));
    expect(summaries['5-5-1'], contains('6 × 3'));
    expect(summaries['1-7-1'], contains('3 × 10'));
    expect(summaries['5-7-1'], contains('3 × 10'));
    expect(summaries['7-7-1'], contains('3 × 15'));
    expect(summaries['4-1-1'], contains('Deload'));
    expect(summaries['8-1-1'], contains('primer'));
  });

  test('privacy, Apollo hash, and unsupported automation stay honest', () {
    expect(package.programme.libraryScope, ProgrammeLibraryScope.coachPrivate);
    expect(manifest['library_scope'], 'coach_private');
    expect(manifest['public_catalogue'], isFalse);
    final publication =
        jsonDecode(File(_publicationPath).readAsStringSync()) as Map;
    expect(publication['publication_kind'], 'private_exact_version');
    expect(publication['public_catalogue'], isFalse);
    expect(publication['source_package_hash'], _expectedHash);
    expect(File(_hashPath).readAsStringSync().trim(), _expectedHash);
    final apollo = File(
      'tool/programmes/apollo_build_12_week_v1.plan-package.yaml',
    ).readAsStringSync();
    expect(
      const PlanPackageCompiler().compile(apollo).contentHashSha256,
      _apolloHash,
    );
    expect(
      File(
        'lib/features/programme/presentation/programme_discovery_decision_preview_catalog.dart',
      ).readAsStringSync().toLowerCase(),
      isNot(contains('bali hybrid base')),
    );
    final source = File(_packagePath).readAsStringSync() +
        File(_founderPath).readAsStringSync();
    expect(source.toLowerCase(), isNot(contains('garmin')));
    expect(source, isNot(contains('P20 *')));
    expect(source, isNot(contains('target_watts')));
    expect(source, contains('b2_calculation: false'));
    expect(source, contains('numeric_target: "none"'));
    expect(source, isNot(contains('lee@')));
    expect(source.toLowerCase(), isNot(contains('enrol_athlete')));
  });

  test('determinism and compile identity stay stable', () {
    final first = const PlanPackageCompiler().compile(
      File(_packagePath).readAsStringSync(),
    );
    final second = const PlanPackageCompiler().compile(
      File(_packagePath).readAsStringSync(),
    );
    expect(first.contentHashSha256, second.contentHashSha256);
    expect(first.contentHashSha256, _expectedHash);
    expect(
      first.manifest!.sessions.map((item) => item.protocolId).toList(),
      second.manifest!.sessions.map((item) => item.protocolId).toList(),
    );
  });
}
