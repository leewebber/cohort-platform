import 'dart:io';

import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionResolver implements PlanPackageSessionResolver {
  _FakeSessionResolver(this.rows);

  final Map<String, PlanPackageSessionRevisionRecord> rows;

  @override
  Future<PlanPackageSessionRevisionRecord?> getRevision(
    String protocolId,
  ) async {
    return rows[protocolId.trim()];
  }
}

class _FakeExistingLookup implements PlanPackageExistingVersionLookup {
  _FakeExistingLookup(this.snapshot);

  final PlanPackageExistingVersionSnapshot? snapshot;

  @override
  Future<PlanPackageExistingVersionSnapshot?> findByLineageCodeAndVersion({
    required String lineageCode,
    required int versionNumber,
  }) async {
    return snapshot;
  }
}

class _RecordingImportStore implements PlanPackageImportStore {
  Map<String, Object?>? lastPayload;
  int callCount = 0;
  PlanPackageImportResult result = PlanPackageImportResult(
    status: PlanPackageImportStatus.importedDraft,
    code: 'created_hidden_draft',
    programmeVersionId: 'v1',
    lineageCode: 'PROG-FIXTURE-01',
    versionNumber: 1,
    packageContentHash: 'a' * 64,
    lifecycleStatus: 'draft',
    approvedForGlobal: false,
  );

  @override
  Future<PlanPackageImportResult> importPackage(
    Map<String, Object?> payload,
  ) async {
    callCount += 1;
    lastPayload = payload;
    return result;
  }
}

void main() {
  late String fixtureYaml;
  late PlanPackageCompileResult compileResult;
  const compiler = PlanPackageCompiler();

  setUpAll(() {
    fixtureYaml = File(
      'test/fixtures/authored_plan_package/minimal_plan_package.yaml',
    ).readAsStringSync();
    compileResult = compiler.compile(fixtureYaml);
    expect(compileResult.isValid, isTrue);
  });

  PlanPackageSessionResolutionService resolvedSessions() {
    return PlanPackageSessionResolutionService(
      _FakeSessionResolver({
        'PROT-SQUAT-A-R1': const PlanPackageSessionRevisionRecord(
          protocolId: 'PROT-SQUAT-A-R1',
          sessionLineageId: 'SL-SQUAT-A',
          revisionNumber: 1,
          lifecycleStatus: 'published',
          contentKind: 'session',
          name: 'Squat A',
        ),
      }),
    );
  }

  group('import preview', () {
    test('valid compile result produces expected preview', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: resolvedSessions(),
      );
      final preview = await service.preview(compileResult: compileResult);

      expect(preview.isImportable, isTrue);
      expect(preview.lineageCode, 'PROG-FIXTURE-01');
      expect(preview.versionNumber, 1);
      expect(preview.packageSchemaVersion, 1);
      expect(preview.packageContentHash, compileResult.contentHashSha256);
      expect(preview.lifecycleStatus, ProgrammeLifecycleStatus.draft);
      expect(preview.libraryScope, ProgrammeLibraryScope.cohortGlobal);
      expect(preview.ownerType, ProgrammeOwnerType.global);
      expect(preview.approvedForGlobal, isFalse);
      expect(preview.weekCount, 2);
      expect(preview.slotCount, 2);
      expect(preview.sessionRevisions, hasLength(1));
      expect(preview.sessionRevisions.first.resolved, isTrue);
      expect(preview.adaptationPermissionIds, ['ADP-REDUCE-VOLUME-W1']);
      expect(preview.protectedInvariantIds, ['INV-ASSESSMENT-IMMUTABLE']);
      expect(preview.assessmentIds, ['ASM-SQUAT-BASELINE']);
      expect(preview.comparisonIdentityIds, ['CMP-SQUAT-3X5']);
    });

    test('invalid compilation cannot reach importable preview', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: resolvedSessions(),
      );
      final preview = await service.preview(
        compileResult: compiler.compile('not: valid: [['),
      );
      expect(preview.isImportable, isFalse);
      expect(
        preview.blockingErrors.any((e) => e.code == 'invalid_compile_result'),
        isTrue,
      );
    });

    test('missing session revisions fail closed', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: PlanPackageSessionResolutionService(
          _FakeSessionResolver({}),
        ),
      );
      final preview = await service.preview(compileResult: compileResult);
      expect(preview.isImportable, isFalse);
      expect(
        preview.blockingErrors.any((e) => e.code == 'session_missing'),
        isTrue,
      );
    });

    test('mutable draft session revisions fail', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: PlanPackageSessionResolutionService(
          _FakeSessionResolver({
            'PROT-SQUAT-A-R1': const PlanPackageSessionRevisionRecord(
              protocolId: 'PROT-SQUAT-A-R1',
              sessionLineageId: 'SL-SQUAT-A',
              revisionNumber: 1,
              lifecycleStatus: 'draft',
            ),
          }),
        ),
      );
      final preview = await service.preview(compileResult: compileResult);
      expect(preview.isImportable, isFalse);
      expect(
        preview.blockingErrors.any((e) => e.code == 'session_not_published'),
        isTrue,
      );
    });

    test('identity mismatch fails', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: PlanPackageSessionResolutionService(
          _FakeSessionResolver({
            'PROT-SQUAT-A-R1': const PlanPackageSessionRevisionRecord(
              protocolId: 'PROT-SQUAT-A-R1',
              sessionLineageId: 'SL-OTHER',
              revisionNumber: 2,
              lifecycleStatus: 'published',
            ),
          }),
        ),
      );
      final preview = await service.preview(compileResult: compileResult);
      expect(
        preview.blockingErrors.any(
          (e) => e.code == 'session_identity_mismatch',
        ),
        isTrue,
      );
    });

    test('canonical template protocol fails', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: PlanPackageSessionResolutionService(
          _FakeSessionResolver({
            'PROT-SQUAT-A-R1': const PlanPackageSessionRevisionRecord(
              protocolId: 'PROT-SQUAT-A-R1',
              sessionLineageId: 'SL-SQUAT-A',
              revisionNumber: 1,
              lifecycleStatus: 'published',
              contentKind: 'session_template',
            ),
          }),
        ),
      );
      final preview = await service.preview(compileResult: compileResult);
      expect(
        preview.blockingErrors.any(
          (e) => e.code == 'canonical_template_forbidden',
        ),
        isTrue,
      );
    });

    test('same hash existing draft is idempotent-importable', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: resolvedSessions(),
        existingVersionLookup: _FakeExistingLookup(
          PlanPackageExistingVersionSnapshot(
            versionId: 'existing',
            lineageId: 'lin',
            lineageCode: 'PROG-FIXTURE-01',
            versionNumber: 1,
            lifecycleStatus: ProgrammeLifecycleStatus.draft,
            libraryScope: ProgrammeLibraryScope.cohortGlobal,
            ownerType: ProgrammeOwnerType.global,
            approvedForGlobal: false,
            packageContentHash: compileResult.contentHashSha256,
            packageSchemaVersion: 1,
          ),
        ),
      );
      final preview = await service.preview(compileResult: compileResult);
      expect(preview.isImportable, isTrue);
      expect(
        preview.existingOutcome,
        PlanPackageExistingImportOutcome.idempotentSameHash,
      );
    });

    test('different hash collision fails', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: resolvedSessions(),
        existingVersionLookup: _FakeExistingLookup(
          PlanPackageExistingVersionSnapshot(
            versionId: 'existing',
            lineageId: 'lin',
            lineageCode: 'PROG-FIXTURE-01',
            versionNumber: 1,
            lifecycleStatus: ProgrammeLifecycleStatus.draft,
            libraryScope: ProgrammeLibraryScope.cohortGlobal,
            ownerType: ProgrammeOwnerType.global,
            approvedForGlobal: false,
            packageContentHash: 'b' * 64,
            packageSchemaVersion: 1,
          ),
        ),
      );
      final preview = await service.preview(compileResult: compileResult);
      expect(preview.isImportable, isFalse);
      expect(
        preview.existingOutcome,
        PlanPackageExistingImportOutcome.hashCollision,
      );
    });

    test('published version conflict fails', () async {
      final service = PlanPackageImportPreviewService(
        sessionResolution: resolvedSessions(),
        existingVersionLookup: _FakeExistingLookup(
          PlanPackageExistingVersionSnapshot(
            versionId: 'existing',
            lineageId: 'lin',
            lineageCode: 'PROG-FIXTURE-01',
            versionNumber: 1,
            lifecycleStatus: ProgrammeLifecycleStatus.published,
            libraryScope: ProgrammeLibraryScope.cohortGlobal,
            ownerType: ProgrammeOwnerType.global,
            approvedForGlobal: false,
            packageContentHash: 'a' * 64,
            packageSchemaVersion: 1,
          ),
        ),
      );
      final preview = await service.preview(compileResult: compileResult);
      expect(
        preview.existingOutcome,
        PlanPackageExistingImportOutcome.publishedConflict,
      );
      expect(preview.isImportable, isFalse);
    });
  });

  group('import payload and application boundary', () {
    test('payload cannot request publication or catalogue approval', () {
      final payload = const PlanPackageImportPayloadBuilder().build(
        compileResult: compileResult,
        importedBy: 'founder-test',
      );
      expect(payload.containsKey('lifecycle_status'), isFalse);
      expect(payload.containsKey('approved_for_global'), isFalse);
      expect(payload.containsKey('published_at'), isFalse);
      expect(payload.containsKey('owner_type'), isFalse);
      expect(payload.containsKey('library_scope'), isFalse);
      expect(payload.containsKey('previous_performance'), isFalse);
      expect(payload['package_content_hash'], compileResult.contentHashSha256);
      expect(payload['imported_by'], 'founder-test');
    });

    test('import service refuses invalid compile results', () async {
      final store = _RecordingImportStore();
      final service = PlanPackageImportService(
        previewService: PlanPackageImportPreviewService(
          sessionResolution: resolvedSessions(),
        ),
        importStore: store,
      );
      final result = await service.importValidatedPackage(
        compileResult: compiler.compile('broken: ['),
        importedBy: 'founder-test',
      );
      expect(result.status, PlanPackageImportStatus.validationFailure);
      expect(store.callCount, 0);
    });

    test('import service applies payload when preview is importable', () async {
      final store = _RecordingImportStore();
      final service = PlanPackageImportService(
        previewService: PlanPackageImportPreviewService(
          sessionResolution: resolvedSessions(),
        ),
        importStore: store,
        sessionResolution: resolvedSessions(),
      );
      final result = await service.importValidatedPackage(
        compileResult: compileResult,
        importedBy: 'founder-test',
      );
      expect(result.isSuccess, isTrue);
      expect(store.callCount, 1);
      expect(store.lastPayload?['approved_for_global'], isNull);
      expect(store.lastPayload?['lifecycle_status'], isNull);
      expect(
        store.lastPayload?['package_content_hash'],
        compileResult.contentHashSha256,
      );
    });

    test('persisted hash equals sprint 1.1 compile hash', () {
      final payload = const PlanPackageImportPayloadBuilder().build(
        compileResult: compileResult,
        importedBy: 'founder-test',
      );
      expect(payload['package_content_hash'], compileResult.contentHashSha256);

      final spaced = compiler.compile(fixtureYaml.replaceAll('\n', '\n\n'));
      expect(spaced.contentHashSha256, compileResult.contentHashSha256);
    });
  });
}
