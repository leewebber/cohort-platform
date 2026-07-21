import 'package:flutter/foundation.dart';

import '../../programme/models/programme_catalog_entry.dart';
import '../models/coach_athlete_operation_result.dart';
import '../models/coach_athlete_roster_entry.dart';
import '../services/coach_athlete_service.dart';

enum JoinCoachStatus {
  idle,
  submitting,
  success,
  error,
}

class JoinCoachController extends ChangeNotifier {
  JoinCoachController({required CoachAthleteService service}) : _service = service;

  final CoachAthleteService _service;

  JoinCoachStatus status = JoinCoachStatus.idle;
  String? errorMessage;
  String? coachDisplayName;
  bool hasActiveCoach = false;

  Future<void> checkExistingRelationship() async {
    final result = await _service.getActiveCoachForAthlete();
    hasActiveCoach = result.value != null;
    notifyListeners();
  }

  Future<bool> acceptInvite(String code) async {
    status = JoinCoachStatus.submitting;
    errorMessage = null;
    notifyListeners();

    final result = await _service.acceptInvite(code.trim());
    if (!result.isSuccess) {
      status = JoinCoachStatus.error;
      errorMessage = result.message ?? 'Unable to join coach.';
      notifyListeners();
      return false;
    }

    coachDisplayName = result.value?.coachDisplayName;
    hasActiveCoach = true;
    status = JoinCoachStatus.success;
    notifyListeners();
    return true;
  }

  void reset() {
    status = JoinCoachStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
}

enum AthleteDetailStatus {
  loading,
  ready,
  error,
}

class AthleteDetailController extends ChangeNotifier {
  AthleteDetailController({
    required CoachAthleteService service,
    required CoachAthleteRosterEntry athlete,
  })  : _service = service,
        athlete = athlete;

  final CoachAthleteService _service;
  final CoachAthleteRosterEntry athlete;

  AthleteDetailStatus status = AthleteDetailStatus.loading;
  String? errorMessage;
  String? activeProgrammeName;
  String? activeProgrammeVersionLabel;
  bool hasActiveAssignment = false;
  List<ProgrammeCatalogEntry> publishedProgrammes = const [];
  bool isAssigning = false;
  String? assignmentSuccessMessage;

  Future<void> load() async {
    status = AthleteDetailStatus.loading;
    errorMessage = null;
    notifyListeners();

    final assignmentResult =
        await _service.getAthleteAssignment(athlete.athleteId);
    if (!assignmentResult.isSuccess &&
        assignmentResult.status != CoachAthleteOperationStatus.failed) {
      status = AthleteDetailStatus.error;
      errorMessage = assignmentResult.message;
      notifyListeners();
      return;
    }

    final assignment = assignmentResult.value;
    hasActiveAssignment = assignment != null;
    activeProgrammeName = athlete.activeProgrammeName;
    activeProgrammeVersionLabel = athlete.activeProgrammeVersionLabel;

    final catalogueResult = await _service.listPublishedProgrammes();
    publishedProgrammes = catalogueResult.value ?? const [];

    status = AthleteDetailStatus.ready;
    notifyListeners();
  }

  Future<bool> assignProgramme({
    required ProgrammeCatalogEntry entry,
    required DateTime startDate,
    required String timezone,
    bool replaceExisting = false,
  }) async {
    isAssigning = true;
    assignmentSuccessMessage = null;
    errorMessage = null;
    notifyListeners();

    final result = await _service.assignProgrammeToAthlete(
      athleteId: athlete.athleteId,
      programmeVersionId: entry.versionId,
      startedAt: startDate,
      timezone: timezone,
      replaceExistingActive: replaceExisting,
    );

    isAssigning = false;

    if (!result.isSuccess) {
      errorMessage = result.message;
      notifyListeners();
      return false;
    }

    assignmentSuccessMessage =
        '${entry.name} assigned to ${athlete.displayName}.';
    await load();
    return true;
  }
}
