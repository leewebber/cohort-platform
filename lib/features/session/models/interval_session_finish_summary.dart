import '../../../models/interval_progress_result.dart';

/// Progress and note snapshot passed when an interval session finishes.
class IntervalSessionFinishSummary {
  const IntervalSessionFinishSummary({
    required this.sessionTitle,
    required this.completedWorkCount,
    required this.totalWorkCount,
    this.sessionNote,
    this.endedEarly = false,
    this.endReasonLabel,
    this.progressResult,
  });

  final String sessionTitle;
  final bool endedEarly;
  final int completedWorkCount;
  final int totalWorkCount;
  final String? endReasonLabel;
  final String? sessionNote;
  final IntervalProgressResult? progressResult;
}
