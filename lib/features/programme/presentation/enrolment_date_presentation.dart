/// Athlete-facing civil dates. ISO remains the persisted/internal form.
abstract final class EnrolmentDatePresentation {
  static const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String athleteFacing(DateTime date) {
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String? fromIso(String? iso) {
    final value = iso?.trim() ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return athleteFacing(DateTime(parsed.year, parsed.month, parsed.day));
  }
}
