import 'package:founder_importer/features/programme_builder/models/programme_builder_path.dart';

/// Coach-facing publish readiness check derived from validation.
class ProgrammePublishReadinessCheck {
  const ProgrammePublishReadinessCheck({
    required this.id,
    required this.label,
    required this.passed,
    this.message,
    this.path,
  });

  final String id;
  final String label;
  final bool passed;
  final String? message;
  final ProgrammeBuilderPath? path;
}

/// Derived publish readiness summary — never bypasses validation service.
class ProgrammePublishReadiness {
  const ProgrammePublishReadiness({
    required this.isReady,
    required this.checks,
    required this.blockingIssueCount,
    required this.warningCount,
  });

  final bool isReady;
  final List<ProgrammePublishReadinessCheck> checks;
  final int blockingIssueCount;
  final int warningCount;

  factory ProgrammePublishReadiness.notReady({
    required List<ProgrammePublishReadinessCheck> checks,
    required int blockingIssueCount,
    required int warningCount,
  }) {
    return ProgrammePublishReadiness(
      isReady: false,
      checks: checks,
      blockingIssueCount: blockingIssueCount,
      warningCount: warningCount,
    );
  }

  factory ProgrammePublishReadiness.ready({
    required List<ProgrammePublishReadinessCheck> checks,
    int warningCount = 0,
  }) {
    return ProgrammePublishReadiness(
      isReady: true,
      checks: checks,
      blockingIssueCount: 0,
      warningCount: warningCount,
    );
  }
}
