import '../../../models/circuit_format.dart';
import '../../../models/circuit_performance_entry.dart';
import '../../../models/circuit_progress_result.dart';
import '../../../models/circuit_score_type.dart';

/// Progress and score snapshot passed when a circuit session finishes.
class CircuitSessionFinishSummary {
  const CircuitSessionFinishSummary({
    required this.sessionTitle,
    required this.format,
    required this.scoreType,
    required this.performance,
    this.endedEarly = false,
    this.completionReason,
    this.sessionNote,
    this.progressResult,
  });

  final String sessionTitle;
  final CircuitFormat format;
  final CircuitScoreType scoreType;
  final CircuitPerformanceEntry performance;
  final bool endedEarly;
  final String? completionReason;
  final String? sessionNote;
  final CircuitProgressResult? progressResult;
}
