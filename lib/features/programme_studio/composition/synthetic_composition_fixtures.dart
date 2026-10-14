import 'dart:convert';

import '../authoring/plan_package_v1_yaml_writer.dart';
import '../protocol_authoring/founder_strength_source_guard.dart';
import '../protocol_authoring/founder_strength_yaml_writer.dart';
import '../protocol_authoring/protocol_authoring_fixtures.dart';
import '../protocol_authoring/synthetic_strength_lineage.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';
import '../../session_revision/models/session_revision_usage_models.dart';

const compositionR1Identity = SessionRevisionIdentity(
  protocolId: d2RootProtocolId,
  sessionLineageId: d2LineageId,
  revisionNumber: 1,
);

Object? compositionSorted(Object? value) => value is Map
    ? {
        for (final k in (value.keys.cast<String>().toList()..sort()))
          k: compositionSorted(value[k]),
      }
    : value is List
    ? value.map(compositionSorted).toList()
    : value;
String compositionJson(Object? value) => jsonEncode(compositionSorted(value));
bool compositionEqual(Object? a, Object? b) =>
    compositionJson(a) == compositionJson(b);

Map<String, dynamic> compositionSeedTree() => d2PackageTree(
  identity: compositionR1Identity,
  title: 'Synthetic strength session',
);
String compositionSeedSource() =>
    const PlanPackageV1YamlWriter().writeDraft(compositionSeedTree());
Map<String, Object> compositionProfile() => Map.unmodifiable({
  'id': 'd2-strength-fixtures',
  'version': 1,
  'fingerprint': d2SourceDigest(
    compositionJson({
      'definitions': d2ExerciseDefinitions().map((d) => d.toJson()).toList(),
      'mappings': d2IdentityMappings().map((m) => m.toJson()).toList(),
    }),
  ),
});

Map<String, Object> compositionTuple(SessionRevisionIdentity i) => {
  'protocol_id': i.protocolId,
  'session_lineage_id': i.sessionLineageId,
  'revision_number': i.revisionNumber,
};
Map<String, dynamic> compositionReference(D2CompiledSession s) => {
  'session_key': SyntheticStrengthLineage.resolve(
    s.identity,
  ).sessionKey(s.identity.revisionNumber),
  ...compositionTuple(s.identity),
  'title': s.protocol.name,
};

/// Pure compiler accepts a wider wrapper than D2 authoring. Match its intake too.
void verifyCompositionSession(D2CompiledSession s) {
  final lineage = SyntheticStrengthLineage.resolve(s.identity);
  if (s.profileFingerprint != fixedFixtureFingerprint()) {
    throw const FormatException(
      "fixture_profile: actual compiler snapshot differs from fixed profile.",
    );
  }
  if (d2SourceDigest(s.source) != s.sourceDigest) {
    throw const FormatException('source_binding: source digest differs.');
  }
  if (lineage == SyntheticStrengthLineage.a &&
      s.identity.revisionNumber == 1 &&
      s.source != d2R1Source()) {
    throw const FormatException(
      'source_binding: original R1 bytes are required.',
    );
  }
  const fixedBindings = {
    'cohort.exercise.d2_fixture_a': 'EX-9001@1',
    'cohort.exercise.d2_fixture_b': 'EX-9002@1',
  };
  if (s.bindings.isEmpty ||
      s.bindings.entries.any(
        (entry) => fixedBindings[entry.key] != entry.value,
      )) {
    throw const FormatException(
      'fixture_profile: exercise bindings differ from the fixed synthetic profile.',
    );
  }
  const guard = FounderStrengthSourceGuard();
  final tree = guard.canonicalTree(
    s.source,
    importKey: lineage.importKey(s.identity.revisionNumber),
  );
  final original = guard.canonicalTree(d2R1Source(), importKey: d2ImportKey(1));
  (original['programme'] as Map)['import_key'] = lineage.importKey(
    s.identity.revisionNumber,
  );
  FounderStrengthSourceGuard.session(tree).clear();
  FounderStrengthSourceGuard.session(original).clear();
  if (const FounderStrengthYamlWriter().write(tree) !=
      const FounderStrengthYamlWriter().write(original)) {
    throw const FormatException(
      'wrapper_locked: preserve the complete D2 wrapper.',
    );
  }
}
