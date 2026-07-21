import '../../../models/session_revision_vocabulary.dart';
import '../../session_revision/models/content_usage_vocabulary.dart';
import '../../session_revision/models/session_revision_usage_models.dart';
import '../../exercise_relationship/models/exercise_usage_models.dart';

/// Coach-facing labels for governance UI (M9.5).
class GovernanceCopy {
  GovernanceCopy._();

  static String lifecycleLabel(SessionRevisionLifecycleStatus status) {
    return switch (status) {
      SessionRevisionLifecycleStatus.draft => 'Draft',
      SessionRevisionLifecycleStatus.published => 'Published',
      SessionRevisionLifecycleStatus.archived => 'Archived',
    };
  }

  static String revisionIdentityLine({
    required String sessionName,
    required int revisionNumber,
    required SessionRevisionLifecycleStatus lifecycleStatus,
  }) {
    return '$sessionName\nRevision $revisionNumber · ${lifecycleLabel(lifecycleStatus)}';
  }

  static String compactRevisionLine({
    required int revisionNumber,
    required SessionRevisionLifecycleStatus lifecycleStatus,
  }) {
    return 'Revision $revisionNumber · ${lifecycleLabel(lifecycleStatus)}';
  }

  static String programmeVersionReference(SessionRevisionProgrammeReference ref) {
    return '${ref.programmeName} · Programme Version ${ref.programmeVersionNumber}';
  }

  static String programmeVersionReferenceFromExercise(
    ExerciseProgrammeReference ref,
  ) {
    return '${ref.programmeName} · Programme Version ${ref.programmeVersionNumber}';
  }

  static String sessionRevisionReference(ExerciseRevisionReference ref) {
    return '${ref.sessionName} · Revision ${ref.sessionRevisionNumber}';
  }

  static String classificationLabel(ContentUsageClassification classification) {
    return switch (classification) {
      ContentUsageClassification.directAuthored => 'Authored usage',
      ContentUsageClassification.activeOperational => 'Active operational usage',
      ContentUsageClassification.historicalPerformance =>
        'Historical usage',
    };
  }

  static String programmeVersionCountLabel(int count) {
    return count == 1 ? '1 Programme Version' : '$count Programme Versions';
  }

  static String slotCountLabel(int count) {
    return count == 1 ? '1 programme slot' : '$count programme slots';
  }

  static String activeAssignmentCountLabel(int count) {
    return count == 1 ? '1 Active Assignment' : '$count Active Assignments';
  }

  static String historicalPerformanceCountLabel(int count) {
    return count == 1
        ? '1 Historical Performance'
        : '$count Historical Performances';
  }

  static String sessionRevisionCountLabel(int count) {
    return count == 1 ? '1 Session Revision' : '$count Session Revisions';
  }

  static String sessionLineageCountLabel(int count) {
    return count == 1 ? '1 Session Lineage' : '$count Session Lineages';
  }

  static String blockLinkSummary({
    required int blockCount,
    required int revisionCount,
  }) {
    final blockLabel = blockCount == 1 ? '1 session block' : '$blockCount session blocks';
    final revisionLabel =
        revisionCount == 1 ? '1 revision' : '$revisionCount revisions';
    return 'Used in $blockLabel across $revisionLabel.';
  }

  static const unusedSessionRevisionMessage =
      'This revision is not currently used by any programme, active assignment, '
      'or historical performance.';

  static const historicalOnlySessionRevisionMessage =
      'This revision is only referenced by historical performances. '
      'It is safe to archive but not delete.';

  static const sessionUsageLookupFailedMessage =
      'Usage information could not be loaded. Destructive actions remain unavailable.';

  static const exerciseUsageLookupFailedMessage =
      'Usage information could not be loaded.';

  static const exerciseUnusedMessage =
      'This exercise is not currently used by any session revision, programme, '
      'active assignment, or historical performance.';

  static String createRevisionSuccessMessage({
    required int newRevisionNumber,
    required int priorRevisionNumber,
  }) {
    return 'Draft revision $newRevisionNumber created. '
        'Existing programmes still use revision $priorRevisionNumber.';
  }
}
