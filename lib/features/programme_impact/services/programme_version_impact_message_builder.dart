import '../../../features/programme_impact/models/programme_version_impact_models.dart';

/// Coach-facing derived copy for Programme Version impact (M10.1).
class ProgrammeVersionImpactMessageBuilder {
  const ProgrammeVersionImpactMessageBuilder._();

  static List<String> buildSummaryMessages(ProgrammeVersionImpactSummary summary) {
    final messages = <String>[];

    if (summary.hasActiveOperationalImpact && summary.hasHistoricalImpact) {
      messages.add(
        'This Programme Version is assigned to ${summary.activeAssignmentCount} '
        'active athletes and has ${summary.historicalImpact.terminalRecordCount} '
        'historical session records.',
      );
    } else if (summary.hasActiveOperationalImpact) {
      messages.add(
        'This Programme Version is assigned to ${summary.activeAssignmentCount} '
        'active athletes.',
      );
    } else if (summary.hasHistoricalImpact) {
      messages.add(
        'This version is no longer actively assigned but remains linked to '
        '${summary.historicalImpact.terminalRecordCount} historical performances.',
      );
    } else if (summary.isUnused) {
      messages.add(
        'This version has no active assignments or historical performances.',
      );
    }

    if (summary.lineageContext.hasNewerVersion &&
        summary.lineageContext.latestPublishedVersionNumber != null &&
        summary.lineageContext.latestPublishedVersionNumber !=
            summary.versionNumber) {
      messages.add(
        'A newer published Programme Version exists. Existing assignments remain '
        'pinned to Version ${summary.versionNumber}.',
      );
    }

    if (summary.historicalImpact.limitationNote != null &&
        summary.historicalImpact.limitationNote!.trim().isNotEmpty) {
      messages.add(summary.historicalImpact.limitationNote!.trim());
    }

    for (final warning in summary.warnings) {
      if (warning.trim().isEmpty) continue;
      messages.add(warning.trim());
    }

    return messages;
  }

  static bool summaryContainsAthleteIdentifiers(List<String> messages) {
    final combined = messages.join(' ').toLowerCase();
    return combined.contains('athlete_id') ||
        combined.contains('athlete id') ||
        RegExp(r'\bathlete-[a-z0-9-]+\b').hasMatch(combined);
  }
}
