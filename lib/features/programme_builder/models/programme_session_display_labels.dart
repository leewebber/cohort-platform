/// Shared session display label rules for athlete-facing previews.
///
/// Mirrors Home title precedence without importing Home feature code.
/// See `44_Programme_Builder.md` §10 and `home_today_session_loader.dart`.
class ProgrammeSessionDisplayLabels {
  const ProgrammeSessionDisplayLabels._();

  static String canonicalSessionTitle({
    required String protocolName,
  }) {
    return protocolName;
  }

  static String? slotContextLabel({
    required String? slotDisplayTitle,
    required String protocolName,
  }) {
    final slotTitle = slotDisplayTitle?.trim();
    if (slotTitle == null || slotTitle.isEmpty) {
      return null;
    }

    if (slotTitle.toLowerCase() == protocolName.trim().toLowerCase()) {
      return null;
    }

    return slotTitle;
  }

  static String slotRequirementLabel({required bool isOptional}) {
    return isOptional ? 'Optional session' : 'Required session';
  }

  static String executableSubtitle({
    required bool isOptional,
    required String protocolName,
    String? slotDisplayTitle,
  }) {
    final parts = <String>[slotRequirementLabel(isOptional: isOptional)];

    final context = slotContextLabel(
      slotDisplayTitle: slotDisplayTitle,
      protocolName: protocolName,
    );
    if (context != null) {
      parts.add(context);
    }

    return parts.join(' • ');
  }

  static String dayLabel({
    String? dayTitle,
    required String dayKey,
  }) {
    final title = dayTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }

    final match = RegExp(r'day_(\d+)').firstMatch(dayKey);
    if (match != null) {
      return 'Day ${match.group(1)}';
    }

    return dayKey;
  }

  static String weekLabel({
    required String programmeName,
    required int weekNumber,
    required String dayKey,
    String? dayTitle,
  }) {
    final parts = <String>[programmeName, 'Week $weekNumber'];

    final day = dayLabel(dayTitle: dayTitle, dayKey: dayKey);
    if (day.isNotEmpty) {
      parts.add(day);
    }

    return parts.join(' • ');
  }

  static const athletePreviewStatus = 'Planned Session';
}
