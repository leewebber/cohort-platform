/// Protocol option row for the programme builder picker.
class ProgrammeBuilderProtocolOption {
  const ProgrammeBuilderProtocolOption({
    required this.protocolId,
    required this.name,
    this.sessionType,
    this.durationMin,
    this.equipmentSummary,
  });

  final String protocolId;
  final String name;
  final String? sessionType;
  final int? durationMin;
  final String? equipmentSummary;
}

/// Published protocol catalogue for programme slot assignment.
abstract class ProgrammeBuilderProtocolPickerService {
  Future<List<ProgrammeBuilderProtocolOption>> listSelectableProtocols({
    String? searchTerm,
    int limit = 100,
  });

  Future<ProgrammeBuilderProtocolOption?> getById(String protocolId);
}
