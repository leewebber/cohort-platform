/// Structured validation issue for Plan Package compile failures.
class PlanPackageValidationIssue {
  const PlanPackageValidationIssue({
    required this.path,
    required this.message,
    this.code,
  });

  /// JSON-pointer-like path into the package document (e.g. `weeks[0].days`).
  final String path;

  final String message;

  /// Optional machine-readable code for tests and tooling.
  final String? code;

  @override
  String toString() =>
      code == null ? '$path: $message' : '$path [$code]: $message';
}
