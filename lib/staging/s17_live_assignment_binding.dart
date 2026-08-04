import 's17_occurrence_baseline.dart';

/// Result of binding resume execution to Athlete D's authenticated live assignment.
class S17LiveAssignmentBindingResult {
  const S17LiveAssignmentBindingResult({
    required this.ok,
    required this.detail,
    this.assignmentId = '',
    this.versionId = '',
    this.lineageCode = '',
    this.packageHash = '',
    this.isMaterialised = false,
    this.staleDefinesSuperseded = false,
  });

  final bool ok;
  final String detail;
  final String assignmentId;
  final String versionId;
  final String lineageCode;
  final String packageHash;
  final bool isMaterialised;
  final bool staleDefinesSuperseded;

  String get redactedDetail {
    String prefix(String value) =>
        value.trim().length <= 8 ? '***' : '${value.trim().substring(0, 8)}…';
    if (!ok) return detail;
    return '$detail assignment=${prefix(assignmentId)} '
        'version=${prefix(versionId)} lineage=$lineageCode '
        'materialised=$isMaterialised stale_defines_superseded=$staleDefinesSuperseded';
  }
}

/// Pure live-assignment binder for B4d.3 resume mode.
///
/// Private define assignment/version/lineage values are never authoritative.
class S17LiveAssignmentBinding {
  static const requiredLineage =
      S17OccurrenceBaseline.multiSlotSchedulingLineage;

  /// Binds to [live] when it is Athlete D's active PROG-S15A-STAGING enrolment.
  static S17LiveAssignmentBindingResult bind({
    required String athleteId,
    required String? liveAssignmentId,
    required String? liveVersionId,
    required String? liveLineageCode,
    required String? liveAthleteId,
    required bool liveIsMaterialised,
    String? livePackageHash,
    String? defineAssignmentId,
    String? defineVersionId,
    String? defineLineageCode,
  }) {
    final liveAssign = liveAssignmentId?.trim() ?? '';
    final liveVersion = liveVersionId?.trim() ?? '';
    final liveLineage = liveLineageCode?.trim() ?? '';
    final owner = liveAthleteId?.trim() ?? '';

    if (liveAssign.isEmpty || liveVersion.isEmpty || liveLineage.isEmpty) {
      return const S17LiveAssignmentBindingResult(
        ok: false,
        detail: 'REFUSED: no authenticated active assignment to bind',
      );
    }
    if (owner.isEmpty || owner != athleteId.trim()) {
      return const S17LiveAssignmentBindingResult(
        ok: false,
        detail: 'REFUSED: live assignment not owned by authenticated Athlete D',
      );
    }
    if (liveLineage == S17OccurrenceBaseline.oneSlotCatalogueLineage) {
      return const S17LiveAssignmentBindingResult(
        ok: false,
        detail: 'REFUSED: live assignment is PROG-S13-ELIG; stale S13 refused',
      );
    }
    if (liveLineage != requiredLineage) {
      return S17LiveAssignmentBindingResult(
        ok: false,
        detail:
            'REFUSED: live lineage $liveLineage != required $requiredLineage',
      );
    }

    final defAssign = defineAssignmentId?.trim() ?? '';
    final defVersion = defineVersionId?.trim() ?? '';
    final defLineage = defineLineageCode?.trim() ?? '';
    final stale =
        (defAssign.isNotEmpty && defAssign != liveAssign) ||
        (defVersion.isNotEmpty && defVersion != liveVersion) ||
        (defLineage.isNotEmpty && defLineage != liveLineage) ||
        defLineage == S17OccurrenceBaseline.oneSlotCatalogueLineage;

    return S17LiveAssignmentBindingResult(
      ok: true,
      detail: 'Bound resume to live PROG-S15A-STAGING assignment',
      assignmentId: liveAssign,
      versionId: liveVersion,
      lineageCode: liveLineage,
      packageHash: livePackageHash?.trim() ?? '',
      isMaterialised: liveIsMaterialised,
      staleDefinesSuperseded: stale,
    );
  }
}
