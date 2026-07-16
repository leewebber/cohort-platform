import '../../../data/repositories/programme_store_exception.dart';
import '../models/programme_builder_operation_result.dart';
import '../models/programme_publish_readiness.dart';
import 'programme_builder_publish_coordinator.dart';
import 'programme_builder_service.dart';
import 'programme_builder_validation_service.dart';
import '../../programme/services/programme_publishing_service.dart';
import '../models/programme_builder_document.dart';

/// Publish and clone orchestration for Programme Builder catalogue workflows.
class ProgrammeBuilderPublishCoordinatorImpl
    implements ProgrammeBuilderPublishCoordinator {
  ProgrammeBuilderPublishCoordinatorImpl({
    required ProgrammeBuilderService builderService,
    required ProgrammePublishingService publishingService,
    required ProgrammeBuilderValidationService validationService,
  })  : _builderService = builderService,
        _publishingService = publishingService,
        _validationService = validationService;

  final ProgrammeBuilderService _builderService;
  final ProgrammePublishingService _publishingService;
  final ProgrammeBuilderValidationService _validationService;

  @override
  ProgrammePublishReadiness validateReadiness(
    ProgrammeBuilderDocument document, {
    Set<String>? knownProtocolIds,
  }) {
    final validation = _validationService.validateForPublish(
      document,
      knownProtocolIds: knownProtocolIds,
    );

    return _validationService.buildPublishReadiness(
      document,
      validation: validation,
      knownProtocolIds: knownProtocolIds,
    );
  }

  @override
  Future<ProgrammeBuilderOperationResult> publish({
    required ProgrammeBuilderDocument document,
    required String coachId,
    Set<String>? knownProtocolIds,
  }) async {
    final readiness = validateReadiness(
      document,
      knownProtocolIds: knownProtocolIds,
    );

    if (!readiness.isReady) {
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.notReady,
        document: document,
        validation: _validationService.validateForPublish(
          document,
          knownProtocolIds: knownProtocolIds,
        ),
      );
    }

    ProgrammeBuilderDocument workingDocument = document;
    if (document.isDirty || document.hasUnsavedChanges) {
      final saveResult = await _builderService.saveDocument(document);
      if (!saveResult.isSuccess || saveResult.document == null) {
        return saveResult;
      }
      workingDocument = saveResult.document!;
    }

    final versionId = workingDocument.metadata.versionId;
    if (versionId == null || versionId.isEmpty) {
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        document: workingDocument,
      );
    }

    try {
      final published = await _publishingService.publishDraft(
        versionId: versionId,
        publishedByCoachId: coachId,
      );

      final reloaded = await _builderService.loadDocument(versionId: published.id);

      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.published,
        document: reloaded,
        publishedVersionId: published.id,
      );
    } on ProgrammeStoreException {
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        document: workingDocument,
      );
    }
  }

  @override
  Future<ProgrammeBuilderOperationResult> cloneVersion({
    required String publishedVersionId,
    required String coachId,
  }) async {
    try {
      final cloned = await _publishingService.cloneToNewDraft(
        publishedVersionId: publishedVersionId,
      );

      final document = await _builderService.loadDocument(versionId: cloned.id);

      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.cloned,
        document: document,
        sourceVersionId: publishedVersionId,
      );
    } on ProgrammeStoreException {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        sourceVersionId: null,
      );
    }
  }
}
