import '../session_occurrence.dart';
import '../programme_mapping/programme_session_occurrence_key.dart';

/// Persistence port enforcing one occurrence per programme slot (domain contract).
abstract interface class ProgrammeSessionOccurrenceRegistry {
  bool containsSlot(ProgrammeSessionOccurrenceKey key);

  SessionOccurrence? occurrenceForSlot(ProgrammeSessionOccurrenceKey key);

  void register(SessionOccurrence occurrence);

  /// All registered occurrences (in-memory implementations only).
  Iterable<SessionOccurrence> get occurrences;
}
