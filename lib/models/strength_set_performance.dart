/// Persisted strength set performance for a single performed set.
///
/// Maps to `training_session_sets`. See `07 Documentation/35_Strength_Performance_Logging.md`.
class StrengthSetPerformance {
  const StrengthSetPerformance({
    required this.id,
    required this.trainingSessionId,
    required this.protocolStepId,
    required this.exerciseId,
    required this.setNumber,
    required this.completed,
    required this.isExtraSet,
    this.targetReps,
    this.targetLoadValue,
    this.targetLoadUnit,
    this.actualReps,
    this.loadValue,
    this.loadUnit,
    this.rpe,
    this.athleteNote,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int trainingSessionId;
  final int protocolStepId;
  final String exerciseId;
  final int setNumber;

  final String? targetReps;
  final double? targetLoadValue;
  final String? targetLoadUnit;

  final String? actualReps;
  final double? loadValue;
  final String? loadUnit;
  final int? rpe;

  final bool completed;
  final bool isExtraSet;
  final String? athleteNote;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const loadUnits = ['kg', 'lb', 'bw', 'rpe', 'unknown'];

  StrengthSetPerformance copyWith({
    int? id,
    int? trainingSessionId,
    int? protocolStepId,
    String? exerciseId,
    int? setNumber,
    String? targetReps,
    double? targetLoadValue,
    String? targetLoadUnit,
    String? actualReps,
    double? loadValue,
    String? loadUnit,
    int? rpe,
    bool? completed,
    bool? isExtraSet,
    String? athleteNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StrengthSetPerformance(
      id: id ?? this.id,
      trainingSessionId: trainingSessionId ?? this.trainingSessionId,
      protocolStepId: protocolStepId ?? this.protocolStepId,
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      targetReps: targetReps ?? this.targetReps,
      targetLoadValue: targetLoadValue ?? this.targetLoadValue,
      targetLoadUnit: targetLoadUnit ?? this.targetLoadUnit,
      actualReps: actualReps ?? this.actualReps,
      loadValue: loadValue ?? this.loadValue,
      loadUnit: loadUnit ?? this.loadUnit,
      rpe: rpe ?? this.rpe,
      completed: completed ?? this.completed,
      isExtraSet: isExtraSet ?? this.isExtraSet,
      athleteNote: athleteNote ?? this.athleteNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory StrengthSetPerformance.fromMap(Map<String, dynamic> map) {
    return StrengthSetPerformance(
      id: map['id'],
      trainingSessionId: map['training_session_id'],
      protocolStepId: map['protocol_step_id'],
      exerciseId: _trimStringRequired(map['exercise_id']),
      setNumber: map['set_number'],
      targetReps: _trimString(map['target_reps']),
      targetLoadValue: _nullableDouble(map['target_load_value']),
      targetLoadUnit: _trimString(map['target_load_unit']),
      actualReps: _trimString(map['actual_reps']),
      loadValue: _nullableDouble(map['load_value']),
      loadUnit: _trimString(map['load_unit']),
      rpe: _nullableInt(map['rpe']),
      completed: map['completed'] == true,
      isExtraSet: map['is_extra_set'] == true,
      athleteNote: _trimString(map['athlete_note']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  /// Maps fields for insert. Server may generate `id` and timestamps.
  Map<String, dynamic> toInsertMap() {
    return {
      'training_session_id': trainingSessionId,
      'protocol_step_id': protocolStepId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      if (targetReps != null) 'target_reps': targetReps,
      if (targetLoadValue != null) 'target_load_value': targetLoadValue,
      if (targetLoadUnit != null) 'target_load_unit': targetLoadUnit,
      if (actualReps != null) 'actual_reps': actualReps,
      if (loadValue != null) 'load_value': loadValue,
      if (loadUnit != null) 'load_unit': loadUnit,
      if (rpe != null) 'rpe': rpe,
      'completed': completed,
      'is_extra_set': isExtraSet,
      if (athleteNote != null) 'athlete_note': athleteNote,
    };
  }

  /// Maps all fields for upsert on the natural set identity key.
  Map<String, dynamic> toUpsertMap() {
    final now = DateTime.now().toUtc().toIso8601String();

    return {
      'training_session_id': trainingSessionId,
      'protocol_step_id': protocolStepId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      if (targetReps != null) 'target_reps': targetReps,
      if (targetLoadValue != null) 'target_load_value': targetLoadValue,
      if (targetLoadUnit != null) 'target_load_unit': targetLoadUnit,
      if (actualReps != null) 'actual_reps': actualReps,
      if (loadValue != null) 'load_value': loadValue,
      if (loadUnit != null) 'load_unit': loadUnit,
      if (rpe != null) 'rpe': rpe,
      'completed': completed,
      'is_extra_set': isExtraSet,
      if (athleteNote != null) 'athlete_note': athleteNote,
      'updated_at': now,
    };
  }

  /// Maps athlete-editable fields for update during an in-progress session.
  Map<String, dynamic> toUpdateMap() {
    return {
      if (actualReps != null) 'actual_reps': actualReps,
      if (loadValue != null) 'load_value': loadValue,
      if (loadUnit != null) 'load_unit': loadUnit,
      if (rpe != null) 'rpe': rpe,
      'completed': completed,
      if (athleteNote != null) 'athlete_note': athleteNote,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static String? _trimString(dynamic value) {
    if (value == null) return null;

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }
}
