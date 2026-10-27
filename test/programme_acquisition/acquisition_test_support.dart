import 'dart:async';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';

void bindAcquisitionActor([String id = 'athlete-a']) => CurrentUserSession.bind(
  UserProfile(
    id: id,
    displayName: 'Test athlete',
    isCoach: false,
    isAthlete: true,
  ),
);

class FakeAcquisitionStore implements AcquisitionStore {
  TrainingSetup setup = const TrainingSetup();
  List<PrivateProgrammeOffer> offers = const [
    PrivateProgrammeOffer(
      versionId: 'private-v1',
      title: '[TEST ONLY] Private programme',
      ready: true,
      durationWeeks: 2,
      sessionsPerWeek: 3,
      equipment: 'Dumbbells',
    ),
  ];
  int acquisitions = 0;
  int saves = 0;
  String? failure;
  Completer<List<PrivateProgrammeOffer>>? pendingList;
  Completer<String>? pendingAcquisition;
  @override
  Future<TrainingSetup> loadSetup() async {
    if (failure != null) throw AcquisitionException(failure!);
    return setup;
  }

  @override
  Future<TrainingSetup> saveSetup(
    String timezone, {
    required bool complete,
  }) async {
    saves++;
    if (failure != null) throw AcquisitionException(failure!);
    return setup = TrainingSetup(timezone: timezone, complete: complete);
  }

  @override
  Future<List<PrivateProgrammeOffer>> catalogue({String? versionId}) async {
    if (failure != null) throw AcquisitionException(failure!);
    return pendingList?.future ??
        offers
            .where((o) => versionId == null || o.versionId == versionId)
            .toList();
  }

  @override
  Future<String> acquire(String versionId, DateTime date) async {
    acquisitions++;
    if (failure != null) throw AcquisitionException(failure!);
    return pendingAcquisition?.future ?? 'assignment-exact';
  }
}
