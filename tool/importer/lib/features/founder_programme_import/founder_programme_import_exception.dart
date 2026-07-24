class FounderProgrammeImportException implements Exception {
  FounderProgrammeImportException(
    this.message, {
    this.validationErrors = const [],
  });

  final String message;
  final List<String> validationErrors;

  @override
  String toString() {
    if (validationErrors.isEmpty) return message;
    return '$message\n${validationErrors.map((e) => '- $e').join('\n')}';
  }
}
