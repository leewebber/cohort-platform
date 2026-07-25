import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

SessionBlock _legacyStrengthRow({Map<String, dynamic>? extra}) {
  return SessionBlock.fromRow({
    'block_id': 'blk-1',
    'block_type': 'strength',
    'title': 'Main',
    'content': '',
    'workout_format': 'none',
    'position': 1,
    ...?extra,
  });
}

const _strengthDefaultPolicy = BlockAdaptationPolicy(
  canRemove: false,
  canShorten: false,
  canReduceVolume: true,
  canReduceIntensity: true,
  canIncreaseRest: true,
  canSuperset: false,
  canReplaceExercises: true,
  canReplaceBlock: false,
);

const _explicitPolicy = BlockAdaptationPolicy(
  canRemove: true,
  canShorten: false,
  canReduceVolume: true,
  canReduceIntensity: false,
  canIncreaseRest: true,
  canSuperset: false,
  canReplaceExercises: false,
  canReplaceBlock: true,
);

void expectSamePolicy(
  BlockAdaptationPolicy? actual,
  BlockAdaptationPolicy expected,
) {
  expect(actual?.toJson(), expected.toJson());
}

void main() {
  group('SessionBlock explicit adaptation metadata', () {
    test('serializes explicit priority using dbValue', () {
      final block = _legacyStrengthRow().copyWith(
        blockPriority: BlockPriority.essential,
      );

      final map = block.explicitAdaptationMetadataToMap();
      expect(
        map[SessionBlockAdaptationMetadataKeys.blockPriority],
        'essential',
      );
    });

    test('serializes explicit policy using canonical JSON', () {
      final block = _legacyStrengthRow().copyWith(
        adaptationPolicy: _explicitPolicy,
      );

      final map = block.explicitAdaptationMetadataToMap();
      expect(
        map[SessionBlockAdaptationMetadataKeys.adaptationPolicy],
        _explicitPolicy.toJson(),
      );
    });

    test('legacy block with both fields absent loads with null explicit values', () {
      final block = _legacyStrengthRow();

      expect(block.blockPriority, isNull);
      expect(block.adaptationPolicy, isNull);
    });

    test('derives default priority from block type', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.warmUp,
        position: 1,
      );

      expect(
        block.effectiveBlockPriority,
        SessionBlockTypeAdaptationPolicy.defaultPriority(
          SessionBlockType.warmUp,
        ),
      );
      expect(block.effectiveBlockPriority, BlockPriority.disposable);
    });

    test('derives default policy from block type', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.strength,
        position: 1,
      );

      expect(block.effectiveAdaptationPolicy, _strengthDefaultPolicy);
    });

    test('explicit priority overrides derived default', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.strength,
        position: 1,
      ).copyWith(blockPriority: BlockPriority.optional);

      expect(block.effectiveBlockPriority, BlockPriority.optional);
      expect(block.blockPriority, BlockPriority.optional);
    });

    test('explicit policy overrides derived default', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.strength,
        position: 1,
      ).copyWith(adaptationPolicy: _explicitPolicy);

      expect(block.effectiveAdaptationPolicy.canRemove, isTrue);
      expect(block.effectiveAdaptationPolicy.canReplaceBlock, isTrue);
      expect(block.adaptationPolicy?.toJson(), _explicitPolicy.toJson());
    });

    test('derived defaults are not emitted as explicitly authored JSON', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.strength,
        position: 1,
      );

      expect(block.explicitAdaptationMetadataToMap(), isEmpty);
      expect(
        block.toRowMap(sessionId: 'sess-1'),
        isNot(contains(SessionBlockAdaptationMetadataKeys.blockPriority)),
      );
      expect(
        block.toRowMap(sessionId: 'sess-1'),
        isNot(contains(SessionBlockAdaptationMetadataKeys.adaptationPolicy)),
      );

      final explicit = block.copyWith(blockPriority: BlockPriority.secondary);
      expect(
        explicit.toRowMap(sessionId: 'sess-1')[
            SessionBlockAdaptationMetadataKeys.blockPriority],
        'secondary',
      );
    });

    test('unknown priority value fails safely without crashing session load', () {
      final rows = [
        {
          'block_id': 'a',
          'block_type': 'strength',
          'title': 'A',
          'content': '',
          'workout_format': 'none',
          'position': 1,
          SessionBlockAdaptationMetadataKeys.blockPriority: 'not_a_priority',
        },
        {
          'block_id': 'b',
          'block_type': 'warm_up',
          'title': 'B',
          'content': '',
          'workout_format': 'none',
          'position': 2,
        },
      ];

      final blocks = rows.map(SessionBlock.fromRow).toList();

      expect(blocks, hasLength(2));
      expect(blocks.first.blockPriority, isNull);
      expect(blocks.first.effectiveBlockPriority, BlockPriority.primary);
      expect(blocks.last.blockPriority, isNull);
    });

    test('mergeAdaptationFromRow round-trips explicit priority', () {
      final base = SessionBlock(
        localId: 'local-1',
        blockType: SessionBlockType.conditioning,
        title: 'Engine',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
      );

      final row = {
        SessionBlockAdaptationMetadataKeys.blockPriority: 'secondary',
      };

      final merged = SessionBlock.mergeAdaptationFromRow(block: base, row: row);
      expect(merged.blockPriority, BlockPriority.secondary);

      final serialized = merged.explicitAdaptationMetadataToMap();
      final roundTrip = SessionBlock.mergeAdaptationFromRow(
        block: base,
        row: serialized,
      );
      expect(roundTrip.blockPriority, BlockPriority.secondary);
    });

    test('mergeAdaptationFromRow round-trips explicit policy', () {
      final base = SessionBlock(
        localId: 'local-1',
        blockType: SessionBlockType.strength,
        title: 'Lift',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
      );

      final row = {
        SessionBlockAdaptationMetadataKeys.adaptationPolicy:
            _explicitPolicy.toJson(),
      };

      final merged = SessionBlock.mergeAdaptationFromRow(block: base, row: row);
      expectSamePolicy(merged.adaptationPolicy, _explicitPolicy);

      final roundTrip = SessionBlock.mergeAdaptationFromRow(
        block: base,
        row: merged.explicitAdaptationMetadataToMap(),
      );
      expectSamePolicy(roundTrip.adaptationPolicy, _explicitPolicy);
    });

    test('explicitBlockAdaptationMetadata DTO carries only authored values', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.strength,
        position: 1,
      ).copyWith(blockPriority: BlockPriority.primary);

      final dto = block.explicitBlockAdaptationMetadata;
      expect(dto.blockTypeDbValue, SessionBlockType.strength.dbValue);
      expect(dto.priority, BlockPriority.primary);
      expect(dto.adaptationPolicy, isNull);
    });

    test('withBlockAdaptationMetadata applies DTO fields', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.accessory,
        position: 2,
      );

      final updated = block.withBlockAdaptationMetadata(
        BlockAdaptationMetadata(
          blockTypeDbValue: SessionBlockType.accessory.dbValue,
          priority: BlockPriority.essential,
          adaptationPolicy: _explicitPolicy,
        ),
      );

      expect(updated.blockPriority, BlockPriority.essential);
      expectSamePolicy(updated.adaptationPolicy, _explicitPolicy);
    });

    test('deepClone preserves explicit adaptation metadata', () {
      final block = _legacyStrengthRow().copyWith(
        blockPriority: BlockPriority.secondary,
        adaptationPolicy: _explicitPolicy,
      );

      final clone = block.deepClone(position: 2);
      expect(clone.blockPriority, BlockPriority.secondary);
      expectSamePolicy(clone.adaptationPolicy, _explicitPolicy);
    });

    test('copyWith clear flags drop explicit adaptation metadata', () {
      final block = _legacyStrengthRow().copyWith(
        blockPriority: BlockPriority.secondary,
        adaptationPolicy: _explicitPolicy,
      );

      final cleared = block.copyWith(
        clearBlockPriority: true,
        clearAdaptationPolicy: true,
      );

      expect(cleared.blockPriority, isNull);
      expect(cleared.adaptationPolicy, isNull);
    });

    test('equality includes explicit adaptation metadata', () {
      final a = _legacyStrengthRow().copyWith(
        blockPriority: BlockPriority.primary,
      );
      final b = _legacyStrengthRow().copyWith(
        blockPriority: BlockPriority.primary,
      );
      final c = _legacyStrengthRow().copyWith(
        blockPriority: BlockPriority.secondary,
      );

      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('SessionBlockAdaptationMetadataCodec.stripPendingPersistenceColumns', () {
    test('removes adaptation keys from upsert map', () {
      final map = _legacyStrengthRow()
          .copyWith(blockPriority: BlockPriority.primary)
          .explicitAdaptationMetadataToMap();

      SessionBlockAdaptationMetadataCodec.stripPendingPersistenceColumns(map);

      expect(
        map.containsKey(SessionBlockAdaptationMetadataKeys.blockPriority),
        isFalse,
      );
    });
  });
}
