import 'dart:convert';
import 'dart:typed_data';

import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:crypto/crypto.dart';

import 'journey_d_protocol_publication.dart';
import 'journey_d_publication_plan_builder.dart';

/// Typed rebind of fixture [PlanPackageSessionRevisionRef.sessionLineageId] only.
///
/// Does not rewrite YAML text and does not alter slots, permissions, protocol
/// IDs, revision numbers, or any unrelated field.
class JourneyDSessionLineageRebinder {
  const JourneyDSessionLineageRebinder({
    this.validator = const PlanPackageValidator(),
    this.canonicaliser = const PlanPackageCanonicaliser(),
  });

  final PlanPackageValidator validator;
  final PlanPackageCanonicaliser canonicaliser;

  /// Symbolic fixture lineage prefix — must not reach import.
  static final symbolicLineagePattern = RegExp(r'^SL-S17-JD-ADAPT-');

  JourneyDReboundPackageResult rebind({
    required PlanPackageManifest original,
    required JourneyDLineageMapping mapping,
    required JourneyDPublicationPlan plan,
  }) {
    if (mapping.count != plan.count) {
      throw JourneyDRebindException(
        'REFUSED: mapping count does not match publication plan',
      );
    }
    if (mapping.canonicalUuids.length != mapping.count) {
      throw JourneyDRebindException(
        'REFUSED: duplicate canonical UUID in mapping',
      );
    }
    for (final intent in plan.intents) {
      final uuid = mapping.bySymbolicLineage[intent.symbolicSessionLineageId];
      if (uuid == null) {
        throw JourneyDRebindException(
          'REFUSED: missing mapping for ${intent.symbolicSessionLineageId}',
        );
      }
      if (!DatabaseUuid.isValidDatabaseUuid(uuid)) {
        throw JourneyDRebindException(
          'REFUSED: mapped lineage is not a UUID for '
          '${intent.symbolicSessionLineageId}',
        );
      }
    }

    final expectedSymbolic = {
      for (final i in plan.intents) i.symbolicSessionLineageId,
    };

    final reboundSessions = <PlanPackageSessionRevisionRef>[];
    for (final session in original.sessions) {
      if (!expectedSymbolic.contains(session.sessionLineageId)) {
        throw JourneyDRebindException(
          'REFUSED: unexpected session lineage ${session.sessionLineageId}',
        );
      }
      final uuid = mapping.bySymbolicLineage[session.sessionLineageId]!;
      reboundSessions.add(
        PlanPackageSessionRevisionRef(
          sessionKey: session.sessionKey,
          protocolId: session.protocolId,
          sessionLineageId: uuid,
          revisionNumber: session.revisionNumber,
          title: session.title,
        ),
      );
    }

    final rebound = PlanPackageManifest(
      packageSchemaVersion: original.packageSchemaVersion,
      programme: original.programme,
      sessions: List.unmodifiable(reboundSessions),
      phases: original.phases,
      weeks: original.weeks,
      adaptationPermissions: original.adaptationPermissions,
      protectedInvariants: original.protectedInvariants,
      assessments: original.assessments,
      performanceEvidenceRequirements: original.performanceEvidenceRequirements,
      comparisonIdentities: original.comparisonIdentities,
    );

    _assertUnrelatedFieldsPreserved(original: original, rebound: rebound);
    _assertNoSymbolicLineagesRemain(rebound);

    final issues = validator.validate(rebound);
    if (issues.isNotEmpty) {
      throw JourneyDRebindException(
        'REFUSED: rebound package semantic validation failed: '
        '${issues.map((i) => i.code).join(',')}',
      );
    }

    final bytes = canonicaliser.canonicalBytes(rebound);
    final hash = sha256.convert(bytes).toString();

    return JourneyDReboundPackageResult(
      manifest: rebound,
      canonicalBytes: bytes,
      contentHashSha256: hash,
      mapping: mapping,
      completeMapping: true,
      symbolicLineagesRemaining: false,
    );
  }

  void _assertUnrelatedFieldsPreserved({
    required PlanPackageManifest original,
    required PlanPackageManifest rebound,
  }) {
    if (original.programme.lineageCode != rebound.programme.lineageCode ||
        original.programme.versionNumber != rebound.programme.versionNumber ||
        original.programme.name != rebound.programme.name) {
      throw JourneyDRebindException('REFUSED: programme identity altered');
    }
    if (original.weeks.length != rebound.weeks.length) {
      throw JourneyDRebindException('REFUSED: week structure altered');
    }
    for (var wi = 0; wi < original.weeks.length; wi++) {
      final ow = original.weeks[wi];
      final rw = rebound.weeks[wi];
      if (ow.weekNumber != rw.weekNumber || ow.days.length != rw.days.length) {
        throw JourneyDRebindException('REFUSED: week/day ordering altered');
      }
      for (var di = 0; di < ow.days.length; di++) {
        final od = ow.days[di];
        final rd = rw.days[di];
        if (od.dayKey != rd.dayKey || od.slots.length != rd.slots.length) {
          throw JourneyDRebindException('REFUSED: day/slot ordering altered');
        }
        for (var si = 0; si < od.slots.length; si++) {
          final os = od.slots[si];
          final rs = rd.slots[si];
          if (os.slotKey != rs.slotKey ||
              os.sessionKey != rs.sessionKey ||
              os.sessionOrder != rs.sessionOrder) {
            throw JourneyDRebindException('REFUSED: slot identity altered');
          }
        }
      }
    }
    if (original.sessions.length != rebound.sessions.length) {
      throw JourneyDRebindException('REFUSED: session catalogue size altered');
    }
    for (var i = 0; i < original.sessions.length; i++) {
      final o = original.sessions[i];
      final r = rebound.sessions[i];
      if (o.sessionKey != r.sessionKey ||
          o.protocolId != r.protocolId ||
          o.revisionNumber != r.revisionNumber ||
          o.title != r.title) {
        throw JourneyDRebindException(
          'REFUSED: session non-lineage fields altered',
        );
      }
    }
    if (!_samePermissions(
      original.adaptationPermissions,
      rebound.adaptationPermissions,
    )) {
      throw JourneyDRebindException('REFUSED: adaptation permissions altered');
    }
  }

  bool _samePermissions(
    List<PlanPackageAdaptationPermission> a,
    List<PlanPackageAdaptationPermission> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].changeKind != b[i].changeKind ||
          a[i].targetRef != b[i].targetRef ||
          a[i].athleteAgreementRequired != b[i].athleteAgreementRequired) {
        return false;
      }
    }
    return true;
  }

  void _assertNoSymbolicLineagesRemain(PlanPackageManifest manifest) {
    for (final session in manifest.sessions) {
      if (symbolicLineagePattern.hasMatch(session.sessionLineageId) ||
          !DatabaseUuid.isValidDatabaseUuid(session.sessionLineageId)) {
        throw JourneyDRebindException(
          'REFUSED: import-relevant session lineage is not a canonical UUID '
          '(${session.sessionKey})',
        );
      }
    }
    for (final comparison in manifest.comparisonIdentities) {
      if (symbolicLineagePattern.hasMatch(comparison.sessionLineageId)) {
        throw JourneyDRebindException(
          'REFUSED: symbolic lineage remains in comparison identity',
        );
      }
    }
  }
}

/// Validated rebound package that alone may be passed to import.
class JourneyDReboundPackageResult {
  const JourneyDReboundPackageResult({
    required this.manifest,
    required this.canonicalBytes,
    required this.contentHashSha256,
    required this.mapping,
    required this.completeMapping,
    required this.symbolicLineagesRemaining,
  });

  final PlanPackageManifest manifest;
  final Uint8List canonicalBytes;
  final String contentHashSha256;
  final JourneyDLineageMapping mapping;
  final bool completeMapping;
  final bool symbolicLineagesRemaining;

  String get canonicalJson => utf8.decode(canonicalBytes);

  bool get isImportReady =>
      completeMapping &&
      !symbolicLineagesRemaining &&
      contentHashSha256.length == 64;

  /// Builds the import RPC payload from this validated rebound package only.
  Map<String, Object?> importPayload({required String importedBy}) {
    if (!isImportReady) {
      throw JourneyDRebindException(
        'REFUSED: rebound package is not import-ready',
      );
    }
    final compile = PlanPackageCompileResult.valid(
      manifest: manifest,
      canonicalBytes: canonicalBytes,
      contentHashSha256: contentHashSha256,
    );
    return const PlanPackageImportPayloadBuilder().build(
      compileResult: compile,
      importedBy: importedBy,
    );
  }
}
