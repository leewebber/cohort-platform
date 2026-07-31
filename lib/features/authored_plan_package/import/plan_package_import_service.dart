import '../plan_package_compiler.dart';
import 'plan_package_import_models.dart';
import 'plan_package_import_payload_builder.dart';
import 'plan_package_import_preview_service.dart';
import 'plan_package_import_store.dart';
import 'plan_package_session_resolver.dart';

/// Application boundary: validated compile result → preview / atomic import.
///
/// Does not depend on the legacy generative Plan Library, Coach Brain, or
/// athlete evidence. Does not embed service-role credentials.
class PlanPackageImportService {
  PlanPackageImportService({
    required PlanPackageImportPreviewService previewService,
    required PlanPackageImportStore importStore,
    PlanPackageImportPayloadBuilder payloadBuilder =
        const PlanPackageImportPayloadBuilder(),
    PlanPackageSessionResolutionService? sessionResolution,
  }) : _previewService = previewService,
       _importStore = importStore,
       _payloadBuilder = payloadBuilder,
       _sessionResolution = sessionResolution;

  final PlanPackageImportPreviewService _previewService;
  final PlanPackageImportStore _importStore;
  final PlanPackageImportPayloadBuilder _payloadBuilder;
  final PlanPackageSessionResolutionService? _sessionResolution;

  Future<PlanPackageImportPreview> preview({
    required PlanPackageCompileResult compileResult,
  }) {
    return _previewService.preview(compileResult: compileResult);
  }

  /// Builds the import payload without invoking the database.
  Map<String, Object?> buildPayload({
    required PlanPackageCompileResult compileResult,
    required String importedBy,
  }) {
    final payload = _payloadBuilder.build(
      compileResult: compileResult,
      importedBy: importedBy,
    );
    _assertPayloadAuthority(payload);
    return payload;
  }

  /// Preview + apply. Fails closed when preview is not importable (except
  /// idempotent same-hash, which is applied as a no-write RPC success).
  Future<PlanPackageImportResult> importValidatedPackage({
    required PlanPackageCompileResult compileResult,
    required String importedBy,
  }) async {
    if (!compileResult.isValid || compileResult.manifest == null) {
      return const PlanPackageImportResult(
        status: PlanPackageImportStatus.validationFailure,
        code: 'invalid_compile_result',
        message: 'Import requires a successful compile result.',
      );
    }

    final preview = await _previewService.preview(compileResult: compileResult);
    if (!preview.isImportable) {
      final first = preview.blockingErrors.isEmpty
          ? null
          : preview.blockingErrors.first;
      final status = switch (preview.existingOutcome) {
        PlanPackageExistingImportOutcome.publishedConflict =>
          PlanPackageImportStatus.publishedVersionConflict,
        PlanPackageExistingImportOutcome.hashCollision =>
          PlanPackageImportStatus.versionCollision,
        PlanPackageExistingImportOutcome.partialDraftConflict =>
          PlanPackageImportStatus.partialStateConflict,
        PlanPackageExistingImportOutcome.nonDraftConflict =>
          PlanPackageImportStatus.versionCollision,
        _ =>
          preview.sessionRevisions.any((s) => !s.resolved)
              ? PlanPackageImportStatus.sessionResolutionFailure
              : PlanPackageImportStatus.validationFailure,
      };
      return PlanPackageImportResult(
        status: status,
        code: first?.code ?? 'import_blocked',
        message: first?.message ?? 'Import blocked by preview validation.',
      );
    }

    // Optional second-pass session check before payload construction.
    final resolver = _sessionResolution;
    if (resolver != null) {
      final sessions = await resolver.resolveAll(compileResult.manifest!);
      final failed = sessions.where((s) => !s.resolved).toList();
      if (failed.isNotEmpty) {
        return PlanPackageImportResult(
          status: PlanPackageImportStatus.sessionResolutionFailure,
          code: failed.first.failureCode ?? 'session_resolution_failure',
          message: failed.first.failureMessage,
        );
      }
    }

    final payload = buildPayload(
      compileResult: compileResult,
      importedBy: importedBy,
    );

    return _importStore.importPackage(payload);
  }

  void _assertPayloadAuthority(Map<String, Object?> payload) {
    const forbidden = {
      'lifecycle_status',
      'approved_for_global',
      'published_at',
      'owner_type',
      'owner_id',
      'library_scope',
      'previous_performance',
      'execution_result',
      'yaml',
      'canonical_json',
      'source_filename',
      'source_path',
    };
    for (final key in forbidden) {
      if (payload.containsKey(key)) {
        throw StateError('Import payload must not include "$key".');
      }
    }
  }
}
