import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/isolation_models.dart';
import 'package:cohort_platform/domain/athlete_coach_isolation/m10_isolation_fixtures.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    command = null;
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
    }
    setState(() {});
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
