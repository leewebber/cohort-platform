import '../session_occurrence.dart';
import 'programme_session_occurrence_key.dart';

/// In-memory index enforcing one occurrence per programme slot (non-persistent).
class ProgrammeSessionOccurrenceRegistry {
  ProgrammeSessionOccurrenceRegistry({Map<ProgrammeSessionOccurrenceKey, SessionOccurrence>? seed})
      : _bySlotKey = Map.from(seed ?? const {});

  final Map<ProgrammeSessionOccurrenceKey, SessionOccurrence> _bySlotKey;

  bool containsSlot(ProgrammeSessionOccurrenceKey key) => _bySlotKey.containsKey(key);

  SessionOccurrence? occurrenceForSlot(ProgrammeSessionOccurrenceKey key) =>
      _bySlotKey[key];

  Iterable<SessionOccurrence> get occurrences => _bySlotKey.values;

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
