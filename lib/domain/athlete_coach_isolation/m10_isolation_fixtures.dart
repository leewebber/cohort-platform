import '../content_graph/content_graph_service.dart';
import '../content_graph/in_memory_content_graph_store.dart';
import '../content_graph/m9_content_graph_fixtures.dart';
import 'in_memory_isolation_store.dart';
import 'isolation_models.dart';
import 'publisher_athlete_isolation_service.dart';

/// Deterministic M10 fixtures. Not Field Manual. Not production.
class M10IsolationFixtures {
  static const firstPartyPublisherId = 'publisher.cohort-global';
  static const acmePublisherId = 'publisher.acme-coach';
  static const missingPublisherId = 'publisher.unknown';

  static const firstPartyPrincipalId = 'principal.fixture-owner';
  static const acmePrincipalId = 'principal.fixture-acme';
  static const readerPrincipalId = 'principal.fixture-reader';

  static const pinnedAthleteId = 'athlete.fixture-existing';
  static const unassignedAthleteId = 'athlete.fixture-unassigned';
  static const foreignAthleteId = 'athlete.fixture-acme';

  static const firstParty = IsolationActor(
    principalId: firstPartyPrincipalId,
    publisherId: firstPartyPublisherId,
    capability: IsolationCapability.publisher,
  );

  static const acme = IsolationActor(
    principalId: acmePrincipalId,
    publisherId: acmePublisherId,
    capability: IsolationCapability.publisher,
  );

  static const unauthorised = IsolationActor(
    principalId: readerPrincipalId,
    publisherId: firstPartyPublisherId,
    capability: IsolationCapability.none,
  );

  static const readerOnly = IsolationActor(
    principalId: readerPrincipalId,
    publisherId: firstPartyPublisherId,
    capability: IsolationCapability.reader,
  );

  static M10IsolationHarness seed({
    bool includePinnedMembership = true,
    bool includeAcmeMembership = true,
    String? staleComposite,
  }) {
    final graphStore = InMemoryContentGraphStore();
    final graph = M9ContentGraphFixtures.seed(store: graphStore);
    final memberships = InMemoryIsolationMembershipStore();
    final service = PublisherAthleteIsolationService(
      memberships: memberships,
      graphStore: graphStore,
      graph: graph,
    );

    if (includePinnedMembership) {
      final compiled = graph
          .compileDraft(M9ContentGraphFixtures.v1Id)
          .manifest
          .compositeContentIdentity;
      if (staleComposite == null) {
        service.activateMembership(
          actor: firstParty,
          athleteId: pinnedAthleteId,
          pinnedAssignmentId: M9ContentGraphFixtures.athleteAssignmentId,
          expectedGraphComposite: compiled,
        );
      } else {
        memberships.put(
          TenantAthleteMembership(
            id: membershipIdFor(
              publisherId: firstPartyPublisherId,
              athleteId: pinnedAthleteId,
            ),
            publisherId: firstPartyPublisherId,
            athleteId: pinnedAthleteId,
            coachPrincipalId: firstPartyPrincipalId,
            status: IsolationMembershipStatus.active,
            pinnedAssignmentId: M9ContentGraphFixtures.athleteAssignmentId,
            expectedGraphComposite: staleComposite,
          ),
        );
      }
    }
    if (includeAcmeMembership) {
      service.activateMembership(
        actor: acme,
        athleteId: foreignAthleteId,
      );
    }
    return M10IsolationHarness(
      graphStore: graphStore,
      graph: graph,
      memberships: memberships,
      service: service,
    );
  }
}

class M10IsolationHarness {
  const M10IsolationHarness({
    required this.graphStore,
    required this.graph,
    required this.memberships,
    required this.service,
  });

  final InMemoryContentGraphStore graphStore;
  final ContentGraphService graph;
  final InMemoryIsolationMembershipStore memberships;
  final PublisherAthleteIsolationService service;
}
