/// Records rows created before a multi-step programme create failed.
///
/// Pre-beta: replace with a single transactional Supabase RPC so lineage,
/// version, and template tree persist atomically.
class ProgrammePartialCreationState {
  const ProgrammePartialCreationState({
    this.lineageId,
    this.versionId,
    required this.failureStage,
  });

  final String? lineageId;
  final String? versionId;
  final String failureStage;

  bool get hasLineage => lineageId != null && lineageId!.isNotEmpty;
  bool get hasVersion => versionId != null && versionId!.isNotEmpty;

  List<String> toDiagnosticLines() {
    return [
      'partialCreation.failureStage=$failureStage',
      if (hasLineage) 'partialCreation.lineageId=$lineageId',
      if (hasVersion) 'partialCreation.versionId=$versionId',
      'partialCreation.note=Pre-beta: use transactional create RPC; no auto-delete yet',
    ];
  }
}
