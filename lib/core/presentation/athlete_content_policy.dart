import '../access/app_role_access.dart';

/// Filters coach-only or external authoring content from athlete-facing surfaces.
class AthleteContentPolicy {
  AthleteContentPolicy._();

  static bool get showExerciseUsagePanel =>
      AppRoleAccess.canAccessCoachOperations;

  static bool get showExerciseProgrammingSection =>
      AppRoleAccess.canAccessCoachOperations;

  static bool get showExerciseScalingSection =>
      AppRoleAccess.canAccessCoachOperations;

  static String? visibleMetadata(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (AppRoleAccess.canAccessCoachOperations) return value.trim();
    if (_looksLikeExternalAuthoringLink(value)) return null;
    return value.trim();
  }

  static Map<String, String?> visibleAttributes(
    Map<String, String?> attributes,
  ) {
    final visible = <String, String?>{};
    for (final entry in attributes.entries) {
      final sanitized = visibleMetadata(entry.value);
      if (sanitized != null && sanitized.isNotEmpty) {
        visible[entry.key] = sanitized;
      }
    }
    return visible;
  }

  static bool _looksLikeExternalAuthoringLink(String value) {
    final lower = value.toLowerCase().trim();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.contains('notion.so') ||
        lower.contains('notion.site');
  }
}
