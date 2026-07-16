import 'package:cohort_platform/features/home/services/home_today_session_loader.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const protocol = Protocol(protocolId: 'BW-001', name: 'Bodyweight Grinder');

  ResolvedTodaySession resolution({String? slotTitle}) {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.executable,
      assignment: ProgrammeAssignment(
        id: 'assignment-1',
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        status: ProgrammeAssignmentStatus.active,
        startedAt: DateTime.utc(2026, 7, 15),
        currentWeek: 1,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      ),
      assignmentId: 'assignment-1',
      programmeVersionId: 'version-1',
      lineageCode: 'COHORT-FOUNDATION-TEST',
      weekNumber: 1,
      dayKey: 'day_1',
      slotTitle: slotTitle,
      plannedProtocolId: 'BW-001',
      effectiveProtocolId: 'BW-001',
      isOptional: false,
      isRestDay: false,
      programmeComplete: false,
    );
  }

  group('HomeTodaySessionLabels', () {
    test('protocol name remains primary title', () {
      expect(
        HomeTodaySessionLabels.canonicalSessionTitle(protocol),
        'Bodyweight Grinder',
      );
    });

    test('differing slot title appears secondarily in subtitle', () {
      final subtitle = HomeTodaySessionLabels.executableSubtitle(
        resolution(slotTitle: 'Monday Conditioning'),
        protocol,
      );

      expect(subtitle, 'Required session • Monday Conditioning');
      expect(subtitle, isNot(contains('Bodyweight Grinder')));
    });

    test('blank slot title does not duplicate protocol name in subtitle', () {
      expect(
        HomeTodaySessionLabels.executableSubtitle(
          resolution(slotTitle: null),
          protocol,
        ),
        'Required session',
      );
      expect(
        HomeTodaySessionLabels.executableSubtitle(
          resolution(slotTitle: '   '),
          protocol,
        ),
        'Required session',
      );
    });

    test('slot title matching protocol name is not shown twice', () {
      expect(
        HomeTodaySessionLabels.executableSubtitle(
          resolution(slotTitle: 'Bodyweight Grinder'),
          protocol,
        ),
        'Required session',
      );
      expect(
        HomeTodaySessionLabels.executableSubtitle(
          resolution(slotTitle: 'bodyweight grinder'),
          protocol,
        ),
        'Required session',
      );
    });
  });
}
