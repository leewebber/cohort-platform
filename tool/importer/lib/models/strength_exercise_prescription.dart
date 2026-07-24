/// Structured strength prescription for an exercise inside a Session block (Sprint 10).
///
/// V1 applies one prescription across all working sets. Set-by-set programming is
/// not supported yet — use separate exercise prescriptions for warm-up/ramp work.
class StrengthExercisePrescription {
  const StrengthExercisePrescription({
    required this.sets,
    required this.reps,
    this.load,
    this.restSeconds,
    this.tempo,
    this.coachCue,
    this.groupId,
  });

  final int sets;
  final StrengthRepPrescription reps;
  final StrengthLoadPrescription? load;
  final int? restSeconds;
  final String? tempo;
  final String? coachCue;
  final String? groupId;

  bool get hasStructuredData =>
      sets > 0 || reps.hasValue || load?.hasValue == true;

  StrengthExercisePrescription copyWith({
    int? sets,
    StrengthRepPrescription? reps,
    StrengthLoadPrescription? load,
    int? restSeconds,
    String? tempo,
    String? coachCue,
    String? groupId,
    bool clearLoad = false,
    bool clearRestSeconds = false,
    bool clearTempo = false,
    bool clearCoachCue = false,
    bool clearGroupId = false,
  }) {
    return StrengthExercisePrescription(
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      load: clearLoad ? null : (load ?? this.load),
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      tempo: clearTempo ? null : (tempo ?? this.tempo),
      coachCue: clearCoachCue ? null : (coachCue ?? this.coachCue),
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sets': sets,
      'reps': reps.toJson(),
      if (load != null && load!.hasValue) 'load': load!.toJson(),
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (_nonEmpty(tempo) != null) 'tempo': tempo!.trim(),
      if (_nonEmpty(coachCue) != null) 'coach_cue': coachCue!.trim(),
      if (_nonEmpty(groupId) != null) 'group_id': groupId!.trim(),
    };
  }

  factory StrengthExercisePrescription.fromJson(Map<String, dynamic> json) {
    final repsRaw = json['reps'];
    final loadRaw = json['load'];

    return StrengthExercisePrescription(
      sets: _parseInt(json['sets']) ?? 0,
      reps: repsRaw is Map<String, dynamic>
          ? StrengthRepPrescription.fromJson(repsRaw)
          : StrengthRepPrescription.fromJson(
              Map<String, dynamic>.from(repsRaw as Map? ?? const {}),
            ),
      load: loadRaw == null
          ? null
          : loadRaw is Map<String, dynamic>
              ? StrengthLoadPrescription.fromJson(loadRaw)
              : StrengthLoadPrescription.fromJson(
                  Map<String, dynamic>.from(loadRaw as Map),
                ),
      restSeconds: _parseInt(json['rest_seconds']),
      tempo: json['tempo']?.toString(),
      coachCue: json['coach_cue']?.toString(),
      groupId: json['group_id']?.toString(),
    );
  }

  StrengthExercisePrescription duplicateIdentity() => this;

  List<String> validate({required bool requireComplete}) {
    final messages = <String>[];
    if (requireComplete && sets <= 0) {
      messages.add('sets must be at least 1.');
    }
    messages.addAll(reps.validate(requireComplete: requireComplete));
    if (load != null) {
      messages.addAll(load!.validate());
    }
    return messages;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

enum StrengthRepType {
  exact,
  range,
  duration,
  distance,
  maxEffort,
  freeText,
}

class StrengthRepPrescription {
  const StrengthRepPrescription({
    required this.type,
    this.exactReps,
    this.minReps,
    this.maxReps,
    this.text,
  });

  final StrengthRepType type;
  final int? exactReps;
  final int? minReps;
  final int? maxReps;
  final String? text;

  bool get hasValue => switch (type) {
        StrengthRepType.exact => exactReps != null && exactReps! > 0,
        StrengthRepType.range =>
          minReps != null && maxReps != null && minReps! > 0 && maxReps! >= minReps!,
        StrengthRepType.duration ||
        StrengthRepType.distance ||
        StrengthRepType.maxEffort ||
        StrengthRepType.freeText =>
          text?.trim().isNotEmpty == true,
      };

  StrengthRepPrescription copyWith({
    StrengthRepType? type,
    int? exactReps,
    int? minReps,
    int? maxReps,
    String? text,
  }) {
    return StrengthRepPrescription(
      type: type ?? this.type,
      exactReps: exactReps ?? this.exactReps,
      minReps: minReps ?? this.minReps,
      maxReps: maxReps ?? this.maxReps,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (exactReps != null) 'exact_reps': exactReps,
      if (minReps != null) 'min_reps': minReps,
      if (maxReps != null) 'max_reps': maxReps,
      if (text?.trim().isNotEmpty == true) 'text': text!.trim(),
    };
  }

  factory StrengthRepPrescription.fromJson(Map<String, dynamic> json) {
    return StrengthRepPrescription(
      type: StrengthRepTypeDb.fromDb(json['type']?.toString()),
      exactReps: StrengthExercisePrescription._parseInt(json['exact_reps']),
      minReps: StrengthExercisePrescription._parseInt(json['min_reps']),
      maxReps: StrengthExercisePrescription._parseInt(json['max_reps']),
      text: json['text']?.toString(),
    );
  }

  factory StrengthRepPrescription.exact(int reps) {
    return StrengthRepPrescription(
      type: StrengthRepType.exact,
      exactReps: reps,
    );
  }

  factory StrengthRepPrescription.range({required int min, required int max}) {
    return StrengthRepPrescription(
      type: StrengthRepType.range,
      minReps: min,
      maxReps: max,
    );
  }

  List<String> validate({required bool requireComplete}) {
    if (!requireComplete) return const [];
    if (!hasValue) {
      return const ['reps are required.'];
    }
    return switch (type) {
      StrengthRepType.exact when exactReps == null || exactReps! <= 0 =>
        const ['exact reps must be at least 1.'],
      StrengthRepType.range when minReps == null ||
          maxReps == null ||
          minReps! <= 0 ||
          maxReps! < minReps! =>
        const ['rep range must have a valid min and max.'],
      StrengthRepType.duration ||
      StrengthRepType.distance ||
      StrengthRepType.maxEffort ||
      StrengthRepType.freeText when text?.trim().isEmpty != false =>
        const ['reps description is required.'],
      _ => const [],
    };
  }

  String toLegacyMetadataValue() {
    return switch (type) {
      StrengthRepType.exact => exactReps?.toString() ?? '',
      StrengthRepType.range => '$minReps–$maxReps',
      StrengthRepType.duration ||
      StrengthRepType.distance ||
      StrengthRepType.maxEffort ||
      StrengthRepType.freeText =>
        text?.trim() ?? '',
    };
  }
}

enum StrengthLoadType {
  bodyweight,
  fixedKg,
  percent1rm,
  rpe,
  rir,
  athleteSelected,
  freeText,
}

class StrengthLoadPrescription {
  const StrengthLoadPrescription({
    required this.type,
    this.kg,
    this.percent1rm,
    this.rpe,
    this.rir,
    this.text,
  });

  final StrengthLoadType type;
  final double? kg;
  final double? percent1rm;
  final int? rpe;
  final int? rir;
  final String? text;

  bool get hasValue => switch (type) {
        StrengthLoadType.bodyweight => true,
        StrengthLoadType.fixedKg => kg != null && kg! > 0,
        StrengthLoadType.percent1rm => percent1rm != null && percent1rm! > 0,
        StrengthLoadType.rpe => rpe != null && rpe! > 0,
        StrengthLoadType.rir => rir != null && rir! >= 0,
        StrengthLoadType.athleteSelected => true,
        StrengthLoadType.freeText => text?.trim().isNotEmpty == true,
      };

  StrengthLoadPrescription copyWith({
    StrengthLoadType? type,
    double? kg,
    double? percent1rm,
    int? rpe,
    int? rir,
    String? text,
  }) {
    return StrengthLoadPrescription(
      type: type ?? this.type,
      kg: kg ?? this.kg,
      percent1rm: percent1rm ?? this.percent1rm,
      rpe: rpe ?? this.rpe,
      rir: rir ?? this.rir,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (kg != null) 'kg': kg,
      if (percent1rm != null) 'percent_1rm': percent1rm,
      if (rpe != null) 'rpe': rpe,
      if (rir != null) 'rir': rir,
      if (text?.trim().isNotEmpty == true) 'text': text!.trim(),
    };
  }

  factory StrengthLoadPrescription.fromJson(Map<String, dynamic> json) {
    return StrengthLoadPrescription(
      type: StrengthLoadTypeDb.fromDb(json['type']?.toString()),
      kg: _parseDouble(json['kg']),
      percent1rm: _parseDouble(json['percent_1rm']),
      rpe: StrengthExercisePrescription._parseInt(json['rpe']),
      rir: StrengthExercisePrescription._parseInt(json['rir']),
      text: json['text']?.toString(),
    );
  }

  List<String> validate() {
    return switch (type) {
      StrengthLoadType.fixedKg when kg == null || kg! <= 0 =>
        const ['load in kg must be greater than 0.'],
      StrengthLoadType.percent1rm when percent1rm == null || percent1rm! <= 0 =>
        const ['1RM percentage must be greater than 0.'],
      StrengthLoadType.rpe when rpe == null || rpe! <= 0 =>
        const ['RPE must be greater than 0.'],
      StrengthLoadType.rir when rir == null || rir! < 0 =>
        const ['RIR must be zero or greater.'],
      StrengthLoadType.freeText when text?.trim().isEmpty != false =>
        const ['load description is required.'],
      _ => const [],
    };
  }

  String toLegacyMetadataValue() {
    return switch (type) {
      StrengthLoadType.bodyweight => 'Bodyweight',
      StrengthLoadType.fixedKg => '${_formatNumber(kg)} kg',
      StrengthLoadType.percent1rm => '${_formatNumber(percent1rm)}% 1RM',
      StrengthLoadType.rpe => 'RPE $rpe',
      StrengthLoadType.rir => '$rir RIR',
      StrengthLoadType.athleteSelected => 'Athlete selected',
      StrengthLoadType.freeText => text?.trim() ?? '',
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class StrengthRepTypeDb {
  static StrengthRepType fromDb(String? value) {
    return StrengthRepType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => StrengthRepType.exact,
    );
  }
}

class StrengthLoadTypeDb {
  static StrengthLoadType fromDb(String? value) {
    return StrengthLoadType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => StrengthLoadType.bodyweight,
    );
  }
}
