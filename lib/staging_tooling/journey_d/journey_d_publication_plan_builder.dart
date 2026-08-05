import 'dart:convert';

import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';

import 'journey_d_protocol_publication.dart';

/// Builds a deterministic publication plan from protocol_intent.json + package.
class JourneyDPublicationPlanBuilder {
  const JourneyDPublicationPlanBuilder();

  static const expectedLineageCode = 'PROG-S17-JD-ADAPT';
  static const reservedLineages = {
    'PROG-S15A-STAGING',
    'PROG-S13-ELIG',
    'PROG-S13-INELIG',
  };

  JourneyDPublicationPlan build({
    required String protocolIntentJson,
    required PlanPackageManifest packageManifest,
  }) {
    final root = jsonDecode(protocolIntentJson);
    if (root is! Map<String, dynamic>) {
      throw JourneyDRebindException(
        'REFUSED: protocol intent root must be object',
      );
    }

    final lineageCode = (root['lineage_code'] as String?)?.trim() ?? '';
    if (lineageCode != expectedLineageCode) {
      throw JourneyDRebindException(
        'REFUSED: protocol intent lineage_code mismatch',
      );
    }
    if (packageManifest.programme.lineageCode != expectedLineageCode) {
      throw JourneyDRebindException(
        'REFUSED: package lineage is not Journey D fixture',
      );
    }
    if (reservedLineages.contains(lineageCode)) {
      throw JourneyDRebindException('REFUSED: reserved lineage');
    }

    final rawProtocols = root['protocols'];
    if (rawProtocols is! List || rawProtocols.isEmpty) {
      throw JourneyDRebindException(
        'REFUSED: protocol intent protocols must be non-empty',
      );
    }

    final intents = <JourneyDProtocolPublicationIntent>[];
    for (final item in rawProtocols) {
      if (item is! Map) {
        throw JourneyDRebindException('REFUSED: protocol intent entry invalid');
      }
      final map = Map<String, dynamic>.from(item);
      intents.add(
        JourneyDProtocolPublicationIntent(
          order: (map['order'] as num?)?.toInt() ?? 0,
          role: (map['role'] as String?)?.trim() ?? '',
          protocolId: (map['protocol_id'] as String?)?.trim() ?? '',
          sessionKey: (map['session_key'] as String?)?.trim() ?? '',
          symbolicSessionLineageId:
              (map['symbolic_session_lineage_id'] as String?)?.trim() ?? '',
          revisionNumber: (map['revision_number'] as num?)?.toInt() ?? 0,
          exerciseId: (map['exercise_id'] as String?)?.trim() ?? '',
          replacementExerciseId: (map['replacement_exercise_id'] as String?)
              ?.trim(),
          substitutionRuleId: (map['substitution_rule_id'] as String?)?.trim(),
          canReplaceExercises: map['can_replace_exercises'] == true,
        ),
      );
    }

    intents.sort((a, b) => a.order.compareTo(b.order));

    _assertPlanIntegrity(intents, packageManifest);
    return JourneyDPublicationPlan(intents: List.unmodifiable(intents));
  }

  void _assertPlanIntegrity(
    List<JourneyDProtocolPublicationIntent> intents,
    PlanPackageManifest package,
  ) {
    if (intents.isEmpty) {
      throw JourneyDRebindException('REFUSED: empty publication plan');
    }

    final symbolic = <String>{};
    final protocols = <String>{};
    final sessionKeys = <String>{};
    final orders = <int>{};

    for (final intent in intents) {
      if (!intent.isFixtureOwned) {
        throw JourneyDRebindException(
          'REFUSED: protocol intent is not fixture-owned '
          '(${intent.protocolId})',
        );
      }
      if (intent.protocolId.isEmpty ||
          intent.sessionKey.isEmpty ||
          intent.symbolicSessionLineageId.isEmpty ||
          intent.revisionNumber < 1 ||
          intent.exerciseId.isEmpty) {
        throw JourneyDRebindException(
          'REFUSED: protocol intent missing required fields',
        );
      }
      if (!symbolic.add(intent.symbolicSessionLineageId)) {
        throw JourneyDRebindException(
          'REFUSED: duplicate symbolic lineage '
          '${intent.symbolicSessionLineageId}',
        );
      }
      if (!protocols.add(intent.protocolId)) {
        throw JourneyDRebindException(
          'REFUSED: duplicate protocol_id ${intent.protocolId}',
        );
      }
      if (!sessionKeys.add(intent.sessionKey)) {
        throw JourneyDRebindException(
          'REFUSED: duplicate session_key ${intent.sessionKey}',
        );
      }
      if (!orders.add(intent.order)) {
        throw JourneyDRebindException(
          'REFUSED: duplicate protocol order ${intent.order}',
        );
      }

      PlanPackageSessionRevisionRef? session;
      for (final candidate in package.sessions) {
        if (candidate.sessionKey == intent.sessionKey) {
          session = candidate;
          break;
        }
      }
      if (session == null) {
        throw JourneyDRebindException(
          'REFUSED: package missing session_key ${intent.sessionKey}',
        );
      }
      if (session.protocolId != intent.protocolId) {
        throw JourneyDRebindException(
          'REFUSED: protocol_id mismatch for ${intent.sessionKey}',
        );
      }
      if (session.sessionLineageId != intent.symbolicSessionLineageId) {
        throw JourneyDRebindException(
          'REFUSED: symbolic lineage mismatch for ${intent.sessionKey}',
        );
      }
      if (session.revisionNumber != intent.revisionNumber) {
        throw JourneyDRebindException(
          'REFUSED: revision_number mismatch for ${intent.sessionKey}',
        );
      }
    }

    // Every package session must be covered exactly once.
    if (package.sessions.length != intents.length) {
      throw JourneyDRebindException(
        'REFUSED: package session count does not match protocol intents',
      );
    }
    for (final session in package.sessions) {
      if (!symbolic.contains(session.sessionLineageId)) {
        throw JourneyDRebindException(
          'REFUSED: package session lineage not in intent '
          '${session.sessionLineageId}',
        );
      }
    }
  }
}

class JourneyDRebindException implements Exception {
  JourneyDRebindException(this.message);
  final String message;

  @override
  String toString() => message;
}
