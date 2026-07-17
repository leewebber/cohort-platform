import 'programme_validation_result.dart';
import 'programme_builder_document.dart';
import 'programme_partial_creation_state.dart';

/// Typed builder workflow status.
enum ProgrammeBuilderOperationStatus {
  created,
  saved,
  validationFailed,
  notEditable,
  notReady,
  storeFailed,
  published,
  cloned,
  duplicated,
  deleted,
  archived,
  noOp,
}

/// Result of a builder lifecycle or persistence operation.
class ProgrammeBuilderOperationResult {
  const ProgrammeBuilderOperationResult({
    required this.status,
    this.document,
    this.validation,
    this.warnings = const [],
    this.publishedVersionId,
    this.sourceVersionId,
    this.newLineageCode,
    this.partialCreation,
  });

  final ProgrammeBuilderOperationStatus status;
  final ProgrammeBuilderDocument? document;
  final ProgrammeValidationResult? validation;
  final List<String> warnings;
  final String? publishedVersionId;
  final String? sourceVersionId;
  final String? newLineageCode;
  final ProgrammePartialCreationState? partialCreation;

  bool get isSuccess =>
      status == ProgrammeBuilderOperationStatus.created ||
      status == ProgrammeBuilderOperationStatus.saved ||
      status == ProgrammeBuilderOperationStatus.published ||
      status == ProgrammeBuilderOperationStatus.cloned ||
      status == ProgrammeBuilderOperationStatus.duplicated ||
      status == ProgrammeBuilderOperationStatus.deleted ||
      status == ProgrammeBuilderOperationStatus.archived;
}

/// Result of a structural edit command.
class ProgrammeBuilderEditResult {
  const ProgrammeBuilderEditResult({
    required this.document,
    this.validation,
    this.canUndo = false,
    this.canRedo = false,
  });

  final ProgrammeBuilderDocument document;
  final ProgrammeValidationResult? validation;
  final bool canUndo;
  final bool canRedo;
}
