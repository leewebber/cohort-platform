class FounderProgrammeImportResult {
  const FounderProgrammeImportResult({
    required this.importKey,
    required this.lineageId,
    required this.lineageCode,
    required this.versionId,
    required this.created,
    required this.sessionCount,
    required this.summaryMessage,
  });

  final String importKey;
  final String lineageId;
  final String lineageCode;
  final String versionId;
  final bool created;
  final int sessionCount;
  final String summaryMessage;
}
