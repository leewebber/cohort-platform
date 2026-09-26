import 'dart:convert';

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
    this.perSide = false,
    this.groupId,
    this.performanceCapture,
    this.calories,
    this.prescribedDistanceMeters,
    this.prescribedDistanceText,
  });

  final int sets;
  final StrengthRepPrescription reps;
  final StrengthLoadPrescription? load;
  final int? restSeconds;
  final String? tempo;
  final String? coachCue;
  final bool perSide;
  final String? groupId;
  final ExercisePerformanceCapture? performanceCapture;
  final int? calories;
  final double? prescribedDistanceMeters;
  final String? prescribedDistanceText;

  bool get hasStructuredData =>
      sets > 0 ||
      reps.hasValue ||
      load?.hasValue == true ||
      calories != null ||
      prescribedDistanceMeters != null ||
      (prescribedDistanceText?.trim().isNotEmpty == true);

  /// RPE chips follow authored capture or an explicit RPE load, not names.
  bool get requiresRpeCapture {
    if (performanceCapture?.rpe == true) return true;
    if (load?.type == StrengthLoadType.rpe) return true;
    final text = load?.text?.trim().toUpperCase();
    return load?.type == StrengthLoadType.freeText &&
        text != null &&
        text.startsWith('RPE');
  }

  StrengthExercisePrescription copyWith({
    int? sets,
    StrengthRepPrescription? reps,
    StrengthLoadPrescription? load,
    int? restSeconds,
    String? tempo,
    String? coachCue,
    bool? perSide,
    String? groupId,
    ExercisePerformanceCapture? performanceCapture,
    int? calories,
    double? prescribedDistanceMeters,
    String? prescribedDistanceText,
    bool clearLoad = false,
    bool clearRestSeconds = false,
    bool clearTempo = false,
    bool clearCoachCue = false,
    bool clearGroupId = false,
    bool clearPerformanceCapture = false,
  }) {
    return StrengthExercisePrescription(
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      load: clearLoad ? null : (load ?? this.load),
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      tempo: clearTempo ? null : (tempo ?? this.tempo),
      coachCue: clearCoachCue ? null : (coachCue ?? this.coachCue),
      perSide: perSide ?? this.perSide,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      performanceCapture: clearPerformanceCapture
          ? null
          : (performanceCapture ?? this.performanceCapture),
      calories: calories ?? this.calories,
      prescribedDistanceMeters:
          prescribedDistanceMeters ?? this.prescribedDistanceMeters,
      prescribedDistanceText:
          prescribedDistanceText ?? this.prescribedDistanceText,
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
      if (perSide) 'per_side': true,
      if (_nonEmpty(groupId) != null) 'group_id': groupId!.trim(),
      if (performanceCapture != null)
        'performance_capture': performanceCapture!.toJson(),
      if (calories != null) 'calories': calories,
      if (prescribedDistanceMeters != null)
        'distance_m': prescribedDistanceMeters,
      if (prescribedDistanceText != null) 'distance_m': prescribedDistanceText,
    };
  }

  factory StrengthExercisePrescription.fromJson(Map<String, dynamic> json) {
    final distance = _decodeDistance(json['distance_m'] ?? json['distance']);
    var capture = _captureFromJson(json['performance_capture']);
    if (capture == null &&
        (distance.meters != null ||
            (distance.text?.trim().isNotEmpty == true))) {
      capture = ExercisePerformanceCapture(
        distanceUnit: 'm',
        loadLabel: json['load'] == null ? null : 'Load per hand',
      );
    }
    return StrengthExercisePrescription(
      sets: _parseInt(json['sets']) ?? 0,
      reps: _decodeReps(json['reps']),
      load: _decodeLoad(json['load']),
      restSeconds: _parseInt(json['rest_seconds']),
      tempo: json['tempo']?.toString(),
      coachCue: json['coach_cue']?.toString(),
      perSide: json['per_side'] == true,
      groupId: json['group_id']?.toString(),
      performanceCapture: capture,
      calories: _parseInt(json['calories']),
      prescribedDistanceMeters: distance.meters,
      prescribedDistanceText: distance.text,
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

  /// Supports both the typed editor contract and the compact persisted
  /// prescription form used by existing authored protocols.
  static StrengthRepPrescription _decodeReps(dynamic value) {
    if (value == null) {
      return StrengthRepPrescription.fromJson(const {});
    }

    final object = _decodeJsonObject(value, field: 'reps');
    if (object != null) return StrengthRepPrescription.fromJson(object);

    if (value is num) {
      final exact = value.toInt();
      if (value != exact || exact <= 0) {
        throw FormatException('Invalid numeric reps value: $value');
      }
      return StrengthRepPrescription.exact(exact);
    }

    if (value is String) {
      final text = value.trim();
      if (_compactRepText.hasMatch(text)) {
        return StrengthRepPrescription(
          type: StrengthRepType.freeText,
          text: text,
        );
      }
      throw FormatException('Invalid compact reps text: $value');
    }

    throw FormatException('reps must be an object, number, or compact text.');
  }

  static StrengthLoadPrescription? _decodeLoad(dynamic value) {
    if (value == null) return null;

    final object = _decodeJsonObject(value, field: 'load');
    if (object != null) return StrengthLoadPrescription.fromJson(object);

    if (value is num && value > 0) {
      return StrengthLoadPrescription(
        type: StrengthLoadType.fixedKg,
        kg: value.toDouble(),
      );
    }

    if (value is String) {
      final text = value.trim();
      if (_compactLoadText.hasMatch(text)) {
        return StrengthLoadPrescription(
          type: StrengthLoadType.freeText,
          text: text,
        );
      }
      throw FormatException('Invalid compact load text: $value');
    }

    throw FormatException('load must be an object, positive number, or text.');
  }

  /// A JSON-encoded object is accepted only where a transport has stringified
  /// the documented object representation. JSON arrays and scalars remain
  /// invalid; ordinary compact text is handled by its field-specific decoder.
  static Map<String, dynamic>? _decodeJsonObject(
    dynamic value, {
    required String field,
  }) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is! String) return null;

    final text = value.trim();
    if (text.isEmpty) {
      throw FormatException('$field must not be empty.');
    }
    if (!text.startsWith('{') && !text.startsWith('[')) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON object for $field: ${error.message}');
    }
    if (decoded is! Map) {
      throw FormatException('$field JSON value must be an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static final RegExp _compactRepText = RegExp(
    r'^\d+(?:\s*-\s*\d+)?(?:\s+steps/leg|/(?:side|leg))?$',
  );

  static final RegExp _compactLoadText = RegExp(r'^[a-z][a-z0-9_-]{0,79}$');

  static ({double? meters, String? text}) _decodeDistance(dynamic value) {
    if (value == null) return (meters: null, text: null);
    if (value is num) return (meters: value.toDouble(), text: null);
    final text = value.toString().trim();
    if (text.isEmpty) return (meters: null, text: null);
    final exact = double.tryParse(text);
    if (exact != null) return (meters: exact, text: null);
    return (meters: null, text: text);
  }

  static ExercisePerformanceCapture? _captureFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return ExercisePerformanceCapture.fromJson(value);
    }
    if (value is Map) {
      return ExercisePerformanceCapture.fromJson(
        Map<String, dynamic>.from(value),
      );
    }
    return null;
  }
}

/// Optional authored metadata describing which athlete actuals an exercise
/// collects. Targets remain in the prescription and are never seeded here.
class ExercisePerformanceCapture {
  const ExercisePerformanceCapture({
    this.loadUnit,
    this.loadLabel,
    this.distanceUnit,
    this.durationOptional = false,
    this.rpe = false,
  });

  final String? loadUnit;
  final String? loadLabel;
  final String? distanceUnit;
  final bool durationOptional;
  final bool rpe;

  Map<String, dynamic> toJson() => {
    if (loadUnit?.trim().isNotEmpty == true) 'load_unit': loadUnit!.trim(),
    if (loadLabel?.trim().isNotEmpty == true) 'load_label': loadLabel!.trim(),
    if (distanceUnit?.trim().isNotEmpty == true)
      'distance_unit': distanceUnit!.trim(),
    if (rpe) 'rpe': true,
    'duration_optional': durationOptional,
  };

  factory ExercisePerformanceCapture.fromJson(Map<String, dynamic> json) {
    return ExercisePerformanceCapture(
      loadUnit: json['load_unit']?.toString(),
      loadLabel: json['load_label']?.toString(),
      distanceUnit: json['distance_unit']?.toString(),
      durationOptional: json['duration_optional'] == true,
      rpe: json['rpe'] == true,
    );
  }
}

enum StrengthRepType { exact, range, duration, distance, maxEffort, freeText }

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
      minReps != null &&
          maxReps != null &&
          minReps! > 0 &&
          maxReps! >= minReps!,
    StrengthRepType.duration ||
    StrengthRepType.distance ||
    StrengthRepType.maxEffort ||
    StrengthRepType.freeText => text?.trim().isNotEmpty == true,
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
      StrengthRepType.exact when exactReps == null || exactReps! <= 0 => const [
        'exact reps must be at least 1.',
      ],
      StrengthRepType.range
          when minReps == null ||
              maxReps == null ||
              minReps! <= 0 ||
              maxReps! < minReps! =>
        const ['rep range must have a valid min and max.'],
      StrengthRepType.duration ||
      StrengthRepType.distance ||
      StrengthRepType.maxEffort ||
      StrengthRepType.freeText when text?.trim().isEmpty != false => const [
        'reps description is required.',
      ],
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
      StrengthRepType.freeText => text?.trim() ?? '',
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
      StrengthLoadType.fixedKg when kg == null || kg! <= 0 => const [
        'load in kg must be greater than 0.',
      ],
      StrengthLoadType.percent1rm when percent1rm == null || percent1rm! <= 0 =>
        const ['1RM percentage must be greater than 0.'],
      StrengthLoadType.rpe when rpe == null || rpe! <= 0 => const [
        'RPE must be greater than 0.',
      ],
      StrengthLoadType.rir when rir == null || rir! < 0 => const [
        'RIR must be zero or greater.',
      ],
      StrengthLoadType.freeText when text?.trim().isEmpty != false => const [
        'load description is required.',
      ],
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
