import '../../../models/protocol.dart';
import 'programme_builder_protocol_picker_service.dart';

/// Maps canonical [Protocol] rows to programme picker options.
class ProgrammeBuilderProtocolOptionMapper {
  const ProgrammeBuilderProtocolOptionMapper();

  ProgrammeBuilderProtocolOption? mapProtocol(
    Protocol protocol, {
    void Function(String protocolId, String reason)? onSkip,
  }) {
    final protocolId = protocol.protocolId.trim();
    if (protocolId.isEmpty) {
      onSkip?.call('', 'missing protocol_id');
      return null;
    }

    final name = protocol.name.trim();
    if (name.isEmpty) {
      onSkip?.call(protocolId, 'missing name (using protocol_id fallback)');
    }

    return ProgrammeBuilderProtocolOption(
      protocolId: protocolId,
      name: name.isEmpty ? protocolId : name,
      sessionType: _nullableLabel(protocol.sessionType),
      durationMin: protocol.durationMin,
      equipmentSummary: _equipmentSummary(protocol),
    );
  }

  List<ProgrammeBuilderProtocolOption> mapProtocols(
    List<Protocol> protocols, {
    void Function(String protocolId, String reason)? onSkip,
  }) {
    final options = <ProgrammeBuilderProtocolOption>[];
    for (final protocol in protocols) {
      final option = mapProtocol(protocol, onSkip: onSkip);
      if (option != null) {
        options.add(option);
      }
    }
    return options;
  }

  List<ProgrammeBuilderProtocolOption> applySearch(
    List<ProgrammeBuilderProtocolOption> options,
    String? searchTerm,
  ) {
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

  static String? _nullableLabel(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _equipmentSummary(Protocol protocol) {
    final parts = <String>[];

    void addPart(dynamic value) {
      if (value == null) return;

      if (value is List) {
        for (final entry in value) {
          addPart(entry);
        }
        return;
      }

      final text = value.toString().trim();
      if (text.isEmpty || text == '[]') return;

      if (!parts.contains(text)) {
        parts.add(text);
      }
    }

    addPart(protocol.requiredEquipment);
    addPart(protocol.optionalEquipment);
    addPart(protocol.equipment);

    if (parts.isEmpty) return null;

    return parts.join(' • ');
  }
}
