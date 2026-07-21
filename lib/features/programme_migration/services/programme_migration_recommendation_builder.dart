import '../models/programme_migration_plan_models.dart';

class ProgrammeMigrationRecommendationBuilder {
  const ProgrammeMigrationRecommendationBuilder._();

  static String recommendationFor(MigrationClassification classification) {
    switch (classification) {
      case MigrationClassification.alreadyCompleted:
        return 'Assignment is already completed.';
      case MigrationClassification.safeImmediate:
        return 'Assignment has not begun or programme content is unchanged.';
      case MigrationClassification.safeAfterCurrentSession:
        return 'Current session should be completed before migration.';
      case MigrationClassification.safeAfterCurrentWeek:
        return 'Current week should be completed before migration.';
      case MigrationClassification.manualReview:
        return 'Programme structure diverged at or before the current position.';
      case MigrationClassification.cannotDetermine:
        return 'Current progress cannot be resolved authoritatively.';
      case MigrationClassification.unsupported:
        return 'Assignment status is not eligible for migration planning.';
    }
  }

  static bool recommendationContainsMigrationCommand(String recommendation) {
    final lower = recommendation.toLowerCase();
    return lower.contains('migrate now') ||
        lower.contains('will migrate') ||
        lower.contains('automatically upgrade');
  }
}
