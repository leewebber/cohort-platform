import '../../../data/repositories/protocol_repository.dart';
import '../diagnostics/programme_protocol_picker_diagnostics.dart';
import 'programme_builder_protocol_option_mapper.dart';
import 'programme_builder_protocol_picker_service.dart';

/// Published protocol catalogue for programme slot assignment.
class ProgrammeBuilderProtocolPickerServiceImpl
    implements ProgrammeBuilderProtocolPickerService {
  ProgrammeBuilderProtocolPickerServiceImpl({
    ProtocolRepository? protocolRepository,
    ProgrammeBuilderProtocolOptionMapper? mapper,
  })  : _protocolRepository = protocolRepository ?? ProtocolRepository(),
        _mapper = mapper ?? const ProgrammeBuilderProtocolOptionMapper();

  final ProtocolRepository _protocolRepository;
  final ProgrammeBuilderProtocolOptionMapper _mapper;

  static const _catalogPublishedFilter = 'published=true (cohort_protocol catalogue)';

  @override
  Future<List<ProgrammeBuilderProtocolOption>> listSelectableProtocols({
    String? searchTerm,
    int limit = 100,
  }) async {
    ProgrammeProtocolPickerDiagnostics.log('load start');
    ProgrammeProtocolPickerDiagnostics.log(
      'source method=ProtocolRepository.listCohortProtocols',
    );
    ProgrammeProtocolPickerDiagnostics.log(
      'published filter=$_catalogPublishedFilter',
    );
    ProgrammeProtocolPickerDiagnostics.log('searchTerm=${searchTerm ?? ''}');

    final protocols = await _protocolRepository.listCohortProtocols(
      limit: limit,
    );

    ProgrammeProtocolPickerDiagnostics.log(
      'raw row count=${protocols.length}',
    );

    final mapped = _mapper.mapProtocols(
      protocols,
      onSkip: (protocolId, reason) {
        ProgrammeProtocolPickerDiagnostics.logSkippedRow(
          protocolId: protocolId,
          reason: reason,
        );
      },
    );

    ProgrammeProtocolPickerDiagnostics.log(
      'mapped option count=${mapped.length}',
    );

    final visible = _mapper.applySearch(mapped, searchTerm);

    ProgrammeProtocolPickerDiagnostics.log(
      'final visible count=${visible.length}',
    );

    return visible;
  }

  @override
  Future<ProgrammeBuilderProtocolOption?> getById(String protocolId) async {
    final protocol = await _protocolRepository.getProtocolById(protocolId.trim());
    if (protocol == null) return null;

    return _mapper.mapProtocol(protocol);
  }
}
