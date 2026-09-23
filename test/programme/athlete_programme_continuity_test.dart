import 'package:cohort_platform/features/programme/domain/athlete_programme_continuity.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

ProgrammeCatalogEntry _entry(
  String id, {
  String lineage = 'L1',
  DateTime? archivedAt,
}) {
  return ProgrammeCatalogEntry(
    versionId: id,
    lineageCode: lineage,
    versionNumber: 1,
    name: 'Name $id',
    lifecycleStatus: ProgrammeLifecycleStatus.published,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    approvedForGlobal: true,
    archivedAt: archivedAt,
  );
}

ProgrammeAssignment _assignment({
  required String versionId,
  String timezone = 'Europe/London',
  ProgrammeAssignmentStatus status = ProgrammeAssignmentStatus.active,
}) {
  return ProgrammeAssignment(
    id: 'a1',
    athleteId: 'ath',
    programmeVersionId: versionId,
    lineageCode: 'L1',
    status: status,
    startedAt: DateTime(2026, 9, 23),
    timezone: timezone,
  );
}

void main() {
  test('current default', () {
    final continuity = AthleteProgrammeContinuity.project(
      assignment: _assignment(versionId: 'v1'),
      pinnedTitle: 'Pinned',
      catalogue: [_entry('v1')],
    );
    expect(continuity.status, AthleteProgrammeContinuityStatus.currentDefault);
    expect(continuity.pinnedTitle, 'Pinned');
    expect(continuity.canLaunchPinnedSession, isTrue);
  });

  test('current pinned with different available', () {
    final continuity = AthleteProgrammeContinuity.project(
      assignment: _assignment(versionId: 'v1'),
      pinnedTitle: 'Old',
      catalogue: [_entry('v2')],
    );
    expect(
      continuity.status,
      AthleteProgrammeContinuityStatus.currentPinnedWithDifferentAvailable,
    );
    expect(continuity.catalogueDefaultVersionId, 'v2');
    expect(continuity.pinnedTitle, 'Old');
  });

  test('pinned unavailable', () {
    final continuity = AthleteProgrammeContinuity.project(
      assignment: _assignment(versionId: 'v1'),
      pinResolvable: false,
      catalogue: [_entry('v2')],
    );
    expect(
      continuity.status,
      AthleteProgrammeContinuityStatus.pinnedUnavailable,
    );
    expect(continuity.canLaunchPinnedSession, isFalse);
  });

  test('abbreviation timezone is repair required', () {
    final continuity = AthleteProgrammeContinuity.project(
      assignment: _assignment(versionId: 'v1', timezone: 'BST'),
      catalogue: [_entry('v1')],
    );
    expect(continuity.needsTimezoneRepair, isTrue);
    expect(continuity.canLaunchPinnedSession, isFalse);
  });

  test('does not mix newer catalogue title onto the pin', () {
    final continuity = AthleteProgrammeContinuity.project(
      assignment: _assignment(versionId: 'v1'),
      pinnedTitle: 'Started title',
      catalogue: [_entry('v2')],
    );
    expect(continuity.pinnedTitle, 'Started title');
    expect(continuity.catalogueDefaultVersionId, 'v2');
  });
}
