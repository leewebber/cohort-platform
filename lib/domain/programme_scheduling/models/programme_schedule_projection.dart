import '../value_objects/scheduled_occurrence_identity.dart';
import 'scheduled_programme_occurrence.dart';

/// Immutable schedule projection for one materialised assignment.
class ProgrammeScheduleProjection {
  ProgrammeScheduleProjection({
    required List<ScheduledProgrammeOccurrence> occurrences,
    required this.scheduleRevision,
  }) : occurrences = List.unmodifiable(
         List<ScheduledProgrammeOccurrence>.from(occurrences)
           ..sort(
             (a, b) =>
                 a.identity.authoredOrderKey.compareTo(b.identity.authoredOrderKey),
           ),
       );

  final List<ScheduledProgrammeOccurrence> occurrences;
  final int scheduleRevision;

  ScheduledProgrammeOccurrence? bySlotId(String sessionSlotId) {
    for (final occurrence in occurrences) {
      if (occurrence.identity.sessionSlotId == sessionSlotId) return occurrence;
    }
    return null;
  }

  ScheduledProgrammeOccurrence? byIdentity(ScheduledOccurrenceIdentity identity) {
    for (final occurrence in occurrences) {
      if (occurrence.identity == identity) return occurrence;
    }
    return null;
  }

  /// Uncompleted occurrences at/after [from] in authored order (inclusive).
  List<ScheduledProgrammeOccurrence> uncompletedFrom(
    ScheduledOccurrenceIdentity from,
  ) {
    final start = from.authoredOrderKey;
    return occurrences
        .where(
          (o) => o.isUncompleted && o.identity.authoredOrderKey >= start,
        )
        .toList(growable: false);
  }

  ProgrammeScheduleProjection replacing(
    Map<String, ScheduledProgrammeOccurrence> bySlotId,
  ) {
    final next = <ScheduledProgrammeOccurrence>[];
    for (final occurrence in occurrences) {
      next.add(bySlotId[occurrence.identity.sessionSlotId] ?? occurrence);
    }
    return ProgrammeScheduleProjection(
      occurrences: next,
      scheduleRevision: scheduleRevision,
    );
  }

  Map<String, Object?> toCanonicalMap() => {
    'scheduleRevision': scheduleRevision,
    'occurrences': occurrences.map((o) => o.toCanonicalMap()).toList(),
  };
}
