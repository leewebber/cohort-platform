import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'content_graph_manifest.dart';
import 'content_graph_models.dart';
import 'content_graph_vocabulary.dart';

/// Content-graph package format v1. Independent of Plan Package schema v1.
///
/// Plan Package v1 remains the interchange hash for programme schedule import
/// and must not be silently reinterpreted.
class ContentGraphCanonicaliser {
  const ContentGraphCanonicaliser();

  static const formatVersion = ContentGraphBinding.graphFormatVersion;
  static const compilerVersion = ContentGraphBinding.compilerVersion;

  String canonicalJson({
    required ProgrammeVersion version,
    required List<ProgrammePlacement> placements,
    required List<SessionTemplateVersion> sessionVersions,
    required List<AuthoredBlock> blocks,
    StructuralContentGraph? graph,
  }) {
    final tree = _sorted({
      'blocks': [
        for (final b in _byKeys(blocks, (x) => [
              x.sessionTemplateVersionId,
              x.position,
              x.id,
            ]))
          _sorted({
            'session_template_version_id': b.sessionTemplateVersionId,
            'position': b.position,
            'title': b.title,
            'exercise_ids': [...b.exerciseIds]..sort(),
            'prescription_by_exercise': _sorted(b.prescriptionByExercise),
          }),
      ],
      'compiler_version': compilerVersion,
      'edges': [
        for (final e in _sortedEdges(graph?.edges ?? const [])) e.toCanonical(),
      ],
      'format_version': formatVersion,
      'nodes': [
        for (final n in _sortedNodes(graph?.nodes ?? const [])) n.toCanonical(),
      ],
      'placements': [
        for (final p in _byKeys(placements, (x) => [
              x.weekNumber,
              x.dayKey,
              x.slotOrder,
            ]))
          _sorted({
            'session_template_version_id': p.sessionTemplateVersionId,
            'week_number': p.weekNumber,
            'day_key': p.dayKey,
            'slot_order': p.slotOrder,
            'title_override': p.titleOverride,
            'progression_parameters': _sorted(p.progressionParameters),
            'adaptation_permission': p.adaptationPermission,
            'optional': p.optional,
          }),
      ],
      'programme_version': _sorted({
        'programme_id': version.programmeId,
        'compiler_format_version': formatVersion,
        'source_package_ref': version.sourcePackageRef,
      }),
      'session_versions': [
        for (final s in _byKeys(sessionVersions, (x) => [x.id]))
          _sorted({
            'id': s.id,
            'template_id': s.templateId,
            'revision_number': s.revisionNumber,
            'source_hash': s.sourceHash,
          }),
      ],
    });
    return jsonEncode(tree);
  }

  String sha256Hex(String canonicalJson) {
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  Map<String, Object?> _sorted(Map<String, Object?> input) {
    final keys = input.keys.toList()..sort();
    return {for (final k in keys) k: input[k]};
  }

  List<T> _byKeys<T>(List<T> items, List<Comparable<dynamic>> Function(T) keys) {
    final copy = [...items];
    copy.sort((a, b) {
      final ak = keys(a);
      final bk = keys(b);
      for (var i = 0; i < ak.length; i++) {
        final c = ak[i].compareTo(bk[i]);
        if (c != 0) return c;
      }
      return 0;
    });
    return copy;
  }

  List<ContentGraphNode> _sortedNodes(List<ContentGraphNode> nodes) {
    final copy = [...nodes];
    copy.sort((a, b) {
      final type = a.type.name.compareTo(b.type.name);
      if (type != 0) return type;
      return a.id.compareTo(b.id);
    });
    return copy;
  }

  List<ContentGraphEdge> _sortedEdges(List<ContentGraphEdge> edges) {
    final copy = [...edges];
    copy.sort((a, b) {
      final keys = [
        a.type.name.compareTo(b.type.name),
        a.fromType.name.compareTo(b.fromType.name),
        a.fromId.compareTo(b.fromId),
        a.toType.name.compareTo(b.toType.name),
        a.toId.compareTo(b.toId),
      ];
      for (final c in keys) {
        if (c != 0) return c;
      }
      return 0;
    });
    return copy;
  }
}

class ContentGraphDiffer {
  const ContentGraphDiffer();

  ContentVersionDiff diff({
    required ProgrammeVersion fromVersion,
    required ProgrammeVersion toVersion,
    required List<ProgrammePlacement> fromPlacements,
    required List<ProgrammePlacement> toPlacements,
    required List<AuthoredBlock> fromBlocks,
    required List<AuthoredBlock> toBlocks,
  }) {
    final entries = <ContentDiffEntry>[];
    final fromBySlot = {
      for (final p in fromPlacements) '${p.weekNumber}/${p.dayKey}/${p.slotOrder}': p,
    };
    final toBySlot = {
      for (final p in toPlacements) '${p.weekNumber}/${p.dayKey}/${p.slotOrder}': p,
    };

    for (final key in {...fromBySlot.keys, ...toBySlot.keys}) {
      final before = fromBySlot[key];
      final after = toBySlot[key];
      if (before == null && after != null) {
        entries.add(ContentDiffEntry(
          path: 'placement.$key',
          classification: ContentDiffClass.breakingExecution,
          summary: 'session added',
        ));
        continue;
      }
      if (before != null && after == null) {
        entries.add(ContentDiffEntry(
          path: 'placement.$key',
          classification: ContentDiffClass.breakingExecution,
          summary: 'session removed',
        ));
        continue;
      }
      if (before!.sessionTemplateVersionId != after!.sessionTemplateVersionId) {
        entries.add(ContentDiffEntry(
          path: 'placement.$key.session',
          classification: ContentDiffClass.breakingExecution,
          summary: 'session version changed',
        ));
      }
      if (before.weekNumber != after.weekNumber ||
          before.dayKey != after.dayKey ||
          before.slotOrder != after.slotOrder) {
        entries.add(ContentDiffEntry(
          path: 'placement.$key.move',
          classification: ContentDiffClass.materialTraining,
          summary: 'placement moved',
        ));
      }
      if (before.progressionParameters.toString() !=
          after.progressionParameters.toString()) {
        entries.add(ContentDiffEntry(
          path: 'placement.$key.prescription',
          classification: ContentDiffClass.materialTraining,
          summary: 'prescription changed',
        ));
      }
      if (before.adaptationPermission != after.adaptationPermission) {
        entries.add(ContentDiffEntry(
          path: 'placement.$key.adaptation',
          classification: ContentDiffClass.materialTraining,
          summary: 'adaptation-permission change',
        ));
      }
      if (before.titleOverride != after.titleOverride) {
        entries.add(ContentDiffEntry(
          path: 'placement.$key.title',
          classification: ContentDiffClass.metadataPresentation,
          summary: 'metadata-only change',
        ));
      }
    }

    final fromExercises = {
      for (final b in fromBlocks) ...b.exerciseIds,
    };
    final toExercises = {
      for (final b in toBlocks) ...b.exerciseIds,
    };
    for (final id in toExercises.difference(fromExercises)) {
      entries.add(ContentDiffEntry(
        path: 'exercise.$id',
        classification: ContentDiffClass.breakingExecution,
        summary: 'exercise added',
      ));
    }
    for (final id in fromExercises.difference(toExercises)) {
      entries.add(ContentDiffEntry(
        path: 'exercise.$id',
        classification: ContentDiffClass.breakingExecution,
        summary: 'exercise removed or substituted',
      ));
    }
    for (final b in toBlocks) {
      final prior = fromBlocks.where((x) => x.id == b.id).toList();
      if (prior.isEmpty) continue;
      if (prior.single.prescriptionByExercise.toString() !=
          b.prescriptionByExercise.toString()) {
        entries.add(ContentDiffEntry(
          path: 'block.${b.id}.prescription',
          classification: ContentDiffClass.materialTraining,
          summary: 'set/rep/load/time change',
        ));
      }
      if (prior.single.position != b.position) {
        entries.add(ContentDiffEntry(
          path: 'block.${b.id}.order',
          classification: ContentDiffClass.materialTraining,
          summary: 'ordering change',
        ));
      }
    }

    entries.sort((a, b) => a.path.compareTo(b.path));
    return ContentVersionDiff(
      fromVersionId: fromVersion.id,
      toVersionId: toVersion.id,
      entries: entries,
    );
  }
}
