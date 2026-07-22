import 'package:flutter/foundation.dart';

import '../../adaptation/models/programme_adaptation_event.dart';
import '../../adaptation/services/adaptation_prescription_service.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/repositories/performance_record_store.dart';
import '../../performance/repositories/supabase_performance_record_store.dart';
import '../../programme/models/programme_catalog_entry.dart';
import '../models/coach_athlete_operation_result.dart';
import '../models/coach_athlete_roster_entry.dart';
import '../services/coach_athlete_service.dart';
import '../../coach_operations/models/coach_athlete_daily_snapshot.dart';
import '../../coach_operations/services/coach_athlete_daily_status_service.dart';

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
    CoachAthleteDailyStatusService? dailyStatusService,
    PerformanceRecordStore? performanceRecordStore,
  })  : _service = service,
        athlete = athlete,
        _dailyStatusService = dailyStatusService,
        _performanceRecordStore =
            performanceRecordStore ?? SupabasePerformanceRecordStore();

  final CoachAthleteService _service;
  final CoachAthleteRosterEntry athlete;
  final CoachAthleteDailyStatusService? _dailyStatusService;
  final PerformanceRecordStore _performanceRecordStore;

  AthleteDetailStatus status = AthleteDetailStatus.loading;
  String? errorMessage;
  String? activeProgrammeName;
  String? activeProgrammeVersionLabel;
  bool hasActiveAssignment = false;
  List<ProgrammeCatalogEntry> publishedProgrammes = const [];
  bool isAssigning = false;
  String? assignmentSuccessMessage;
  ProgrammeAdaptationEvent? latestAdaptation;
  CoachAthleteDailySnapshot? operationalSnapshot;
  List<TrainingSessionRecord> recentSessions = const [];

  final AdaptationPrescriptionService _adaptationPrescriptionService =
      AdaptationPrescriptionService();

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

    if (assignment != null) {
      latestAdaptation = await _adaptationPrescriptionService
          .getLatestForAssignment(assignment.id);
    } else {
      latestAdaptation = null;
    }

    final catalogueResult = await _service.listPublishedProgrammes();
    publishedProgrammes = catalogueResult.value ?? const [];

    final dailyStatusService = _dailyStatusService;
    if (dailyStatusService != null) {
      try {
        operationalSnapshot =
            await dailyStatusService.loadSnapshotForAthlete(athlete.athleteId);
      } on CoachAthleteDailyStatusException catch (error) {
        errorMessage = error.message;
      }
    }

    recentSessions = await _performanceRecordStore.listHistory(
      athleteId: athlete.athleteId,
      limit: 5,
    );

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
