import '../../../models/training_content_vocabulary.dart';

/// Lightweight list-row model for Training Library tabs.
class TrainingLibraryItemSummary {
  const TrainingLibraryItemSummary({
    required this.contentId,
    required this.contentKind,
    required this.title,
    this.sessionType,
    this.durationMin,
    this.stepCount,
    this.updatedAt,
    this.endorsementStatus,
    this.authoringScope,
    this.publicCode,
  });

  final String contentId;
  final TrainingContentKind contentKind;
  final String title;
  final String? sessionType;
  final int? durationMin;
  final int? stepCount;
  final DateTime? updatedAt;
  final TrainingEndorsementStatus? endorsementStatus;
  final TrainingAuthoringScope? authoringScope;

  /// Official Cohort Protocol code (e.g. RN-006). Null for coach Sessions.
  final String? publicCode;

  bool get isCohortProtocol =>
      contentKind == TrainingContentKind.cohortProtocol;

  bool get isReusableSession =>
      contentKind == TrainingContentKind.session &&
      authoringScope == TrainingAuthoringScope.coachPrivate;
}
