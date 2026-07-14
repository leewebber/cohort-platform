import 'interval_block.dart';
import 'interval_modality.dart';
import 'interval_rep_entry.dart';

/// Device-neutral programmed interval session derived from protocol steps.
///
/// Built by an interval plan builder service before execution starts. The plan
/// is immutable during a session; actual performance lives on [IntervalRepEntry]
/// copies inside [IntervalSessionExecutionState].
///
/// See `07 Documentation/37_Interval_Execution_Engine.md`.
class IntervalSessionPlan {
  const IntervalSessionPlan({
    required this.sessionTitle,
    required this.modality,
    required this.blocks,
    this.protocolId,
  });

  final String sessionTitle;
  final IntervalModality modality;
  final List<IntervalBlock> blocks;
  final String? protocolId;

  List<IntervalRepEntry> get timelineEntries => [
        for (final block in blocks) ...block.entries,
      ];

  int get totalPhases => timelineEntries.length;

  int get totalWorkPhases =>
      timelineEntries.where((entry) => entry.isWorkPhase).length;

  IntervalRepEntry? entryByLocalId(String localId) {
    for (final block in blocks) {
      for (final entry in block.entries) {
        if (entry.localId == localId) {
          return entry;
        }
      }
    }

    return null;
  }
}
