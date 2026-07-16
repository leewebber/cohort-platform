import 'programme_builder_document.dart';

/// Result of undo or redo navigation.
class ProgrammeBuilderHistoryResult {
  const ProgrammeBuilderHistoryResult({
    required this.document,
    required this.canUndo,
    required this.canRedo,
  });

  final ProgrammeBuilderDocument document;
  final bool canUndo;
  final bool canRedo;
}

/// Lightweight client-only undo/redo using bounded document snapshots.
///
/// Never persisted to Supabase. See `44_Programme_Builder.md` §3.
class ProgrammeBuilderHistory {
  ProgrammeBuilderHistory({this.maxDepth = 20})
      : assert(maxDepth > 0, 'maxDepth must be positive');

  final int maxDepth;
  final List<ProgrammeBuilderDocument> _undoStack = [];
  final List<ProgrammeBuilderDocument> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  int get undoDepth => _undoStack.length;

  int get redoDepth => _redoStack.length;

  /// Records a snapshot before a mutating edit. Clears redo.
  void recordBeforeEdit(ProgrammeBuilderDocument snapshot) {
    _undoStack.add(_snapshotWithoutDerivedState(snapshot));
    _trimStack(_undoStack);
    _redoStack.clear();
  }

  /// Restores the previous document snapshot.
  ProgrammeBuilderHistoryResult? undo(ProgrammeBuilderDocument current) {
    if (_undoStack.isEmpty) return null;

    _redoStack.add(_snapshotWithoutDerivedState(current));
    final restored = _undoStack.removeLast();
    return ProgrammeBuilderHistoryResult(
      document: restored,
      canUndo: canUndo,
      canRedo: canRedo,
    );
  }

  /// Re-applies a reverted document snapshot.
  ProgrammeBuilderHistoryResult? redo(ProgrammeBuilderDocument current) {
    if (_redoStack.isEmpty) return null;

    _undoStack.add(_snapshotWithoutDerivedState(current));
    final restored = _redoStack.removeLast();
    return ProgrammeBuilderHistoryResult(
      document: restored,
      canUndo: canUndo,
      canRedo: canRedo,
    );
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  ProgrammeBuilderDocument _snapshotWithoutDerivedState(
    ProgrammeBuilderDocument document,
  ) {
    return document.copyWith(
      clearLastValidation: true,
      clearPublishReadiness: true,
    );
  }

  void _trimStack(List<ProgrammeBuilderDocument> stack) {
    while (stack.length > maxDepth) {
      stack.removeAt(0);
    }
  }
}
