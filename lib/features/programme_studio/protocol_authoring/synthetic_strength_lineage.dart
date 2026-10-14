import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../session_revision/models/session_revision_usage_models.dart';
import '../../session_revision/services/session_revision_clone.dart';
import 'founder_strength_source_guard.dart';
import 'protocol_authoring_fixtures.dart';

/// Exactly two local source policies; names never allocate or resolve identity.
class SyntheticStrengthLineage {
  const SyntheticStrengthLineage._(
    this.id,
    this.root,
    this.importPrefix,
    this.keyPrefix,
    this.label,
  );
  static const a = SyntheticStrengthLineage._(
    d2LineageId,
    d2RootProtocolId,
    'syn-d2-strength-r',
    'SYN-D2-STRENGTH-R',
    'Lineage A',
  );
  static const b = SyntheticStrengthLineage._(
    'SYN-D2-STRENGTH-B-LINEAGE',
    'syn-d2-strength-b-r1-w1-d1-s1',
    'syn-d2-strength-b-r',
    'SYN-D2-STRENGTH-B-R',
    'Lineage B',
  );
  final String id, root, importPrefix, keyPrefix, label;
  String importKey(int number) => '$importPrefix$number';
  String sessionKey(int number) => '$keyPrefix$number';
  SessionRevisionIdentity identity(int number) => SessionRevisionIdentity(
    protocolId: number == 1
        ? root
        : SessionRevisionClone.revisionProtocolIdForNumber(
            sourceProtocolId: root,
            revisionNumber: number,
          ),
    sessionLineageId: id,
    revisionNumber: number,
  );
  static SyntheticStrengthLineage resolve(
    SessionRevisionIdentity identity, {
    bool allowSecond = true,
  }) {
    final policy = identity.sessionLineageId == a.id
        ? a
        : allowSecond && identity.sessionLineageId == b.id
        ? b
        : null;
    if (policy == null ||
        identity.revisionNumber < 1 ||
        !sameRevision(policy.identity(identity.revisionNumber), identity)) {
      throw const FormatException(
        'revision_identity: unknown synthetic revision tuple.',
      );
    }
    return policy;
  }

  Map<String, dynamic> emptyRootTree() {
    final tree = d2FounderTree();
    (tree['programme'] as Map)['import_key'] = importKey(1);
    final session = FounderStrengthSourceGuard.session(tree);
    session.clear();
    session.addAll({
      'title': '',
      'session_type': 'strength',
      'blocks': [
        {
          'title': '',
          'block_type': 'strength',
          'order': 1,
          'exercises': [
            {
              'transitional_exercise_id': '',
              'order': 1,
              'prescription': {'sets': '', 'reps': ''},
            },
          ],
        },
      ],
    });
    return jsonDecode(jsonEncode(tree)) as Map<String, dynamic>;
  }
}

String revisionKey(SessionRevisionIdentity i) =>
    jsonEncode([i.protocolId, i.sessionLineageId, i.revisionNumber]);
bool sameRevision(SessionRevisionIdentity a, SessionRevisionIdentity b) =>
    revisionKey(a) == revisionKey(b);
int compareRevisions(SessionRevisionIdentity a, SessionRevisionIdentity b) {
  int rank(String id) => id == SyntheticStrengthLineage.a.id ? 0 : 1;
  final lineage = rank(a.sessionLineageId).compareTo(rank(b.sessionLineageId));
  if (lineage != 0) return lineage;
  final number = a.revisionNumber.compareTo(b.revisionNumber);
  return number != 0 ? number : a.protocolId.compareTo(b.protocolId);
}

Object? sortedFixtureJson(Object? value) => value is Map
    ? {
        for (final key in (value.keys.cast<String>().toList()..sort()))
          key: sortedFixtureJson(value[key]),
      }
    : value is List
    ? value.map(sortedFixtureJson).toList()
    : value;
String fixtureSnapshotFingerprint(
  Iterable<Object?> definitions,
  Iterable<Object?> mappings,
) => sha256
    .convert(
      utf8.encode(
        jsonEncode(
          sortedFixtureJson({
            'definitions': definitions.toList(),
            'mappings': mappings.toList(),
          }),
        ),
      ),
    )
    .toString();
String fixedFixtureFingerprint() => fixtureSnapshotFingerprint(
  d2ExerciseDefinitions().map((d) => d.toJson()),
  d2IdentityMappings().map((m) => m.toJson()),
);
