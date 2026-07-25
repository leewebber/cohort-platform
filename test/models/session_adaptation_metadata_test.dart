import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_adaptation_metadata_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtocolDraft adaptation metadata', () {
    test('serializes primary intent using dbValue', () {
      final draft = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Lower Strength',
        steps: const [],
        primarySessionIntent: SessionIntent.lowerBodyStrength,
      );

      final map = draft.toProtocolMap();
      expect(
        map[SessionAdaptationMetadataKeys.primarySessionIntent],
        'lower_body_strength',
      );
    });

    test('serializes multiple secondary intents', () {
      final draft = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Hybrid',
        steps: const [],
        secondarySessionIntents: const [
          SessionIntent.prehabilitation,
          SessionIntent.mobility,
        ],
      );

      final map = draft.toProtocolMap();
      expect(
        map[SessionAdaptationMetadataKeys.secondarySessionIntents],
        ['prehabilitation', 'mobility'],
      );
    });

    test('defaults secondary intents to empty immutable list', () {
      final draft = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Legacy',
        steps: const [],
      );

      expect(draft.secondarySessionIntents, isEmpty);
      expect(draft.toProtocolMap(), isNot(contains(SessionAdaptationMetadataKeys.secondarySessionIntents)));
    });

    test('canonicalizes duplicate secondary intents on construction', () {
      final draft = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Test',
        steps: const [],
        secondarySessionIntents: const [
          SessionIntent.mobility,
          SessionIntent.mobility,
          SessionIntent.prehabilitation,
        ],
      );

      expect(draft.secondarySessionIntents, [
        SessionIntent.mobility,
        SessionIntent.prehabilitation,
      ]);
    });

    test('removes primary intent from secondary intents on construction', () {
      final draft = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Test',
        steps: const [],
        primarySessionIntent: SessionIntent.tempo,
        secondarySessionIntents: const [
          SessionIntent.tempo,
          SessionIntent.aerobicBase,
        ],
      );

      expect(draft.secondarySessionIntents, [SessionIntent.aerobicBase]);
    });

    test('normalizes invalid minimum viable duration to null', () {
      final draft = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Test',
        steps: const [],
        minimumViableDurationMin: 0,
      );

      expect(draft.minimumViableDurationMin, isNull);
    });

    test('legacy row without adaptation keys parses via Protocol.fromMap', () {
      final protocol = Protocol.fromMap({
        'protocol_id': 'legacy-1',
        'name': 'Legacy Session',
        'duration_min': 45,
      });

      expect(protocol.primarySessionIntent, isNull);
      expect(protocol.secondarySessionIntents, isEmpty);
      expect(protocol.minimumViableDurationMin, isNull);
    });

    test('unknown intent dbValue is ignored without crashing', () {
      final protocol = Protocol.fromMap({
        'protocol_id': 'sess-1',
        'name': 'Session',
        SessionAdaptationMetadataKeys.primarySessionIntent: 'not_a_real_intent',
        SessionAdaptationMetadataKeys.secondarySessionIntents: [
          'lower_body_strength',
          'unknown_intent_value',
        ],
      });

      expect(protocol.primarySessionIntent, isNull);
      expect(protocol.secondarySessionIntents, [SessionIntent.lowerBodyStrength]);
    });

    test('mergeAdaptationFromRow round-trips through toProtocolMap', () {
      final base = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Session',
        steps: [],
        durationMin: 60,
      );

      final row = {
        SessionAdaptationMetadataKeys.primarySessionIntent: 'threshold',
        SessionAdaptationMetadataKeys.secondarySessionIntents: [
          'aerobic_base',
        ],
        SessionAdaptationMetadataKeys.minimumViableDurationMin: 30,
      };

      final merged = ProtocolDraft.mergeAdaptationFromRow(draft: base, row: row);
      expect(merged.primarySessionIntent, SessionIntent.threshold);
      expect(merged.secondarySessionIntents, [SessionIntent.aerobicBase]);
      expect(merged.minimumViableDurationMin, 30);

      final serialized = merged.toProtocolMap();
      final roundTrip = ProtocolDraft.mergeAdaptationFromRow(
        draft: ProtocolDraft(protocolId: 'sess-1', name: 'Session', steps: []),
        row: serialized,
      );
      expect(roundTrip.primarySessionIntent, SessionIntent.threshold);
      expect(roundTrip.secondarySessionIntents, [SessionIntent.aerobicBase]);
      expect(roundTrip.minimumViableDurationMin, 30);
    });
  });

  group('SessionAdaptationMetadataValidation', () {
    test('reports when minimum viable duration exceeds planned duration', () {
      final messages = SessionAdaptationMetadataValidation.validate(
        primarySessionIntent: SessionIntent.lowerBodyStrength,
        secondarySessionIntents: const [],
        minimumViableDurationMin: 50,
        plannedDurationMin: 45,
      );

      expect(messages, isNotEmpty);
      expect(messages.first, contains('exceeds planned session duration'));
    });

    test('reports duplicate secondary intents before canonicalization', () {
      final messages = SessionAdaptationMetadataValidation.validate(
        secondarySessionIntents: const [
          SessionIntent.mobility,
          SessionIntent.mobility,
        ],
      );

      expect(messages, isNotEmpty);
    });

    test('reports primary duplicated in secondary list', () {
      final messages = SessionAdaptationMetadataValidation.validate(
        primarySessionIntent: SessionIntent.tempo,
        secondarySessionIntents: const [
          SessionIntent.tempo,
          SessionIntent.aerobicBase,
        ],
      );

      expect(messages, isNotEmpty);
    });
  });

  group('SessionAdaptationMetadataCodec.stripPendingPersistenceColumns', () {
    test('removes adaptation keys when merging legacy partial upsert maps', () {
      final map = {
        'protocol_id': 'id',
        'name': 'Name',
        SessionAdaptationMetadataKeys.primarySessionIntent: 'long_run',
        SessionAdaptationMetadataKeys.minimumViableDurationMin: 20,
      };

      SessionAdaptationMetadataCodec.stripPendingPersistenceColumns(map);

      expect(map.containsKey(SessionAdaptationMetadataKeys.primarySessionIntent), isFalse);
      expect(map.containsKey(SessionAdaptationMetadataKeys.minimumViableDurationMin), isFalse);
    });

    test('toProtocolMap includes adaptation keys for upsert after migration', () {
      final draft = ProtocolDraft(
        protocolId: 'sess-1',
        name: 'Session',
        steps: const [],
        primarySessionIntent: SessionIntent.tempo,
        minimumViableDurationMin: 25,
      );

      final map = draft.toProtocolMap();
      expect(
        map[SessionAdaptationMetadataKeys.primarySessionIntent],
        'tempo',
      );
      expect(
        map[SessionAdaptationMetadataKeys.minimumViableDurationMin],
        25,
      );
    });
  });
}
