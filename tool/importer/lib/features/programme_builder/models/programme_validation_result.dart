import 'package:founder_importer/features/programme_builder/models/programme_builder_path.dart';

/// Validation issue severity.
enum ProgrammeValidationSeverity {
  error,
  warning,
  info,
}

/// Stable validation codes for programme builder rules.
enum ProgrammeValidationCode {
  metaNameRequired,
  metaLineageCodeInvalid,
  metaDurationMismatch,
  treeNoWeeks,
  treeWeekNumberGap,
  treeDuplicateWeekNumber,
  treeDayKeyInvalid,
  treeDuplicateDayKey,
  treeDuplicateDayOrder,
  treeDuplicateSlotOrder,
  treeRestDayHasSlots,
  treeTrainingDayNoSlots,
  treeEmptyProgramme,
  slotProtocolRequired,
  slotProtocolUnknown,
  slotOptionalFlagMismatch,
  slotDisplayTitleDuplicatesProtocol,
  engineResolverRejects,
  engineSampleResolutionFail,
}

/// A single validation issue with optional document path.
class ProgrammeValidationIssue {
  const ProgrammeValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.path,
  });

  final ProgrammeValidationCode code;
  final ProgrammeValidationSeverity severity;
  final String message;
  final ProgrammeBuilderPath? path;

  bool get isBlocking => severity == ProgrammeValidationSeverity.error;
}

/// Aggregate validation output.
class ProgrammeValidationResult {
  const ProgrammeValidationResult({
    required this.issues,
  });

  final List<ProgrammeValidationIssue> issues;

  bool get isPublishable => blockingIssueCount == 0;

  int get blockingIssueCount =>
      issues.where((issue) => issue.isBlocking).length;

  int get warningCount => issues
      .where((issue) => issue.severity == ProgrammeValidationSeverity.warning)
      .length;

  int get infoCount => issues
      .where((issue) => issue.severity == ProgrammeValidationSeverity.info)
      .length;

  factory ProgrammeValidationResult.empty() {
    return const ProgrammeValidationResult(issues: []);
  }

  factory ProgrammeValidationResult.fromIssues(
    List<ProgrammeValidationIssue> issues,
  ) {
    return ProgrammeValidationResult(issues: issues);
  }
}
