/// Catalogue row actions.
enum ProgrammeCatalogueAction {
  open,
  validate,
  publish,
  preview,
  cloneVersion,
  duplicateProgramme,
  archive,
  deleteDraft,
}

/// Result of a catalogue action.
class ProgrammeCatalogueActionResult {
  const ProgrammeCatalogueActionResult({
    required this.action,
    required this.success,
    this.versionId,
    this.message,
    this.navigateToEditor = false,
    this.refreshTab = false,
    this.warnings = const [],
    this.debugDetail,
  });

  final ProgrammeCatalogueAction action;
  final bool success;
  final String? versionId;
  final String? message;
  final bool navigateToEditor;
  final bool refreshTab;

  /// Structured failure detail for debug surfaces (not shown to end users).
  final List<String> warnings;

  /// Multi-line debug text (exceptions, store codes, operation steps).
  final String? debugDetail;
}
