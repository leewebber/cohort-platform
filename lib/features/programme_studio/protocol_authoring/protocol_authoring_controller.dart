import '../workspace_json.dart';
import 'workspace_session_draft.dart';
import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter/foundation.dart';

import '../../session_revision/models/session_revision_usage_models.dart';
import 'founder_strength_source_guard.dart';
import 'founder_strength_yaml_writer.dart';
import 'protocol_authoring_fixtures.dart';
import 'synthetic_strength_lineage.dart';
import 'synthetic_session_revision_catalogue.dart';
import 'synthetic_strength_review_bridge.dart';
import 'synthetic_strength_session_compiler.dart';

class ProtocolAuthoringController extends ChangeNotifier {
  ProtocolAuthoringController({
    SyntheticStrengthSessionCompiler? compiler,
    this.lineage = SyntheticStrengthLineage.a,
  }) : compiler =
           compiler ??
           SyntheticStrengthSessionCompiler(
             allowSecondLineage: lineage == SyntheticStrengthLineage.b,
           ) {
    ready = _initialize();
  }
  ProtocolAuthoringController._workspace(
    this.compiler,
    this.lineage,
    this._catalogue,
  ) {
    ready = Future.value();
  }

  final SyntheticStrengthSessionCompiler compiler;
  final SyntheticStrengthLineage lineage;
  bool _rootDraft = false;
  bool get isCreatingRoot => _rootDraft;
  bool get hasFrozenRoot => _catalogue?.revisions.isNotEmpty ?? false;
  bool get canCreateRoot =>
      lineage == SyntheticStrengthLineage.b && !hasFrozenRoot && !isEditing;
  static const guard = FounderStrengthSourceGuard();
  static const writer = FounderStrengthYamlWriter();
  static const bridge = SyntheticStrengthReviewBridge();
  late final Future<void> ready;
  SyntheticSessionRevisionCatalogue? _catalogue;
  final Set<int> _programmeEntries = {1};
  int _selected = 1, _opened = 1, _parent = 1, _generation = 0;
  SessionRevisionIdentity? _draftIdentity;
  Map<String, dynamic>? _tree;
  String? _rejectedSource;
  D2ReviewReceipt? _current;
  int? _reviewGeneration;
  bool _disposed = false, _busy = false;
  List<String> _errors = [];
  Future<void> _initialize() async {
    if (lineage == SyntheticStrengthLineage.b) {
      _catalogue = SyntheticSessionRevisionCatalogue.emptyRoot();
      return;
    }
    try {
      final initial = await compiler.compileExact(
        d2R1Source(),
        const SessionRevisionIdentity(
          protocolId: d2RootProtocolId,
          sessionLineageId: d2LineageId,
          revisionNumber: 1,
        ),
      );
      if (_disposed) return;
      _catalogue = SyntheticSessionRevisionCatalogue(initial);
    } catch (error) {
      if (!_disposed) _errors = ['$error'];
    }
    if (!_disposed) notifyListeners();
  }

  bool get initialized => _catalogue != null && (hasFrozenRoot || _rootDraft);
  bool get isEditing => _draftIdentity != null;
  bool get busy => _busy;
  int get selectedRevision => _selected;
  int get openedRevision => _opened;
  int get generation => _generation;
  SessionRevisionIdentity get activeIdentity =>
      _draftIdentity ?? _catalogue!.at(_opened).identity;
  List<D2LocalRevision> get revisions => _catalogue?.revisions ?? const [];
  Map<String, dynamic>? get tree => _tree == null
      ? null
      : jsonDecode(jsonEncode(_tree)) as Map<String, dynamic>;
  List<String> get errors => List.unmodifiable(_errors);
  String get originalSource => _rootDraft || !hasFrozenRoot
      ? ''
      : _catalogue!.at(isEditing ? _parent : _opened).source;
  String get source =>
      _rejectedSource ??
      (_tree == null ? originalSource : writer.write(_tree!));
  D2ReviewReceipt? get current =>
      _reviewGeneration == _generation ? _current : null;
  bool get semanticChange =>
      current != null &&
      (_rootDraft ||
          current!.session.semanticJson !=
              _catalogue!.at(_parent).compiled.semanticJson);
  String get status => busy
      ? 'Validating exact source…'
      : current != null
      ? 'Validated and reviewed — current source'
      : errors.isNotEmpty
      ? 'Invalid draft — current review and export unavailable'
      : 'Validate source to refresh review and export';
  Iterable<D2CompiledSession> get _programmeSessions => _programmeEntries
      .where(
        (n) => _catalogue!.revisions.any((r) => r.identity.revisionNumber == n),
      )
      .map((n) => _catalogue!.at(n).compiled);
  String get selectedProgrammeSource => bridge.packageSource(
    _catalogue!.at(_selected).compiled,
    _programmeSessions,
  );
  String get selectedProgrammeHash => const PlanPackageCompiler()
      .compile(selectedProgrammeSource)
      .contentHashSha256!;

  void _invalidate() {
    _generation++;
    _current = null;
    _reviewGeneration = null;
    _errors = [];
    _busy = false;
  }

  void _fail(Object error) {
    _invalidate();
    _errors = ['$error'];
    notifyListeners();
  }

  void openRevision(int number) {
    if (isEditing) {
      _fail(
        'Cancel or freeze the working draft before opening a frozen revision.',
      );
      return;
    }
    try {
      _catalogue!.at(number);
      _invalidate();
      _opened = number;
      _parent = number;
      _rejectedSource = null;
      notifyListeners();
    } catch (error) {
      _fail(error);
    }
  }

  void createRootDraft() {
    if (_disposed || !canCreateRoot) return;
    _invalidate();
    _rootDraft = true;
    _draftIdentity = lineage.identity(1);
    _tree = lineage.emptyRootTree();
    _rejectedSource = null;
    notifyListeners();
  }

  void openIdentity(SessionRevisionIdentity identity) {
    if (!sameRevision(identity, lineage.identity(identity.revisionNumber))) {
      _fail('revision_identity: foreign owner.');
      return;
    }
    openRevision(identity.revisionNumber);
  }

  void createDraft() {
    if (!initialized || isEditing) return;
    _invalidate();
    _parent = _opened;
    _draftIdentity = _catalogue!.reserve(_parent);
    _resetTree();
    notifyListeners();
  }

  void _resetTree() {
    if (_rootDraft) {
      _tree = lineage.emptyRootTree();
      _rejectedSource = null;
      return;
    }
    final baseline = guard.canonicalTree(
      _catalogue!.at(_parent).source,
      importKey: lineage.importKey(_parent),
    );
    (baseline['programme'] as Map)['import_key'] = lineage.importKey(
      _draftIdentity!.revisionNumber,
    );
    _tree = baseline;
    _rejectedSource = null;
  }

  void resetDraft() {
    if (!isEditing) return;
    _invalidate();
    _resetTree();
    notifyListeners();
  }

  void cancelDraft() {
    if (!isEditing) return;
    if (!_rootDraft) _catalogue!.abandon(_draftIdentity!);
    _rootDraft = false;
    _invalidate();
    _draftIdentity = null;
    _tree = null;
    _rejectedSource = null;
    _opened = _parent;
    notifyListeners();
  }

  bool reopen(String bytes) {
    _invalidate();
    if (!isEditing) {
      _errors = [
        'Frozen source is read-only. Create a new local draft revision first.',
      ];
      notifyListeners();
      return false;
    }
    try {
      final next = guard.canonicalTree(
        bytes,
        importKey: lineage.importKey(_draftIdentity!.revisionNumber),
      );
      final baseline = guard.canonicalTree(
        _rootDraft ? d2R1Source() : _catalogue!.at(_parent).source,
        importKey: _rootDraft ? d2ImportKey(1) : lineage.importKey(_parent),
      );
      (baseline['programme'] as Map)['import_key'] = lineage.importKey(
        _draftIdentity!.revisionNumber,
      );
      // All wrapper fields remain locked; only the complete session may differ.
      final session = jsonDecode(
        jsonEncode(FounderStrengthSourceGuard.session(next)),
      );
      FounderStrengthSourceGuard.session(next).clear();
      FounderStrengthSourceGuard.session(baseline).clear();
      if (jsonEncode(next) != jsonEncode(baseline)) {
        // Compare canonical writer bytes so input map key order is irrelevant.
        if (writer.write(next) != writer.write(baseline)) {
          throw const FormatException(
            'wrapper_locked: wrapper identity/schedule/notes are read-only.',
          );
        }
      }
      FounderStrengthSourceGuard.session(
        next,
      ).addAll(session as Map<String, dynamic>);
      _tree = next;
      _rejectedSource = null;
      notifyListeners();
      return true;
    } catch (error) {
      _tree = null;
      _rejectedSource = bytes;
      _errors = ['$error'];
      notifyListeners();
      return false;
    }
  }

  void _edit(void Function(Map<String, dynamic>) operation) {
    if (!isEditing || _tree == null) return;
    _invalidate();
    _rejectedSource = null;
    try {
      operation(_tree!);
    } catch (error) {
      _errors = ['$error'];
    }
    notifyListeners();
  }

  void editSession(String field, String value) => _edit((tree) {
    if (!{
      'title',
      'coach_notes',
      'estimated_duration_minutes',
    }.contains(field)) {
      throw const FormatException('Unsupported session field.');
    }
    _set(
      FounderStrengthSourceGuard.session(tree),
      field,
      value,
      optional: field != 'title',
      number: field == 'estimated_duration_minutes',
    );
  });
  void editBlock(String field, String value) => _edit((tree) {
    if (!{'title', 'coach_notes'}.contains(field)) {
      throw const FormatException('Unsupported block field.');
    }
    _set(
      FounderStrengthSourceGuard.block(tree),
      field,
      value,
      optional: field != 'title',
    );
  });
  void editExercise(int index, String field, String value) => _edit((tree) {
    final row = FounderStrengthSourceGuard.exerciseRows(tree)[index];
    if (field == 'exercise_name') {
      _set(row, field, value, optional: true);
      return;
    }
    if (!{'sets', 'reps', 'rest_seconds', 'tempo', 'notes'}.contains(field)) {
      throw const FormatException('Unsupported prescription field.');
    }
    _set(
      row['prescription'] as Map<String, dynamic>,
      field,
      value,
      optional: !{'sets', 'reps'}.contains(field),
      number: {'sets', 'reps', 'rest_seconds'}.contains(field),
    );
  });
  void _set(
    Map<String, dynamic> map,
    String key,
    String value, {
    bool optional = false,
    bool number = false,
  }) {
    if (optional && value.trim().isEmpty) {
      map.remove(key);
      return;
    }
    map[key] = number ? int.tryParse(value) ?? value : value;
  }

  void replaceExercise(int index, String transitionalId) => _edit((tree) {
    final row = FounderStrengthSourceGuard.exerciseRows(tree)[index];
    row['transitional_exercise_id'] = transitionalId;
    row.remove('exercise_name');
  });
  void addExercise() => _edit((tree) {
    final rows = FounderStrengthSourceGuard.block(tree)['exercises'] as List;
    if (rows.length >= 2) {
      throw const FormatException('D2 supports at most two exercises.');
    }
    rows.add(<String, dynamic>{
      'transitional_exercise_id': '',
      'order': rows.length + 1,
      'prescription': <String, dynamic>{'sets': '', 'reps': ''},
    });
  });
  void removeExercise(int index) => _edit((tree) {
    final rows = FounderStrengthSourceGuard.block(tree)['exercises'] as List;
    rows.removeAt(index);
    _renumber(rows);
  });
  void moveExercise(int from, int to) => _edit((tree) {
    final rows = FounderStrengthSourceGuard.block(tree)['exercises'] as List;
    final row = rows.removeAt(from);
    rows.insert(to, row);
    _renumber(rows);
  });
  void _renumber(List rows) {
    for (var i = 0; i < rows.length; i++) {
      rows[i]['order'] = i + 1;
    }
  }

  void setLoadMode(int index, String mode) => _edit((tree) {
    final dose =
        FounderStrengthSourceGuard.exerciseRows(tree)[index]['prescription']
            as Map;
    if (!{'unspecified', 'bodyweight', 'kg', 'rpe'}.contains(mode)) {
      throw const FormatException('Unsupported load mode.');
    }
    dose.remove('target_rpe');
    if (mode == 'unspecified') {
      dose.remove('load');
    } else {
      dose['load'] = <String, dynamic>{
        'unit': mode,
        if (mode != 'bodyweight') 'value': '',
      };
    }
  });
  void editLoadValue(int index, String value) => _edit((tree) {
    final load =
        (FounderStrengthSourceGuard.exerciseRows(tree)[index]['prescription']
                as Map)['load']
            as Map;
    final parsed = load['unit'] == 'rpe'
        ? int.tryParse(value)
        : double.tryParse(value);
    load['value'] = parsed != null && parsed.isFinite ? parsed : value;
  });
  Future<bool> validate() async {
    if (!initialized || _disposed) return false;
    if (_rejectedSource != null) {
      _fail(
        const FormatException(
          'rejected_source: Reopen supported source or reset/discard this draft before validation. Retained rejected input grants no freeze authority.',
        ),
      );
      return false;
    }
    _invalidate();
    final token = _generation;
    final identity = activeIdentity;
    _busy = true;
    notifyListeners();
    try {
      final original = source;
      final bytes = isEditing
          ? writer.write(
              guard.canonicalTree(
                original,
                importKey: lineage.importKey(identity.revisionNumber),
              ),
            )
          : original;
      final compiled = await compiler.compileExact(bytes, identity);
      if (_disposed || token != _generation) return false;
      final reviewed = bridge.project(compiled, _programmeSessions);
      if (_disposed || token != _generation) return false;
      _current = reviewed;
      _reviewGeneration = token;
      _busy = false;
      if (isEditing) {
        _tree = guard.canonicalTree(
          bytes,
          importKey: lineage.importKey(identity.revisionNumber),
        );
      }
      notifyListeners();
      // A listener can edit directly or queue an edit while observing success.
      // Settle that notification before granting the validation receipt.
      await Future<void>.value();
      return !_disposed && token == _generation && current != null;
    } catch (error) {
      if (_disposed || token != _generation) return false;
      _busy = false;
      _errors = ['$error'];
      notifyListeners();
      return false;
    }
  }

  Future<String?> exportFounder() async {
    final token = _generation + 1;
    if (!await validate() || _disposed || token != _generation) return null;
    return current?.session.source;
  }

  Future<String?> exportPackage() async {
    final token = _generation + 1;
    if (!await validate() || _disposed || token != _generation) return null;
    return current?.packageSource;
  }

  Future<bool> freeze() async {
    if (!isEditing) return false;
    final rootDraft = _rootDraft;
    final token = _generation + 1;
    if (!await validate() || _disposed || token != _generation || !isEditing) {
      return false;
    }
    final candidate = current?.session;
    if (candidate == null) return false;
    try {
      final catalogue = _catalogue!;
      bool isCurrent() =>
          !_disposed &&
          token == _generation &&
          identical(catalogue, _catalogue) &&
          _rootDraft == rootDraft &&
          sameRevision(_draftIdentity!, candidate.identity);
      final frozen = rootDraft
          ? await catalogue.freezeRoot(
              candidate,
              compiler,
              isCurrent: isCurrent,
            )
          : await catalogue.freeze(candidate, compiler, isCurrent: isCurrent);
      if (_disposed || token != _generation) return false;
      _invalidate();
      _opened = frozen.identity.revisionNumber;
      _parent = _opened;
      _rootDraft = false;
      _draftIdentity = null;
      _tree = null;
      _rejectedSource = null;
      final completedGeneration = _generation;
      notifyListeners();
      await Future<void>.value();
      return !_disposed && completedGeneration == _generation;
    } catch (error) {
      if (token == _generation && !_disposed) _fail(error);
      return false;
    }
  }

  Future<bool> selectProgrammeIdentity(SessionRevisionIdentity identity) {
    if (!sameRevision(identity, lineage.identity(identity.revisionNumber))) {
      _fail('revision_identity: foreign selection.');
      return Future.value(false);
    }
    return selectProgrammeRevision(identity.revisionNumber);
  }

  Future<bool> selectProgrammeRevision(int number) async {
    if (isEditing) {
      _fail('Freeze or cancel the working draft before programme selection.');
      return false;
    }
    _invalidate();
    final token = _generation;
    try {
      final snapshot = _catalogue!.at(number);
      final verified = await compiler.compileExact(
        snapshot.source,
        snapshot.identity,
      );
      if (_disposed || token != _generation) return false;
      if (verified.sourceDigest != snapshot.digest ||
          verified.semanticJson != snapshot.compiled.semanticJson) {
        throw StateError('revision_binding: frozen source changed.');
      }
      _selected = number;
      _opened = number;
      _parent = number;
      _programmeEntries.add(number);
      _rejectedSource = null;
      return validate();
    } catch (error) {
      if (token == _generation && !_disposed) _fail(error);
      return false;
    }
  }

  List<String> get sourceDiff {
    final before = originalSource.split('\n'), after = source.split('\n');
    final table = List.generate(
      before.length + 1,
      (_) => List.filled(after.length + 1, 0),
    );
    for (var i = before.length - 1; i >= 0; i--) {
      for (var j = after.length - 1; j >= 0; j--) {
        table[i][j] = before[i] == after[j]
            ? table[i + 1][j + 1] + 1
            : (table[i + 1][j] >= table[i][j + 1]
                  ? table[i + 1][j]
                  : table[i][j + 1]);
      }
    }
    var i = 0, j = 0;
    final lines = <String>[];
    while (i < before.length || j < after.length) {
      if (i < before.length && j < after.length && before[i] == after[j]) {
        i++;
        j++;
      } else if (i < before.length &&
          (j == after.length || table[i + 1][j] >= table[i][j + 1])) {
        lines.add('- ${i + 1}: ${before[i++]}');
      } else {
        lines.add('+ ${j + 1}: ${after[j++]}');
      }
    }
    return lines;
  }

  Map<String, dynamic> get workspaceState => {
    'lineage': lineage.id,
    'catalogue': _catalogue!.workspaceState,
    'opened': _opened,
    'selected': _selected,
    'programme_entries': _programmeEntries.toList()..sort(),
    'draft': !isEditing
        ? null
        : {
            'number': _draftIdentity!.revisionNumber,
            'parent': _rootDraft ? null : _parent,
            'tree': tree,
            'rejected_source': _rejectedSource,
          },
  };

  static Future<ProtocolAuthoringController> restoreWorkspace(
    Object? input,
    SyntheticStrengthLineage lineage,
    SyntheticStrengthSessionCompiler compiler,
  ) async {
    final state = workspaceObject(input, {
      'lineage',
      'catalogue',
      'opened',
      'selected',
      'programme_entries',
      'draft',
    }, 'session owner');
    if (state['lineage'] != lineage.id) {
      workspaceInvalid('Foreign session owner.');
    }
    final catalogue = await SyntheticSessionRevisionCatalogue.restoreWorkspace(
      state['catalogue'],
      lineage,
      compiler,
    );
    final c = ProtocolAuthoringController._workspace(
      compiler,
      lineage,
      catalogue,
    );
    try {
      final numbers = catalogue.revisions
          .map((r) => r.identity.revisionNumber)
          .toSet();
      c._opened = workspaceInt(state['opened'], 'opened', min: 1);
      c._selected = workspaceInt(state['selected'], 'selected', min: 1);
      c._parent = c._opened;
      c._programmeEntries.clear();
      for (final n in workspaceList(
        state['programme_entries'],
        'standalone available',
      )) {
        final number = workspaceInt(n, 'standalone version', min: 1);
        // Empty B's inherited standalone placeholder 1 is not a frozen entry.
        if ((!numbers.contains(number) && !(numbers.isEmpty && number == 1)) ||
            !c._programmeEntries.add(number)) {
          workspaceInvalid('Conflicting standalone availability.');
        }
      }
      if (!c._programmeEntries.contains(1) ||
          !c._programmeEntries.contains(c._selected) ||
          (numbers.isEmpty
              ? c._opened != 1 || c._selected != 1
              : !numbers.contains(c._opened) ||
                    !numbers.contains(c._selected))) {
        workspaceInvalid('Unknown opened/selected version.');
      }
      final reservations = (catalogue.workspaceState['reservations'] as List);
      if (state['draft'] == null) {
        if (reservations.isNotEmpty) {
          workspaceInvalid('Reservation without draft.');
        }
      } else {
        final draft = workspaceObject(state['draft'], {
          'number',
          'parent',
          'tree',
          'rejected_source',
        }, 'draft');
        final n = workspaceInt(draft['number'], 'draft number', min: 1);
        c._rootDraft = numbers.isEmpty;
        if (c._rootDraft) {
          if (lineage != SyntheticStrengthLineage.b ||
              n != 1 ||
              draft['parent'] != null ||
              reservations.isNotEmpty) {
            workspaceInvalid('Invalid initial-root draft.');
          }
        } else {
          final parent = workspaceInt(
            draft['parent'],
            'draft parent',
            min: 1,
            max: n - 1,
          );
          if (parent != c._opened ||
              reservations.length != 1 ||
              reservations.single['number'] != n ||
              reservations.single['parent'] != parent) {
            workspaceInvalid('Draft/reservation mismatch.');
          }
          c._parent = parent;
        }
        c._draftIdentity = lineage.identity(n);
        if (draft['tree'] != null && draft['rejected_source'] == null) {
          final tree = draft['tree'];
          if (tree is! Map<String, dynamic>) {
            workspaceInvalid('Draft tree required.');
          }
          validateWorkspaceSessionDraft(tree, lineage, n);
          c._tree = jsonDecode(jsonEncode(tree)) as Map<String, dynamic>;
        } else if (draft['tree'] == null &&
            draft['rejected_source'] is String) {
          c._rejectedSource = workspaceString(
            draft['rejected_source'],
            'rejected draft input',
          );
        } else {
          workspaceInvalid('Choose form draft or rejected input, not both.');
        }
      }
      return c;
    } catch (_) {
      c.dispose();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
