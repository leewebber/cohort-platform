class Protocol {
  final String protocolId;
  final String name;
  final String? goal;
  final String? equipment;
  final int? durationMin;
  final String? capability;
  final String? demand;
  final String? recovery;
  final String? description;
  final String? mainSession;
  final String? trainingQuality;
  final String? sessionType;
  final String? environment;
  final String? suitableFor;

  const Protocol({
    required this.protocolId,
    required this.name,
    this.goal,
    this.equipment,
    this.durationMin,
    this.capability,
    this.demand,
    this.recovery,
    this.description,
    this.mainSession,
    this.trainingQuality,
    this.sessionType,
    this.environment,
    this.suitableFor,
  });

  factory Protocol.fromMap(Map<String, dynamic> map) {
    return Protocol(
      protocolId: map['protocol_id'] ?? '',
      name: map['name'] ?? '',
      goal: map['primary_capability'],
      equipment: map['equipment'],
      durationMin: map['duration_min'],
      capability: map['body_focus'],
      demand: map['physiological_demand'],
      recovery: map['recovery_cost'],
      description: map['purpose'],
      mainSession: map['main_session'] ?? map['original_workout'],
      trainingQuality: map['training_quality'],
      sessionType: map['session_type'],
      environment: map['environment'],
      suitableFor: map['suitable_for'],
    );
  }
}