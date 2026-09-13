import '../models/backfill_programme_session.dart';

abstract class BackfillProgrammeSessionStore {
  const BackfillProgrammeSessionStore();

  bool get isSupported;

  Future<BackfillProgrammeSessionResult> save(
    BackfillProgrammeSessionCommand command,
  );
}
