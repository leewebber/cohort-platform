import '../../../../data/repositories/protocol_repository.dart';
import 'programme_builder_protocol_name_resolver.dart';

/// Production resolver backed by [ProtocolRepository].
class ProgrammeBuilderProtocolNameResolverImpl
    implements ProgrammeBuilderProtocolNameResolver {
  ProgrammeBuilderProtocolNameResolverImpl({
    ProtocolRepository? protocolRepository,
  }) : _protocolRepository = protocolRepository ?? ProtocolRepository();

  final ProtocolRepository _protocolRepository;

  @override
  Future<Map<String, String>> resolveNames(Set<String> protocolIds) {
    return _protocolRepository.getProtocolNamesByIds(protocolIds);
  }
}
