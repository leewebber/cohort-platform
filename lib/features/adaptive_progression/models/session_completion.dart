/// In-memory record of a finished athlete workout (no persistence).
class SessionCompletion {
  const SessionCompletion({
    required this.completionId,
    required this.athleteId,
    required this.completedAt,
    required this.exercisesCompleted,
    required this.totalExercises,
    this.sessionId,
    this.planId,
    this.assignmentId,
    this.planName,
    this.sessionName,
    this.duration,
    this.sessionRpe,
    this.notes,
  });

  final String completionId;
  final String athleteId;
  final String? sessionId;
  final String? planId;
  final String? assignmentId;
  final String? planName;
  final String? sessionName;
  final DateTime completedAt;
  final Duration? duration;
  final int exercisesCompleted;
  final int totalExercises;
  final int? sessionRpe;
  final String? notes;

  double get completionRatio {
    if (totalExercises <= 0) return 1.0;
    return (exercisesCompleted / totalExercises).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toPersistenceMap() => {
    'completionId': completionId,
    'athleteId': athleteId,
    'sessionId': sessionId,
    'planId': planId,
    'assignmentId': assignmentId,
    'planName': planName,
    'sessionName': sessionName,
    'completedAt': completedAt.toIso8601String(),
    'durationSeconds': duration?.inSeconds,
    'exercisesCompleted': exercisesCompleted,
    'totalExercises': totalExercises,
    'sessionRpe': sessionRpe,
    'notes': notes,
  };
}

/// Ephemeral store of session completions (Sprint 4 — memory only).
class SessionCompletionStore {
  SessionCompletionStore._();

  static final List<SessionCompletion> _items = [];

  static List<SessionCompletion> get all => List.unmodifiable(_items);

  static SessionCompletion? get latest =>
      _items.isEmpty ? null : _items.last;

  static void add(SessionCompletion completion) => _items.add(completion);

  static void clear() => _items.clear();
}
