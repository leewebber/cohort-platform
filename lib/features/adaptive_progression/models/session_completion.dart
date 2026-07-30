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
    this.programmedSessionKey,
    this.planVersion,
    this.acceptedAdaptationId,
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
  final String? programmedSessionKey;
  final String? planVersion;
  final String? acceptedAdaptationId;

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
    'programmedSessionKey': programmedSessionKey,
    'planVersion': planVersion,
    'acceptedAdaptationId': acceptedAdaptationId,
  };

  factory SessionCompletion.fromPersistenceMap(Map<String, dynamic> map) {
    final completedRaw = map['completedAt']?.toString();
    final completedAt = completedRaw == null
        ? null
        : DateTime.tryParse(completedRaw)?.toUtc();
    if (completedAt == null) {
      throw const FormatException('Invalid completedAt');
    }
    final durationSeconds = (map['durationSeconds'] as num?)?.toInt();
    return SessionCompletion(
      completionId: map['completionId']?.toString() ?? '',
      athleteId: map['athleteId']?.toString() ?? '',
      sessionId: map['sessionId']?.toString(),
      planId: map['planId']?.toString(),
      assignmentId: map['assignmentId']?.toString(),
      planName: map['planName']?.toString(),
      sessionName: map['sessionName']?.toString(),
      completedAt: completedAt,
      duration: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds),
      exercisesCompleted: (map['exercisesCompleted'] as num?)?.toInt() ?? 0,
      totalExercises: (map['totalExercises'] as num?)?.toInt() ?? 0,
      sessionRpe: (map['sessionRpe'] as num?)?.toInt(),
      notes: map['notes']?.toString(),
      programmedSessionKey: map['programmedSessionKey']?.toString(),
      planVersion: map['planVersion']?.toString(),
      acceptedAdaptationId: map['acceptedAdaptationId']?.toString(),
    );
  }
}

/// In-memory session completions, hydrated from [AthleteLocalRepository].
class SessionCompletionStore {
  SessionCompletionStore._();

  static final List<SessionCompletion> _items = [];

  static List<SessionCompletion> get all => List.unmodifiable(_items);

  static SessionCompletion? get latest =>
      _items.isEmpty ? null : _items.last;

  static void add(SessionCompletion completion) => _items.add(completion);

  static void replaceAll(Iterable<SessionCompletion> completions) {
    _items
      ..clear()
      ..addAll(completions);
  }

  static void clear() => _items.clear();
}
