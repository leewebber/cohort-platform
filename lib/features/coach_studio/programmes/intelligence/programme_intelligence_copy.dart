import '../../../../models/programme_vocabulary.dart';
import '../../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../../programme_migration/models/programme_migration_plan_models.dart';

/// Coach-facing copy for Programme Intelligence (M10.4). No raw IDs.
class ProgrammeIntelligenceCopy {
  const ProgrammeIntelligenceCopy._();

  static const sectionTitle = 'Programme Intelligence';

  static String lifecycleLabel(ProgrammeLifecycleStatus status) {
    return switch (status) {
      ProgrammeLifecycleStatus.draft => 'Draft',
      ProgrammeLifecycleStatus.published => 'Published',
      ProgrammeLifecycleStatus.archived => 'Archived',
    };
  }

  static String migrationClassificationLabel(MigrationClassification classification) {
    return switch (classification) {
      MigrationClassification.alreadyCompleted => 'Completed',
      MigrationClassification.safeImmediate => 'Safe now',
      MigrationClassification.safeAfterCurrentSession => 'After session',
      MigrationClassification.safeAfterCurrentWeek => 'After week',
      MigrationClassification.manualReview => 'Review',
      MigrationClassification.cannotDetermine => 'Unknown',
      MigrationClassification.unsupported => 'Unsupported',
    };
  }

  static String changeTypeLabel(ProgrammeChangeType changeType) {
    return switch (changeType) {
      ProgrammeChangeType.added => 'Added',
      ProgrammeChangeType.removed => 'Removed',
      ProgrammeChangeType.modified => 'Modified',
      ProgrammeChangeType.moved => 'Moved',
      ProgrammeChangeType.replaced => 'Replaced',
      ProgrammeChangeType.unchanged => 'Unchanged',
    };
  }

  static String impactUnavailableMessage = 'Impact information could not be loaded.';
  static String comparisonUnavailableMessage =
      'Comparison could not be loaded for the selected version.';
  static String migrationUnavailableMessage =
      'Migration planning could not be loaded.';
  static String selectComparisonPrompt =
      'Choose another version in this lineage to compare.';
  static String noOtherVersionsMessage =
      'No other versions are available in this lineage.';

  static String versionLabel(int versionNumber) => 'Version $versionNumber';

  static String assignmentRowLabel(int index) => 'Assignment ${index + 1}';

  static bool containsRawUuid(String text) {
    return RegExp(
      r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
      caseSensitive: false,
    ).hasMatch(text);
  }
}
