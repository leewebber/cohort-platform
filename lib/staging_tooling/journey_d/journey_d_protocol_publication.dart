import 'package:cohort_platform/core/utils/database_uuid.dart';

import 'journey_d_write_accounting.dart';

/// One fixture protocol that must be published before package import (B4d.21b).
class JourneyDProtocolPublicationIntent {
  const JourneyDProtocolPublicationIntent({
    required this.order,
    required this.role,
    required this.protocolId,
    required this.sessionKey,
    required this.symbolicSessionLineageId,
    required this.revisionNumber,
    required this.exerciseId,
    this.replacementExerciseId,
    this.substitutionRuleId,
    this.canReplaceExercises = false,
  });

  final int order;
  final String role;
  final String protocolId;
  final String sessionKey;
  final String symbolicSessionLineageId;
  final int revisionNumber;
  final String exerciseId;
  final String? replacementExerciseId;
  final String? substitutionRuleId;
  final bool canReplaceExercises;

  bool get isFixtureOwned =>
      protocolId.startsWith('PROT-S17-JD-ADAPT-') &&
      symbolicSessionLineageId.startsWith('SL-S17-JD-ADAPT-') &&
      sessionKey.startsWith('SES-JD-ADAPT-');
}

/// Stage state for a single protocol publication / rebind operation.
enum JourneyDPublicationStageState {
  notStarted,
  inProgress,
  applied,
  failed,
  timedOut,
  unknown,
}

/// Typed publication result for one fixture protocol.
class JourneyDProtocolPublicationResult {
  const JourneyDProtocolPublicationResult({
    required this.intent,
    required this.state,
    this.returnedSessionLineageId,
    this.returnedRevisionNumber,
    this.detail = '',
    this.furtherMutationProhibited = false,
    this.writeAccounting = JourneyDWriteAccounting.none,
  });

  final JourneyDProtocolPublicationIntent intent;
  final JourneyDPublicationStageState state;
  final String? returnedSessionLineageId;
  final int? returnedRevisionNumber;
  final String detail;
  final bool furtherMutationProhibited;
  final JourneyDWriteAccounting writeAccounting;

  bool get isApplied => state == JourneyDPublicationStageState.applied;

  /// Redacted evidence for routine logs (never includes raw UUID).
  Map<String, Object?> get redactedEvidence => {
    'protocol_id': intent.protocolId,
    'symbolic_session_lineage_id': intent.symbolicSessionLineageId,
    'session_key': intent.sessionKey,
    'revision_number': intent.revisionNumber,
    'state': state.name,
    'returned_session_lineage_id_redacted': _redactUuid(
      returnedSessionLineageId,
    ),
    'returned_revision_number': returnedRevisionNumber,
    'detail': detail,
    'further_mutation_prohibited': furtherMutationProhibited,
    'write_accounting': writeAccounting.toJson(),
  };

  static String? _redactUuid(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!DatabaseUuid.isValidDatabaseUuid(value)) return '***invalid***';
    return '${value.substring(0, 8)}…';
  }
}

/// Complete one-to-one symbolic → UUID mapping after publication.
class JourneyDLineageMapping {
  const JourneyDLineageMapping(this.bySymbolicLineage);

  final Map<String, String> bySymbolicLineage;

  int get count => bySymbolicLineage.length;

  Set<String> get symbolicIds => bySymbolicLineage.keys.toSet();

  Set<String> get canonicalUuids => bySymbolicLineage.values.toSet();
}

/// Outcome of building a publication plan from protocol intent + package.
class JourneyDPublicationPlan {
  const JourneyDPublicationPlan({required this.intents});

  final List<JourneyDProtocolPublicationIntent> intents;

  int get count => intents.length;
}

/// Canonical publisher boundary — implementations must call
/// [ProtocolBuilderService.publishDraft] (or a test fake of that contract).
/// Never implement protocol publication via improvised SQL.
abstract class JourneyDProtocolPublisher {
  /// Publishes exactly [intent]'s fixture protocol and returns a typed result.
  ///
  /// Attribution must be by [JourneyDProtocolPublicationIntent.protocolId],
  /// not display-name guessing or result-list order alone.
  Future<JourneyDProtocolPublicationResult> publish(
    JourneyDProtocolPublicationIntent intent,
  );
}
