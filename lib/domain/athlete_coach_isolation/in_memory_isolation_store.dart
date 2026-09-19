import 'isolation_models.dart';
import 'isolation_store.dart';

class InMemoryIsolationMembershipStore implements IsolationMembershipStore {
  final rows = <String, TenantAthleteMembership>{};

  @override
  TenantAthleteMembership? membership(String id) => rows[id];

  @override
  Iterable<TenantAthleteMembership> activeForPublisher(String publisherId) {
    return rows.values.where(
      (row) => row.isActive && row.publisherId == publisherId,
    );
  }

  @override
  TenantAthleteMembership? activeForAthlete(String athleteId) {
    for (final row in rows.values) {
      if (row.isActive && row.athleteId == athleteId) {
        return row;
      }
    }
    return null;
  }

  @override
  void put(TenantAthleteMembership membership) {
    rows[membership.id] = membership;
  }
}
