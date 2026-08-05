import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';

import 'journey_d_protocol_publication.dart';
import 'journey_d_publication_plan_builder.dart';
import 'journey_d_session_lineage_rebinder.dart';

/// Live-only publication → attribution → typed rebind → import-ready package.
///
/// Dry-run must never call [run]. Callers must enforce staging + live guards
/// before invoking this pipeline.
class JourneyDRebindPipeline {
  const JourneyDRebindPipeline({
    required this.publisher,
    this.planBuilder = const JourneyDPublicationPlanBuilder(),
    this.rebinder = const JourneyDSessionLineageRebinder(),
  });

  final JourneyDProtocolPublisher publisher;
  final JourneyDPublicationPlanBuilder planBuilder;
  final JourneyDSessionLineageRebinder rebinder;

  /// Executes publication for every intent then rebinds the package.
  ///
  /// On failure/ambiguity: later protocol publications remain not_started,
  /// rebound package is null, furtherMutationProhibited is true.
  Future<JourneyDRebindPipelineResult> run({
    required String protocolIntentJson,
    required PlanPackageManifest originalPackage,
  }) async {
    final plan = planBuilder.build(
      protocolIntentJson: protocolIntentJson,
      packageManifest: originalPackage,
    );

    final results = <JourneyDProtocolPublicationResult>[];
    var furtherProhibited = false;

    for (final intent in plan.intents) {
      if (furtherProhibited) {
        results.add(
          JourneyDProtocolPublicationResult(
            intent: intent,
            state: JourneyDPublicationStageState.notStarted,
            detail: 'blocked_by_prior_failure',
            furtherMutationProhibited: true,
          ),
        );
        continue;
      }

      final published = await publisher.publish(intent);
      final attributed = _attribute(published);
      results.add(attributed);

      if (!attributed.isApplied) {
        furtherProhibited = true;
        continue;
      }
    }

    if (furtherProhibited || results.any((r) => !r.isApplied)) {
      return JourneyDRebindPipelineResult(
        plan: plan,
        publicationResults: List.unmodifiable(results),
        mapping: null,
        rebound: null,
        furtherMutationProhibited: true,
        importReady: false,
      );
    }

    try {
      final mapping = _buildMapping(plan: plan, results: results);
      final rebound = rebinder.rebind(
        original: originalPackage,
        mapping: mapping,
        plan: plan,
      );
      return JourneyDRebindPipelineResult(
        plan: plan,
        publicationResults: List.unmodifiable(results),
        mapping: mapping,
        rebound: rebound,
        furtherMutationProhibited: false,
        importReady: rebound.isImportReady,
      );
    } on JourneyDRebindException catch (e) {
      return JourneyDRebindPipelineResult(
        plan: plan,
        publicationResults: List.unmodifiable(results),
        mapping: null,
        rebound: null,
        furtherMutationProhibited: true,
        importReady: false,
        detail: e.message,
      );
    }
  }

  JourneyDProtocolPublicationResult _attribute(
    JourneyDProtocolPublicationResult published,
  ) {
    if (published.state == JourneyDPublicationStageState.unknown) {
      return JourneyDProtocolPublicationResult(
        intent: published.intent,
        state: JourneyDPublicationStageState.unknown,
        returnedSessionLineageId: published.returnedSessionLineageId,
        returnedRevisionNumber: published.returnedRevisionNumber,
        detail: published.detail,
        furtherMutationProhibited: true,
        writeAccounting: published.writeAccounting,
      );
    }
    if (published.state == JourneyDPublicationStageState.failed) {
      return JourneyDProtocolPublicationResult(
        intent: published.intent,
        state: JourneyDPublicationStageState.failed,
        detail: published.detail,
        furtherMutationProhibited: true,
        writeAccounting: published.writeAccounting,
      );
    }
    if (published.state != JourneyDPublicationStageState.applied) {
      return JourneyDProtocolPublicationResult(
        intent: published.intent,
        state: JourneyDPublicationStageState.unknown,
        detail: 'unexpected_publication_state:${published.state.name}',
        furtherMutationProhibited: true,
        writeAccounting: published.writeAccounting,
      );
    }

    final lineage = published.returnedSessionLineageId?.trim();
    if (lineage == null || lineage.isEmpty) {
      return JourneyDProtocolPublicationResult(
        intent: published.intent,
        state: JourneyDPublicationStageState.failed,
        detail: 'missing_returned_session_lineage_id',
        furtherMutationProhibited: true,
        writeAccounting: published.writeAccounting,
      );
    }
    if (!DatabaseUuid.isValidDatabaseUuid(lineage)) {
      return JourneyDProtocolPublicationResult(
        intent: published.intent,
        state: JourneyDPublicationStageState.failed,
        returnedSessionLineageId: lineage,
        detail: 'malformed_or_non_uuid_session_lineage_id',
        furtherMutationProhibited: true,
        writeAccounting: published.writeAccounting,
      );
    }
    if (JourneyDSessionLineageRebinder.symbolicLineagePattern.hasMatch(
          lineage,
        ) ||
        lineage.startsWith('SL-')) {
      return JourneyDProtocolPublicationResult(
        intent: published.intent,
        state: JourneyDPublicationStageState.failed,
        returnedSessionLineageId: lineage,
        detail: 'returned_lineage_still_symbolic',
        furtherMutationProhibited: true,
        writeAccounting: published.writeAccounting,
      );
    }
    if (published.returnedRevisionNumber != null &&
        published.returnedRevisionNumber != published.intent.revisionNumber) {
      return JourneyDProtocolPublicationResult(
        intent: published.intent,
        state: JourneyDPublicationStageState.failed,
        returnedSessionLineageId: lineage,
        returnedRevisionNumber: published.returnedRevisionNumber,
        detail: 'unexpected_revision_number',
        furtherMutationProhibited: true,
        writeAccounting: published.writeAccounting,
      );
    }

    return JourneyDProtocolPublicationResult(
      intent: published.intent,
      state: JourneyDPublicationStageState.applied,
      returnedSessionLineageId: lineage,
      returnedRevisionNumber:
          published.returnedRevisionNumber ?? published.intent.revisionNumber,
      detail: published.detail,
      writeAccounting: published.writeAccounting,
    );
  }

  JourneyDLineageMapping _buildMapping({
    required JourneyDPublicationPlan plan,
    required List<JourneyDProtocolPublicationResult> results,
  }) {
    if (results.length != plan.count) {
      throw JourneyDRebindException('REFUSED: incomplete publication results');
    }

    final bySymbolic = <String, String>{};
    final uuids = <String>{};
    final seenSymbolic = <String>{};
    final seenProtocol = <String>{};

    for (final result in results) {
      if (!result.isApplied) {
        throw JourneyDRebindException('REFUSED: non-applied result in mapping');
      }
      final intent = result.intent;
      if (!seenSymbolic.add(intent.symbolicSessionLineageId)) {
        throw JourneyDRebindException(
          'REFUSED: duplicate symbolic lineage in results',
        );
      }
      if (!seenProtocol.add(intent.protocolId)) {
        throw JourneyDRebindException(
          'REFUSED: duplicate protocol_id in results',
        );
      }
      final uuid = result.returnedSessionLineageId!;
      if (!uuids.add(uuid)) {
        throw JourneyDRebindException(
          'REFUSED: duplicate returned UUID across publications',
        );
      }
      // Explicit attribution by protocol intent identity (not display name).
      bySymbolic[intent.symbolicSessionLineageId] = uuid;
    }

    if (bySymbolic.length != plan.count ||
        uuids.length != plan.count ||
        seenSymbolic.length != plan.count) {
      throw JourneyDRebindException(
        'REFUSED: one-to-one mapping cardinality mismatch',
      );
    }

    for (final intent in plan.intents) {
      if (!bySymbolic.containsKey(intent.symbolicSessionLineageId)) {
        throw JourneyDRebindException(
          'REFUSED: unattributable missing mapping for '
          '${intent.symbolicSessionLineageId}',
        );
      }
    }

    return JourneyDLineageMapping(Map.unmodifiable(bySymbolic));
  }
}

class JourneyDRebindPipelineResult {
  const JourneyDRebindPipelineResult({
    required this.plan,
    required this.publicationResults,
    required this.mapping,
    required this.rebound,
    required this.furtherMutationProhibited,
    required this.importReady,
    this.detail = '',
  });

  final JourneyDPublicationPlan plan;
  final List<JourneyDProtocolPublicationResult> publicationResults;
  final JourneyDLineageMapping? mapping;
  final JourneyDReboundPackageResult? rebound;
  final bool furtherMutationProhibited;
  final bool importReady;
  final String detail;

  /// Import may proceed only with a validated rebound package.
  JourneyDReboundPackageResult requireImportPackage() {
    final package = rebound;
    if (!importReady || package == null || !package.isImportReady) {
      throw JourneyDRebindException(
        'REFUSED: import blocked — validated rebound package unavailable',
      );
    }
    return package;
  }
}

/// Structural gate: symbolic packages cannot be imported after publication starts.
class JourneyDImportGate {
  const JourneyDImportGate();

  /// Returns the import payload only when [pipelineResult] is import-ready.
  Map<String, Object?> payloadForImport({
    required JourneyDRebindPipelineResult pipelineResult,
    required String importedBy,
  }) {
    if (pipelineResult.furtherMutationProhibited ||
        !pipelineResult.importReady ||
        pipelineResult.rebound == null) {
      throw JourneyDRebindException(
        'REFUSED: import not_started — rebound validation incomplete or failed',
      );
    }
    return pipelineResult.requireImportPackage().importPayload(
      importedBy: importedBy,
    );
  }
}
