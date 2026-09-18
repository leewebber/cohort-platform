import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/domain/content_graph/apollo_local_graph_binder.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_manifest.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_models.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_service.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_vocabulary.dart';
import 'package:cohort_platform/domain/content_graph/in_memory_content_graph_store.dart';
import 'package:cohort_platform/domain/content_graph/m9_content_graph_fixtures.dart';
import 'package:flutter/material.dart';

/// Local M9 explorer. Fixtures only. Not a production entry point.
///
///   flutter run -d chrome --web-port 4187 -t lib/main_m9_content_graph_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const M9ContentGraphPreviewApp());
}

class M9ContentGraphPreviewApp extends StatelessWidget {
  const M9ContentGraphPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: const M9ContentGraphExplorer(),
    );
  }
}

class M9ContentGraphExplorer extends StatefulWidget {
  const M9ContentGraphExplorer({super.key});

  @override
  State<M9ContentGraphExplorer> createState() => _M9ContentGraphExplorerState();
}

class _M9ContentGraphExplorerState extends State<M9ContentGraphExplorer> {
  late final InMemoryContentGraphStore store;
  late final ContentGraphService service;
  final log = <String>[];

  @override
  void initState() {
    super.initState();
    store = InMemoryContentGraphStore();
    service = M9ContentGraphFixtures.seed(store: store);
    log.add('v1 published and existing athlete pinned');
  }

  void _record(String line) {
    setState(() => log.add(line));
  }

  @override
  Widget build(BuildContext context) {
    final v1 = store.programmeVersion(M9ContentGraphFixtures.v1Id)!;
    final assignment = service.resolveAssignment(
      M9ContentGraphFixtures.athleteAssignmentId,
    );
    final compiled = service.compileDraft(v1.id);
    final activeCount = service
        .usedByExercise(M9ContentGraphFixtures.exerciseSquat)
        .activeAssignmentCount;
    return Scaffold(
      appBar: AppBar(title: const Text('M9 Content Graph (fixtures)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'LOCAL FIXTURES ONLY — not Field Manual, not production.',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Text('Programme: ${M9ContentGraphFixtures.programmeId}'),
          Text('v1: ${v1.id} ${v1.lifecycle.name} default=${v1.catalogueDefault}'),
          Text(
            'Existing athlete pinned to v1: ${assignment.athleteId} → ${assignment.programmeVersionId}',
          ),
          Text('Source package hash: ${compiled.manifest.sourceCanonicalContentSha256}'),
          Text(
            'Supplemental relationship-source hash: ${compiled.manifest.supplementalRelationshipSha256}',
          ),
          Text('Graph hash: ${compiled.manifest.graphCanonicalSha256}'),
          Text(
            'Composite content identity: ${compiled.manifest.compositeContentIdentity}',
          ),
          Text(
            'Active assignment count (operational, not in graph hash): $activeCount',
          ),
          const Text(
            'Apollo v1 compatibility bridge: Plan Package v1 hash '
            '${ApolloLocalGraphBinder.expectedPlanPackageHash} is retained; '
            'exercise edges require separately versioned Apollo SQL relationships.',
          ),
          const Text(
            'PROPOSAL ONLY — Plan Package v2: embed canonical EX-* IDs, '
            'session-template-version lineage, and graph references. No v1 rewrite.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _cloneAndPublishV2,
                child: const Text('Clone → edit → publish v2'),
              ),
              OutlinedButton(
                onPressed: _enrolNew,
                child: const Text('New enrolment'),
              ),
              OutlinedButton(
                onPressed: _retireV1,
                child: const Text('Retire v1 for new enrolments'),
              ),
              OutlinedButton(
                onPressed: _usedBy,
                child: const Text('Used by'),
              ),
              OutlinedButton(
                onPressed: _rejectIdentical,
                child: const Text('Reject identical publish'),
              ),
              OutlinedButton(
                onPressed: _denyExternal,
                child: const Text('Deny cross-namespace'),
              ),
              OutlinedButton(
                onPressed: _alignedPackageGraph,
                child: const Text('Valid aligned package + graph'),
              ),
              OutlinedButton(
                onPressed: _rejectStaleGraph,
                child: const Text('Stale graph rejection'),
              ),
              OutlinedButton(
                onPressed: _rejectAlteredPackage,
                child: const Text('Altered package rejection'),
              ),
              OutlinedButton(
                onPressed: _rejectUnresolvedExercise,
                child: const Text('Unresolved exercise rejection'),
              ),
              OutlinedButton(
                onPressed: _assignmentCountWithoutHashChange,
                child: const Text('Assignment count vs graph hash'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final line in log) Text('• $line'),
        ],
      ),
    );
  }

  void _cloneAndPublishV2() {
    M9ContentGraphFixtures.forkSessionTemplateRevision(store);
    final draft = service.cloneDraftFromPublished(
      actor: M9ContentGraphFixtures.firstParty,
      publishedVersionId: M9ContentGraphFixtures.v1Id,
      draftVersionId: M9ContentGraphFixtures.v2DraftId,
    );
    store.putPlacement(
      store.placementsForVersion(draft.id).single.copyWith(
        sessionTemplateVersionId: M9ContentGraphFixtures.sessionV2Id,
      ),
    );
    service.rebindSupplementalFromGraph(draft.id);
    final diff = service.diffAgainstPrevious(draft.id);
    final published = service.publish(
      actor: M9ContentGraphFixtures.firstParty,
      programmeVersionId: draft.id,
      setCatalogueDefault: true,
    );
    _record(
      'published ${published.id}; existing still ${service.resolveAssignment(M9ContentGraphFixtures.athleteAssignmentId).programmeVersionId}; diff ${diff.entries.length}',
    );
  }

  void _enrolNew() {
    final enrolled = service.enrol(
      assignmentId: 'assignment.preview-new',
      athleteId: 'athlete.preview-new',
      programmeId: M9ContentGraphFixtures.programmeId,
    );
    _record('new enrolment pinned to ${enrolled.programmeVersionId}');
  }

  void _retireV1() {
    service.retire(
      actor: M9ContentGraphFixtures.firstParty,
      programmeVersionId: M9ContentGraphFixtures.v1Id,
    );
    _record(
      'v1 retired; existing assignment still ${service.resolveAssignment(M9ContentGraphFixtures.athleteAssignmentId).programmeVersionId}',
    );
  }

  void _usedBy() {
    final exercise = service.usedByExercise(M9ContentGraphFixtures.exerciseSquat);
    final session = service.usedBySessionTemplateVersion(
      M9ContentGraphFixtures.sessionV1Id,
    );
    _record(
      'EX-136 used-by ${exercise.hits.length} hits, active ${exercise.activeAssignmentCount}; session active ${session.activeAssignmentCount}',
    );
  }

  void _rejectIdentical() {
    try {
      final draft = service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.firstParty,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: 'draft-identical',
      );
      service.publish(
        actor: M9ContentGraphFixtures.firstParty,
        programmeVersionId: draft.id,
      );
      _record('unexpected identical publish');
    } on ContentGraphException catch (error) {
      _record('identical publish ${error.code.name}');
    }
  }

  void _denyExternal() {
    try {
      service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.external,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: 'stolen',
      );
      _record('unexpected external clone');
    } on ContentGraphException catch (error) {
      _record('cross-namespace ${error.code.name}');
    }
  }

  void _alignedPackageGraph() {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    service.validateManifest(
      compiled.manifest,
      programmeVersionId: M9ContentGraphFixtures.v1Id,
    );
    _record(
      'aligned package ${compiled.manifest.sourceCanonicalContentSha256} '
      'graph ${compiled.manifest.graphCanonicalSha256}',
    );
  }

  void _rejectStaleGraph() {
    try {
      final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
      service.validateManifest(
        compiled.manifest.copyWith(graphCanonicalSha256: 'stale-graph'),
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      );
      _record('unexpected stale graph accepted');
    } on ContentGraphException catch (error) {
      _record('stale graph ${error.code.name}');
    }
  }

  void _rejectAlteredPackage() {
    try {
      final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
      service.validateManifest(
        compiled.manifest.copyWith(
          sourceCanonicalContentSha256: 'altered-package',
        ),
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      );
      _record('unexpected altered package accepted');
    } on ContentGraphException catch (error) {
      _record('altered package ${error.code.name}');
    }
  }

  void _rejectUnresolvedExercise() {
    try {
      service.assertDerivedUsedByEdge(
        const ContentGraphEdge(
          type: ContentRelationshipType.exerciseUsedByBlock,
          fromType: ContentNodeType.exercise,
          fromId: 'EX-999',
          toType: ContentNodeType.authoredBlock,
          toId: 'block.missing',
        ),
        M9ContentGraphFixtures.v1Id,
      );
      _record('unexpected unresolved exercise accepted');
    } on ContentGraphException catch (error) {
      _record('unresolved exercise ${error.code.name}');
    }
  }

  void _assignmentCountWithoutHashChange() {
    final before = service.compileDraft(M9ContentGraphFixtures.v1Id).sha256;
    service.enrol(
      assignmentId: 'assignment.preview-count',
      athleteId: 'athlete.preview-count',
      programmeId: M9ContentGraphFixtures.programmeId,
    );
    final after = service.compileDraft(M9ContentGraphFixtures.v1Id).sha256;
    final count = service
        .usedByExercise(M9ContentGraphFixtures.exerciseSquat)
        .activeAssignmentCount;
    _record(
      'assignment count $count graph hash unchanged=${before == after}',
    );
  }
}
