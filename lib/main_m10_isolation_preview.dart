import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/consent_store.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/isolation_models.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/m10_isolation_fixtures.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/publisher_athlete_consent_service.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/publisher_athlete_isolation_service.dart';
import 'package:cohort_platform/domain/content_graph/m9_content_graph_fixtures.dart';
import 'package:flutter/material.dart';

/// Internal M10 isolation preview. Fixtures only.
///
///   flutter run -d chrome --web-port 4190 -t lib/main_m10_isolation_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const M10IsolationPreviewApp());
}

class M10IsolationPreviewApp extends StatelessWidget {
  const M10IsolationPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: const M10IsolationPreviewScreen(),
    );
  }
}

enum _PreviewScene {
  success,
  empty,
  unauthorised,
  invalid,
  stale,
  pinning,
  pendingNoRoster,
  acceptedOwnPin,
  foreignPinHidden,
  declined,
  revoked,
  expired,
  missingCapability,
  auditTimeline,
}

class M10IsolationPreviewScreen extends StatefulWidget {
  const M10IsolationPreviewScreen({super.key});

  @override
  State<M10IsolationPreviewScreen> createState() =>
      _M10IsolationPreviewScreenState();
}

class _M10IsolationPreviewScreenState extends State<M10IsolationPreviewScreen> {
  _PreviewScene scene = _PreviewScene.success;
  late PublisherAthleteIsolationService service;
  IsolationRosterResult? roster;
  IsolationActivateResult? command;
  String? compiledComposite;
  List<String> consentLog = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    command = null;
    consentLog = const [];
    switch (scene) {
      case _PreviewScene.success:
        final harness = M10IsolationFixtures.seed();
        service = harness.service;
        compiledComposite = harness.graph
            .compileDraft(M9ContentGraphFixtures.v1Id)
            .manifest
            .compositeContentIdentity;
        roster = service.inspectRoster(M10IsolationFixtures.firstParty);
      case _PreviewScene.empty:
        final harness = M10IsolationFixtures.seed(
          includePinnedMembership: false,
          includeAcmeMembership: false,
        );
        service = harness.service;
        roster = service.inspectRoster(M10IsolationFixtures.firstParty);
      case _PreviewScene.unauthorised:
        final harness = M10IsolationFixtures.seed();
        service = harness.service;
        roster = service.inspectRoster(M10IsolationFixtures.unauthorised);
      case _PreviewScene.invalid:
        final harness = M10IsolationFixtures.seed();
        service = harness.service;
        command = service.activateMembership(
          actor: M10IsolationFixtures.firstParty,
          athleteId: M10IsolationFixtures.unassignedAthleteId,
          athleteDisplayName: 'Alex',
        );
        roster = service.inspectRoster(M10IsolationFixtures.firstParty);
      case _PreviewScene.stale:
        final harness = M10IsolationFixtures.seed(
          staleComposite: '0' * 64,
        );
        service = harness.service;
        roster = service.inspectRoster(M10IsolationFixtures.firstParty);
      case _PreviewScene.pinning:
        final harness = M10IsolationFixtures.seed();
        service = harness.service;
        command = service.activateMembership(
          actor: M10IsolationFixtures.firstParty,
          athleteId: M10IsolationFixtures.pinnedAthleteId,
          pinnedAssignmentId: 'assignment.does-not-exist',
        );
        roster = service.inspectRoster(M10IsolationFixtures.firstParty);
      case _PreviewScene.pendingNoRoster:
      case _PreviewScene.acceptedOwnPin:
      case _PreviewScene.foreignPinHidden:
      case _PreviewScene.declined:
      case _PreviewScene.revoked:
      case _PreviewScene.expired:
      case _PreviewScene.missingCapability:
      case _PreviewScene.auditTimeline:
        consentLog = _consentScene(scene);
        roster = null;
        command = null;
    }
    setState(() {});
  }

  List<String> _consentScene(_PreviewScene scene) {
    final clock = FixedConsentClock(DateTime.utc(2026, 9, 19, 12));
    final store = InMemoryConsentStore();
    final publisher = M10IsolationFixtures.firstParty;
    const athlete = IsolationActor(
      principalId: 'athlete.fixture-consent',
      publisherId: M10IsolationFixtures.firstPartyPublisherId,
      capability: IsolationCapability.reader,
    );
    final service = PublisherAthleteConsentService(
      store: store,
      clock: clock,
      knownAthletes: {athlete.principalId},
      activePublishers: {
        M10IsolationFixtures.firstPartyPublisherId,
        M10IsolationFixtures.acmePublisherId,
      },
      pinsForAthlete: (id) {
        if (scene == _PreviewScene.foreignPinHidden) {
          return const PublisherProgrammePin(
            assignmentId: 'assignment.foreign',
            programmeVersionId: 'programme-version.acme',
            publisherId: M10IsolationFixtures.acmePublisherId,
          );
        }
        return const PublisherProgrammePin(
          assignmentId: M9ContentGraphFixtures.athleteAssignmentId,
          programmeVersionId: M9ContentGraphFixtures.v1Id,
          publisherId: M10IsolationFixtures.firstPartyPublisherId,
          versionName: 'Apollo fixture v1',
          compositeIdentity: 'fixture-composite',
        );
      },
    );
    if (scene == _PreviewScene.missingCapability) {
      return [
        'invite=${service.invite(actor: M10IsolationFixtures.unauthorised, athleteId: athlete.principalId).outcome.name}',
      ];
    }
    final invited = service.invite(actor: publisher, athleteId: athlete.principalId);
    if (scene == _PreviewScene.pendingNoRoster) {
      return [
        'invite=${invited.outcome.name}',
        'roster=${service.inspectRoster(publisher).length}',
      ];
    }
    if (scene == _PreviewScene.declined) {
      return [
        'decline=${service.decline(athlete: athlete, invitationId: invited.invitation!.id).outcome.name}',
        'roster=${service.inspectRoster(publisher).length}',
      ];
    }
    if (scene == _PreviewScene.expired) {
      clock.advance(const Duration(days: 8));
      return [
        'accept=${service.accept(athlete: athlete, invitationId: invited.invitation!.id).outcome.name}',
      ];
    }
    final accepted = service.accept(
      athlete: athlete,
      invitationId: invited.invitation!.id,
    );
    if (scene == _PreviewScene.acceptedOwnPin ||
        scene == _PreviewScene.foreignPinHidden) {
      final row = service.inspectRoster(publisher).single;
      return [
        'accept=${accepted.outcome.name}',
        'visibility=${row.assignmentVisibility.name}',
        'version=${row.programmeVersionId ?? 'hidden'}',
        'composite=${row.graphCompositeIdentity ?? 'hidden'}',
      ];
    }
    if (scene == _PreviewScene.revoked) {
      return [
        'revoke=${service.revoke(actor: athlete, membershipId: accepted.membership!.id).outcome.name}',
        'roster=${service.inspectRoster(publisher).length}',
      ];
    }
    return [
      for (final event in store.events) '${event.transition} → ${event.newState}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('M10 isolation (internal preview)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'INTERNAL PREVIEW — local fixtures only. Not Field Manual, '
            'not production, not a phone release.',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'M9 graph is consumed for publisher identity, assignment pin, '
            'used-by exercise count, and composite identity. Pins are not '
            'rewritten.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _PreviewScene.values)
                ChoiceChip(
                  label: Text(value.name),
                  selected: scene == value,
                  onSelected: (_) {
                    scene = value;
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (compiledComposite != null)
            Text('Fixture v1 composite: $compiledComposite'),
          if (roster != null) ...[
            const SizedBox(height: 12),
            Text('Roster status: ${roster!.status.name}'),
            if (roster!.failureCode != null)
              Text('Failure: ${roster!.failureCode}'),
            for (final entry in roster!.entries)
              ListTile(
                title: Text(entry.athleteId),
                subtitle: Text(
                  'pin ${entry.pinnedProgrammeVersionId ?? 'none'} · '
                  'used-by exercises ${entry.usedByExerciseCount} · '
                  'composite ${entry.graphCompositeIdentity ?? 'none'}'
                  '${entry.staleDeclaredComposite ? ' · STALE' : ''}',
                ),
              ),
          ],
          if (consentLog.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Consent log', style: Theme.of(context).textTheme.titleMedium),
            for (final line in consentLog) Text(line),
          ],
          if (command != null) ...[
            const SizedBox(height: 12),
            Text('Command: ${command!.status.name}'),
            if (command!.failureCode != null)
              Text('Command failure: ${command!.failureCode}'),
          ],
          const SizedBox(height: 24),
          Text(
            'Proposal-only items (Plan Package v2, athlete graph UI, audited '
            'repin, hosted memberships) are not shown as ready.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
