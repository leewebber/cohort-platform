import '../../../models/programme_assignment.dart';
import '../../../models/programme_vocabulary.dart';
import '../models/programme_catalog_entry.dart';
import 'enrolment_iana_timezone.dart';

enum AthleteProgrammeContinuityStatus {
  none,
  currentDefault,
  currentPinned,
  currentPinnedWithDifferentAvailable,
  pinnedUnavailable,
  completed,
}

enum AssignmentTimezoneHealth { valid, repairRequired }

/// Shared pin-versus-catalogue-default projection.
class AthleteProgrammeContinuity {
  const AthleteProgrammeContinuity({
    required this.status,
    required this.timezoneHealth,
    this.pinnedVersionId,
    this.pinnedTitle,
    this.catalogueDefaultVersionId,
    this.lineageCode,
  });

  final AthleteProgrammeContinuityStatus status;
  final AssignmentTimezoneHealth timezoneHealth;
  final String? pinnedVersionId;
  final String? pinnedTitle;
  final String? catalogueDefaultVersionId;
  final String? lineageCode;

  bool get isPinnedUnavailable =>
      status == AthleteProgrammeContinuityStatus.pinnedUnavailable;

  bool get needsTimezoneRepair =>
      timezoneHealth == AssignmentTimezoneHealth.repairRequired;

  bool get canLaunchPinnedSession =>
      !isPinnedUnavailable &&
      !needsTimezoneRepair &&
      (status == AthleteProgrammeContinuityStatus.currentDefault ||
          status == AthleteProgrammeContinuityStatus.currentPinned ||
          status ==
              AthleteProgrammeContinuityStatus
                  .currentPinnedWithDifferentAvailable);

  static AssignmentTimezoneHealth timezoneHealthFor(String? timezone) {
    return EnrolmentIanaTimezone.isValidIdentifier(timezone)
        ? AssignmentTimezoneHealth.valid
        : AssignmentTimezoneHealth.repairRequired;
  }

  static String? catalogueDefaultVersionIdFor({
    required String? lineageCode,
    required Iterable<ProgrammeCatalogEntry> catalogue,
  }) {
    final code = lineageCode?.trim() ?? '';
    if (code.isEmpty) return null;
    final matches = catalogue
        .where((entry) => entry.lineageCode == code && _isEligible(entry))
        .toList(growable: false);
    if (matches.length != 1) return null;
    return matches.single.versionId;
  }

  static AthleteProgrammeContinuity project({
    ProgrammeAssignment? assignment,
    String? pinnedTitle,
    bool pinResolvable = true,
    required Iterable<ProgrammeCatalogEntry> catalogue,
    bool executionUnavailable = false,
  }) {
    if (assignment == null) {
      return const AthleteProgrammeContinuity(
        status: AthleteProgrammeContinuityStatus.none,
        timezoneHealth: AssignmentTimezoneHealth.valid,
      );
    }

    final tz = timezoneHealthFor(assignment.timezone);
    if (assignment.status == ProgrammeAssignmentStatus.completed) {
      return AthleteProgrammeContinuity(
        status: AthleteProgrammeContinuityStatus.completed,
        timezoneHealth: tz,
        pinnedVersionId: assignment.programmeVersionId,
        pinnedTitle: pinnedTitle,
        lineageCode: assignment.lineageCode,
        catalogueDefaultVersionId: catalogueDefaultVersionIdFor(
          lineageCode: assignment.lineageCode,
          catalogue: catalogue,
        ),
      );
    }

    if (!pinResolvable || executionUnavailable) {
      return AthleteProgrammeContinuity(
        status: AthleteProgrammeContinuityStatus.pinnedUnavailable,
        timezoneHealth: tz,
        pinnedVersionId: assignment.programmeVersionId,
        pinnedTitle: pinnedTitle,
        lineageCode: assignment.lineageCode,
        catalogueDefaultVersionId: catalogueDefaultVersionIdFor(
          lineageCode: assignment.lineageCode,
          catalogue: catalogue,
        ),
      );
    }

    final defaultId = catalogueDefaultVersionIdFor(
      lineageCode: assignment.lineageCode,
      catalogue: catalogue,
    );
    final pin = assignment.programmeVersionId;
    if (defaultId != null && defaultId == pin) {
      return AthleteProgrammeContinuity(
        status: AthleteProgrammeContinuityStatus.currentDefault,
        timezoneHealth: tz,
        pinnedVersionId: pin,
        pinnedTitle: pinnedTitle,
        catalogueDefaultVersionId: defaultId,
        lineageCode: assignment.lineageCode,
      );
    }

    final differentAvailable = defaultId != null && defaultId != pin;
    return AthleteProgrammeContinuity(
      status: differentAvailable
          ? AthleteProgrammeContinuityStatus.currentPinnedWithDifferentAvailable
          : AthleteProgrammeContinuityStatus.currentPinned,
      timezoneHealth: tz,
      pinnedVersionId: pin,
      pinnedTitle: pinnedTitle,
      catalogueDefaultVersionId: defaultId,
      lineageCode: assignment.lineageCode,
    );
  }

  static AthleteProgrammeContinuityStatus catalogCardStatus({
    required String versionId,
    required String? activeVersionId,
    required String? catalogueDefaultVersionId,
    required bool catalogueEligible,
  }) {
    if (activeVersionId != null && activeVersionId == versionId) {
      if (catalogueDefaultVersionId == versionId) {
        return AthleteProgrammeContinuityStatus.currentDefault;
      }
      return AthleteProgrammeContinuityStatus.currentPinned;
    }
    if (!catalogueEligible) {
      return AthleteProgrammeContinuityStatus.pinnedUnavailable;
    }
    return AthleteProgrammeContinuityStatus.none;
  }

  static bool _isEligible(ProgrammeCatalogEntry entry) {
    return entry.lifecycleStatus == ProgrammeLifecycleStatus.published &&
        entry.approvedForGlobal &&
        entry.archivedAt == null &&
        !entry.hasBlockingValidationErrors;
  }
}
