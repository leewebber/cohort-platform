import '../models/fixed_programme_occurrence_projection.dart';

/// The athlete has an active programme, but it cannot supply an
/// occurrence-backed calendar. This is deliberately different from a
/// successful no-assignment result.
class FixedProgrammeCalendarUnavailableException implements Exception {
  const FixedProgrammeCalendarUnavailableException(this.code);

  final String code;

  @override
  String toString() => 'Fixed programme calendar unavailable: $code';
}

abstract class FixedProgrammeOccurrenceProjectionStore {
  Future<FixedProgrammeCalendarProjection?> resolveActive();

  /// Exact-assignment read. Active and completed may succeed.
  /// Completed calendars are inspection-only in the client.
  Future<FixedProgrammeCalendarProjection> resolveForAssignment(
    String assignmentId,
  );
}

Future<FixedProgrammeCalendarProjection> resolveAssignmentFromActiveFallback(
  FixedProgrammeOccurrenceProjectionStore store,
  String assignmentId,
) async {
  final active = await store.resolveActive();
  if (active != null && active.assignmentId == assignmentId) {
    return active;
  }
  throw const FixedProgrammeCalendarUnavailableException(
    'assignment_not_found',
  );
}
