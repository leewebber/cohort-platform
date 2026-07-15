/// Result of deleting programme slot outcomes for an assignment.
class ProgrammeSlotOutcomeDeleteResult {
  const ProgrammeSlotOutcomeDeleteResult({
    required this.deletedCount,
    required this.deletedIds,
  });

  final int deletedCount;
  final List<String> deletedIds;
}
