import '../ports/programme_session_occurrence_registry.dart';
import '../session_occurrence.dart';
import 'programme_session_occurrence_key.dart';

/// In-memory [ProgrammeSessionOccurrenceRegistry] (non-persistent).
class InMemoryProgrammeSessionOccurrenceRegistry
    implements ProgrammeSessionOccurrenceRegistry {
  InMemoryProgrammeSessionOccurrenceRegistry({
    Map<ProgrammeSessionOccurrenceKey, SessionOccurrence>? seed,
  }) : _bySlotKey = Map.from(seed ?? const {});

  final Map<ProgrammeSessionOccurrenceKey, SessionOccurrence> _bySlotKey;

  @override
  bool containsSlot(ProgrammeSessionOccurrenceKey key) =>
      _bySlotKey.containsKey(key);

  @override
  SessionOccurrence? occurrenceForSlot(ProgrammeSessionOccurrenceKey key) =>
      _bySlotKey[key];

  @override
  Iterable<SessionOccurrence> get occurrences => _bySlotKey.values;

  @override
  void register(SessionOccurrence occurrence) {
    final key = _keyFor(occurrence);
    if (key == null) {
      throw ArgumentError('Occurrence missing programme slot references');
    }
    _bySlotKey[key] = occurrence;
  }

  ProgrammeSessionOccurrenceKey? _keyFor(SessionOccurrence occurrence) {
    if (!occurrence.hasProgrammeSlotReference) return null;
    return ProgrammeSessionOccurrenceKey(
      programmeAssignmentId: occurrence.programmeAssignmentId!,
      programmeSessionSlotId: occurrence.programmeSessionSlotId!,
    );
  }
}
