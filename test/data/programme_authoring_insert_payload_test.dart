import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgrammeLineage insert payload', () {
    test('includes created_by for authenticated coach ownership', () {
      const coachId = '550e8400-e29b-41d4-a716-446655440000';

      final payload = ProgrammeLineage(
        id: '',
        code: 'PROG-TEST-001',
        createdBy: coachId,
      ).toInsertMap();

      expect(payload['code'], 'PROG-TEST-001');
      expect(payload['created_by'], coachId);
      expect(payload.containsKey('id'), isFalse);
    });
  });

  group('Programme version draft ownership fields', () {
    test('coach draft insert map carries owner_id for RLS', () {
      const coachId = '550e8400-e29b-41d4-a716-446655440000';

      final payload = ProgrammeVersion(
        id: '',
        lineageId: '660e8400-e29b-41d4-a716-446655440001',
        versionNumber: 1,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        libraryScope: ProgrammeLibraryScope.coachPrivate,
        ownerType: ProgrammeOwnerType.coach,
        ownerId: coachId,
        name: 'Test Programme',
        approvedForGlobal: false,
        approvedForAdaptation: false,
      ).toInsertMap();

      expect(payload['owner_type'], 'coach');
      expect(payload['owner_id'], coachId);
      expect(payload['library_scope'], 'coach_private');
      expect(payload['lifecycle_status'], 'draft');
    });
  });

  group('Programme version day insert payload', () {
    test('includes week_id for ownership chain RLS checks', () {
      const weekId = '770e8400-e29b-41d4-a716-446655440002';

      final payload = ProgrammeVersionDay(
        id: '',
        weekId: weekId,
        dayKey: 'day_1',
        dayOrder: 1,
      ).toInsertMap();

      expect(payload['week_id'], weekId);
      expect(payload['day_key'], 'day_1');
      expect(payload.containsKey('id'), isFalse);
    });
  });
}
