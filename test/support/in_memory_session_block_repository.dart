import 'package:cohort_platform/data/repositories/session_block_repository.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';

/// Faithful in-memory round-trip for [SessionBlockRepository] serializers.
class InMemorySessionBlockRepository extends SessionBlockRepository {
  InMemorySessionBlockRepository();

  final Map<String, List<SessionBlock>> _blocksBySessionId = {};
  final List<Map<String, dynamic>> persistedExerciseRows = [];

  @override
  Future<List<SessionBlock>> getSessionBlocks(String sessionId) async {
    final stored = _blocksBySessionId[sessionId];
    if (stored == null || stored.isEmpty) {
      return const [];
    }

    return stored
        .map(
          (block) => SessionBlock.fromRow(
            block.toRowMap(sessionId: sessionId)
              ..['block_id'] = block.persistedId ?? block.localId,
            linkedExercises: block.linkedExercises
                .map(
                  (link) => SessionBlockExerciseLink.fromRow(
                    link.toRowMap(
                      blockId: block.persistedId ?? block.localId,
                    )..['id'] = link.persistedId ?? link.localId,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> replaceSessionBlocks({
    required String sessionId,
    required List<SessionBlock> blocks,
  }) async {
    _blocksBySessionId.remove(sessionId);
    persistedExerciseRows.clear();

    if (blocks.isEmpty) {
      return;
    }

    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    final persistedBlocks = <SessionBlock>[];
    for (final block in ordered) {
      final blockId = block.persistedId ?? 'block-${persistedBlocks.length + 1}';
      final persistedLinks = <SessionBlockExerciseLink>[];

      for (final link in block.linkedExercises) {
        final linkId = link.persistedId ?? 'link-${persistedLinks.length + 1}';
        final row = link.toRowMap(blockId: blockId)..['id'] = linkId;
        persistedExerciseRows.add(Map<String, dynamic>.from(row));
        persistedLinks.add(
          SessionBlockExerciseLink.fromRow(row),
        );
      }

      persistedBlocks.add(
        block.copyWith(
          persistedId: blockId,
          linkedExercises: persistedLinks,
        ),
      );
    }

    _blocksBySessionId[sessionId] = persistedBlocks;
  }

  List<Map<String, dynamic>> exerciseRowsForSession(String sessionId) {
    final blocks = _blocksBySessionId[sessionId] ?? const [];
    final blockIds = blocks
        .map((block) => block.persistedId)
        .whereType<String>()
        .toSet();
    return persistedExerciseRows
        .where((row) => blockIds.contains(row['block_id']?.toString()))
        .toList(growable: false);
  }
}
