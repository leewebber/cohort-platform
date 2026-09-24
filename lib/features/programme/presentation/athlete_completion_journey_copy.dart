/// Athlete-facing Sprint 3 completion and history copy.
///
/// Status chips, headlines, and supporting lines only. Not architecture.
abstract final class AthleteCompletionJourneyCopy {
  static const complete = 'Complete';
  static const calendarSupporting =
      'You can review this completed programme and its sessions.';

  static String completedProgrammesHeadline(String programmeTitle) {
    return 'You completed $programmeTitle.';
  }

  static const completedProgrammesSupporting =
      'You can still review the programme and your results.';

  static const refreshFailed = 'Refresh failed';
  static const progressRefreshHeadline = 'Couldn’t refresh progress';
  static const progressRefreshSupporting =
      'Showing your most recently loaded progress.';
  static const unavailable = 'Unavailable';
  static const progressBlockedHeadline = 'Progress couldn’t be loaded';
  static const tryAgainWhenReady = 'Try again when you’re ready.';

  static const historyRefreshHeadline = 'Couldn’t refresh history';
  static const historyRefreshSupporting =
      'Showing your most recently loaded history.';
  static const historyBlockedHeadline = 'History couldn’t be loaded';

  static const accessRequired = 'Access required';
  static const missingAthleteHeadline =
      'We couldn’t open your athlete profile';
  static const missingAthleteSupporting = 'Sign in again or try again.';

  static const athleteProfileRequired = 'Athlete profile required';
  static const coachOnlyHeadline = 'This area requires an athlete profile';
  static const coachOnlySupporting =
      'Your current account does not have athlete access.';

  static const currentProgramme = 'Current programme';

  static String currentAfterCompletedHeadline(String currentTitle) {
    return '$currentTitle is your current programme.';
  }

  static String currentAfterCompletedSupporting(String completedTitle) {
    return 'Your completed $completedTitle results remain in History.';
  }

  static String displayTitle(String? authored, {String? fallback}) {
    final title = authored?.trim();
    if (title != null && title.isNotEmpty) return title;
    final code = fallback?.trim();
    if (code != null && code.isNotEmpty) return code;
    return 'this programme';
  }
}
