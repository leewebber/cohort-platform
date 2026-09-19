import 'package:cohort_platform/domain/athlete_coach_isolation/consent_models.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/consent_store.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/isolation_models.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/publisher_athlete_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryConsentStore store;
  late FixedConsentClock clock;
  late PublisherAthleteConsentService service;

  const publisher = IsolationActor(
    principalId: 'principal.pub-a',
    publisherId: 'publisher.a',
    capability: IsolationCapability.publisher,
  );
  const otherPublisher = IsolationActor(
    principalId: 'principal.pub-b',
    publisherId: 'publisher.b',
    capability: IsolationCapability.publisher,
  );
  const athlete = IsolationActor(
    principalId: 'athlete.one',
    publisherId: 'publisher.a',
    capability: IsolationCapability.reader,
  );
  const unauthorised = IsolationActor(
    principalId: 'principal.none',
    publisherId: 'publisher.a',
    capability: IsolationCapability.none,
  );

  setUp(() {
    store = InMemoryConsentStore();
    clock = FixedConsentClock(DateTime.utc(2026, 9, 19, 12));
    service = PublisherAthleteConsentService(
      store: store,
      clock: clock,
      knownAthletes: {'athlete.one', 'athlete.two'},
      activePublishers: {'publisher.a', 'publisher.b'},
      athleteDisplayNames: {'athlete.one': 'Fixture One'},
      pinsForAthlete: (id) {
        if (id != 'athlete.one') return null;
        return const PublisherProgrammePin(
          assignmentId: 'assignment.own',
          programmeVersionId: 'programme-version.a',
          publisherId: 'publisher.a',
          versionName: 'Alpha',
          compositeIdentity:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );
      },
    );
  });

  test('enrolment is not represented as membership', () {
    expect(store.memberships, isEmpty);
    expect(service.inspectRoster(publisher), isEmpty);
  });

  test('pending invite grants no roster row', () {
    final invited = service.invite(actor: publisher, athleteId: 'athlete.one');
    expect(invited.outcome, ConsentOutcome.invited);
    expect(service.inspectRoster(publisher), isEmpty);
  });

  test('accept then roster shows own pin; double accept is idempotent', () {
    final invited = service.invite(actor: publisher, athleteId: 'athlete.one');
    final first = service.accept(
      athlete: athlete,
      invitationId: invited.invitation!.id,
    );
    final second = service.accept(
      athlete: athlete,
      invitationId: invited.invitation!.id,
    );
    expect(first.outcome, ConsentOutcome.accepted);
    expect(second.outcome, ConsentOutcome.alreadyActive);
    expect(second.membership!.id, first.membership!.id);
    final roster = service.inspectRoster(publisher);
    expect(roster, hasLength(1));
    expect(roster.single.assignmentVisibility, AssignmentVisibility.own);
    expect(
      roster.single.graphCompositeIdentity,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
  });

  test('only the target athlete can accept', () {
    final invited = service.invite(actor: publisher, athleteId: 'athlete.one');
    final result = service.accept(
      athlete: const IsolationActor(
        principalId: 'athlete.two',
        publisherId: 'publisher.a',
        capability: IsolationCapability.reader,
      ),
      invitationId: invited.invitation!.id,
    );
    expect(result.outcome, ConsentOutcome.unauthorised);
    expect(service.inspectRoster(publisher), isEmpty);
  });

  test('cross-publisher roster is empty', () {
    final invited = service.invite(actor: publisher, athleteId: 'athlete.one');
    service.accept(athlete: athlete, invitationId: invited.invitation!.id);
    expect(service.inspectRoster(otherPublisher), isEmpty);
  });

  test('foreign assignment is hidden', () {
    service = PublisherAthleteConsentService(
      store: store,
      clock: clock,
      knownAthletes: {'athlete.one'},
      activePublishers: {'publisher.a', 'publisher.b'},
      pinsForAthlete: (_) => const PublisherProgrammePin(
        assignmentId: 'assignment.foreign',
        programmeVersionId: 'programme-version.b',
        publisherId: 'publisher.b',
      ),
    );
    final invited = service.invite(actor: publisher, athleteId: 'athlete.one');
    service.accept(athlete: athlete, invitationId: invited.invitation!.id);
    final row = service.inspectRoster(publisher).single;
    expect(row.assignmentVisibility, AssignmentVisibility.foreignHidden);
    expect(row.assignmentId, isNull);
    expect(row.graphCompositeIdentity, isNull);
  });

  test('decline and revoke are idempotent', () {
    final invited = service.invite(actor: publisher, athleteId: 'athlete.two');
    expect(
      service.decline(
        athlete: const IsolationActor(
          principalId: 'athlete.two',
          publisherId: 'publisher.a',
          capability: IsolationCapability.reader,
        ),
        invitationId: invited.invitation!.id,
      ).outcome,
      ConsentOutcome.declined,
    );
    expect(
      service.decline(
        athlete: const IsolationActor(
          principalId: 'athlete.two',
          publisherId: 'publisher.a',
          capability: IsolationCapability.reader,
        ),
        invitationId: invited.invitation!.id,
      ).outcome,
      ConsentOutcome.alreadyDeclined,
    );

    final invited2 = service.invite(actor: publisher, athleteId: 'athlete.one');
    final accepted = service.accept(
      athlete: athlete,
      invitationId: invited2.invitation!.id,
    );
    expect(
      service.revoke(actor: athlete, membershipId: accepted.membership!.id).outcome,
      ConsentOutcome.revoked,
    );
    expect(
      service.revoke(actor: athlete, membershipId: accepted.membership!.id).outcome,
      ConsentOutcome.alreadyRevoked,
    );
    expect(service.inspectRoster(publisher), isEmpty);
  });

  test('expired invitation cannot activate', () {
    final invited = service.invite(
      actor: publisher,
      athleteId: 'athlete.one',
      ttl: const Duration(hours: 1),
    );
    clock.advance(const Duration(hours: 2));
    expect(
      service.accept(
        athlete: athlete,
        invitationId: invited.invitation!.id,
      ).outcome,
      ConsentOutcome.expired,
    );
    expect(service.inspectRoster(publisher), isEmpty);
  });

  test('missing capability and display-name identity fail closed', () {
    expect(
      service.invite(actor: unauthorised, athleteId: 'athlete.one').outcome,
      ConsentOutcome.unauthorised,
    );
    expect(
      service.invite(actor: publisher, athleteId: 'unknown').outcome,
      ConsentOutcome.invalidTarget,
    );
  });

  test('audit is append-only and idempotent retries do not duplicate', () {
    final invited = service.invite(actor: publisher, athleteId: 'athlete.one');
    service.invite(actor: publisher, athleteId: 'athlete.one');
    expect(
      store.events.where((e) => e.transition == 'invitation_created'),
      hasLength(1),
    );
    service.accept(athlete: athlete, invitationId: invited.invitation!.id);
    service.accept(athlete: athlete, invitationId: invited.invitation!.id);
    expect(
      store.events.where((e) => e.transition == 'invitation_accepted'),
      hasLength(1),
    );
  });

  test('multiple publishers require separate consent', () {
    service.invite(actor: publisher, athleteId: 'athlete.one');
    final b = service.invite(actor: otherPublisher, athleteId: 'athlete.one');
    service.accept(
      athlete: const IsolationActor(
        principalId: 'athlete.one',
        publisherId: 'publisher.b',
        capability: IsolationCapability.reader,
      ),
      invitationId: b.invitation!.id,
    );
    expect(service.inspectRoster(publisher), isEmpty);
    expect(service.inspectRoster(otherPublisher), hasLength(1));
  });
}
