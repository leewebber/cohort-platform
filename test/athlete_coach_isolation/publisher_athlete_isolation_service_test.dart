import 'dart:io';

import 'package:cohort_platform/domain/athlete_coach_isolation/isolation_models.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/m10_isolation_fixtures.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_models.dart';
import 'package:cohort_platform/domain/content_graph/m9_content_graph_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical roster shows pinned athlete and M9 used-by', () {
    final harness = M10IsolationFixtures.seed();
    final compiled = harness.graph
        .compileDraft(M9ContentGraphFixtures.v1Id)
        .manifest
        .compositeContentIdentity;
    final roster = harness.service.inspectRoster(M10IsolationFixtures.firstParty);
    expect(roster.status, IsolationRosterStatus.ready);
    expect(roster.entries, hasLength(1));
    final entry = roster.entries.single;
    expect(entry.athleteId, M10IsolationFixtures.pinnedAthleteId);
    expect(entry.pinnedAssignmentId, M9ContentGraphFixtures.athleteAssignmentId);
    expect(entry.pinnedProgrammeVersionId, M9ContentGraphFixtures.v1Id);
    expect(entry.graphCompositeIdentity, compiled);
    expect(entry.usedByExerciseCount, greaterThan(0));
    expect(entry.staleDeclaredComposite, isFalse);
  });

  test('empty namespace is empty not an error', () {
    final harness = M10IsolationFixtures.seed(
      includePinnedMembership: false,
      includeAcmeMembership: false,
    );
    final roster = harness.service.inspectRoster(M10IsolationFixtures.firstParty);
    expect(roster.status, IsolationRosterStatus.empty);
    expect(roster.entries, isEmpty);
  });

  test('missing publisher is unavailable', () {
    final harness = M10IsolationFixtures.seed();
    final roster = harness.service.inspectRoster(
      const IsolationActor(
        principalId: 'principal.orphan',
        publisherId: M10IsolationFixtures.missingPublisherId,
        capability: IsolationCapability.reader,
      ),
    );
    expect(roster.status, IsolationRosterStatus.unavailable);
  });

  test('blank ids are invalid input', () {
    final harness = M10IsolationFixtures.seed();
    final roster = harness.service.inspectRoster(
      const IsolationActor(
        principalId: ' ',
        publisherId: M10IsolationFixtures.firstPartyPublisherId,
        capability: IsolationCapability.reader,
      ),
    );
    expect(roster.status, IsolationRosterStatus.invalidInput);
    final activate = harness.service.activateMembership(
      actor: M10IsolationFixtures.firstParty,
      athleteId: '',
    );
    expect(activate.status, IsolationActivateStatus.invalidInput);
  });

  test('unauthorised actor is denied', () {
    final harness = M10IsolationFixtures.seed();
    final roster = harness.service.inspectRoster(M10IsolationFixtures.unauthorised);
    expect(roster.status, IsolationRosterStatus.unauthorised);
    expect(roster.failureCode, 'capability_denied');
    final activate = harness.service.activateMembership(
      actor: M10IsolationFixtures.unauthorised,
      athleteId: M10IsolationFixtures.unassignedAthleteId,
    );
    expect(activate.status, IsolationActivateStatus.unauthorised);
  });

  test('reader cannot write', () {
    final harness = M10IsolationFixtures.seed();
    final activate = harness.service.activateMembership(
      actor: M10IsolationFixtures.readerOnly,
      athleteId: M10IsolationFixtures.unassignedAthleteId,
    );
    expect(activate.status, IsolationActivateStatus.unauthorised);
  });

  test('cross-publisher roster and athlete conflict', () {
    final harness = M10IsolationFixtures.seed();
    final acmeRoster = harness.service.inspectRoster(M10IsolationFixtures.acme);
    expect(acmeRoster.entries.map((e) => e.athleteId), [
      M10IsolationFixtures.foreignAthleteId,
    ]);
    expect(
      acmeRoster.entries.any(
        (e) => e.athleteId == M10IsolationFixtures.pinnedAthleteId,
      ),
      isFalse,
    );
    final conflict = harness.service.activateMembership(
      actor: M10IsolationFixtures.acme,
      athleteId: M10IsolationFixtures.pinnedAthleteId,
    );
    expect(conflict.status, IsolationActivateStatus.conflict);
    expect(conflict.failureCode, 'cross_publisher_athlete');
  });

  test('activate is idempotent for the same triple', () {
    final harness = M10IsolationFixtures.seed(includePinnedMembership: false);
    final first = harness.service.activateMembership(
      actor: M10IsolationFixtures.firstParty,
      athleteId: M10IsolationFixtures.unassignedAthleteId,
    );
    final second = harness.service.activateMembership(
      actor: M10IsolationFixtures.firstParty,
      athleteId: M10IsolationFixtures.unassignedAthleteId,
    );
    expect(first.status, IsolationActivateStatus.activated);
    expect(second.status, IsolationActivateStatus.alreadyActive);
    expect(second.membership!.id, first.membership!.id);
  });

  test('existing pin cannot be replaced', () {
    final harness = M10IsolationFixtures.seed();
    harness.graphStore.putAssignment(
      PinnedAssignment(
        id: 'assignment.other-pin',
        athleteId: M10IsolationFixtures.pinnedAthleteId,
        programmeVersionId: M9ContentGraphFixtures.v1Id,
        active: true,
      ),
    );
    final result = harness.service.activateMembership(
      actor: M10IsolationFixtures.firstParty,
      athleteId: M10IsolationFixtures.pinnedAthleteId,
      pinnedAssignmentId: 'assignment.other-pin',
    );
    expect(result.status, IsolationActivateStatus.assignmentPinned);
    final roster = harness.service.inspectRoster(M10IsolationFixtures.firstParty);
    expect(
      roster.entries.single.pinnedAssignmentId,
      M9ContentGraphFixtures.athleteAssignmentId,
    );
  });

  test('stale declared composite is rejected', () {
    final harness = M10IsolationFixtures.seed(staleComposite: '0' * 64);
    final roster = harness.service.inspectRoster(M10IsolationFixtures.firstParty);
    expect(roster.status, IsolationRosterStatus.staleManifest);
    expect(roster.entries.single.staleDeclaredComposite, isTrue);

    final fresh = M10IsolationFixtures.seed(includePinnedMembership: false);
    final activate = fresh.service.activateMembership(
      actor: M10IsolationFixtures.firstParty,
      athleteId: M10IsolationFixtures.pinnedAthleteId,
      pinnedAssignmentId: M9ContentGraphFixtures.athleteAssignmentId,
      expectedGraphComposite: '1' * 64,
    );
    expect(activate.status, IsolationActivateStatus.staleManifest);
  });

  test('display name is refused as an identity key', () {
    final harness = M10IsolationFixtures.seed();
    final result = harness.service.activateMembership(
      actor: M10IsolationFixtures.firstParty,
      athleteId: M10IsolationFixtures.unassignedAthleteId,
      athleteDisplayName: 'Alex',
    );
    expect(result.status, IsolationActivateStatus.invalidInput);
    expect(result.failureCode, 'display_name_is_not_identity');
  });

  test('output is deterministic across isolated seeds', () {
    final a = M10IsolationFixtures.seed().service.inspectRoster(
      M10IsolationFixtures.firstParty,
    );
    final b = M10IsolationFixtures.seed().service.inspectRoster(
      M10IsolationFixtures.firstParty,
    );
    expect(a.status, b.status);
    expect(a.entries.single.membershipId, b.entries.single.membershipId);
    expect(
      a.entries.single.graphCompositeIdentity,
      b.entries.single.graphCompositeIdentity,
    );
    expect(a.entries.single.usedByExerciseCount, b.entries.single.usedByExerciseCount);
  });

  test('capability fail-closed when write is absent', () {
    expect(IsolationCapability.none.rosterRead, isFalse);
    expect(IsolationCapability.none.membershipWrite, isFalse);
    expect(IsolationCapability.reader.membershipWrite, isFalse);
  });

  test('preview fixtures are excluded from production entry points', () {
    const forbidden = [
      'm10_isolation_fixtures',
      'main_m10_isolation_preview',
      'M10IsolationFixtures',
    ];
    const paths = [
      'lib/main.dart',
      'lib/features/app_shell/athlete_app_shell.dart',
      'lib/features/home/home_screen.dart',
      'lib/features/home/services/athlete_home_runtime_authority.dart',
    ];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();
      for (final token in forbidden) {
        expect(source.contains(token), isFalse, reason: '$path contains $token');
      }
    }
  });

  test('roster inspect stays bounded at 200 memberships', () {
    final harness = M10IsolationFixtures.seed(
      includePinnedMembership: false,
      includeAcmeMembership: false,
    );
    for (var i = 0; i < 200; i++) {
      final result = harness.service.activateMembership(
        actor: M10IsolationFixtures.firstParty,
        athleteId: 'athlete.scale.$i',
      );
      expect(result.status, IsolationActivateStatus.activated);
    }
    final sw = Stopwatch()..start();
    final roster = harness.service.inspectRoster(M10IsolationFixtures.firstParty);
    sw.stop();
    expect(roster.status, IsolationRosterStatus.ready);
    expect(roster.entries, hasLength(200));
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  test('foreign publisher cannot attach a first-party pin', () {
    final harness = M10IsolationFixtures.seed(includeAcmeMembership: false);
    final result = harness.service.activateMembership(
      actor: M10IsolationFixtures.acme,
      athleteId: M10IsolationFixtures.pinnedAthleteId,
      pinnedAssignmentId: M9ContentGraphFixtures.athleteAssignmentId,
    );
    expect(result.status, IsolationActivateStatus.unauthorised);
    expect(result.failureCode, 'foreign_programme_pin');
  });
}
