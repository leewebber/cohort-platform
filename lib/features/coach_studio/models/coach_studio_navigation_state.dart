import 'coach_studio_section.dart';

/// Client-only Coach Studio navigation memory for the current app session.
///
/// Not persisted to Supabase. Not a business-service concern.
class CoachStudioNavigationState {
  CoachStudioNavigationState._();

  static final CoachStudioNavigationState instance =
      CoachStudioNavigationState._();

  CoachStudioSection? lastSection;
  CoachStudioSection? currentSection;

  void rememberSection(CoachStudioSection section) {
    currentSection = section;
    lastSection = section;
  }

  void clearCurrentSection() {
    currentSection = null;
  }

  bool get shouldOpenProgrammesDirectly =>
      lastSection == CoachStudioSection.programmes;
}
