import 'dart:convert';

class ProtocolStep {
  final int id;
  final String protocolId;
  final int stepOrder;
  final String section;
  final String stepType;
  final String displayStyle;
  final String? exerciseId;
  final String title;
  final String? notes;
  final Map<String, dynamic> metadata;

  const ProtocolStep({
    required this.id,
    required this.protocolId,
    required this.stepOrder,
    required this.section,
    required this.stepType,
    required this.displayStyle,
    required this.title,
    required this.metadata,
    this.exerciseId,
    this.notes,
  });

  factory ProtocolStep.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> metadata = {};

    final value = map['metadata'];

    if (value is Map<String, dynamic>) {
      metadata = value;
    } else if (value is String && value.isNotEmpty) {
      metadata = Map<String, dynamic>.from(jsonDecode(value));
    }

    return ProtocolStep(
      id: map['id'],
      protocolId: map['protocol_id'],
      stepOrder: map['step_order'],
      section: map['section'] ?? '',
      stepType: map['step_type'] ?? '',
      displayStyle: map['display_style'] ?? 'exercise',
      exerciseId: map['exercise_id'],
      title: map['title'] ?? '',
      notes: map['notes'],
      metadata: metadata,
    );
  }

  String? get reps => metadata['reps']?.toString();

  String? get sets => metadata['sets']?.toString();

  String? get distance => metadata['distance']?.toString();

  String? get duration => metadata['duration']?.toString();

  String? get rest => metadata['rest']?.toString();

  String? get tempo => metadata['tempo']?.toString();

  String? get load => metadata['load']?.toString();
}