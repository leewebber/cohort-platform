import '../plan_package_manifest.dart';
import 'plan_package_import_models.dart';

/// Read-only port for resolving immutable Session Revision identities.
///
/// Implementations must not mutate sessions. Preview and import both use this.
abstract class PlanPackageSessionResolver {
  Future<PlanPackageSessionRevisionRecord?> getRevision(String protocolId);
}

/// Resolves and validates package session refs against existing published revisions.
class PlanPackageSessionResolutionService {
  const PlanPackageSessionResolutionService(this._resolver);

  final PlanPackageSessionResolver _resolver;

  Future<List<PlanPackageResolvedSessionRevision>> resolveAll(
    PlanPackageManifest manifest,
  ) async {
    final results = <PlanPackageResolvedSessionRevision>[];
    for (final session in manifest.sessions) {
      results.add(await resolveOne(session));
    }
    return List.unmodifiable(results);
  }

  Future<PlanPackageResolvedSessionRevision> resolveOne(
    PlanPackageSessionRevisionRef session,
  ) async {
    final row = await _resolver.getRevision(session.protocolId);
    if (row == null) {
      return PlanPackageResolvedSessionRevision(
        sessionKey: session.sessionKey,
        protocolId: session.protocolId,
        sessionLineageId: session.sessionLineageId,
        revisionNumber: session.revisionNumber,
        title: session.title,
        resolved: false,
        failureCode: 'session_missing',
        failureMessage: 'Session revision ${session.protocolId} not found.',
      );
    }

    if (row.lifecycleStatus != 'published') {
      return PlanPackageResolvedSessionRevision(
        sessionKey: session.sessionKey,
        protocolId: session.protocolId,
        sessionLineageId: session.sessionLineageId,
        revisionNumber: session.revisionNumber,
        title: session.title,
        resolved: false,
        failureCode: 'session_not_published',
        failureMessage:
            'Session revision ${session.protocolId} is not published.',
      );
    }

    final contentKind = row.contentKind?.trim() ?? '';
    if (contentKind == 'session_template' ||
        session.protocolId.startsWith('TMP-')) {
      return PlanPackageResolvedSessionRevision(
        sessionKey: session.sessionKey,
        protocolId: session.protocolId,
        sessionLineageId: session.sessionLineageId,
        revisionNumber: session.revisionNumber,
        title: session.title,
        resolved: false,
        failureCode: 'canonical_template_forbidden',
        failureMessage:
            'Canonical session templates cannot be live-attached to programme slots.',
      );
    }

    if (row.sessionLineageId != session.sessionLineageId ||
        row.revisionNumber != session.revisionNumber) {
      return PlanPackageResolvedSessionRevision(
        sessionKey: session.sessionKey,
        protocolId: session.protocolId,
        sessionLineageId: session.sessionLineageId,
        revisionNumber: session.revisionNumber,
        title: session.title,
        resolved: false,
        failureCode: 'session_identity_mismatch',
        failureMessage: 'Session identity mismatch for ${session.protocolId}.',
      );
    }

    return PlanPackageResolvedSessionRevision(
      sessionKey: session.sessionKey,
      protocolId: session.protocolId,
      sessionLineageId: session.sessionLineageId,
      revisionNumber: session.revisionNumber,
      title: session.title,
      resolved: true,
    );
  }
}
