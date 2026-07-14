import 'interval_phase_type.dart';
import 'interval_rep_entry.dart';

/// Structural grouping within an interval session plan.
///
/// Blocks organise the athlete-facing overview: warm-up, repeated work/recovery
/// cycles, and cool-down. [entries] holds the flattened executable timeline for
/// the block after repetition expansion.
///
/// See `07 Documentation/37_Interval_Execution_Engine.md`.
class IntervalBlock {
  const IntervalBlock({
    required this.blockIndex,
    required this.title,
    required this.blockType,
    required this.entries,
    this.protocolStepId,
    this.section,
  });

  /// Stable order within the session (0-based).
  final int blockIndex;

  /// Athlete-facing block label (e.g. `Main Set`, `6 × 400 m`).
  final String title;

  /// High-level block role in the session arc.
  final IntervalBlockType blockType;

  /// Expanded phase entries belonging to this block.
  final List<IntervalRepEntry> entries;

  /// Source protocol step when the block maps to a single programmed step.
  final int? protocolStepId;

  /// Coach programming section (e.g. `Warm Up`, `Main Set`).
  final String? section;

  int get totalPhases => entries.length;

  int get completedPhases => entries.where((entry) => entry.completed).length;

  bool get isFullyComplete =>
      entries.isNotEmpty && completedPhases == entries.length;

  List<IntervalRepEntry> get workEntries =>
      entries.where((entry) => entry.phaseType == IntervalPhaseType.work).toList();
}

/// Session-structure role of a block.
enum IntervalBlockType {
  warmUp,
  repeated,
  coolDown,
  single,
  instruction,
}
