/// Structured validation issue for Exercise Knowledge contracts.
///
/// Shape mirrors [PlanPackageValidationIssue] conventions (path/message/code).
class ExerciseKnowledgeValidationIssue {
  const ExerciseKnowledgeValidationIssue({
    required this.path,
    required this.message,
    this.code,
  });

  final String path;
  final String message;
  final String? code;

  @override
  String toString() =>
      code == null ? '$path: $message' : '$path [$code]: $message';
}
