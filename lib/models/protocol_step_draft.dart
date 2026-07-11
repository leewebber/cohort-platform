import 'protocol_step.dart';

/// Editable in-memory representation of a single protocol step before save.
///
/// Prescription fields map into `protocol_steps.metadata` JSON on save.
/// See `07 Documentation/34_Protocol_Builder.md`.
class ProtocolStepDraft {
  const ProtocolStepDraft({
    required this.localId,
    required this.stepOrder,
    required this.title,
    this.persistedId,
    this.section,
    this.stepType,
    this.displayStyle,
    this.exerciseId,
    this.notes,
    this.sets,
    this.reps,
    this.distance,
    this.duration,
    this.rest,
    this.tempo,
    this.load,
  });

  /// Client-generated identity stable for the editing session.
  final String localId;

  /// Supabase `protocol_steps.id` when editing an existing row.
  final int? persistedId;

  final int stepOrder;
  final String? section;
  final String? stepType;
  final String? displayStyle;
  final String? exerciseId;
  final String title;
  final String? notes;
  final String? sets;
  final String? reps;
  final String? distance;
  final String? duration;
  final String? rest;
  final String? tempo;
  final String? load;

  factory ProtocolStepDraft.fromProtocolStep(ProtocolStep step) {
    return ProtocolStepDraft(
      localId: 'step-${step.id}',
      persistedId: step.id,
      stepOrder: step.stepOrder,
      section: step.section,
      stepType: step.stepType,
      displayStyle: step.displayStyle,
      exerciseId: step.exerciseId,
      title: step.title,
      notes: step.notes,
      sets: step.sets,
      reps: step.reps,
      distance: step.distance,
      duration: step.duration,
      rest: step.rest,
      tempo: step.tempo,
      load: step.load,
    );
  }

  ProtocolStepDraft copyWith({
    String? localId,
    int? persistedId,
    int? stepOrder,
    String? section,
    String? stepType,
    String? displayStyle,
    String? exerciseId,
    String? title,
    String? notes,
    String? sets,
    String? reps,
    String? distance,
    String? duration,
    String? rest,
    String? tempo,
    String? load,
  }) {
    return ProtocolStepDraft(
      localId: localId ?? this.localId,
      persistedId: persistedId ?? this.persistedId,
      stepOrder: stepOrder ?? this.stepOrder,
      section: section ?? this.section,
      stepType: stepType ?? this.stepType,
      displayStyle: displayStyle ?? this.displayStyle,
      exerciseId: exerciseId ?? this.exerciseId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      rest: rest ?? this.rest,
      tempo: tempo ?? this.tempo,
      load: load ?? this.load,
    );
  }

  /// Maps coach-friendly prescription fields to `protocol_steps.metadata`.
  Map<String, dynamic> toMetadataMap() {
    final metadata = <String, dynamic>{};

    _putIfPresent(metadata, 'sets', sets);
    _putIfPresent(metadata, 'reps', reps);
    _putIfPresent(metadata, 'distance', distance);
    _putIfPresent(metadata, 'duration', duration);
    _putIfPresent(metadata, 'rest', rest);
    _putIfPresent(metadata, 'tempo', tempo);
    _putIfPresent(metadata, 'load', load);

    return metadata;
  }

  /// Maps step fields to `protocol_steps` columns (excluding auto-generated id).
  Map<String, dynamic> toStepMap({required String protocolId}) {
    return {
      if (persistedId != null) 'id': persistedId,
      'protocol_id': protocolId,
      'step_order': stepOrder,
      'section': section ?? '',
      'step_type': stepType ?? '',
      'display_style': displayStyle ?? 'exercise',
      'exercise_id': _nullableString(exerciseId),
      'title': title,
      'notes': _nullableString(notes),
      'metadata': toMetadataMap(),
    };
  }

  static void _putIfPresent(
    Map<String, dynamic> target,
    String key,
    String? value,
  ) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }

    target[key] = trimmed;
  }

  static String? _nullableString(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
