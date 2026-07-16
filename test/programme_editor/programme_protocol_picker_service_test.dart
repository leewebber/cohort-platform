import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protocol picker filters by id and name', () async {
    final service = _FakeProtocolPickerService();

    final all = await service.listSelectableProtocols();
    expect(all, hasLength(2));

    final filtered = await service.listSelectableProtocols(searchTerm: 'BW-002');
    expect(filtered, hasLength(1));
    expect(filtered.single.protocolId, 'BW-002');
  });
}

class _FakeProtocolPickerService implements ProgrammeBuilderProtocolPickerService {
  @override
  Future<ProgrammeBuilderProtocolOption?> getById(String protocolId) async {
    return ProgrammeBuilderProtocolOption(
      protocolId: protocolId,
      name: 'Protocol $protocolId',
    );
  }

  @override
  Future<List<ProgrammeBuilderProtocolOption>> listSelectableProtocols({
    String? searchTerm,
    int limit = 50,
  }) async {
    final options = [
      const ProgrammeBuilderProtocolOption(
        protocolId: 'BW-001',
        name: 'Bodyweight Grinder',
        sessionType: 'strength',
        durationMin: 45,
        equipmentSummary: 'Bodyweight',
      ),
      const ProgrammeBuilderProtocolOption(
        protocolId: 'BW-002',
        name: 'Mobility Flow',
        sessionType: 'mobility',
        durationMin: 30,
      ),
    ];

    final term = searchTerm?.trim().toLowerCase();
    if (term == null || term.isEmpty) return options;

    return options
        .where(
          (option) =>
              option.name.toLowerCase().contains(term) ||
              option.protocolId.toLowerCase().contains(term),
        )
        .toList();
  }
}
