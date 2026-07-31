import '../../../models/programme_vocabulary.dart';
import '../plan_package_compiler.dart';
import '../plan_package_validation_issue.dart';
import 'plan_package_existing_version_lookup.dart';
import 'plan_package_import_models.dart';
import 'plan_package_session_resolver.dart';

/// Side-effect-free import preview. Performs optional identity reads only.
///
/// Never writes. Never generates missing coaching. Never includes credentials.
class PlanPackageImportPreviewService {
  const PlanPackageImportPreviewService({
    required PlanPackageSessionResolutionService sessionResolution,
    PlanPackageExistingVersionLookup? existingVersionLookup,
  }) : _sessionResolution = sessionResolution,
       _existingVersionLookup = existingVersionLookup;

  final PlanPackageSessionResolutionService _sessionResolution;
  final PlanPackageExistingVersionLookup? _existingVersionLookup;

  Future<PlanPackageImportPreview> preview({
    required PlanPackageCompileResult compileResult,
  }) async {
    if (!compileResult.isValid || compileResult.manifest == null) {
      return PlanPackageImportPreview(
        lineageCode: '',
        versionNumber: 0,
        packageSchemaVersion: 0,
        packageContentHash: '',
        programmeName: '',
        coachingIntent: '',
        libraryScope: ProgrammeLibraryScope.cohortGlobal,
        ownerType: ProgrammeOwnerType.global,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        approvedForGlobal: false,
        phaseCount: 0,
        weekCount: 0,
        dayCount: 0,
        slotCount: 0,
        sessionRevisions: const [],
        adaptationPermissionIds: const [],
        protectedInvariantIds: const [],
        assessmentIds: const [],
        evidenceRequirementIds: const [],
        comparisonIdentityIds: const [],
        blockingErrors: [
          const PlanPackageValidationIssue(
            path: r'$',
            code: 'invalid_compile_result',
            message: 'Import preview requires a successful compile result.',
          ),
        ],
        warnings: const [],
      );
    }

    final manifest = compileResult.manifest!;
    final sessions = await _sessionResolution.resolveAll(manifest);
    final errors = <PlanPackageValidationIssue>[
      for (final s in sessions)
        if (!s.resolved)
          PlanPackageValidationIssue(
            path: 'sessions.${s.sessionKey}',
            code: s.failureCode ?? 'session_resolution_failure',
            message: s.failureMessage ?? 'Session resolution failed.',
          ),
    ];

    // Import pathway always targets Cohort Global hidden draft ownership,
    // regardless of YAML library_scope/owner_type display fields.
    final warnings = <PlanPackageValidationIssue>[];
    if (manifest.programme.libraryScope != ProgrammeLibraryScope.cohortGlobal ||
        manifest.programme.ownerType != ProgrammeOwnerType.global) {
      warnings.add(
        const PlanPackageValidationIssue(
          path: 'programme',
          code: 'ownership_overridden_server_side',
          message:
              'Import enforces Cohort Global ownership server-side; '
              'YAML library_scope/owner_type are not trusted for persistence.',
        ),
      );
    }

    PlanPackageExistingImportOutcome? existingOutcome;
    final lookup = _existingVersionLookup;
    if (lookup != null) {
      final existing = await lookup.findByLineageCodeAndVersion(
        lineageCode: manifest.programme.lineageCode,
        versionNumber: manifest.programme.versionNumber,
      );
      if (existing != null) {
        existingOutcome = existing.classifyAgainstPackage(
          packageContentHash: compileResult.contentHashSha256!,
          packageSchemaVersion: manifest.packageSchemaVersion,
        );
        switch (existingOutcome) {
          case PlanPackageExistingImportOutcome.publishedConflict:
            errors.add(
              PlanPackageValidationIssue(
                path: 'programme.version_number',
                code: 'published_version_exists',
                message:
                    'Programme version ${existing.versionNumber} is published '
                    'and cannot be overwritten.',
              ),
            );
          case PlanPackageExistingImportOutcome.nonDraftConflict:
            errors.add(
              const PlanPackageValidationIssue(
                path: 'programme.version_number',
                code: 'non_draft_exists',
                message: 'Existing version is not an importable draft.',
              ),
            );
          case PlanPackageExistingImportOutcome.hashCollision:
            errors.add(
              const PlanPackageValidationIssue(
                path: 'package_content_hash',
                code: 'hash_collision',
                message:
                    'Same lineage/version exists with a different hash. '
                    'Bump version_number for corrected content.',
              ),
            );
          case PlanPackageExistingImportOutcome.partialDraftConflict:
            errors.add(
              const PlanPackageValidationIssue(
                path: 'programme',
                code: 'partial_existing_draft',
                message:
                    'Existing draft is incomplete or inconsistent. Fail closed.',
              ),
            );
          case PlanPackageExistingImportOutcome.idempotentSameHash:
            break;
        }
      }
    }

    var dayCount = 0;
    var slotCount = 0;
    for (final week in manifest.weeks) {
      dayCount += week.days.length;
      for (final day in week.days) {
        slotCount += day.slots.length;
      }
    }

    return PlanPackageImportPreview(
      lineageCode: manifest.programme.lineageCode,
      versionNumber: manifest.programme.versionNumber,
      packageSchemaVersion: manifest.packageSchemaVersion,
      packageContentHash: compileResult.contentHashSha256!,
      programmeName: manifest.programme.name,
      description: manifest.programme.description,
      coachingIntent: manifest.programme.coachingIntent,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      lifecycleStatus: ProgrammeLifecycleStatus.draft,
      approvedForGlobal: false,
      phaseCount: manifest.phases.length,
      weekCount: manifest.weeks.length,
      dayCount: dayCount,
      slotCount: slotCount,
      sessionRevisions: sessions,
      adaptationPermissionIds: [
        for (final a in manifest.adaptationPermissions) a.id,
      ],
      protectedInvariantIds: [
        for (final i in manifest.protectedInvariants) i.id,
      ],
      assessmentIds: [for (final a in manifest.assessments) a.id],
      evidenceRequirementIds: [
        for (final e in manifest.performanceEvidenceRequirements) e.id,
      ],
      comparisonIdentityIds: [
        for (final c in manifest.comparisonIdentities) c.id,
      ],
      blockingErrors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
      existingOutcome: existingOutcome,
    );
  }
}
