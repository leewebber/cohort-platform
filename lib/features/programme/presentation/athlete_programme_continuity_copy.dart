import '../domain/athlete_programme_continuity.dart';
import 'athlete_completion_journey_copy.dart';

/// Single athlete-facing continuity vocabulary. Not colour-only.
abstract final class AthleteProgrammeContinuityCopy {
  static const currentProgramme = 'Current programme';
  static const continuingStartedVersion =
      'You’re continuing the programme version you started.';
  static const differentVersionAvailable =
      'Another version is available to view. Your current training has not '
      'changed.';
  static const pinnedUnavailable =
      'This programme version is temporarily unavailable. Your training has '
      'not been changed.';
  static const retry = 'Retry';
  static const timezoneRepairRequired =
      'Your programme timezone needs to be confirmed before scheduled '
      'training can continue.';
  static const travelAnchor =
      'Programme dates stay on this training timezone, including when you '
      'travel.';
  static const timezoneRequired =
      'A training timezone is required to schedule this programme correctly.';
  static const selectTimezone = 'Select timezone';
  static const useSelectedTimezone = 'Use selected timezone';
  static const changeTimezone = 'Change';
  static const trainingTimezone = 'Training timezone';
  static const suggestedTimezones = 'Suggested';
  static const allTimezones = 'All timezones';
  static const searchResults = 'Search results';
  static const intendedStartDate = 'Intended start date';
  static const intendedStartProvisional = 'Intended local start (to confirm)';
  static const confirmedStartDate = 'Confirmed start date';
  static const searchTimezones = 'Search timezones';
  static const programmeUnchangedHeadline = 'Your programme is unchanged';
  static const pinnedUnavailableHeadline = 'Programme temporarily unavailable';
  static const timezoneRepairHeadline = 'Confirm your training timezone';
  static const enrolledHeadline = 'You’re enrolled';
  static const currentProgrammeHeadline = 'Current programme';
  static const scheduleUnresolved =
      'Scheduled training cannot be resolved until this timezone is a '
      'validated IANA identifier.';
  static const repairNotApplied =
      'Your assignment has not been changed. No timezone repair has been '
      'applied.';

  static String statusChip(AthleteProgrammeContinuityStatus status) {
    switch (status) {
      case AthleteProgrammeContinuityStatus.currentDefault:
      case AthleteProgrammeContinuityStatus.currentPinned:
      case AthleteProgrammeContinuityStatus.currentPinnedWithDifferentAvailable:
        return currentProgramme;
      case AthleteProgrammeContinuityStatus.completed:
        return 'Complete';
      case AthleteProgrammeContinuityStatus.pinnedUnavailable:
        return 'Unavailable';
      case AthleteProgrammeContinuityStatus.none:
        return 'Available';
    }
  }

  static String overviewMessage(AthleteProgrammeContinuity continuity) {
    if (continuity.needsTimezoneRepair) return timezoneRepairRequired;
    switch (continuity.status) {
      case AthleteProgrammeContinuityStatus.currentDefault:
        return currentProgramme;
      case AthleteProgrammeContinuityStatus.currentPinned:
        return continuingStartedVersion;
      case AthleteProgrammeContinuityStatus.currentPinnedWithDifferentAvailable:
        return '$continuingStartedVersion $differentVersionAvailable';
      case AthleteProgrammeContinuityStatus.pinnedUnavailable:
        return pinnedUnavailable;
      case AthleteProgrammeContinuityStatus.completed:
        return AthleteCompletionJourneyCopy.completedProgrammesSupporting;
      case AthleteProgrammeContinuityStatus.none:
        return 'You are not enrolled in a programme yet.';
    }
  }

  static String homeCalendarMessage(AthleteProgrammeContinuity continuity) {
    if (continuity.needsTimezoneRepair) return timezoneRepairRequired;
    if (continuity.isPinnedUnavailable) return pinnedUnavailable;
    return overviewMessage(continuity);
  }

  static String failureMessage(Object error) {
    final text = error.toString();
    if (text.contains('timezone_unavailable') ||
        text.contains('invalid timezone') ||
        text.contains('invalid_timezone')) {
      return timezoneRepairRequired;
    }
    return pinnedUnavailable;
  }
}
