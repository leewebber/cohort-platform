import 'package:cohort_plan_package/cohort_plan_package.dart';

import '../authoring/programme_authoring_source.dart';
import '../domain/programme_review_models.dart';
import '../projection/programme_review_source.dart';
import '../protocol_authoring/synthetic_session_revision_catalogue.dart';
import '../protocol_authoring/synthetic_strength_review_bridge.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';
import 'synthetic_composition_fixtures.dart';

/// Append-only detached snapshots; draft allocation belongs solely to D2.
class SyntheticProgrammeRevisionCatalogue {
  SyntheticProgrammeRevisionCatalogue(D2LocalRevision r1) {
    verifyCompositionSession(r1.compiled);
    if (r1.identity.revisionNumber != 1) {
      throw StateError('Original R1 required.');
    }
    _entries.add(r1.compiled);
  }
  SyntheticProgrammeRevisionCatalogue.readOnly(
    Iterable<D2CompiledSession> entries,
  ) {
    _readOnly = true;
    for (final s in entries) {
      checkAppend(s);
      if (contains(s)) {
        throw const FormatException('sources: duplicate revision identity.');
      }
      _entries.add(s);
    }
    _entries.sort(
      (a, b) => a.identity.revisionNumber.compareTo(b.identity.revisionNumber),
    );
    if (_entries.where((s) => s.identity.revisionNumber == 1).length != 1) {
      throw const FormatException('sources: original R1 is required.');
    }
  }
  bool _readOnly = false;
  final List<D2CompiledSession> _entries = [];
  int epoch = 0;
  List<D2CompiledSession> get entries => List.unmodifiable(_entries);
  bool contains(D2CompiledSession s) => _entries.any(
    (e) =>
        compositionEqual(
          compositionTuple(e.identity),
          compositionTuple(s.identity),
        ) &&
        e.source == s.source &&
        e.sourceDigest == s.sourceDigest &&
        e.semanticJson == s.semanticJson &&
        compositionEqual(e.bindings, s.bindings),
  );

  void checkAppend(D2CompiledSession s) {
    verifyCompositionSession(s);
    for (final e in _entries) {
      final sameNumber =
          e.identity.sessionLineageId == s.identity.sessionLineageId &&
          e.identity.revisionNumber == s.identity.revisionNumber;
      if ((e.identity.protocolId == s.identity.protocolId || sameNumber) &&
          !contains(s)) {
        throw const FormatException(
          'revision_collision: immutable tuple/source/bindings conflict.',
        );
      }
    }
  }

  bool appendVerified(D2CompiledSession s) {
    if (_readOnly) throw StateError('Reconstructed review is read-only.');
    checkAppend(s);
    if (contains(s)) return false;
    _entries.add(s);
    _entries.sort(
      (a, b) => a.identity.revisionNumber.compareTo(b.identity.revisionNumber),
    );
    epoch++;
    return true;
  }
}

class CompositionProgrammeSource implements ProgrammeAuthoringSource {
  CompositionProgrammeSource(this.catalogue);
  final SyntheticProgrammeRevisionCatalogue catalogue;
  @override
  String get id => 'synthetic-composition';
  @override
  String get label => 'Synthetic composition — protected contracts';
  @override
  String get originalSource => compositionSeedSource();
  @override
  Map<String, dynamic> get trustedTree => compositionSeedTree();
  @override
  List<Map<String, dynamic>> get sessionReferences =>
      catalogue.entries.map(compositionReference).toList();
  @override
  List<PlanPackageValidationIssue> catalogueIssues(
    PlanPackageManifest manifest,
  ) {
    final actual = [
      for (final r in manifest.sessions)
        {
          'session_key': r.sessionKey,
          'protocol_id': r.protocolId,
          'session_lineage_id': r.sessionLineageId,
          'revision_number': r.revisionNumber,
          'title': r.title,
        },
    ];
    final expected = sessionReferences;
    actual.sort(
      (a, b) =>
          (a['session_key'] as String).compareTo(b['session_key'] as String),
    );
    expected.sort(
      (a, b) =>
          (a['session_key'] as String).compareTo(b['session_key'] as String),
    );
    return compositionEqual(actual, expected)
        ? []
        : [
            const PlanPackageValidationIssue(
              path: 'sessions',
              code: 'composition_catalogue_mismatch',
              message:
                  'Every reference must exactly match one admitted immutable revision and source.',
            ),
          ];
  }

  @override
  ProgrammeReviewSourceBundle bundle(String exactYaml) =>
      compositionBundle(exactYaml, catalogue.entries);
}

ProgrammeReviewSourceBundle compositionBundle(
  String yaml,
  Iterable<D2CompiledSession> entries,
) {
  final sessions = List<D2CompiledSession>.unmodifiable(entries);
  const bridge = SyntheticStrengthReviewBridge();
  final text = bridge.readerText(sessions);
  bridge.verifyReaderText(text, sessions);
  return ProgrammeReviewSourceBundle(
    spec: const ProgrammeReviewSourceSpec(
      catalogId: 'synthetic-composition',
      classification: ProgrammeReviewClassification.fixtureTestExample,
      planPackagePath: 'synthetic/composition.plan-package.yaml',
      fixture: true,
      executableProtocolSqlPaths: ['synthetic/composition-derived-reader-text'],
    ),
    planPackageYaml: yaml,
    executableProtocolSql: List.unmodifiable([text]),
  );
}
