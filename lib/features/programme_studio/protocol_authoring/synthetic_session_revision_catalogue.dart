import '../../session_revision/models/session_revision_usage_models.dart';
import '../../session_revision/services/session_revision_clone.dart';
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
  SyntheticSessionRevisionCatalogue(D2CompiledSession initial) {
    if (initial.identity.revisionNumber != 1 ||
        initial.source != d2R1Source()) {
      throw StateError('R1 must be the exact retained fixture source.');
    }
    _frozen[1] = D2LocalRevision._(initial);
  }
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
    return SessionRevisionIdentity(
      protocolId: SessionRevisionClone.revisionProtocolIdForNumber(
        sourceProtocolId: d2RootProtocolId,
        revisionNumber: number,
      ),
      sessionLineageId: d2LineageId,
      revisionNumber: number,
    );
  }

  void abandon(SessionRevisionIdentity identity) =>
      _reservations.remove(identity.revisionNumber);
  Future<D2LocalRevision> freeze(
    D2CompiledSession candidate,
    SyntheticStrengthSessionCompiler compiler, {
    bool Function()? isCurrent,
  }) async {
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
