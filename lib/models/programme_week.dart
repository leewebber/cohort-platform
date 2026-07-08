class ProgrammeWeek {
  final int id;
  final String programmeId;
  final int weekNumber;
  final String title;

  const ProgrammeWeek({
    required this.id,
    required this.programmeId,
    required this.weekNumber,
    required this.title,
  });

  factory ProgrammeWeek.fromMap(
    Map<String, dynamic> map,
  ) {
    return ProgrammeWeek(
      id: map['id'],
      programmeId: map['programme_id'],
      weekNumber: map['week_number'],
      title: map['title'] ?? '',
    );
  }
}