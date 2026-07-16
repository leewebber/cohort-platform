import '../models/programme_builder_document.dart';
import '../models/programme_builder_operation_result.dart';
import '../models/programme_publish_readiness.dart';
import '../models/programme_validation_result.dart';

/// Publish and clone orchestration for programme builder workflows.
abstract class ProgrammeBuilderPublishCoordinator {
  /// Validates and derives publish readiness without persisting.
  ProgrammePublishReadiness validateReadiness(
    ProgrammeBuilderDocument document, {
    Set<String>? knownProtocolIds,
  });

  /// Full publish workflow: validate → save if dirty → publish.
  Future<ProgrammeBuilderOperationResult> publish({
    required ProgrammeBuilderDocument document,
    required String coachId,
    Set<String>? knownProtocolIds,
  });

  /// Clone Version — same lineage, version N+1 draft.
  ///
  /// Delegates to [ProgrammePublishingService.cloneToNewDraft].
  Future<ProgrammeBuilderOperationResult> cloneVersion({
    required String publishedVersionId,
    required String coachId,
  });
}

/// Typed validation output for publish coordinator preflight.
class ProgrammeBuilderPublishValidation {
  const ProgrammeBuilderPublishValidation({
    required this.validation,
    required this.readiness,
  });

  final ProgrammeValidationResult validation;
  final ProgrammePublishReadiness readiness;

  bool get canPublish => readiness.isReady && validation.isPublishable;
}
