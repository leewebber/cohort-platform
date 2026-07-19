import '../../core/services/supabase_service.dart';
import '../../models/session_block.dart';
import '../../models/session_block_exercise_link.dart';

class SessionBlockRepository {
  const SessionBlockRepository();

  Future<List<SessionBlock>> getSessionBlocks(String sessionId) async {
    final blockRows = await SupabaseService.client
        .from('session_blocks')
        .select()
        .eq('session_id', sessionId)
        .order('position', ascending: true);

    if (blockRows.isEmpty) {
      return const [];
    }

    final blockIds = blockRows
        .map((row) => row['block_id']?.toString())
        .whereType<String>()
        .toList(growable: false);

    final exerciseRows = await SupabaseService.client
        .from('session_block_exercises')
        .select()
        .inFilter('block_id', blockIds)
        .order('position', ascending: true);

    final linksByBlock = <String, List<SessionBlockExerciseLink>>{};
    for (final row in exerciseRows) {
      final blockId = row['block_id']?.toString();
      if (blockId == null) continue;
      linksByBlock.putIfAbsent(blockId, () => []).add(
            SessionBlockExerciseLink.fromRow(
              Map<String, dynamic>.from(row),
            ),
          );
    }

    return blockRows
        .map<SessionBlock>(
          (row) => SessionBlock.fromRow(
            Map<String, dynamic>.from(row),
            linkedExercises:
                linksByBlock[row['block_id']?.toString()] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<void> replaceSessionBlocks({
    required String sessionId,
    required List<SessionBlock> blocks,
  }) async {
    await SupabaseService.client
        .from('session_blocks')
        .delete()
        .eq('session_id', sessionId);

    if (blocks.isEmpty) {
      return;
    }

    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    for (final block in ordered) {
      final blockMap = block.toRowMap(sessionId: sessionId);
      blockMap.remove('block_id');

      final inserted = await SupabaseService.client
          .from('session_blocks')
          .insert(blockMap)
          .select()
          .single();

      final blockId = inserted['block_id']?.toString();
      if (blockId == null) continue;

      if (block.linkedExercises.isEmpty) continue;

      final linkMaps = block.linkedExercises
          .map(
            (link) => link.toRowMap(blockId: blockId)..remove('id'),
          )
          .toList(growable: false);

      await SupabaseService.client
          .from('session_block_exercises')
          .insert(linkMaps);
    }
  }
}
