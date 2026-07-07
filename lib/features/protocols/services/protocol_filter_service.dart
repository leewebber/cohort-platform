import '../../../data/repositories/protocol_repository.dart';

class ProtocolFilterService {
  ProtocolFilterService(this._repository);

  final ProtocolRepository _repository;

  Future<List<String>> goals() {
    return _repository.getGoals();
  }

  Future<List<String>> equipment() {
    return _repository.getEquipment();
  }

  Future<List<String>> capabilities() {
    return _repository.getCapabilities();
  }

  Future<List<String>> demandLevels() {
    return _repository.getDemandLevels();
  }

  Future<List<String>> recoveryLevels() {
    return _repository.getRecoveryLevels();
  }
}