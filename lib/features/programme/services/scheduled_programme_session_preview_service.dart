import '../../session/models/session_execution_plan.dart';
import '../../session/services/session_execution_loader.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';

class ScheduledProgrammeSessionPreview {
  const ScheduledProgrammeSessionPreview({
    required this.calendar,
    required this.day,
    this.occurrence,
    this.plan,
  });

  final FixedProgrammeCalendarProjection calendar;
  final AthleteProgrammeWeekDayPresentation day;
  final FixedProgrammeOccurrenceProjection? occurrence;
  final SessionExecutionPlan? plan;

  bool get isRest => occurrence == null;
}

/// Resolves immutable assigned content for a calendar day without preparing or
/// starting a training session.
///
/// The caller supplies an authenticated fixed-calendar snapshot, then selects
/// only by occurrence identity. Protocol identity is always recovered from the
/// authoritative occurrence contained in that snapshot.
class ScheduledProgrammeSessionPreviewService {
  ScheduledProgrammeSessionPreviewService({SessionExecutionLoader? loader})
    : _loader = loader ?? SessionExecutionLoader();

  final SessionExecutionLoader _loader;

  Future<ScheduledProgrammeSessionPreview> load({
    required FixedProgrammeCalendarProjection calendar,
    required AthleteProgrammeWeekDayPresentation day,
  }) async {
    if (calendar.scheduleMode != 'fixed_schedule') {
      throw StateError(
        'Scheduled preview requires a fixed programme calendar.',
      );
    }
    if (day.isOutsideProgramme) {
      throw StateError('This date is outside the active programme.');
    }

    final selected = day.occurrence;
    if (selected == null) {
      if (day.state != FixedProgrammeOccurrenceState.rest) {
        throw StateError('Scheduled preview is missing an occurrence.');
      }
      return ScheduledProgrammeSessionPreview(calendar: calendar, day: day);
    }

    final occurrence = _authoritativeOccurrence(
      calendar,
      selected.occurrenceId,
    );
    if (occurrence.assignmentId != calendar.assignmentId ||
        occurrence.assignmentId != selected.assignmentId ||
        occurrence.scheduledDate != _isoDate(day.date) ||
        occurrence.scheduledDate != selected.scheduledDate ||
        occurrence.sessionSlotId != selected.sessionSlotId ||
        occurrence.programmeVersionId != selected.programmeVersionId ||
        occurrence.programmedSessionKey != selected.programmedSessionKey ||
        occurrence.protocolId != selected.protocolId ||
        occurrence.state != day.state ||
        occurrence.state != selected.state) {
      throw StateError(
        'Scheduled preview does not match the assigned occurrence linkage.',
      );
    }

    final loaded = await _loader.load(
      protocolId: occurrence.protocolId,
      displayTitle: occurrence.sessionTitle,
      programmeContextLabel: calendar.programmeName,
    );
    if (!loaded.plan.hasExecutableBlocks) {
      throw StateError('Scheduled session content is unavailable.');
    }
    return ScheduledProgrammeSessionPreview(
      calendar: calendar,
      day: day,
      occurrence: occurrence,
      plan: loaded.plan,
    );
  }

  FixedProgrammeOccurrenceProjection _authoritativeOccurrence(
    FixedProgrammeCalendarProjection calendar,
    String occurrenceId,
  ) {
    FixedProgrammeOccurrenceProjection? match;
    for (final occurrence in calendar.occurrences) {
      if (occurrence.occurrenceId != occurrenceId) continue;
      if (match != null) {
        throw StateError(
          'Scheduled preview occurrence identity is duplicated.',
        );
      }
      match = occurrence;
    }
    if (match == null) {
      throw StateError('Scheduled preview occurrence is not assigned.');
    }
    return match;
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
