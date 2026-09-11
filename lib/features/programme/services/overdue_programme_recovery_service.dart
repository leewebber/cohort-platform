import '../models/overdue_programme_recovery.dart';
import 'overdue_programme_recovery_store.dart';

class OverdueProgrammeRecoveryService {
  const OverdueProgrammeRecoveryService({required this.store});

  final OverdueProgrammeRecoveryStore store;

  Future<OverdueProgrammeRecoveryResult> recover(
    OverdueProgrammeRecoveryCommand command,
  ) {
    return store.recover(command);
  }
}
