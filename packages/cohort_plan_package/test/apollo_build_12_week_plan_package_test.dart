import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';

const _packagePath =
    '../../tool/programmes/apollo_build_12_week_v1.plan-package.yaml';
const _gatePath =
    '../../supabase/tests/sql/gate_ae_apollo_week12_executable_protocols.sql';
const _apolloCanonicalHash =
    '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83';

const _dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

List<String> _scheduledDayCodes(int week) {
  if (week == 12) {
    return _dayCodes;
  }
  return const ['MON', 'THU', 'WED', 'TUE', 'FRI', 'SAT', 'SUN'];
}

String _scheduledProtocol(
  PlanPackageManifest manifest,
  int weekNumber,
  int dayOrder,
) {
  final week = manifest.weeks.singleWhere(
    (item) => item.weekNumber == weekNumber,
  );
  final slot = week.days
      .singleWhere((day) => day.dayOrder == dayOrder)
      .slots
      .single;
  return manifest.sessions
      .singleWhere((session) => session.sessionKey == slot.sessionKey)
      .protocolId;
}

String _protocolId(int week, String day) => 'APOLLO-W$week-$day-R1';

String _lineageId(int week, int dayOrder) =>
    'a${week + 10}0000$dayOrder-0000-4000-8000-00000000000$dayOrder';

String _migrationPath(int week) {
  final hourMinute = 1200 + ((week - 1) * 10) + (week > 6 ? 40 : 0);
  final suffix = hourMinute.toString().padLeft(4, '0');
  return '../../supabase/migrations/20260821${suffix}00_apollo_build_week'
      '${week}_executable_protocols.sql';
}

void main() {
  const compiler = PlanPackageCompiler();
  late String yaml;
  late PlanPackageManifest manifest;

  setUpAll(() {
    yaml = File(_packagePath).readAsStringSync();
    final result = compiler.compile(yaml);
    expect(result.isValid, isTrue, reason: result.issues.toString());
    manifest = result.manifest!;
  });

  test('parses and compiles the complete stable Apollo package', () {
    final first = compiler.compile(yaml);
    final second = compiler.compile(yaml);

    expect(first.isValid && second.isValid, isTrue);
    expect(manifest.programme.lineageCode, 'APOLLO-BUILD-12-WEEK');
    expect(manifest.programme.versionNumber, 2);
    expect(manifest.programme.name, 'Apollo Build — 12-Week Initial Block');
    expect(first.canonicalJson, second.canonicalJson);
    expect(first.contentHashSha256, second.contentHashSha256);
    expect(first.contentHashSha256, _apolloCanonicalHash);
    expect(first.contentHashSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('has twelve ordered weeks, seven ordered days, and 84 slots', () {
    expect(manifest.weeks, hasLength(12));
    expect(manifest.weeks.map((week) => week.weekNumber), [
      for (var week = 1; week <= 12; week++) week,
    ]);

    final slots = [
      for (final week in manifest.weeks)
        for (final day in week.days)
          for (final slot in day.slots) slot,
    ];
    expect(slots, hasLength(84));

    for (final week in manifest.weeks) {
      expect(week.days, hasLength(7));
      expect(week.days.map((day) => day.dayOrder), [1, 2, 3, 4, 5, 6, 7]);
      expect(week.days.map((day) => day.title), _dayNames);
      expect(week.days.every((day) => day.slots.length == 1), isTrue);
    }
  });

  test(
    'references each committed deterministic Apollo protocol exactly once',
    () {
      expect(manifest.sessions, hasLength(84));

      final expected = <String, String>{
        for (var week = 1; week <= 12; week++)
          for (var day = 1; day <= 7; day++)
            _protocolId(week, _dayCodes[day - 1]): _lineageId(week, day),
      };
      final actual = {
        for (final session in manifest.sessions)
          session.protocolId: session.sessionLineageId,
      };

      expect(actual, expected);
      expect(actual.keys.toSet(), hasLength(84));
      expect(actual.values.toSet(), hasLength(84));
      expect(
        manifest.sessions.every(
          (session) =>
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              ).hasMatch(session.sessionLineageId) &&
              !session.protocolId.contains('placeholder') &&
              !session.protocolId.contains('nil'),
        ),
        isTrue,
      );

      final expectedScheduled = <String>[
        for (var week = 1; week <= 12; week++)
          for (final dayCode in _scheduledDayCodes(week))
            _protocolId(week, dayCode),
      ];
      final scheduledProtocolIds = <String>[
        for (final week in manifest.weeks)
          for (final day in week.days)
            for (final slot in day.slots)
              manifest.sessions
                  .singleWhere(
                    (session) => session.sessionKey == slot.sessionKey,
                  )
                  .protocolId,
      ];
      expect(scheduledProtocolIds, expectedScheduled);
      expect(scheduledProtocolIds.toSet(), hasLength(84));
    },
  );

  test('places quality running before Racehorse in weeks 1–11 only', () {
    for (final week in manifest.weeks) {
      final day2 = _scheduledProtocol(manifest, week.weekNumber, 2);
      final day3 = _scheduledProtocol(manifest, week.weekNumber, 3);
      final day4 = _scheduledProtocol(manifest, week.weekNumber, 4);
      expect(day3, _protocolId(week.weekNumber, 'WED'));
      if (week.weekNumber == 12) {
        expect(day2, 'APOLLO-W12-TUE-R1');
        expect(day4, 'APOLLO-W12-THU-R1');
      } else {
        expect(day2, _protocolId(week.weekNumber, 'THU'));
        expect(day4, _protocolId(week.weekNumber, 'TUE'));
      }
    }
  });

  test('cross-layer parity matches committed migrations and Gate AE', () {
    for (var week = 1; week <= 12; week++) {
      final migration = File(_migrationPath(week)).readAsStringSync();
      for (var day = 1; day <= 7; day++) {
        final protocol = _protocolId(week, _dayCodes[day - 1]);
        final lineage = _lineageId(week, day);
        expect(
          RegExp("\\('$protocol',[^\\n]*'$lineage',1,").hasMatch(migration),
          isTrue,
          reason: 'Committed migration lacks $protocol -> $lineage.',
        );
      }
    }

    final gate = File(_gatePath).readAsStringSync();
    expect(gate, contains("'eighty_four_apollo_protocols'"));
  });

  test('retains reduced-fatigue and Week 12 assessment/recovery structure', () {
    final week4 = manifest.weeks[3];
    final week8 = manifest.weeks[7];
    expect(week4.intent, ProgrammeIntent.deload);
    expect(week8.intent, ProgrammeIntent.deload);
    expect(week4.coachNote, contains('Reduced-fatigue'));
    expect(week8.coachNote, contains('60–70%'));

    final week12 = manifest.weeks[11];
    expect(week12.days.map((day) => day.slots.single.displayTitle), [
      'Final Apollo Strength',
      'Apollo Base Assessment',
      'Final Racehorse',
      'Recovery',
      'Apollo Primer',
      'Apollo Assessment',
      'Apollo Arrival',
    ]);
    expect(week12.days[3].coachNote, contains('selectable-mode'));
    expect(week12.days[5].coachNote, contains('no additional conditioning'));
    expect(week12.days[6].coachNote, contains('no long run, lifting'));
  });

  test('session keys and slot keys are globally unique', () {
    final sessionKeys = manifest.sessions.map((session) => session.sessionKey);
    final slotKeys = [
      for (final week in manifest.weeks)
        for (final day in week.days)
          for (final slot in day.slots) slot.slotKey,
    ];

    expect(sessionKeys.toSet(), hasLength(84));
    expect(slotKeys.toSet(), hasLength(84));
  });
}
