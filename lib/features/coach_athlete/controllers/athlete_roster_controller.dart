import 'package:flutter/foundation.dart';

import '../models/coach_athlete_invite.dart';
import '../models/coach_athlete_operation_result.dart';
import '../models/coach_athlete_roster_entry.dart';
import '../services/coach_athlete_service.dart';

enum AthleteRosterStatus {
  loading,
  ready,
  empty,
  error,
  coachRoleRequired,
}

class AthleteRosterController extends ChangeNotifier {
  AthleteRosterController({required CoachAthleteService service})
      : _service = service;

  final CoachAthleteService _service;

  AthleteRosterStatus status = AthleteRosterStatus.loading;
  List<CoachAthleteRosterEntry> athletes = const [];
  List<CoachAthleteInvite> pendingInvites = const [];
  String? errorMessage;
  CoachAthleteInvite? latestInvite;
  bool isCreatingInvite = false;

  Future<void> load() async {
    status = AthleteRosterStatus.loading;
    errorMessage = null;
    notifyListeners();

    final rosterResult = await _service.listLinkedAthletes();
    if (!rosterResult.isSuccess) {
      status = rosterResult.status == CoachAthleteOperationStatus.coachRoleRequired
          ? AthleteRosterStatus.coachRoleRequired
          : AthleteRosterStatus.error;
      errorMessage = rosterResult.message;
      notifyListeners();
      return;
    }

    athletes = rosterResult.value ?? const [];
    final inviteResult = await _service.listPendingInvites();
    pendingInvites = inviteResult.value ?? const [];

    status = athletes.isEmpty
        ? AthleteRosterStatus.empty
        : AthleteRosterStatus.ready;
    notifyListeners();
  }

  Future<CoachAthleteInvite?> createInvite() async {
    isCreatingInvite = true;
    notifyListeners();

    final result = await _service.createInvite();
    isCreatingInvite = false;

    if (!result.isSuccess) {
      errorMessage = result.message;
      notifyListeners();
      return null;
    }

    latestInvite = result.value;
    await load();
    return latestInvite;
  }

  Future<bool> revokeInvite(String inviteId) async {
    final result = await _service.revokeInvite(inviteId);
    if (!result.isSuccess) {
      errorMessage = result.message;
      notifyListeners();
      return false;
    }

    await load();
    return true;
  }
}
