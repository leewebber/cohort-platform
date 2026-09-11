import '../models/overdue_programme_recovery.dart';

abstract class OverdueProgrammeRecoveryStore {
  Future<OverdueProgrammeRecoveryResult> recover(
    OverdueProgrammeRecoveryCommand command,
  );
}
