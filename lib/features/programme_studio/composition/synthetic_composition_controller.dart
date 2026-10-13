import 'dart:async';

import 'package:flutter/foundation.dart';

import '../authoring/programme_authoring_controller.dart';
import '../authoring/programme_authoring_fixtures.dart';
import '../protocol_authoring/protocol_authoring_controller.dart';
import '../protocol_authoring/synthetic_session_revision_catalogue.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';
import 'synthetic_composition_fixtures.dart';
import 'synthetic_composition_handoff.dart';
import 'synthetic_composition_review_bridge.dart';
import 'synthetic_programme_revision_catalogue.dart';

/// Owns both transient source lanes; no store, import/apply or athlete services.
class SyntheticCompositionController extends ChangeNotifier {
  SyntheticCompositionController({SyntheticStrengthSessionCompiler? compiler})
    : compiler = compiler ?? SyntheticStrengthSessionCompiler() {
    ready = _initialize();
  }
  final SyntheticStrengthSessionCompiler compiler;
  late Future<void> ready;
  late ProtocolAuthoringController session;
  ProgrammeAuthoringController? _programme;
  SyntheticProgrammeRevisionCatalogue? _catalogue;
  CompositionReviewReceipt? _current, _reconstructed;
  int _operation = 0, _programmeRevision = 0, _sessionGeneration = 0;
  bool _disposed = false, _busy = false, _disposeNotifierPending = false;
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
      : session.isEditing
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
    session = ProtocolAuthoringController(compiler: compiler);
    _sessionGeneration = session.generation;
    session.addListener(_sessionChanged);
    await session.ready;
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
    if (session.generation != _sessionGeneration) {
      _sessionGeneration = session.generation;
      _invalidate();
    }
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
      if (!initialized ||
          session.isEditing ||
          programme.tree == null ||
          !session.revisions.any((r) => identical(r, candidate))) {
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
      return !_disposed &&
          identical(catalogue, _catalogue) &&
          identical(editor, _programme);
    } catch (error) {
      return _fail(error, token);
    }
  }

  Future<bool> select(int week, int day, int slot, int revision) async {
    final token = _begin();
    notifyListeners();
    if (!_alive(token)) return false;
    try {
      if (!initialized || session.isEditing) {
        throw const FormatException(
          'selection: freeze/cancel the working session draft.',
        );
      }
      final choices = admitted
          .where((s) => s.identity.revisionNumber == revision)
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
      if (_disposed || !identical(editor, _programme)) return false;
      notifyListeners();
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
      if (!initialized || session.isEditing) {
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
      !_disposed && identical(r, _current) && !session.isEditing;

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

  Future<void> reset() async {
    if (_disposed) return;
    _invalidate();
    _release();
    _programme = null;
    _catalogue = null;
    rejectedHandoff = null;
    ready = _initialize();
    notifyListeners();
    await ready;
  }

  void _release() {
    final oldProgramme = _programme, oldSession = session;
    oldProgramme?.removeListener(_programmeChanged);
    oldSession.removeListener(_sessionChanged);
    // Tokens and ownership detach immediately. Child cleanup waits until any
    // programme/session notification callback stack has completely unwound.
    scheduleMicrotask(() {
      oldProgramme?.dispose();
      oldSession.dispose();
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
    _release();
    if (_notificationDepth > 0) {
      _disposeNotifierPending = true;
    } else {
      super.dispose();
    }
  }
}
