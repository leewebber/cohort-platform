import 'package:cohort_platform/features/home/presentation/athlete_home_today_presentation.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FixedProgrammeOccurrenceProjection occ({
    required String id,
    required String date,
    required FixedProgrammeOccurrenceState state,
    required String title,
    required int sessionOrder,
    String dayKey = 'sun',
    int? trainingSessionId,
  }) {
    return FixedProgrammeOccurrenceProjection(
      assignmentId: 'assign-1',
      occurrenceId: id,
      sessionSlotId: 'slot-$id',
      programmeVersionId: 'version-1',
      protocolId: 'PROT-$id',
      programmedSessionKey:
          'prog:assign-1@version-1:w1:$dayKey:s$sessionOrder:PROT-$id',
      weekNumber: 1,
      dayKey: dayKey,
      sessionOrder: sessionOrder,
      scheduledDate: date,
      originalScheduledDate: date,
      state: state,
      sessionTitle: title,
      trainingSessionId: trainingSessionId,
    );
  }

  FixedProgrammeCalendarProjection calendar({
    required List<FixedProgrammeOccurrenceProjection> occurrences,
    String today = '2026-09-27',
  }) {
    return FixedProgrammeCalendarProjection(
      assignmentId: 'assign-1',
      programmeName: 'Private fixture',
      timezone: 'Asia/Makassar',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-09-26',
      today: today,
      weekStart: '2026-09-21',
      weekEnd: '2026-09-27',
      occurrences: occurrences,
      currentWeek: const [],
    );
  }

  test('Sunday AM and PM share a date and keep distinct identities', () {
    final projection = calendar(
      occurrences: [
        occ(
          id: 'am',
          date: '2026-09-27',
          state: FixedProgrammeOccurrenceState.today,
          title: 'Long Aerobic',
          sessionOrder: 1,
        ),
        occ(
          id: 'pm',
          date: '2026-09-27',
          state: FixedProgrammeOccurrenceState.planned,
          title: 'Upper Strength',
          sessionOrder: 2,
        ),
      ],
    );
    final sunday = projection.occurrencesOnDate('2026-09-27');
    expect(sunday, hasLength(2));
    expect(sunday.map((e) => e.occurrenceId), ['am', 'pm']);
    expect(sunday[0].programmedSessionKey, isNot(sunday[1].programmedSessionKey));
    expect(
      AthleteHomeTodayFormatter.prioritizedTodaySessions(projection),
      hasLength(2),
    );
  });

  test('completing AM leaves PM as the actionable today session', () {
    final projection = calendar(
      occurrences: [
        occ(
          id: 'am',
          date: '2026-09-27',
          state: FixedProgrammeOccurrenceState.completed,
          title: 'Long Aerobic',
          sessionOrder: 1,
          trainingSessionId: 11,
        ),
        occ(
          id: 'pm',
          date: '2026-09-27',
          state: FixedProgrammeOccurrenceState.planned,
          title: 'Upper Strength',
          sessionOrder: 2,
        ),
      ],
    );
    expect(projection.todayOccurrence?.occurrenceId, 'pm');
    expect(projection.todaySessions, hasLength(2));
    expect(
      projection.todaySessions.firstWhere((e) => e.occurrenceId == 'am').state,
      FixedProgrammeOccurrenceState.completed,
    );
    final wednesday = occ(
      id: 'wed',
      date: '2026-09-30',
      state: FixedProgrammeOccurrenceState.planned,
      title: 'VO2',
      sessionOrder: 1,
      dayKey: 'wed',
    );
    final withFuture = calendar(
      occurrences: [...projection.occurrences, wednesday],
    );
    expect(withFuture.canOfferFutureTrainTodaySwap(wednesday), isTrue);
  });

  test('two incomplete same-day sessions fail closed for date swap', () {
    final am = occ(
      id: 'am',
      date: '2026-09-27',
      state: FixedProgrammeOccurrenceState.today,
      title: 'Long Aerobic',
      sessionOrder: 1,
    );
    final later = occ(
      id: 'later',
      date: '2026-09-29',
      state: FixedProgrammeOccurrenceState.planned,
      title: 'VO2',
      sessionOrder: 1,
      dayKey: 'wed',
    );
    final projection = calendar(occurrences: [am, later]);
    // Only one today session — swap remains plausible.
    expect(projection.canOfferFutureTrainTodaySwap(later), isTrue);

    final both = calendar(
      occurrences: [
        am,
        occ(
          id: 'pm',
          date: '2026-09-27',
          state: FixedProgrammeOccurrenceState.planned,
          title: 'Upper Strength',
          sessionOrder: 2,
        ),
        later,
      ],
    );
    expect(both.canOfferFutureTrainTodaySwap(later), isFalse);
  });

  test('week-day JSON round-trip keeps both same-day sessions', () {
    final am = {
      'id': 'am',
      'session_slot_id': 'slot-am',
      'programme_version_id': 'version-1',
      'protocol_id': 'PROT-AM',
      'programmed_session_key': 'prog:assign-1@version-1:w1:sun:s1:PROT-AM',
      'week_number': 1,
      'day_key': 'sun',
      'session_order': 1,
      'scheduled_date': '2026-09-27',
      'original_scheduled_date': '2026-09-27',
      'state': 'TODAY',
      'session_title': 'Long Aerobic',
    };
    final pm = {
      ...am,
      'id': 'pm',
      'session_slot_id': 'slot-pm',
      'protocol_id': 'PROT-PM',
      'programmed_session_key': 'prog:assign-1@version-1:w1:sun:s2:PROT-PM',
      'session_order': 2,
      'state': 'PLANNED',
      'session_title': 'Upper Strength',
    };
    final day = FixedProgrammeCalendarDayProjection.fromMap({
      'date': '2026-09-27',
      'state': 'TODAY',
      'occurrence': am,
      'occurrences': [am, pm],
    }, assignmentId: 'assign-1');
    expect(day.occurrences, hasLength(2));
    expect(day.occurrence?.occurrenceId, 'am');

    expect(
      () => FixedProgrammeCalendarDayProjection.fromMap({
        'date': '2026-09-27',
        'state': 'TODAY',
        'occurrence': am,
        'occurrences': [am, {...pm, 'session_order': 1}],
      }, assignmentId: 'assign-1'),
      throwsFormatException,
    );
  });
}
