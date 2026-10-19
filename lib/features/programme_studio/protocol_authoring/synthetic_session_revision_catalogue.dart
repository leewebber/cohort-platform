import 'workspace_session_draft.dart';
import 'founder_strength_source_guard.dart';
import '../workspace_json.dart';
import '../../session_revision/models/session_revision_usage_models.dart';
import 'synthetic_strength_lineage.dart';
import 'protocol_authoring_fixtures.dart';
import 'synthetic_strength_session_compiler.dart';

/// An immutable local fixture snapshot. Imported origin is tracked by its owner;
/// this object alone never proves historical freeze or publication.
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
  final Map<int, int> _parents = {};
  int _highestReserved = 1;
  int _sourceImportHighWater = 0;
  final Set<int> _importedSnapshots = {};
  bool get hasImportedSnapshots => _importedSnapshots.isNotEmpty;
  bool isImportedSnapshot(int number) => _importedSnapshots.contains(number);
  int get sourceImportHighWater => _sourceImportHighWater;
  List<D2LocalRevision> get revisions => List.unmodifiable(_frozen.values);
  D2LocalRevision at(int number) =>
      _frozen[number] ?? (throw StateError('Unknown frozen revision $number.'));
  SessionRevisionIdentity reserve(int parent) {
    at(parent);
    if (_highestReserved >= 1000000) {
      throw StateError(
        'revision_limit: no new local number is available above this inventory.',
      );
    }
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
    _parents[number] = parent;
    _reservations.remove(number);
    return snapshot;
  }

  Map<String, dynamic> get workspaceState => {
    if (hasImportedSnapshots)
      'source_import': {
        'high_water': _sourceImportHighWater,
        'revision_numbers': _importedSnapshots.toList()..sort(),
      },
    'highest_reserved': _highestReserved,
    'abandoned_ranges': _abandonedRanges,
    'frozen': [
      for (final r in revisions)
        {
          'number': r.identity.revisionNumber,
          'parent': _parents[r.identity.revisionNumber],
          'source': r.source,
        },
    ],
    'reservations': [
      for (final e in _reservations.entries)
        {'number': e.key, 'parent': e.value},
    ],
  };

  List<Map<String, int>> get _abandonedRanges {
    final used = {
      ..._frozen.keys,
      ..._reservations.keys,
    }.where((n) => n > 1).toList()..sort();
    final ranges = <Map<String, int>>[];
    var next = hasImportedSnapshots ? _sourceImportHighWater + 1 : 2;
    for (final n in used.where((n) => n >= next)) {
      if (n > next) ranges.add({'first': next, 'last': n - 1});
      next = n + 1;
    }
    if (next <= _highestReserved) {
      ranges.add({'first': next, 'last': _highestReserved});
    }
    return ranges;
  }

  static Future<SyntheticSessionRevisionCatalogue> restoreWorkspace(
    Object? input,
    SyntheticStrengthLineage lineage,
    SyntheticStrengthSessionCompiler compiler, {
    bool allowImportedSnapshots = false,
  }) async {
    const fields = {
      'highest_reserved',
      'abandoned_ranges',
      'frozen',
      'reservations',
    };
    final state = workspaceFields(
      input,
      {...fields, if (allowImportedSnapshots) 'source_import'},
      fields,
      'catalogue',
    );
    final imported = <int>{};
    var importHigh = 0;
    if (state.containsKey('source_import')) {
      final basis = workspaceObject(state['source_import'], {
        'high_water',
        'revision_numbers',
      }, 'source import');
      importHigh = workspaceInt(
        basis['high_water'],
        'source import high-water',
        min: 1,
      );
      var previous = 0;
      for (final raw in workspaceList(
        basis['revision_numbers'],
        'imported snapshots',
      )) {
        final n = workspaceInt(
          raw,
          'imported snapshot number',
          min: 1,
          max: importHigh,
        );
        if (n <= previous || (previous == 0 && n != 1)) {
          workspaceInvalid(
            'Imported snapshots must start at 1 and be uniquely ordered.',
          );
        }
        previous = n;
        imported.add(n);
      }
      if (imported.isEmpty || imported.last != importHigh) {
        workspaceInvalid(
          'Source import high-water must equal its greatest snapshot number.',
        );
      }
    }
    final highest = workspaceInt(state['highest_reserved'], 'highest_reserved');
    if (highest < importHigh) {
      workspaceInvalid(
        'Revision allocation cannot fall below imported inventory.',
      );
    }
    final rows = workspaceList(state['frozen'], 'frozen');
    final compiled = <int, D2CompiledSession>{}, parents = <int, int>{};
    var previous = 0;
    for (final raw in rows) {
      final row = workspaceObject(raw, {
        'number',
        'parent',
        'source',
      }, 'frozen revision');
      final n = workspaceInt(
        row['number'],
        'revision number',
        min: 1,
        max: highest,
      );
      if (n <= previous || (previous == 0 && n != 1)) {
        workspaceInvalid(
          'Revisions must start with root 1 and be ordered uniquely.',
        );
      }
      previous = n;
      final source = workspaceString(row['source'], 'frozen source');
      guardWorkspaceYaml(source);
      validateWorkspaceSessionDraft(
        const FounderStrengthSourceGuard().canonicalTree(
          source,
          importKey: lineage.importKey(n),
        ),
        lineage,
        n,
      );
      final result = await compiler.compileExact(source, lineage.identity(n));
      if (!sameRevision(result.identity, lineage.identity(n)) ||
          result.source != source ||
          result.sourceDigest != d2SourceDigest(source) ||
          result.profileFingerprint != fixedFixtureFingerprint()) {
        workspaceInvalid('Actual compiler identity/source/profile differs.');
      }
      if (imported.isNotEmpty && n <= importHigh && !imported.contains(n)) {
        workspaceInvalid(
          'A snapshot below the source-import high-water cannot claim a local parent.',
        );
      }
      if (n == 1 || imported.contains(n)) {
        if (row['parent'] != null) {
          workspaceInvalid(
            'Root/imported snapshots cannot claim historical parents.',
          );
        }
      } else {
        final parent = workspaceInt(
          row['parent'],
          'frozen parent',
          min: 1,
          max: n - 1,
        );
        if (!compiled.containsKey(parent) ||
            compiled[parent]!.semanticJson == result.semanticJson) {
          workspaceInvalid('Missing parent or no-op frozen descendant.');
        }
        parents[n] = parent;
      }
      compiled[n] = result;
    }
    if (!compiled.keys.toSet().containsAll(imported)) {
      workspaceInvalid('Source import basis references missing snapshots.');
    }
    if (lineage == SyntheticStrengthLineage.a && compiled.isEmpty) {
      workspaceInvalid('Exact A root required.');
    }
    if (compiled.isEmpty && highest != 0) {
      workspaceInvalid('Empty B owner cannot reserve descendants.');
    }
    final restored = compiled.isEmpty
        ? SyntheticSessionRevisionCatalogue.emptyRoot()
        : SyntheticSessionRevisionCatalogue(compiled[1]!, lineage: lineage);
    for (final e in compiled.entries.where((e) => e.key != 1)) {
      restored._frozen[e.key] = D2LocalRevision._(e.value);
    }
    restored._sourceImportHighWater = importHigh;
    restored._importedSnapshots.addAll(imported);
    restored._parents.addAll(parents);
    restored._highestReserved = highest;
    for (final raw in workspaceList(
      state['reservations'],
      'reservations',
      max: 1,
    )) {
      final row = workspaceObject(raw, {'number', 'parent'}, 'reservation');
      final n = workspaceInt(
        row['number'],
        'reservation number',
        min: 2,
        max: highest,
      );
      final parent = workspaceInt(
        row['parent'],
        'reservation parent',
        min: 1,
        max: n - 1,
      );
      if (n != highest ||
          compiled.containsKey(n) ||
          !compiled.containsKey(parent)) {
        workspaceInvalid('Conflicting reservation.');
      }
      restored._reservations[n] = parent;
    }
    if (encodeWorkspaceJson(restored._abandonedRanges) !=
        encodeWorkspaceJson(state['abandoned_ranges'])) {
      workspaceInvalid(
        'Abandoned revision ranges conflict with reservations/high-water.',
      );
    }
    return restored;
  }
}
