class FounderAcceptanceInstallResult {
  const FounderAcceptanceInstallResult({
    required this.programmeCreated,
    required this.programmeUpdated,
    required this.sessionCreated,
    required this.sessionUpdated,
    required this.blockCount,
    required this.summaryMessage,
  });

  final bool programmeCreated;
  final bool programmeUpdated;
  final bool sessionCreated;
  final bool sessionUpdated;
  final int blockCount;
  final String summaryMessage;

  bool get isSuccess => blockCount > 0;
}
