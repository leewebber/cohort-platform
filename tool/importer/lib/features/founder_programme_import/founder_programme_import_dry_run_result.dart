/// Result of validating a founder YAML import without writing to Supabase.
class FounderProgrammeImportDryRunResult {
  const FounderProgrammeImportDryRunResult({
    required this.importKey,
    required this.lineageCode,
    required this.validationErrors,
    required this.warnings,
    required this.unresolvedExerciseSlugs,
    required this.sessionCount,
    required this.wouldCreateLineage,
    required this.readyForApply,
  });

  final String importKey;
  final String lineageCode;
  final List<String> validationErrors;
  final List<String> warnings;
  final List<String> unresolvedExerciseSlugs;
  final int sessionCount;
  final bool wouldCreateLineage;
  final bool readyForApply;

  String get summaryMessage {
    if (!readyForApply) {
      return 'Dry-run failed: ${validationErrors.length} validation error(s).';
    }
    final action = wouldCreateLineage ? 'create' : 'update';
    return 'Dry-run passed: would $action draft $lineageCode ($importKey) with $sessionCount session(s).';
  }
}
