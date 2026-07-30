import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/training_content_vocabulary.dart';
import 'session_template_taxonomy.dart';

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
    this.purpose,
    this.requiredEquipment,
    this.technicalComplexity,
    this.primarySessionIntent,
    this.modalityFilter,
    this.equipmentFilter,
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

  /// Official Cohort Protocol / template code (e.g. RN-006, TMP-001).
  final String? publicCode;

  final String? purpose;
  final String? requiredEquipment;
  final String? technicalComplexity;
  final SessionIntent? primarySessionIntent;
  final SessionTemplateModalityFilter? modalityFilter;
  final SessionTemplateEquipmentFilter? equipmentFilter;

  bool get isCohortProtocol =>
      contentKind == TrainingContentKind.cohortProtocol;

  bool get isReusableSession =>
      contentKind == TrainingContentKind.session &&
      authoringScope == TrainingAuthoringScope.coachPrivate;

  bool get isCanonicalTemplate =>
      contentKind == TrainingContentKind.sessionTemplate &&
      authoringScope == TrainingAuthoringScope.cohortGlobal;
}
