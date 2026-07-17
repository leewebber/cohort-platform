import 'dart:io';

import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/features/coach_studio/programmes/widgets/programme_protocol_picker_sheet.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_option_mapper.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_picker_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_picker_service_impl.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = ProgrammeBuilderProtocolOptionMapper();

  final catalogProtocols = [
    const Protocol(protocolId: 'BW-001', name: 'Bodyweight Grinder', sessionType: 'strength', durationMin: 45, equipment: 'Bodyweight'),
    const Protocol(protocolId: 'RN-006', name: 'Classic Threshold', sessionType: 'interval', durationMin: 60),
    const Protocol(protocolId: 'FG-009', name: 'Full Gym Chipper', sessionType: 'circuit', durationMin: 50, equipment: 'Gym'),
    const Protocol(protocolId: 'ST-001', name: 'Lower Body A', sessionType: 'strength', durationMin: 55),
    Protocol(
      protocolId: 'EQ-001',
      name: 'Equipment List Protocol',
      sessionType: null,
      requiredEquipment: 'Kettlebell',
      optionalEquipment: 'Dumbbell',
    ),
    const Protocol(protocolId: '', name: 'Missing Id'),
    const Protocol(protocolId: 'NONAME-001', name: ''),
  ];

  ProgrammeBuilderProtocolPickerService serviceWithCatalog(
    List<Protocol> protocols,
  ) {
    return ProgrammeBuilderProtocolPickerServiceImpl(
      protocolRepository: _FakeProtocolRepository(protocols),
    );
  }

  group('ProgrammeBuilderProtocolOptionMapper', () {
    test('maps multiple canonical protocols including BW-001 RN-006 FG-009 ST-001', () {
      final options = mapper.mapProtocols(catalogProtocols);

      expect(options.map((option) => option.protocolId), containsAll([
        'BW-001',
        'RN-006',
        'FG-009',
        'ST-001',
      ]));
    });

    test('null session_type and duration do not drop row', () {
      final option = mapper.mapProtocol(
        const Protocol(protocolId: 'REST-001', name: 'Recovery Walk'),
      );

      expect(option, isNotNull);
      expect(option!.sessionType, isNull);
      expect(option.durationMin, isNull);
    });

    test('missing name falls back to protocol_id', () {
      final option = mapper.mapProtocol(
        const Protocol(protocolId: 'NONAME-001', name: ''),
      );

      expect(option?.name, 'NONAME-001');
    });

    test('combines required and optional equipment without dropping row', () {
      final option = mapper.mapProtocol(
        const Protocol(
          protocolId: 'EQ-001',
          name: 'Equipment List Protocol',
          requiredEquipment: 'Kettlebell',
          optionalEquipment: 'Dumbbell',
        ),
      );

      expect(option?.equipmentSummary, contains('Kettlebell'));
      expect(option?.equipmentSummary, contains('Dumbbell'));
    });

    test('malformed json-like equipment string is kept as summary text', () {
      final option = mapper.mapProtocol(
        const Protocol(
          protocolId: 'EQ-002',
          name: 'Broken Equipment',
          equipment: '[Kettlebell, Dumbbell]',
        ),
      );

      expect(option?.equipmentSummary, '[Kettlebell, Dumbbell]');
    });

    test('search by protocol id', () {
      final options = mapper.applySearch(
        mapper.mapProtocols(catalogProtocols),
        'RN-006',
      );

      expect(options, hasLength(1));
      expect(options.single.protocolId, 'RN-006');
    });

    test('search by name', () {
      final options = mapper.applySearch(
        mapper.mapProtocols(catalogProtocols),
        'chipper',
      );

      expect(options.single.protocolId, 'FG-009');
    });

    test('empty search returns all mapped options', () {
      final mapped = mapper.mapProtocols(catalogProtocols);
      expect(mapper.applySearch(mapped, ''), mapped);
      expect(mapper.applySearch(mapped, null), mapped);
    });

    test('does not apply hidden session-type filter', () {
      final options = mapper.mapProtocols(catalogProtocols);
      final sessionTypes = options.map((option) => option.sessionType).toSet();

      expect(sessionTypes, containsAll(['strength', 'interval', 'circuit', null]));
    });
  });

  group('ProgrammeBuilderProtocolPickerServiceImpl', () {
    test('returns multiple protocols from catalog repository', () async {
      final service = serviceWithCatalog(catalogProtocols);

      final options = await service.listSelectableProtocols();

      expect(options.length, greaterThanOrEqualTo(4));
      expect(options.map((option) => option.protocolId), containsAll([
        'BW-001',
        'RN-006',
        'FG-009',
        'ST-001',
      ]));
    });

    test('filters by search term without losing canonical ids', () async {
      final service = serviceWithCatalog(catalogProtocols);

      final options = await service.listSelectableProtocols(searchTerm: 'BW-001');

      expect(options, hasLength(1));
      expect(options.single.protocolId, 'BW-001');
    });

    test('getById resolves without content-kind filter', () async {
      final service = serviceWithCatalog(catalogProtocols);

      final option = await service.getById('FG-009');

      expect(option?.protocolId, 'FG-009');
      expect(option?.name, 'Full Gym Chipper');
    });
  });

  group('ProgrammeProtocolPickerSheet widget', () {
    testWidgets('renders multiple protocol options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgrammeProtocolPickerSheet(
              listProtocols: ({searchTerm}) async {
                return const [
                  ProgrammeBuilderProtocolOption(
                    protocolId: 'BW-001',
                    name: 'Bodyweight Grinder',
                    sessionType: 'strength',
                    durationMin: 45,
                  ),
                  ProgrammeBuilderProtocolOption(
                    protocolId: 'RN-006',
                    name: 'Classic Threshold',
                    sessionType: 'interval',
                    durationMin: 60,
                  ),
                  ProgrammeBuilderProtocolOption(
                    protocolId: 'FG-009',
                    name: 'Full Gym Chipper',
                    sessionType: 'circuit',
                  ),
                ];
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bodyweight Grinder'), findsOneWidget);
      expect(find.text('Classic Threshold'), findsOneWidget);
      expect(find.text('Full Gym Chipper'), findsOneWidget);
      expect(find.textContaining('BW-001'), findsOneWidget);
      expect(find.textContaining('RN-006'), findsOneWidget);
      expect(find.textContaining('FG-009'), findsOneWidget);
    });

    testWidgets('shows no search results message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgrammeProtocolPickerSheet(
              listProtocols: ({searchTerm}) async => const [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No protocols are available in the library yet.'),
        findsOneWidget,
      );
    });

    testWidgets('shows load error and retry', (tester) async {
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgrammeProtocolPickerSheet(
              listProtocols: ({searchTerm}) async {
                attempts += 1;
                if (attempts == 1) {
                  throw Exception('network');
                }
                return const [
                  ProgrammeBuilderProtocolOption(
                    protocolId: 'ST-001',
                    name: 'Lower Body A',
                  ),
                ];
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('We could not load protocols right now.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Lower Body A'), findsOneWidget);
    });

    test('widget file has no Supabase imports', () {
      final source = File(
        'lib/features/coach_studio/programmes/widgets/programme_protocol_picker_sheet.dart',
      ).readAsStringSync();

      expect(source.toLowerCase(), isNot(contains('supabase')));
    });
  });
}

class _FakeProtocolRepository extends ProtocolRepository {
  _FakeProtocolRepository(this._protocols);

  final List<Protocol> _protocols;

  @override
  Future<List<Protocol>> listCohortProtocols({int limit = 100}) async {
    return _protocols.take(limit).toList();
  }

  @override
  Future<List<Protocol>> listCatalogProtocols({int limit = 100}) async {
    return listCohortProtocols(limit: limit);
  }

  @override
  Future<Protocol?> getProtocolById(String protocolId) async {
    for (final protocol in _protocols) {
      if (protocol.protocolId == protocolId) {
        return protocol;
      }
    }
    return null;
  }
}
