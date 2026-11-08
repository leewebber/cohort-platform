import 'adaptation_reason.dart';
import 'adaptation_session_environment.dart';
import 'recovery_state.dart';

class AdaptationRequest {
  const AdaptationRequest({
    required this.reason,
    this.recoveryState,
    this.environment,
    this.availableEquipment,
    this.confirmedMatchingDumbbellPair = false,
    this.availableMinutes,
  });

  final AdaptationReason reason;
  final RecoveryState? recoveryState;
  final AdaptationSessionEnvironment? environment;
  final Set<String>? availableEquipment;
  final bool confirmedMatchingDumbbellPair;
  final int? availableMinutes;

  @override
  String toString() {
    return 'AdaptationRequest('
        'reason: $reason, '
        'recoveryState: $recoveryState, '
        'environment: $environment, '
        'availableEquipment: $availableEquipment, '
        'availableMinutes: $availableMinutes'
        ')';
  }
}
