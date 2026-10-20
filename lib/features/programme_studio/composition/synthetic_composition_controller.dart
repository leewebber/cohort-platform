import 'prescription_comparison.dart';
import '../workspace_json.dart';
import 'source_intake/canonical_source_intake.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../authoring/programme_authoring_controller.dart';
import '../authoring/programme_authoring_fixtures.dart';
import '../protocol_authoring/protocol_authoring_controller.dart';
import '../protocol_authoring/synthetic_session_revision_catalogue.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';
import '../protocol_authoring/synthetic_strength_lineage.dart';
import '../../session_revision/models/session_revision_usage_models.dart';
import 'synthetic_composition_fixtures.dart';
import 'synthetic_composition_handoff.dart';
import 'synthetic_composition_review_bridge.dart';
import 'synthetic_programme_revision_catalogue.dart';

/// Consent is tied to one verified workspace snapshot, not display labels.
class PreparedVersionUse {
  PreparedVersionUse._(
    this._workspace,
    this._token,
    this._editor,
    this._catalogue,
    this._selection,
    this._append,
    this.revision,
    this.slotKey, {
    this.comparison,
    this.currentVersion,
    this.targetLabel,
    this.unchangedOccurrences = const [],
  });
  final SyntheticCompositionController _workspace;
  final int _token;
  final ProgrammeAuthoringController _editor;
  final SyntheticProgrammeRevisionCatalogue _catalogue;
  final PreparedProgrammeSelection _selection;
  final PreparedCatalogueAppend _append;
  final D2LocalRevision revision;
  final String slotKey;
  final PrescriptionComparison? comparison;
  final D2CompiledSession? currentVersion;
  final String? targetLabel;
  final List<String> unchangedOccurrences;
  List<D2CompiledSession> get includedVersions => _append.entries;
}

/// Detached reconstructed candidate; no live objects are exposed or merged.
class PreparedEditableWorkspace {
  PreparedEditableWorkspace._(
    this._owner,
    this._generation,
    this._transfer,
    this._candidate, {
    this.canonicalSources = false,
  });
  final SyntheticCompositionController _owner;
  final int _generation, _transfer;
  final bool canonicalSources;
  int get importedVersions => _candidate!.owners.fold(
    0,
    (n, o) =>
        n +
        o.revisions
            .where((r) => o.isImportedSnapshot(r.identity.revisionNumber))
            .length,
  );
  SyntheticCompositionController? _candidate;
  int get savedVersions =>
      _candidate!.owners.fold(0, (n, o) => n + o.revisions.length);
  int get privateVersions => savedVersions - _candidate!.admitted.length;
  int get drafts => _candidate!.owners.where((o) => o.isEditing).length;
  String get programmeName =>
      _candidate!.programme.tree!['programme']['name'] as String? ?? '';
  void dispose() {
    _candidate?.dispose();
    _candidate = null;
  }
}

/// Owns both transient source lanes; no store, import/apply or athlete services.
class SyntheticCompositionController extends ChangeNotifier {
  SyntheticCompositionController({SyntheticStrengthSessionCompiler? compiler})
    : compiler =
          compiler ??
          SyntheticStrengthSessionCompiler(allowSecondLineage: true) {
    ready = _initialize();
  }
  SyntheticCompositionController._workspace(this.compiler) {
    ready = Future.value();
  }
  final SyntheticStrengthSessionCompiler compiler;
  late Future<void> ready;
  late ProtocolAuthoringController _session, _secondSession;
  ProtocolAuthoringController get session => _session;
  ProtocolAuthoringController get secondSession => _secondSession;
  List<ProtocolAuthoringController> get owners => [session, secondSession];
  bool get anyDraft => owners.any((owner) => owner.isEditing);
  ProtocolAuthoringController ownerFor(SessionRevisionIdentity identity) {
    final lineage = SyntheticStrengthLineage.resolve(identity);
    return lineage == SyntheticStrengthLineage.a ? session : secondSession;
  }

  void createSecondSession() {
    if (!initialized || anyDraft || _disposed) return;
    secondSession.createRootDraft();
  }

  ProgrammeAuthoringController? _programme;
  SyntheticProgrammeRevisionCatalogue? _catalogue;
  CompositionReviewReceipt? _current, _reconstructed;
  int _operation = 0, _programmeRevision = 0;
  final Map<ProtocolAuthoringController, int> _sessionGenerations = {};
  bool _disposed = false, _busy = false, _disposeNotifierPending = false;
  bool _ownsChildren = true;
  int _workspaceTransfer = 0;
  String? _savedWorkspaceText;
  int _notificationDepth = 0;
  List<String> _errors = [];
  String? rejectedHandoff;
  static const handoff = SyntheticCompositionHandoff();

  ProgrammeAuthoringController get programme => _programme!;
  bool get initialized => _programme != null;
  bool get busy => _busy;
  int get generation => _operation;
  CompositionReviewReceipt? get current => _current;
  CompositionReviewReceipt? get reconstructed => _reconstructed;
  List<D2CompiledSession> get admitted => _catalogue?.entries ?? const [];
  List<String> get errors => List.unmodifiable(_errors);
  String get status => !initialized
      ? 'Opening retained R1 source…'
      : anyDraft
      ? 'Working session draft — freeze or cancel before joint review/export'
      : busy
      ? 'Checking exact programme and session sources…'
      : current != null
      ? 'Joint validation and review — current exact sources'
      : errors.isNotEmpty
      ? 'Invalid operation — joint review and export unavailable'
      : 'Sources changed — refresh joint review';

  Future<void> _initialize() async {
    final token = ++_operation;
    _session = ProtocolAuthoringController(compiler: compiler);
    _secondSession = ProtocolAuthoringController(
      compiler: compiler,
      lineage: SyntheticStrengthLineage.b,
    );
    _sessionGenerations.clear();
    for (final owner in owners) {
      _sessionGenerations[owner] = owner.generation;
      owner.addListener(_sessionChanged);
    }
    await Future.wait(owners.map((owner) => owner.ready));
    if (_disposed || token != _operation) return;
    if (!session.initialized) {
      _errors = session.errors;
      notifyListeners();
      return;
    }
    try {
      _catalogue = SyntheticProgrammeRevisionCatalogue(
        session.revisions.single,
      );
    } catch (error) {
      _errors = ['$error'];
      notifyListeners();
      return;
    }
    _programme = ProgrammeAuthoringController(
      fixture: programmeAuthoringFixtures.first,
      source: CompositionProgrammeSource(_catalogue!),
    );
    _programmeRevision = programme.revision;
    programme.addListener(_programmeChanged);
    notifyListeners();
  }

  void _programmeChanged() {
    if (programme.revision != _programmeRevision) {
      _programmeRevision = programme.revision;
      _invalidate();
    }
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    var changed = false;
    for (final owner in owners) {
      if (owner.generation != _sessionGenerations[owner]) {
        _sessionGenerations[owner] = owner.generation;
        changed = true;
      }
    }
    if (changed) _invalidate();
    if (!_disposed) notifyListeners();
  }

  void _invalidate() {
    _operation++;
    _current = null;
    _reconstructed = null;
    _errors = [];
    _busy = false;
  }

  int _begin() {
    _invalidate();
    _busy = true;
    return _operation;
  }

  int _beginPreparation() {
    _operation++;
    _errors = [];
    _busy = true;
    return _operation;
  }

  void _failPreparation(Object error, int token) {
    if (!_alive(token)) return;
    _busy = false;
    _errors = ['$error'];
    notifyListeners();
  }

  bool _alive(int token) => !_disposed && token == _operation;
  bool _fail(Object error, int token) {
    if (_alive(token)) {
      _busy = false;
      _current = null;
      _reconstructed = null;
      _errors = ['$error'];
      notifyListeners();
    }
    return false;
  }

  void reportFailure(Object error) {
    if (_disposed) return;
    _invalidate();
    _errors = ['$error'];
    notifyListeners();
  }

  Future<D2CompiledSession> _verify(D2CompiledSession s) async {
    final v = await compiler.compileExact(s.source, s.identity);
    verifyCompositionSession(v);
    if (v.source != s.source ||
        v.sourceDigest != s.sourceDigest ||
        v.semanticJson != s.semanticJson ||
        !sameRevision(v.identity, s.identity) ||
        v.profileFingerprint != s.profileFingerprint ||
        !compositionEqual(v.bindings, s.bindings)) {
      throw const FormatException(
        'source_binding: frozen receipt differs from exact recompiled source.',
      );
    }
    return v;
  }

  Future<bool> admit(D2LocalRevision candidate) async {
    final token = _begin();
    notifyListeners();
    if (!_alive(token)) return false;
    try {
      final owner = ownerFor(candidate.identity);
      if (!initialized ||
          anyDraft ||
          programme.tree == null ||
          !owner.revisions.any((r) => identical(r, candidate))) {
        throw const FormatException(
          'admission: choose a genuine frozen revision from this workspace, after freeze/cancel.',
        );
      }
      final catalogue = _catalogue!, editor = programme;
      final verified = await _verify(candidate.compiled);
      if (!_alive(token)) return false;
      catalogue.checkAppend(verified);
      if (!catalogue.contains(verified)) {
        // Both sides commit synchronously before observers can see admission.
        catalogue.appendVerified(verified);
        editor.refreshSourceCatalogue();
      }
      if (_disposed ||
          !identical(catalogue, _catalogue) ||
          !identical(editor, _programme)) {
        return false;
      }
      // Refresh already invalidates busy state. Do not overwrite a newer
      // operation started by an edit/notification after the completed append.
      if (_alive(token)) _busy = false;
      notifyListeners();
      // Settle queued notification callbacks before reporting a committed append.
      // A newer same-workspace operation remains valid; reset/disposal does not.
      await Future<void>.value();
      return !_disposed &&
          identical(catalogue, _catalogue) &&
          identical(editor, _programme);
    } catch (error) {
      return _fail(error, token);
    }
  }

  Future<PreparedVersionUse?> prepareUseVersion(
    String slotKey,
    D2LocalRevision candidate,
  ) async {
    final token = _beginPreparation();
    notifyListeners();
    if (!_alive(token)) return null;
    try {
      final owner = ownerFor(candidate.identity);
      if (!initialized ||
          anyDraft ||
          !owner.revisions.any((r) => identical(r, candidate))) {
        throw const FormatException(
          'Choose a saved version owned by this workspace.',
        );
      }
      final editor = programme, catalogue = _catalogue!;
      final occurrences = [
        for (final w in editor.tree!['weeks'] as List)
          for (final d in w['days'] as List)
            for (final s in d['slots'] as List)
              (
                key: s['slot_key'],
                sessionKey: s['session_key'],
                label:
                    'Week ${w['week_number']} · Day ${d['day_order']} · Workout ${s['session_order']}',
              ),
      ];
      final target = occurrences.where((o) => o.key == slotKey).single;
      final selected = admitted
          .where(
            (s) => compositionReference(s)['session_key'] == target.sessionKey,
          )
          .single;
      final currentVersion = await _verify(selected);
      if (!_alive(token)) return null;
      final verified = <D2CompiledSession>[];
      if (!admitted.any(
        (s) =>
            s.identity.sessionLineageId ==
                candidate.identity.sessionLineageId &&
            s.identity.revisionNumber == 1,
      )) {
        final root = owner.revisions.singleWhere(
          (r) => r.identity.revisionNumber == 1,
        );
        verified.add(await _verify(root.compiled));
        if (!_alive(token)) return null;
      }
      verified.add(await _verify(candidate.compiled));
      if (!_alive(token)) return null;
      final append = catalogue.prepareAppend(verified);
      final selection = editor.prepareCatalogueSelection(
        append.entries.map(compositionReference).toList(),
        slotKey,
        compositionReference(verified.last)['session_key'] as String,
      );
      // Check the complete prospective source lanes using existing all-slot review.
      reviewComposition(selection.source, append.entries);
      if (!_alive(token)) return null;
      final comparison = PrescriptionComparison.compare(
        currentVersion,
        verified.last,
      );
      if (!comparison.supported) {
        throw FormatException(comparison.summary);
      }
      final result = PreparedVersionUse._(
        this,
        token,
        editor,
        catalogue,
        selection,
        append,
        candidate,
        slotKey,
        currentVersion: currentVersion,
        comparison: comparison,
        targetLabel: target.label,
        unchangedOccurrences: List.unmodifiable(
          occurrences
              .where(
                (o) => o.key != slotKey && o.sessionKey == target.sessionKey,
              )
              .map((o) => o.label),
        ),
      );
      _busy = false;
      notifyListeners();
      await Future<void>.value();
      return isCurrentVersionUse(result) ? result : null;
    } catch (error) {
      _failPreparation(error, token);
      return null;
    }
  }

  /// Uses the same exact-source preparation and atomic commit as one-version
  /// consent; setup creates occurrences without overwriting existing choices.
  Future<PreparedVersionUse?> prepareFourWeekSchedule(
    D2LocalRevision a,
    D2LocalRevision b,
    int dayA,
    int dayB,
  ) async {
    final token = _beginPreparation();
    notifyListeners();
    if (!_alive(token)) return null;
    try {
      if (!initialized ||
          anyDraft ||
          a.identity.sessionLineageId != SyntheticStrengthLineage.a.id ||
          b.identity.sessionLineageId != SyntheticStrengthLineage.b.id ||
          !session.revisions.any((r) => identical(r, a)) ||
          !secondSession.revisions.any((r) => identical(r, b))) {
        throw const FormatException(
          'Save exact versions of both sessions before schedule setup.',
        );
      }
      final editor = programme, catalogue = _catalogue!;
      final additions = <D2CompiledSession>[];
      for (final r in [a, secondSession.revisions.first, b]) {
        additions.add(await _verify(r.compiled));
        if (!_alive(token)) return null;
      }
      final append = catalogue.prepareAppend(additions);
      final selection = editor.prepareFourWeekSchedule(
        append.entries.map(compositionReference).toList(),
        compositionReference(a.compiled)['session_key'] as String,
        compositionReference(b.compiled)['session_key'] as String,
        dayA,
        dayB,
      );
      reviewComposition(selection.source, append.entries);
      if (!_alive(token)) return null;
      final result = PreparedVersionUse._(
        this,
        token,
        editor,
        catalogue,
        selection,
        append,
        b,
        'four-week-setup',
      );
      _busy = false;
      notifyListeners();
      await Future<void>.value();
      return isCurrentVersionUse(result) ? result : null;
    } catch (error) {
      _failPreparation(error, token);
      return null;
    }
  }

  bool isCurrentVersionUse(PreparedVersionUse prepared) =>
      identical(prepared._workspace, this) &&
      _alive(prepared._token) &&
      !anyDraft &&
      (prepared.comparison?.supported ?? true) &&
      identical(prepared._editor, _programme) &&
      identical(prepared._catalogue, _catalogue) &&
      prepared._editor.isCurrentSelection(prepared._selection) &&
      prepared._catalogue.isCurrentAppend(prepared._append) &&
      ownerFor(
        prepared.revision.identity,
      ).revisions.any((r) => identical(r, prepared.revision));

  Future<bool> usePreparedVersion(PreparedVersionUse prepared) async {
    if (!isCurrentVersionUse(prepared)) return false;
    final editor = programme, catalogue = _catalogue!;
    _busy = true;
    notifyListeners();
    if (!isCurrentVersionUse(prepared)) return false;
    final committed = editor.commitCatalogueSelection(
      prepared._selection,
      () => catalogue.commitAppend(prepared._append),
    );
    if (!committed) return false;
    // Programme notification invalidates the receipt. Preserve any newer work.
    notifyListeners();
    await Future<void>.value();
    return !_disposed &&
        identical(editor, _programme) &&
        identical(catalogue, _catalogue);
  }

  // Compatibility for the original A-only API; cross-lineage callers use tuples.
  Future<bool> select(int week, int day, int slot, int revision) =>
      selectRevision(
        week,
        day,
        slot,
        SyntheticStrengthLineage.a.identity(revision),
      );
  Future<bool> selectRevision(
    int week,
    int day,
    int slot,
    SessionRevisionIdentity identity,
  ) async {
    final token = _begin();
    notifyListeners();
    if (!_alive(token)) return false;
    try {
      if (!initialized || anyDraft) {
        throw const FormatException(
          'selection: freeze/cancel the working session draft.',
        );
      }
      final choices = admitted
          .where((s) => sameRevision(s.identity, identity))
          .toList();
      if (choices.length != 1) {
        throw const FormatException(
          'selection: explicitly admit this frozen revision first.',
        );
      }
      final editor = programme;
      final snapshot = editor.tree;
      final target =
          (((((snapshot!['weeks'] as List)[week] as Map)['days'] as List)[day]
                      as Map)['slots']
                  as List)[slot]
              as Map;
      if (target['is_optional'] != false ||
          target['completion_expectation'] != 'required') {
        throw const FormatException(
          'selection: only an existing required slot is supported.',
        );
      }
      final verified = await _verify(choices.single);
      if (!_alive(token)) return false;
      editor.editSlot(
        week,
        day,
        slot,
        'session_key',
        compositionReference(verified)['session_key'] as String,
      );
      if (_disposed ||
          !identical(editor, _programme) ||
          editor.issues.isNotEmpty) {
        return false;
      }
      notifyListeners();
      await Future<void>.value();
      return !_disposed && identical(editor, _programme);
    } catch (error) {
      return _fail(error, token);
    }
  }

  Future<bool> validate() async {
    final token = _begin();
    notifyListeners();
    if (!_alive(token)) return false;
    try {
      if (!initialized || anyDraft) {
        throw const FormatException(
          'joint_review: freeze or cancel the working draft first.',
        );
      }
      final yaml = programme.draftSource;
      final captured = admitted;
      final verified = <D2CompiledSession>[];
      for (final s in captured) {
        verified.add(await _verify(s));
        if (!_alive(token)) return false;
      }
      final result = reviewComposition(yaml, verified);
      if (!_alive(token)) return false;
      if (!programme.validateAndReview() ||
          !_alive(token) ||
          programme.verifiedExport() != yaml) {
        if (!_alive(token)) return false;
        throw FormatException(
          'programme: ${programme.issues.map((i) => '${i.path}: ${i.message}').join('\n')}',
        );
      }
      _current = result;
      _busy = false;
      notifyListeners();
      await Future<void>.value();
      return _alive(token) && identical(_current, result);
    } catch (error) {
      return _fail(error, token);
    }
  }

  Future<String?> exportHandoff() async {
    if (!await validate()) return null;
    final token = _operation, receipt = _current;
    await Future<void>.value();
    if (!_alive(token) || receipt == null || !identical(receipt, _current)) {
      return null;
    }
    return handoff.write(receipt);
  }

  bool isCurrentReceipt(CompositionReviewReceipt r) =>
      !_disposed && identical(r, _current) && !anyDraft;

  /// Synchronous consumption gate: an awaited export may be invalidated before
  /// its caller resumes. Compare against the exact currently owned receipt.
  bool canConsumeExport(String bytes, {bool reconstructed = false}) {
    final receipt = reconstructed ? _reconstructed : _current;
    return !_disposed &&
        receipt != null &&
        (reconstructed || isCurrentReceipt(receipt)) &&
        handoff.write(receipt) == bytes;
  }

  Future<bool> reopen(String text) async {
    final token = _begin();
    rejectedHandoff = text;
    notifyListeners();
    if (!_alive(token)) return false;
    try {
      final result = await handoff.read(text, compiler);
      if (!_alive(token)) return false;
      _reconstructed = result;
      rejectedHandoff = null;
      _busy = false;
      notifyListeners();
      await Future<void>.value();
      return _alive(token) && identical(_reconstructed, result);
    } catch (error) {
      return _fail(error, token);
    }
  }

  String? reconstructedExport() =>
      _reconstructed == null ? null : handoff.write(_reconstructed!);

  bool get hasImportedSnapshots =>
      initialized && owners.any((o) => o.hasImportedSnapshots);

  Map<String, dynamic> get _workspaceState => {
    'kind': 'cohort_editable_workspace',
    'version': hasImportedSnapshots ? 3 : 2,
    'fixture_profile': compositionProfile(),
    'owners': [for (final owner in owners) owner.workspaceState],
    'admitted': [for (final s in admitted) compositionTuple(s.identity)],
    'programme_source': programme.draftSource,
  };
  String get workspaceContents => encodeWorkspaceJson(_workspaceState);
  bool get workspaceSaveRequested => _savedWorkspaceText != null;
  bool get workspaceHasChanges =>
      !initialized || _savedWorkspaceText != workspaceContents;

  static Future<SyntheticCompositionController> restoreEditableWorkspace(
    String text, {
    SyntheticStrengthSessionCompiler? compiler,
  }) async {
    final root = workspaceObject(readWorkspaceJson(text), {
      'kind',
      'version',
      'fixture_profile',
      'owners',
      'admitted',
      'programme_source',
    }, 'workspace');
    if (root['kind'] != 'cohort_editable_workspace' ||
        root['version'] is! int ||
        !{1, 2, 3}.contains(root['version']) ||
        !compositionEqual(root['fixture_profile'], compositionProfile())) {
      workspaceInvalid(
        'Unsupported editable format/profile. Review exports are read-only.',
      );
    }
    final engine =
        compiler ?? SyntheticStrengthSessionCompiler(allowSecondLineage: true);
    final rows = workspaceList(root['owners'], 'owners', max: 2);
    if (rows.length != 2) {
      workspaceInvalid('Exactly the existing A/B owners are required.');
    }
    ProtocolAuthoringController? a, b;
    ProgrammeAuthoringController? editor;
    try {
      a = await ProtocolAuthoringController.restoreWorkspace(
        rows[0],
        SyntheticStrengthLineage.a,
        engine,
        allowImportedSnapshots: root['version'] == 3,
      );
      b = await ProtocolAuthoringController.restoreWorkspace(
        rows[1],
        SyntheticStrengthLineage.b,
        engine,
        allowImportedSnapshots: root['version'] == 3,
      );
      if (root['version'] == 3 &&
          !a.hasImportedSnapshots &&
          !b.hasImportedSnapshots) {
        workspaceInvalid(
          'Workspace v3 requires explicit source-import basis; ordinary workspaces use v2.',
        );
      }
      final all = [...a.revisions, ...b.revisions];
      final catalogue = SyntheticProgrammeRevisionCatalogue(a.revisions.first);
      final declared = <D2LocalRevision>[], keys = <String>{};
      for (final raw in workspaceList(root['admitted'], 'admitted', max: 256)) {
        final tuple = workspaceObject(raw, {
          'protocol_id',
          'session_lineage_id',
          'revision_number',
        }, 'admitted identity');
        final matches = all
            .where((r) => compositionEqual(compositionTuple(r.identity), tuple))
            .toList();
        if (matches.length != 1 ||
            !keys.add(revisionKey(matches.single.identity))) {
          workspaceInvalid('Foreign/duplicate/conflicting admitted identity.');
        }
        declared.add(matches.single);
      }
      if (!declared.any(
        (r) => sameRevision(r.identity, SyntheticStrengthLineage.a.identity(1)),
      )) {
        workspaceInvalid('A root must be available.');
      }
      declared.sort((a, b) => compareRevisions(a.identity, b.identity));
      for (final r in declared) {
        catalogue.appendVerified(r.compiled);
      }
      editor = ProgrammeAuthoringController(
        fixture: programmeAuthoringFixtures.first,
        source: CompositionProgrammeSource(catalogue),
      );
      editor.restoreWorkspaceSource(
        workspaceString(root['programme_source'], 'programme source'),
        legacySchedule: root['version'] == 1,
        retainSourceFormatting: root['version'] == 3,
      );
      final result = SyntheticCompositionController._workspace(engine);
      result._session = a;
      result._secondSession = b;
      result._programme = editor;
      result._catalogue = catalogue;
      result._attachWorkspaceListeners();
      result._savedWorkspaceText = result.workspaceContents;
      return result;
    } catch (_) {
      a?.dispose();
      b?.dispose();
      editor?.dispose();
      rethrow;
    }
  }

  void _attachWorkspaceListeners() {
    _sessionGenerations.clear();
    for (final owner in owners) {
      _sessionGenerations[owner] = owner.generation;
      owner.addListener(_sessionChanged);
    }
    _programmeRevision = programme.revision;
    programme.addListener(_programmeChanged);
  }

  void _detachWorkspaceListeners() {
    _programme?.removeListener(_programmeChanged);
    for (final owner in owners) {
      owner.removeListener(_sessionChanged);
    }
  }

  Future<String?> saveEditableWorkspace() async {
    if (_disposed || !initialized || busy) return null;
    final token = _operation, text = workspaceContents;
    SyntheticCompositionController? check;
    try {
      check = await restoreEditableWorkspace(text, compiler: compiler);
      if (!_alive(token) || workspaceContents != text) return null;
      return text;
    } finally {
      check?.dispose();
    }
  }

  bool canConsumeWorkspace(String text) =>
      !_disposed && initialized && !busy && workspaceContents == text;
  void markWorkspaceDownloadRequested(String text) {
    if (!canConsumeWorkspace(text)) return;
    _savedWorkspaceText = text;
    notifyListeners();
  }

  Future<PreparedEditableWorkspace?> prepareEditableWorkspace(
    String text,
  ) async {
    if (_disposed || !initialized) return null;
    final token = _operation, transfer = ++_workspaceTransfer;
    final candidate = await restoreEditableWorkspace(text, compiler: compiler);
    if (!_alive(token) || transfer != _workspaceTransfer) {
      candidate.dispose();
      return null;
    }
    return PreparedEditableWorkspace._(this, token, transfer, candidate);
  }

  /// Source files have snapshots, not saved editor history. Construct an
  /// explicit v3 source-import basis, then use the existing untrusted workspace
  /// reconstruction and ownership checks. No historical parent is inferred.
  static Future<SyntheticCompositionController> fromCanonicalSources(
    Uint8List bytes, {
    SyntheticStrengthSessionCompiler? compiler,
  }) async {
    final engine =
        compiler ?? SyntheticStrengthSessionCompiler(allowSecondLineage: true);
    final checked = await readCanonicalSources(bytes, engine);
    Map<String, dynamic> owner(SyntheticStrengthLineage lineage) {
      final sessions = checked.sessions
          .where((s) => s.identity.sessionLineageId == lineage.id)
          .toList();
      final numbers = sessions.map((s) => s.identity.revisionNumber).toList()
        ..sort();
      return {
        'lineage': lineage.id,
        'opened': 1,
        'selected': 1,
        'programme_entries': numbers.isEmpty ? [1] : numbers,
        'draft': null,
        'catalogue': {
          'highest_reserved': numbers.isEmpty ? 0 : numbers.last,
          'abandoned_ranges': <Object>[],
          'reservations': <Object>[],
          if (numbers.isNotEmpty)
            'source_import': {
              'high_water': numbers.last,
              'revision_numbers': numbers,
            },
          'frozen': [
            for (final s in sessions)
              {
                'number': s.identity.revisionNumber,
                'parent': null,
                'source': s.source,
              },
          ],
        },
      };
    }

    final result = await restoreEditableWorkspace(
      encodeWorkspaceJson({
        'kind': 'cohort_editable_workspace',
        'version': 3,
        'fixture_profile': compositionProfile(),
        'owners': [
          owner(SyntheticStrengthLineage.a),
          owner(SyntheticStrengthLineage.b),
        ],
        'admitted': checked.sessions
            .map((s) => compositionTuple(s.identity))
            .toList(),
        'programme_source': checked.programmeSource,
      }),
      compiler: engine,
    );
    // The author has opened canonical sources, not saved/restored an editable file.
    result._savedWorkspaceText = null;
    return result;
  }

  Future<PreparedEditableWorkspace?> prepareCanonicalSources(
    Uint8List bytes,
  ) async {
    if (_disposed || !initialized) return null;
    final token = _operation, transfer = ++_workspaceTransfer;
    final candidate = await fromCanonicalSources(bytes, compiler: compiler);
    if (!_alive(token) || transfer != _workspaceTransfer) {
      candidate.dispose();
      return null;
    }
    return PreparedEditableWorkspace._(
      this,
      token,
      transfer,
      candidate,
      canonicalSources: true,
    );
  }

  bool isCurrentEditableWorkspace(PreparedEditableWorkspace p) =>
      identical(p._owner, this) &&
      _alive(p._generation) &&
      p._transfer == _workspaceTransfer &&
      p._candidate != null;
  Future<bool> replaceEditableWorkspace(PreparedEditableWorkspace p) async {
    if (!isCurrentEditableWorkspace(p)) return false;
    final next = p._candidate!;
    next._detachWorkspaceListeners();
    _release();
    _invalidate();
    _session = next.session;
    _secondSession = next.secondSession;
    _programme = next._programme;
    _catalogue = next._catalogue;
    _savedWorkspaceText = next._savedWorkspaceText;
    rejectedHandoff = null;
    _attachWorkspaceListeners();
    final installed = _programme;
    next._ownsChildren = false;
    p.dispose();
    notifyListeners();
    await Future<void>.value();
    return !_disposed && identical(installed, _programme);
  }

  Future<void> reset() async {
    if (_disposed) return;
    _invalidate();
    _release();
    _programme = null;
    _catalogue = null;
    _savedWorkspaceText = null;
    rejectedHandoff = null;
    ready = _initialize();
    notifyListeners();
    await ready;
  }

  void _release() {
    final oldProgramme = _programme;
    final oldOwners = owners;
    oldProgramme?.removeListener(_programmeChanged);
    for (final owner in oldOwners) {
      owner.removeListener(_sessionChanged);
    }
    // Tokens and ownership detach immediately. Child cleanup waits until any
    // programme/session notification callback stack has completely unwound.
    scheduleMicrotask(() {
      oldProgramme?.dispose();
      for (final owner in oldOwners) {
        owner.dispose();
      }
    });
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      if (_notificationDepth == 0 && _disposeNotifierPending) {
        _disposeNotifierPending = false;
        super.dispose();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _invalidate();
    if (_ownsChildren) _release();
    if (_notificationDepth > 0) {
      _disposeNotifierPending = true;
    } else {
      super.dispose();
    }
  }
}
