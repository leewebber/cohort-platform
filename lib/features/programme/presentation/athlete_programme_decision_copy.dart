/// Athlete-facing copy for Programme Discovery and Decision.
///
/// Production journey must not mention testing access, purchase, matching,
/// or AI recommendation.
abstract final class AthleteProgrammeDecisionCopy {
  static const catalogueTitle = 'Choose programme';
  static const catalogueIntro =
      'Inspect programmes, compare two options, and enrol only when you '
      'are ready.';
  static const viewDetails = 'View details';
  static const compare = 'Compare';
  static const selectedForCompare = 'Selected for compare';
  static const compareNow = 'Compare selected';
  static const clearCompare = 'Clear comparison';
  static const currentProgramme = 'Current programme';
  static const available = 'Available';
  static const unavailable = 'Not available';
  static const notProvided = 'Not provided';
  static const notSpecified = 'Not specified';
  static const atAGlance = 'At a glance';
  static const switchingUnavailable =
      'Programme switching is not available here yet.';
  static const enrol = 'Enrol';
  static const enrolReviewTitle = 'Enrol in this programme?';
  static const enrolConfirm = 'Confirm enrolment';
  static const cancel = 'Cancel';
  static const retry = 'Retry';
  static const enrolPending = 'Enrolling…';
  static const enrolSuccess = 'Enrolled. Your programme is ready.';
  static const alreadyEnrolled = 'You are already enrolled in this programme.';
  static const catalogueLoading = 'Loading programmes…';
  static const catalogueEmpty =
      'No programmes are available in the catalogue right now.';
  static const catalogueUnavailable =
      'Programmes could not be loaded. Retry to try again.';
  static const detailUnavailable =
      'This programme is not available to inspect right now.';
  static const compareNeedTwo = 'Select exactly two programmes to compare.';
  static const compareUnavailable =
      'One of the selected programmes is no longer available.';
  static const assignedDuringFlow =
      'You now have a current programme. Enrolment is not available here.';

  static String enrolReviewBody(String programmeName) {
    return '$programmeName becomes your current programme. Your training '
        'stays pinned to this exact programme version.';
  }

  static String comparisonAnnouncement({
    required String dimension,
    required String leftName,
    required String leftValue,
    required String rightName,
    required String rightValue,
  }) {
    return '$dimension. $leftName, $leftValue. $rightName, $rightValue.';
  }
}
