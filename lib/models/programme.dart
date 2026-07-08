class Programme {
  final int id;
  final String programmeId;
  final String name;
  final String? description;
  final String? goal;
  final String? level;
  final int durationWeeks;
  final bool published;

  const Programme({
    required this.id,
    required this.programmeId,
    required this.name,
    required this.durationWeeks,
    required this.published,
    this.description,
    this.goal,
    this.level,
  });

  factory Programme.fromMap(Map<String, dynamic> map) {
    return Programme(
      id: map['id'],
      programmeId: map['programme_id'],
      name: map['name'],
      description: map['description'],
      goal: map['goal'],
      level: map['level'],
      durationWeeks: map['duration_weeks'] ?? 0,
      published: map['published'] ?? false,
    );
  }
}