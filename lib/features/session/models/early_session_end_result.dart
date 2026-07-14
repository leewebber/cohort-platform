import 'early_session_end_reason.dart';

/// Result from [EarlySessionEndDialog] when the athlete confirms early finish.
class EarlySessionEndResult {
  const EarlySessionEndResult({this.reason});

  final EarlySessionEndReason? reason;
}
