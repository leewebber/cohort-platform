import '../models/backfill_programme_session.dart';
import 'backfill_programme_session_store.dart';

/// Hosted backfill is unavailable until the reviewed schema migration is applied.
class SupabaseBackfillProgrammeSessionStore
    implements BackfillProgrammeSessionStore {
  const SupabaseBackfillProgrammeSessionStore();

  @override
  bool get isSupported => false;

  @override
  Future<BackfillProgrammeSessionResult> save(
    BackfillProgrammeSessionCommand command,
  ) async {
    return const BackfillProgrammeSessionResult(
      status: BackfillProgrammeSessionStatus.failed,
      code: 'backfill_schema_unavailable',
      message:
          'Historical result entry is not available on this environment yet.',
    );
  }
}
