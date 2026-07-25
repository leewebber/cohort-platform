import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/session_block.dart';

/// Simulates `performance_protocols` upsert/load for adaptation metadata tests.
class InMemoryProtocolRowStore {
  final Map<String, Map<String, dynamic>> rowsByProtocolId = {};

  void upsertFromDraft(ProtocolDraft draft, {bool published = false}) {
    final map = Map<String, dynamic>.from(draft.toProtocolMap());
    map['published'] = published;
    rowsByProtocolId[draft.protocolId] = map;
  }

  Map<String, dynamic>? row(String protocolId) => rowsByProtocolId[protocolId];

  Protocol loadProtocol(String protocolId) {
    final row = rowsByProtocolId[protocolId];
    if (row == null) {
      throw StateError('Protocol $protocolId not found.');
    }
    return Protocol.fromMap(Map<String, dynamic>.from(row));
  }

  ProtocolDraft loadDraft({
    required String protocolId,
    List<SessionBlock> blocks = const [],
  }) {
    final row = rowsByProtocolId[protocolId];
    if (row == null) {
      throw StateError('Protocol $protocolId not found.');
    }
    final map = Map<String, dynamic>.from(row);

    final base = ProtocolDraft(
      protocolId: map['protocol_id']?.toString() ?? protocolId,
      name: map['name']?.toString() ?? '',
      steps: const [],
      blocks: blocks,
      published: map['published'] == true,
    );

    return ProtocolDraft.mergeAdaptationFromRow(
      draft: ProtocolDraft.applyTrainingContentMetadata(
        draft: base,
        row: map,
      ),
      row: map,
    );
  }

  /// Mirrors [ProtocolBuilderService._buildProtocolUpsertMap] after migration.
  Map<String, dynamic> buildUpsertMap(ProtocolDraft draft, {required bool published}) {
    final map = Map<String, dynamic>.from(draft.toProtocolMap());
    map['published'] = published;
    return map;
  }
}

/// Loads session metadata for programme slots without failing the programme.
List<Protocol> loadProgrammeProtocolsSafely(
  InMemoryProtocolRowStore store,
  Iterable<String> protocolIds,
) {
  final loaded = <Protocol>[];
  for (final id in protocolIds) {
    final row = store.row(id);
    if (row == null) continue;
    loaded.add(Protocol.fromMap(Map<String, dynamic>.from(row)));
  }
  return loaded;
}

ProtocolDraft cohortProtocolWithAdaptationMetadata({
  required String protocolId,
  String name = 'Threshold Intervals',
}) {
  return ProtocolDraft(
    protocolId: protocolId,
    name: name,
    sessionFormat: 'intervals',
    sessionType: 'Running',
    durationMin: 45,
    steps: const [],
    published: true,
    primarySessionIntent: SessionIntent.threshold,
    secondarySessionIntents: const [SessionIntent.aerobicBase],
    minimumViableDurationMin: 30,
  );
}

const explicitBlockPolicy = BlockAdaptationPolicy(
  canRemove: true,
  canShorten: false,
  canReduceVolume: true,
  canReduceIntensity: false,
  canIncreaseRest: true,
  canSuperset: false,
  canReplaceExercises: false,
  canReplaceBlock: true,
);
