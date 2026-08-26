import '../../../core/services/supabase_service.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import 'fixed_programme_occurrence_projection_store.dart';

class FixedProgrammeOccurrenceProjectionSupabaseStore
    implements FixedProgrammeOccurrenceProjectionStore {
  const FixedProgrammeOccurrenceProjectionSupabaseStore();
  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async {
    final raw = await SupabaseService.client.rpc(
      'resolve_active_fixed_programme_calendar',
    );
    if (raw is! Map) {
      throw StateError('Malformed fixed schedule projection');
    }
    final map = Map<String, dynamic>.from(raw);
    final status = map['status']?.toString();
    if (status == 'absent') {
      final code = map['code']?.toString();
      if (code == 'no_active_assignment') {
        return null;
      }
      throw FixedProgrammeCalendarUnavailableException(
        code ?? 'unknown_absence',
      );
    }
    if (status != 'ok') {
      throw StateError(
        map['code']?.toString() ?? 'Fixed schedule projection failed',
      );
    }
    return FixedProgrammeCalendarProjection.fromMap(map);
  }
}
