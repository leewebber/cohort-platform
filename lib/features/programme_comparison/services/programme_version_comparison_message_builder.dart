import '../models/programme_version_comparison_models.dart';

class ProgrammeVersionComparisonMessageBuilder {
  const ProgrammeVersionComparisonMessageBuilder._();

  static List<String> buildSummaryMessages(
    ProgrammeVersionComparisonSummary summary,
  ) {
    if (summary.isIdentical && !summary.isPartial) {
      return [
        'No differences were found between Version '
        '${summary.identity.sourceVersionNumber} and Version '
        '${summary.identity.targetVersionNumber}.',
      ];
    }

    if (summary.isPartial) {
      return [
        'Comparison is partial because enrichment could not be completed exactly.',
        ...summary.limitationNotes,
      ];
    }

    final messages = <String>[];
    final metrics = summary.structureMetrics;
    final parts = <String>[];

    if (metrics.weekCountDelta != 0) {
      parts.add('${metrics.weekCountDelta.abs()} week${metrics.weekCountDelta.abs() == 1 ? '' : 's'}');
    }
    if (metrics.slotCountDelta != 0) {
      parts.add('${metrics.slotCountDelta.abs()} Session slot${metrics.slotCountDelta.abs() == 1 ? '' : 's'}');
    }
    if (summary.exerciseSetChange.netExerciseCountChange != 0 &&
        summary.exerciseSetChange.addedExercises.isNotEmpty ||
        summary.exerciseSetChange.removedExercises.isNotEmpty) {
      final exerciseDelta = summary.exerciseSetChange.addedExercises.length -
          summary.exerciseSetChange.removedExercises.length;
      if (exerciseDelta != 0) {
        parts.add('${exerciseDelta.abs()} Exercise${exerciseDelta.abs() == 1 ? '' : 's'}');
      }
    }

    if (parts.isNotEmpty) {
      final direction = metrics.slotCountDelta >= 0 &&
              metrics.weekCountDelta >= 0 &&
              summary.exerciseSetChange.netExerciseCountChange >= 0
          ? 'adds'
          : 'changes';
      messages.add(
        'Version ${summary.identity.targetVersionNumber} $direction ${parts.join(', ')}.',
      );
    }

    if (summary.sessionRevisionChanges.isNotEmpty) {
      messages.add(
        'Version ${summary.identity.targetVersionNumber} updates '
        '${summary.sessionRevisionChanges.length} Session Revision'
        '${summary.sessionRevisionChanges.length == 1 ? '' : 's'}.',
      );

      final first = summary.sessionRevisionChanges.first;
      if (first.sourceSessionName != null &&
          first.sourceRevisionNumber != null &&
          first.targetRevisionNumber != null &&
          first.sourceSessionName == first.targetSessionName) {
        messages.add(
          '${first.sourceSessionName} changed from Revision '
          '${first.sourceRevisionNumber} to Revision ${first.targetRevisionNumber}.',
        );
      }
    }

    if (summary.dayChanges.any((c) => c.changeType == ProgrammeChangeType.removed)) {
      messages.add(
        'Version ${summary.identity.targetVersionNumber} removes '
        '${summary.dayChanges.where((c) => c.changeType == ProgrammeChangeType.removed).length} '
        'training day${summary.dayChanges.where((c) => c.changeType == ProgrammeChangeType.removed).length == 1 ? '' : 's'}.',
      );
    }

    for (final warning in summary.warnings) {
      if (warning.trim().isNotEmpty) messages.add(warning.trim());
    }

    return messages;
  }

  static bool summaryContainsRawIdentifiers(List<String> messages) {
    final combined = messages.join(' ');
    return RegExp(
      r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
      caseSensitive: false,
    ).hasMatch(combined);
  }

  static bool summaryContainsMigrationRecommendation(List<String> messages) {
    final combined = messages.join(' ').toLowerCase();
    return combined.contains('upgrade') ||
        combined.contains('migrate') ||
        combined.contains('should assign');
  }
}
