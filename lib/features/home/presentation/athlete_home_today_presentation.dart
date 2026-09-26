import '../../../models/protocol.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/strength_prescription_formatter.dart';
import '../../programme/models/fixed_programme_occurrence_projection.dart';
import '../../programme/presentation/athlete_programme_lifecycle_presentation.dart';
import '../../programme/presentation/programme_day_label_formatter.dart';
import '../../session/models/prepared_execution_package.dart';
import '../../session/models/session_execution_plan.dart';

class AthleteHomePrescriptionLine {
  const AthleteHomePrescriptionLine({required this.name, this.detail});

  final String name;
  final String? detail;
}

/// Formats today-only Home copy from authored programme and prepared session data.
abstract final class AthleteHomeTodayFormatter {
  static const collapsedPrescriptionCount = 5;

  static String fullDate(DateTime date) =>
      AthleteProgrammeDateFormatter.weekdayDayMonth(date);

  static String weekDayLabel({
    required int? weekNumber,
    required String? dayKey,
  }) {
    final day = dayKey == null
        ? null
        : ProgrammeDayLabelFormatter.format(dayKey: dayKey);
    if (weekNumber == null && day == null) return '';
    if (weekNumber == null) return day!;
    if (day == null) return 'Week $weekNumber';
    return 'Week $weekNumber · $day';
  }

  static String compactProgrammeContext({
    required String programmeName,
    required int? weekNumber,
    required String? dayKey,
  }) {
    final weekDay = weekDayLabel(weekNumber: weekNumber, dayKey: dayKey);
    if (weekDay.isEmpty) return programmeName;
    return '$programmeName\n$weekDay';
  }

  static String? metaLine({
    String? sessionType,
    String? location,
    String? duration,
  }) {
    final parts = <String>[
      ?_text(sessionType),
      ?_text(location),
      ?_duration(duration),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String? focus(PreparedExecutionPackage package) {
    final protocol = package.plan.protocol;
    return _text(protocol?.goal) ??
        _text(package.brief.primaryFocus) ??
        _text(package.brief.objective) ??
        _text(package.brief.trainingIntent);
  }

  static String? notes(PreparedExecutionPackage package) {
    final protocol = package.plan.protocol;
    return _text(package.brief.sessionNotes) ??
        _text(package.brief.coachNotes) ??
        _text(protocol?.coachingNotes);
  }

  static String? sessionType({
    required PreparedExecutionPackage package,
    FixedProgrammeOccurrenceProjection? occurrence,
  }) {
    return _text(occurrence?.sessionType) ??
        _text(package.plan.protocol?.sessionType) ??
        _text(package.brief.trainingIntent);
  }

  static String? location(PreparedExecutionPackage package) {
    final protocol = package.plan.protocol;
    return _text(protocol?.environment) ??
        _text(protocol?.equipment) ??
        _text(protocol?.requiredEquipment);
  }

  static String? duration(PreparedExecutionPackage package) {
    final minutes =
        package.brief.estimatedDurationMinutes ??
        package.plan.durationMin ??
        package.plan.protocol?.durationMin;
    if (minutes == null || minutes <= 0) return null;
    return 'approximately $minutes min';
  }

  static List<AthleteHomePrescriptionLine> prescriptionLines(
    SessionExecutionPlan plan,
  ) {
    final lines = <AthleteHomePrescriptionLine>[];
    final blocks = List<SessionExecutionBlock>.from(plan.blocks)
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final block in blocks) {
      if (block.linkedExercises.isNotEmpty) {
        for (final exercise in block.linkedExercises) {
          final name = exercise.athleteLabel.trim();
          if (name.isEmpty) continue;
          final prescription = exercise.prescription;
          lines.add(
            AthleteHomePrescriptionLine(
              name: name,
              detail: prescription == null
                  ? null
                  : StrengthPrescriptionFormatter.formatSetsReps(prescription),
            ),
          );
        }
        continue;
      }
      if (!block.hasAthleteVisibleContent) continue;
      final title = block.title.trim();
      if (title.isEmpty) continue;
      lines.add(
        AthleteHomePrescriptionLine(
          name: title,
          detail: _text(block.timerSummary) ?? _text(block.content),
        ),
      );
    }
    return List.unmodifiable(lines);
  }

  static String? restGuidance(Protocol? protocol) {
    return _text(protocol?.recovery) ??
        _text(protocol?.coachingNotes) ??
        _text(protocol?.description);
  }

  static String? nextSessionHint(FixedProgrammeCalendarProjection calendar) {
    if (!calendar.isRestToday && !calendar.todaySessionsAreComplete) {
      return null;
    }
    final next = calendar.nextPlannedOccurrence;
    if (next == null || next.scheduledDate == calendar.today) return null;
    final when = _relativeWhen(
      today: DateTime.parse(calendar.today),
      scheduled: DateTime.parse(next.scheduledDate),
    );
    return 'Next: ${next.sessionTitle} · $when';
  }

  static List<FixedProgrammeOccurrenceProjection> prioritizedTodaySessions(
    FixedProgrammeCalendarProjection calendar,
  ) {
    return authoredTodaySessions(calendar);
  }

  /// Display order is authored `session_order`, not resume priority.
  static List<FixedProgrammeOccurrenceProjection> authoredTodaySessions(
    FixedProgrammeCalendarProjection calendar,
  ) {
    final sessions = [...calendar.todaySessions];
    sessions.sort((a, b) => a.sessionOrder.compareTo(b.sessionOrder));
    return List.unmodifiable(sessions);
  }

  static String sessionCountCopy(int count) {
    if (count == 1) return '1 session scheduled';
    return '$count sessions scheduled';
  }

  static String? timeOfDayLabel(
    ProgrammeSessionTimeOfDay timeOfDay, {
    required bool sameDayGroup,
  }) {
    return switch (timeOfDay) {
      ProgrammeSessionTimeOfDay.morning => 'AM',
      ProgrammeSessionTimeOfDay.afternoon => 'PM',
      ProgrammeSessionTimeOfDay.evening => 'Evening',
      ProgrammeSessionTimeOfDay.any =>
        sameDayGroup ? 'Unspecified time' : null,
    };
  }

  static String? timeOfDaySpoken(
    ProgrammeSessionTimeOfDay timeOfDay, {
    required bool sameDayGroup,
  }) {
    return switch (timeOfDay) {
      ProgrammeSessionTimeOfDay.morning => 'Morning',
      ProgrammeSessionTimeOfDay.afternoon => 'Afternoon',
      ProgrammeSessionTimeOfDay.evening => 'Evening',
      ProgrammeSessionTimeOfDay.any =>
        sameDayGroup ? 'Unspecified time' : null,
    };
  }

  static String _relativeWhen({
    required DateTime today,
    required DateTime scheduled,
  }) {
    final days = DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days == 1) return 'Tomorrow';
    return AthleteProgrammeDateFormatter.weekdayDayMonth(scheduled);
  }

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _duration(String? value) => _text(value);
}
