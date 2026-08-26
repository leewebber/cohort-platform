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
}
