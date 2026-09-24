import '../../../models/programme_assignment.dart';
import '../../../models/programme_vocabulary.dart';

enum AthleteProgrammeContextKind { active, completed, none }

/// Typed failure when programme context cannot be resolved.
class AthleteProgrammeContextUnavailable implements Exception {
  const AthleteProgrammeContextUnavailable([this.cause]);

  final Object? cause;

  @override
  String toString() =>
      cause == null
          ? 'Athlete programme context is unavailable.'
          : 'Athlete programme context is unavailable: $cause';
}

/// Shared athlete programme context: active, most-recent completed, or none.
class AthleteProgrammeContext {
  const AthleteProgrammeContext._(this.kind, this.assignment);

  const AthleteProgrammeContext.active(ProgrammeAssignment assignment)
    : this._(AthleteProgrammeContextKind.active, assignment);

  const AthleteProgrammeContext.completed(ProgrammeAssignment assignment)
    : this._(AthleteProgrammeContextKind.completed, assignment);

  const AthleteProgrammeContext.none()
    : this._(AthleteProgrammeContextKind.none, null);

  final AthleteProgrammeContextKind kind;
  final ProgrammeAssignment? assignment;

  bool get isActive => kind == AthleteProgrammeContextKind.active;
  bool get isCompleted => kind == AthleteProgrammeContextKind.completed;
  bool get isNone => kind == AthleteProgrammeContextKind.none;

  bool get isMaterialised => assignment?.isMaterialised ?? false;

  static ProgrammeAssignment? mostRecentCompleted(
    Iterable<ProgrammeAssignment> assignments,
  ) {
    final completed = assignments
        .where((row) => row.status == ProgrammeAssignmentStatus.completed)
        .toList(growable: false);
    if (completed.isEmpty) return null;
    final ranked = [...completed]
      ..sort((a, b) {
        final byCompleted = _stamp(b.completedAt).compareTo(
          _stamp(a.completedAt),
        );
        if (byCompleted != 0) return byCompleted;
        final byUpdated = _stamp(b.updatedAt).compareTo(_stamp(a.updatedAt));
        if (byUpdated != 0) return byUpdated;
        final byCreated = _stamp(b.createdAt).compareTo(_stamp(a.createdAt));
        if (byCreated != 0) return byCreated;
        return b.id.compareTo(a.id);
      });
    return ranked.first;
  }

  static DateTime _stamp(DateTime? value) {
    return value?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
