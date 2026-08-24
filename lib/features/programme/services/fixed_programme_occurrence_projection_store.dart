import '../models/fixed_programme_occurrence_projection.dart';

abstract class FixedProgrammeOccurrenceProjectionStore {
  Future<FixedProgrammeCalendarProjection?> resolveActive();
}
