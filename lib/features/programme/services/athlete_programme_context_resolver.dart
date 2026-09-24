import '../../../data/repositories/programme_assignment_store.dart';
import '../../../models/programme_vocabulary.dart';
import '../domain/athlete_programme_context.dart';

/// Resolves the single production assignment projection for athlete surfaces.
class AthleteProgrammeContextResolver {
  const AthleteProgrammeContextResolver(this._assignments);

  final ProgrammeAssignmentStore _assignments;

  Future<AthleteProgrammeContext> resolve(String athleteId) async {
    final trimmed = athleteId.trim();
    if (trimmed.isEmpty) {
      throw const AthleteProgrammeContextUnavailable(
        'Athlete context is required.',
      );
    }
    try {
      final active = await _assignments.getActiveAssignment(trimmed);
      if (active != null) {
        if (active.status != ProgrammeAssignmentStatus.active ||
            active.athleteId != trimmed) {
          throw const AthleteProgrammeContextUnavailable(
            'Active assignment identity is malformed.',
          );
        }
        return AthleteProgrammeContext.active(active);
      }
      final listed = await _assignments.listForAthlete(trimmed);
      for (final row in listed) {
        if (row.athleteId != trimmed) {
          throw const AthleteProgrammeContextUnavailable(
            'Assignment list included a foreign athlete.',
          );
        }
      }
      final completed = AthleteProgrammeContext.mostRecentCompleted(listed);
      if (completed != null) {
        return AthleteProgrammeContext.completed(completed);
      }
      return const AthleteProgrammeContext.none();
    } on AthleteProgrammeContextUnavailable {
      rethrow;
    } catch (error) {
      throw AthleteProgrammeContextUnavailable(error);
    }
  }
}
