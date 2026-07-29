import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import '../models/athlete_profile.dart';
import '../../plans/models/plan.dart';
import '../../plans/models/plan_assignment.dart';

/// In-memory athlete coaching context (profile + plan assignment + today's session).
class AthleteProfileSession {
  AthleteProfileSession._();

  static AthleteProfile? _profile;
  static AthleteGeneratedProgramme? _programme;
  static Plan? _activePlan;
  static PlanAssignment? _assignment;

  static AthleteProfile? get profile => _profile;
  static AthleteGeneratedProgramme? get programme => _programme;
  static Plan? get activePlan => _activePlan;
  static PlanAssignment? get activeAssignment => _assignment;

  static bool get hasActivePlan =>
      _assignment != null &&
      _assignment!.isActive &&
      _activePlan != null &&
      _programme != null;

  /// True when athlete has profile + generated session (with or without plan).
  static bool get hasCompletedOnboarding =>
      _profile != null && _programme != null;

  static void bind({
    required AthleteProfile profile,
    AthleteGeneratedProgramme? programme,
    Plan? activePlan,
    PlanAssignment? assignment,
  }) {
    _profile = profile;
    _programme = programme;
    _activePlan = activePlan;
    _assignment = assignment;
  }

  static void updateProgramme(AthleteGeneratedProgramme programme) {
    _programme = programme;
  }

  static void clear() {
    _profile = null;
    _programme = null;
    _activePlan = null;
    _assignment = null;
  }

  static Map<String, dynamic>? toPersistenceMap() {
    final profile = _profile;
    if (profile == null) return null;
    return {
      'profile': profile.toPersistenceMap(),
      'programmeSessionId': _programme?.planBundle.plan.sessionId,
      'orchestrationId':
          _programme?.planBundle.planningContext.orchestrationId,
      'activePlanId': _activePlan?.planId,
      'assignment': _assignment?.toPersistenceMap(),
    };
  }
}

/// Coach Brain output bound after plan assignment / generation.
class AthleteGeneratedProgramme {
  const AthleteGeneratedProgramme({
    required this.planBundle,
    required this.programmeName,
    required this.phaseLabel,
  });

  final CoachBrainWorkoutPlan planBundle;
  final String programmeName;
  final String phaseLabel;

  String get sessionTitle => planBundle.brief.sessionName;
  int? get durationMinutes => planBundle.brief.estimatedDurationMinutes;
  String get goalLabel =>
      AthleteProfileSession.activePlan?.goalLabel ??
      AthleteProfileSession.profile?.planningGoalLabel ??
      planBundle.brief.trainingIntent ??
      'Training';
}
