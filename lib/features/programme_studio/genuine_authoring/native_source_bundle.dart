import 'dart:convert';
import 'dart:typed_data';

import 'package:cohort_plan_package/cohort_plan_package.dart';

import '../../session_revision/models/session_revision_usage_models.dart';
import '../composition/source_export/canonical_source_bundle.dart';
import '../composition/source_intake/canonical_source_intake.dart';
import '../workspace_json.dart';
import 'genuine_workspace.dart';
import 'native_session_source.dart';

/// Native source-index v2 extends the existing TAR transport. Review and package
/// hashes never stand in for body bytes or catalogue evidence.
class NativeSourceBundle {
  NativeSourceBundle.prepare(GenuineWorkspace workspace) {
    if (!workspace.reviewCurrent ||
        workspace.errors.isNotEmpty ||
        workspace.hasDrafts) {
      throw const FormatException(
        'Refresh a complete locally validated review before preparing export. Unresolved exercise setups block preparation.',
      );
    }
    final source = workspace.programme.verifiedExport();
    if (source == null) {
      throw const FormatException('Programme review is stale.');
    }
    final compile = const PlanPackageCompiler().compile(source);
    const NativeSessionCompiler().inspect(compile, workspace.policy.graphs);
    final sources = <String, String>{
      'programme.plan-package.yaml': source,
      'programme.canonical.json': compile.canonicalJson!,
      'protocol-graphs.json': workspace.policy.graphs,
      'catalogue-evidence.json': jsonEncode(workspace.catalogue.source),
      'origin-inventory.json': jsonEncode(workspace.origins),
      'prescription-review.txt': workspace.occurrences
          .map((slot) {
            final revision = workspace.selected(slot['slot_key'] as String);
            return 'Week ${slot['week']} day ${slot['day']} · local version ${revision.identity.revisionNumber}\n${workspace.inspectRevision(revision).readable}';
          })
          .join('\n\n'),
      'validation.json': jsonEncode({
        'status': 'LOCALLY_VALIDATED_NOT_APPROVED_OR_PUBLISHED',
        'package_sha256': compile.contentHashSha256,
        'graphs_sha256': nativeDigest(workspace.policy.graphs),
        'D8': 'PENDING',
        'Gate_A': 'OPEN',
      }),
      'README.md':
          'Prepared local Plan Package v2 and exact native graph sources.\nNot approval, hosted publication, assignment or started athlete state.\nEditable files separately retain drafts/history. Imported canonical sources are new local snapshots with unknown history.\nPackage hashes do not include all graph bytes; verify source-index.json and all members.\nNo owner/version/activation/publication receipt is fabricated.\n',
    };
    final sessions = <Map<String, dynamic>>[];
    var i = 0;
    for (final owner in workspace.owners.values) {
      for (final r in owner.revisions) {
        if (!workspace.policy.available.contains(r.key)) continue;
        final path =
            'native-graphs/graph-${(++i).toString().padLeft(4, '0')}.json';
        sources[path] = r.source;
        sessions.add({
          'path': path,
          'type': 'native_reviewed_protocol_graph',
          'identity': {
            'protocol_id': r.identity.protocolId,
            'session_lineage_id': owner.lineage,
            'revision_number': r.identity.revisionNumber,
          },
          'session_key': r.key,
          'title': r.title,
          'source_sha256': nativeDigest(r.source),
        });
      }
    }
    sources['source-index.json'] = encodeWorkspaceJson({
      'kind': 'derived_canonical_source_file_index',
      'version': 2,
      'profile': genuineWorkspaceProfile,
      'package_sha256': compile.contentHashSha256,
      'sessions': sessions,
      'files_sha256': {
        for (final e in sources.entries) e.key: nativeDigest(e.value),
      },
    });
    transport = CanonicalSourceBundle.native(sources);
    // Inspect the actual transport bytes, not the visible form values.
    verify(transport.archiveBytes, workspace.catalogue);
  }
  late final CanonicalSourceBundle transport;

  static Map<String, String> verify(
    Uint8List archive,
    LegacyCatalogueEvidence catalogue,
  ) {
    final files = readCanonicalArchive(archive, nativeGraphs: true);
    final index = workspaceObject(
      readWorkspaceJson(files['source-index.json'] ?? ''),
      {
        'kind',
        'version',
        'profile',
        'package_sha256',
        'sessions',
        'files_sha256',
      },
      'native source index',
    );
    if (index['kind'] != 'derived_canonical_source_file_index' ||
        index['version'] != 2 ||
        index['profile'] != genuineWorkspaceProfile) {
      workspaceInvalid('Unsupported native source inventory.');
    }
    final hashes = index['files_sha256'];
    if (hashes is! Map ||
        !nativeEqual(
          files.keys.toSet().difference({'source-index.json'}).toList()..sort(),
          hashes.keys.toList()..sort(),
        )) {
      workspaceInvalid('Archive inventory does not exactly cover the files.');
    }
    for (final e in hashes.entries) {
      if (nativeDigest(files[e.key]!) != e.value) {
        workspaceInvalid('Archive source digest differs: ${e.key}.');
      }
    }
    const fixed = {
      'programme.plan-package.yaml',
      'programme.canonical.json',
      'protocol-graphs.json',
      'catalogue-evidence.json',
      'origin-inventory.json',
      'prescription-review.txt',
      'validation.json',
      'README.md',
      'source-index.json',
    };
    if (files.keys.any(
      (k) =>
          !fixed.contains(k) &&
          !RegExp(r'^native-graphs/graph-\d{4}\.json$').hasMatch(k),
    )) {
      workspaceInvalid('Unknown native source member.');
    }
    if (!fixed.every(files.containsKey)) {
      workspaceInvalid('Missing native source member.');
    }
    if (!nativeEqual(
      jsonDecode(files['catalogue-evidence.json']!),
      catalogue.source,
    )) {
      workspaceInvalid(
        'Catalogue evidence differs from separately trusted retained evidence.',
      );
    }
    final compile = const PlanPackageCompiler().compile(
      files['programme.plan-package.yaml']!,
    );
    if (!compile.isValid ||
        compile.manifest!.packageSchemaVersion != 2 ||
        compile.contentHashSha256 != index['package_sha256'] ||
        compile.canonicalJson != files['programme.canonical.json']) {
      workspaceInvalid('Native package artifact differs.');
    }
    final refs = {for (final s in compile.manifest!.sessions) s.sessionKey: s};
    final graphInventory = <Map<String, dynamic>>[];
    final keys = <String>{}, paths = <String>{};
    for (final raw in workspaceList(
      index['sessions'],
      'native sources',
      max: 128,
    )) {
      final row = workspaceObject(raw, {
        'path',
        'type',
        'identity',
        'session_key',
        'title',
        'source_sha256',
      }, 'native member');
      final key = workspaceString(row['session_key'], 'session key'),
          path = workspaceString(row['path'], 'source path');
      if (!keys.add(key) ||
          !paths.add(path) ||
          row['type'] != 'native_reviewed_protocol_graph' ||
          !RegExp(r'^native-graphs/graph-\d{4}\.json$').hasMatch(path)) {
        workspaceInvalid('Duplicate/unsupported native member.');
      }
      final ref = refs[key],
          tuple = workspaceObject(row['identity'], {
            'protocol_id',
            'session_lineage_id',
            'revision_number',
          }, 'native identity');
      if (ref == null ||
          tuple['protocol_id'] != ref.protocolId ||
          tuple['session_lineage_id'] != ref.sessionLineageId ||
          tuple['revision_number'] != ref.revisionNumber ||
          row['title'] != ref.title ||
          nativeDigest(files[path] ?? '') != row['source_sha256']) {
        workspaceInvalid('Native member/revision binding differs.');
      }
      final receipt = const NativeSessionCompiler().compile(
        source: files[path]!,
        identity: SessionRevisionIdentity(
          protocolId: ref.protocolId,
          sessionLineageId: ref.sessionLineageId,
          revisionNumber: ref.revisionNumber,
        ),
        catalogue: catalogue,
        title: row['title'] as String,
      );
      if (!receipt.admitted) workspaceInvalid(receipt.issues.join('\n'));
      graphInventory.add(readWorkspaceJson(files[path]!));
    }
    if (keys.length != refs.length ||
        paths.length !=
            files.keys.where((k) => k.startsWith('native-graphs/')).length) {
      workspaceInvalid('Native scope is incomplete.');
    }
    final aggregate = jsonDecode(files['protocol-graphs.json']!) as List;
    if (!nativeEqual(aggregate, graphInventory)) {
      workspaceInvalid(
        'Individual and aggregate native graph meaning differs.',
      );
    }
    const NativeSessionCompiler().inspect(
      compile,
      files['protocol-graphs.json']!,
    );
    return files;
  }

  static GenuineWorkspace open(
    Uint8List archive,
    LegacyCatalogueEvidence catalogue,
  ) =>
      GenuineWorkspace.fromNativeSources(verify(archive, catalogue), catalogue);
}
