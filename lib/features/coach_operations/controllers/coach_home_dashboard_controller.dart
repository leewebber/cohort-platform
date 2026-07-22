import 'package:flutter/foundation.dart';

import '../models/coach_athlete_daily_snapshot.dart';
import '../services/coach_athlete_daily_status_service.dart';

enum CoachHomeDashboardStatus {
  loading,
  ready,
  empty,
  coachRoleRequired,
  error,
}

class CoachHomeDashboardController extends ChangeNotifier {
  CoachHomeDashboardController({
    required CoachAthleteDailyStatusService dailyStatusService,
  }) : _dailyStatusService = dailyStatusService;

  final CoachAthleteDailyStatusService _dailyStatusService;

  CoachHomeDashboardStatus status = CoachHomeDashboardStatus.loading;
  String? errorMessage;
  List<CoachAthleteDailySnapshot> snapshots = const [];
  CoachDashboardFilter activeFilter = CoachDashboardFilter.all;

  List<CoachAthleteDailySnapshot> get filteredSnapshots {
    return snapshots
        .where((snapshot) => snapshot.matchesFilter(activeFilter))
        .toList(growable: false);
  }

  Future<void> load() async {
    status = CoachHomeDashboardStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _dailyStatusService.loadDashboardSnapshots();
      snapshots = loaded;
      status = loaded.isEmpty
          ? CoachHomeDashboardStatus.empty
          : CoachHomeDashboardStatus.ready;
    } on CoachAthleteDailyStatusException catch (error) {
      status = error.coachRoleRequired
          ? CoachHomeDashboardStatus.coachRoleRequired
          : CoachHomeDashboardStatus.error;
      errorMessage = error.message;
    } catch (error) {
      status = CoachHomeDashboardStatus.error;
      errorMessage = error.toString();
    }

    notifyListeners();
  }

  void setFilter(CoachDashboardFilter filter) {
    activeFilter = filter;
    notifyListeners();
  }
}
