import '../../../core/services/supabase_service.dart';
import 'programme_builder_protocol_picker_service.dart';

/// Published protocol catalogue for programme slot assignment.
class ProgrammeBuilderProtocolPickerServiceImpl
    implements ProgrammeBuilderProtocolPickerService {
  const ProgrammeBuilderProtocolPickerServiceImpl();

  @override
  Future<List<ProgrammeBuilderProtocolOption>> listSelectableProtocols({
    String? searchTerm,
    int limit = 50,
  }) async {
    final response = await SupabaseService.client
        .from('performance_protocols')
        .select(
          'protocol_id, name, session_type, duration_min, equipment, required_equipment',
        )
        .eq('published', true)
        .order('name')
        .limit(limit);

    final options = response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList();

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

  @override
  Future<ProgrammeBuilderProtocolOption?> getById(String protocolId) async {
    final response = await SupabaseService.client
        .from('performance_protocols')
        .select(
          'protocol_id, name, session_type, duration_min, equipment, required_equipment',
        )
        .eq('protocol_id', protocolId.trim())
        .eq('published', true)
        .maybeSingle();

    if (response == null) return null;
    return _fromRow(Map<String, dynamic>.from(response));
  }

  ProgrammeBuilderProtocolOption _fromRow(Map<String, dynamic> row) {
    final equipment = row['equipment']?.toString().trim();
    final requiredEquipment = row['required_equipment']?.toString().trim();
    final equipmentSummary = [
      if (requiredEquipment != null && requiredEquipment.isNotEmpty)
        requiredEquipment,
      if (equipment != null && equipment.isNotEmpty) equipment,
    ].join(' • ');

    return ProgrammeBuilderProtocolOption(
      protocolId: row['protocol_id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      sessionType: row['session_type']?.toString(),
      durationMin: _nullableInt(row['duration_min']),
      equipmentSummary:
          equipmentSummary.isEmpty ? null : equipmentSummary,
    );
  }

  int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
