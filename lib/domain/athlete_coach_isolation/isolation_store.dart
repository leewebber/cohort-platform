import 'isolation_models.dart';

abstract class IsolationMembershipStore {
  TenantAthleteMembership? membership(String id);

  Iterable<TenantAthleteMembership> activeForPublisher(String publisherId);

  TenantAthleteMembership? activeForAthlete(String athleteId);

  void put(TenantAthleteMembership membership);
}
