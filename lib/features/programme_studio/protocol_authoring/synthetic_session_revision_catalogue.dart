import '../../session_revision/models/session_revision_usage_models.dart';
import 'synthetic_strength_lineage.dart';
import 'protocol_authoring_fixtures.dart';
import 'synthetic_strength_session_compiler.dart';

/// A frozen, unpublished local fixture snapshot, not a persisted lifecycle.
class D2LocalRevision {
  D2LocalRevision._(this.compiled);
  final D2CompiledSession compiled;
  String get source => compiled.source;
  String get digest => compiled.sourceDigest;
  SessionRevisionIdentity get identity => compiled.identity;
}

class SyntheticSessionRevisionCatalogue {
  SyntheticSessionRevisionCatalogue(
    D2CompiledSession initial, {
    this.lineage = SyntheticStrengthLineage.a,
  }) {
    if (initial.profileFingerprint != fixedFixtureFingerprint()) {
      throw const FormatException(
        "fixture_profile: actual compiler snapshot differs.",
      );
    }
    if (initial.identity.revisionNumber != 1 ||
        (lineage == SyntheticStrengthLineage.a &&
            initial.source != d2R1Source()) ||
        !sameRevision(initial.identity, lineage.identity(1)) ||
        initial.profileFingerprint != fixedFixtureFingerprint()) {
      throw StateError('R1 must be the exact retained fixture source.');
    }
    _frozen[1] = D2LocalRevision._(initial);
  }
  SyntheticSessionRevisionCatalogue.emptyRoot()
    : lineage = SyntheticStrengthLineage.b,
      _highestReserved = 0;
  final SyntheticStrengthLineage lineage;
  final Map<int, D2LocalRevision> _frozen = {};
  final Map<int, int> _reservations = {};
  int _highestReserved = 1;
  List<D2LocalRevision> get revisions => List.unmodifiable(_frozen.values);
  D2LocalRevision at(int number) =>
      _frozen[number] ?? (throw StateError('Unknown frozen revision $number.'));
  SessionRevisionIdentity reserve(int parent) {
    at(parent);
    final number = ++_highestReserved;
    _reservations[number] = parent;
    return lineage.identity(number);
  }

  void abandon(SessionRevisionIdentity identity) {
    if (!sameRevision(identity, lineage.identity(identity.revisionNumber))) {
      throw StateError('revision_identity: foreign reservation.');
    }
    _reservations.remove(identity.revisionNumber);
  }

  Future<D2LocalRevision> freezeRoot(
    D2CompiledSession candidate,
    SyntheticStrengthSessionCompiler compiler, {
    required bool Function() isCurrent,
  }) async {
    if (lineage != SyntheticStrengthLineage.b ||
        _frozen.isNotEmpty ||
        !sameRevision(candidate.identity, lineage.identity(1))) {
      throw StateError('revision_collision: root already frozen or foreign.');
    }
    final verified = await compiler.compileExact(
      candidate.source,
      candidate.identity,
    );
    if (!isCurrent() || _frozen.isNotEmpty) {
      throw StateError('stale_revision: root changed during freeze.');
    }
    _verifyReceipt(candidate, verified);
    final snapshot = D2LocalRevision._(verified);
    _frozen[1] = snapshot;
    _highestReserved = 1;
    return snapshot;
  }

  void _verifyReceipt(D2CompiledSession candidate, D2CompiledSession verified) {
    if (!sameRevision(candidate.identity, verified.identity) ||
        !sameRevision(
          candidate.identity,
          lineage.identity(candidate.identity.revisionNumber),
        ) ||
        verified.source != candidate.source ||
        verified.semanticJson != candidate.semanticJson ||
        verified.sourceDigest != candidate.sourceDigest ||
        verified.profileFingerprint != fixedFixtureFingerprint() ||
        verified.profileFingerprint != candidate.profileFingerprint) {
      throw StateError(
        'revision_binding: receipt differs from exact source/profile.',
      );
    }
  }

  Future<D2LocalRevision> freeze(
    D2CompiledSession candidate,
    SyntheticStrengthSessionCompiler compiler, {
    bool Function()? isCurrent,
  }) async {
    if (!sameRevision(
      candidate.identity,
      lineage.identity(candidate.identity.revisionNumber),
    )) {
      throw StateError("revision_identity: foreign candidate.");
    }
    final number = candidate.identity.revisionNumber;
    final parent = _reservations[number];
    if (parent == null || _frozen.containsKey(number)) {
      throw StateError('revision_collision: no active reservation.');
    }
    final verified = await compiler.compileExact(
      candidate.source,
      candidate.identity,
    );
    if (isCurrent != null && !isCurrent()) {
      throw StateError('stale_revision: source changed during freeze.');
    }
    if (_reservations[number] != parent || _frozen.containsKey(number)) {
      throw StateError('revision_collision: reservation changed.');
    }
    _verifyReceipt(candidate, verified);
    if (verified.semanticJson != candidate.semanticJson ||
        verified.sourceDigest != candidate.sourceDigest) {
      throw StateError('revision_binding: receipt differs from exact source.');
    }
    if (verified.semanticJson == at(parent).compiled.semanticJson) {
      throw StateError(
        'no_semantic_change: edit the source or cancel; formatting alone cannot freeze a revision.',
      );
    }
    final snapshot = D2LocalRevision._(verified);
    _frozen[number] = snapshot;
    _reservations.remove(number);
    return snapshot;
  }
}
