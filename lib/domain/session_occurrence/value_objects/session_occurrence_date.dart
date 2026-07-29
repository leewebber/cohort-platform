/// Calendar date for programme scheduling (timezone-neutral domain value).
class SessionOccurrenceDate {
  const SessionOccurrenceDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  factory SessionOccurrenceDate.fromDateTime(DateTime dateTime) {
    return SessionOccurrenceDate(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionOccurrenceDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
