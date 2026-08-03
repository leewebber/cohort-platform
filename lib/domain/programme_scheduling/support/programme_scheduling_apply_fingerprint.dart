import 'programme_scheduling_preview_fingerprint.dart';

/// Cross-runtime apply fingerprint contract (Sprint 1.7D/1.7E).
///
/// Binds schedule-authoritative preview fields that both Dart and PostgreSQL
/// must hash identically. Free-text impact messages remain excluded.
///
/// Move/Swap/Push share the base payload (operation, affected rows, collisions).
/// Skip additionally binds authoritative cursor before/after. Cursor keys are
/// omitted for non-Skip operations so existing Move/Swap vectors stay stable.
///
/// Canonical JSON algorithm: [ProgrammeSchedulingPreviewFingerprint].
class ProgrammeSchedulingApplyFingerprint {
  const ProgrammeSchedulingApplyFingerprint._();

  static const policyVersion = 'programme.scheduling.policy.v1';

  /// Builds the canonical apply payload for Move/Swap/Push/Skip confirmation.
  static Map<String, Object?> payload({
    required Map<String, Object?> operation,
    required String assignmentId,
    required String programmeVersionId,
    required String packageContentHash,
    required int scheduleRevision,
    required String timezone,
    required List<Map<String, Object?>> affected,
    required List<String> collidingDates,
    String policyVersion = ProgrammeSchedulingApplyFingerprint.policyVersion,
    Map<String, Object?>? cursorBefore,
    Object? cursorAfter = _cursorAbsent,
  }) {
    final affectedSorted = List<Map<String, Object?>>.from(affected)
      ..sort((a, b) {
        final ak = a['sessionSlotId']?.toString() ?? '';
        final bk = b['sessionSlotId']?.toString() ?? '';
        return ak.compareTo(bk);
      });
    final collisions = List<String>.from(collidingDates)..sort();
    final map = <String, Object?>{
      'affected': affectedSorted,
      'assignmentId': assignmentId,
      'collidingDates': collisions,
      'operation': operation,
      'packageContentHash': packageContentHash,
      'policyVersion': policyVersion,
      'programmeVersionId': programmeVersionId,
      'scheduleRevision': scheduleRevision,
      'timezone': timezone,
    };
    // Skip-only authoritative cursor binding (null cursorAfter = terminal).
    if (!identical(cursorAfter, _cursorAbsent)) {
      map['cursorAfter'] = cursorAfter;
      map['cursorBefore'] = cursorBefore;
    }
    return map;
  }

  static const Object _cursorAbsent = Object();

  static String compute(Map<String, Object?> applyPayload) {
    return ProgrammeSchedulingPreviewFingerprint.compute(applyPayload);
  }

  /// Affected-row shape shared with PostgreSQL.
  static Map<String, Object?> affectedRow({
    required String sessionSlotId,
    required String programmedSessionKey,
    required String originalDate,
    required String proposedDate,
    required String originalDisposition,
    required String proposedDisposition,
    required int weekNumber,
    required String dayKey,
    required int sessionOrder,
    required String protocolId,
  }) {
    return {
      'dayKey': dayKey,
      'originalDate': originalDate,
      'originalDisposition': originalDisposition,
      'programmedSessionKey': programmedSessionKey,
      'proposedDate': proposedDate,
      'proposedDisposition': proposedDisposition,
      'protocolId': protocolId,
      'sessionOrder': sessionOrder,
      'sessionSlotId': sessionSlotId,
      'weekNumber': weekNumber,
    };
  }

  /// Cursor coordinate shape shared with PostgreSQL (Skip fingerprint).
  static Map<String, Object?> cursorRow({
    required String sessionSlotId,
    required int weekNumber,
    required String dayKey,
    required int sessionOrder,
  }) {
    return {
      'dayKey': dayKey,
      'sessionOrder': sessionOrder,
      'sessionSlotId': sessionSlotId,
      'weekNumber': weekNumber,
    };
  }
}
