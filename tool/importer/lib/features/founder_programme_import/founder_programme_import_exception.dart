class FounderProgrammeImportException implements Exception {
  FounderProgrammeImportException(
    this.message, {
    this.validationErrors = const [],
    this.writesStarted = false,
  });

  final String message;
  final List<String> validationErrors;
  final bool writesStarted;

  @override
  String toString() {
    if (validationErrors.isEmpty) return message;
    return '$message\n${validationErrors.map((e) => '- $e').join('\n')}';
  }
}
