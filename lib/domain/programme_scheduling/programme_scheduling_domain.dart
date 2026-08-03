/// Sprint 1.7B programme scheduling domain (compute-only preview).
///
/// No persistence, apply, cursor mutation, or athlete-facing UI.
library;

export 'models/programme_schedule_projection.dart';
export 'models/programme_scheduling_preview.dart';
export 'models/programme_scheduling_requests.dart';
export 'models/programme_scheduling_snapshot.dart';
export 'models/scheduled_programme_occurrence.dart';
export 'policy/programme_scheduling_policy.dart';
export 'policy/programme_scheduling_undo_policy_inputs.dart';
export 'services/programme_scheduling_preview_engine.dart';
export 'support/baseline_programme_schedule_projection.dart';
export 'support/programme_scheduling_apply_fingerprint.dart';
export 'support/programme_scheduling_preview_fingerprint.dart';
export 'support/session_occurrence_date_arithmetic.dart';
export 'value_objects/scheduled_occurrence_identity.dart';
export 'vocabulary/programme_schedule_disposition.dart';
export 'vocabulary/programme_scheduling_assignment_status.dart';
export 'vocabulary/programme_scheduling_operation_type.dart';
export 'vocabulary/programme_scheduling_preview_code.dart';
