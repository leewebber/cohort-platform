import 'package:cohort_platform/features/home/debug/home_debug_programme_refresh_policy.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/programme_progression_result.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProgrammeAssignmentOperationResult assignmentResult(
    ProgrammeAssignmentOperationStatus status, {
    ProgrammeAssignment? assignment,
  }) {
    return ProgrammeAssignmentOperationResult(
      status: status,
      assignment: assignment,
    );
  }

  group('HomeDebugProgrammeRefreshPolicy', () {
    ProgrammeAssignment activeAssignment() {
      return ProgrammeAssignment(
        id: 'assignment-1',
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        status: ProgrammeAssignmentStatus.active,
        startedAt: DateTime.utc(2026, 7, 15),
      );
    }

    test('assign success statuses request refresh', () {
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(
          assignmentResult(
            ProgrammeAssignmentOperationStatus.assigned,
            assignment: activeAssignment(),
          ),
        ),
        isTrue,
      );
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(
          assignmentResult(
            ProgrammeAssignmentOperationStatus.replaced,
            assignment: activeAssignment(),
          ),
        ),
        isTrue,
      );
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(
          assignmentResult(
            ProgrammeAssignmentOperationStatus.partialSuccess,
            assignment: activeAssignment(),
          ),
        ),
        isTrue,
      );
    });

    test('assign conflict and failure do not request refresh', () {
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(
          assignmentResult(ProgrammeAssignmentOperationStatus.failed),
        ),
        isFalse,
      );
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(
          assignmentResult(
            ProgrammeAssignmentOperationStatus.alreadyActiveConflict,
            assignment: activeAssignment(),
          ),
        ),
        isFalse,
      );
    });

    test('reset success statuses request refresh', () {
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(
          assignmentResult(
            ProgrammeAssignmentOperationStatus.assigned,
            assignment: activeAssignment(),
          ),
        ),
        isTrue,
      );
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(
          assignmentResult(
            ProgrammeAssignmentOperationStatus.partialSuccess,
            assignment: activeAssignment(),
          ),
        ),
        isTrue,
      );
    });

    test('failed reset does not request refresh', () {
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(
          ProgrammeAssignmentOperationResult.failed(message: 'DELETE removed 0 rows'),
        ),
        isFalse,
      );
    });

    test('progression success requests refresh', () {
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterProgression(
          ProgrammeProgressionResult(
            status: ProgrammeProgressionStatus.completed,
            updatedAssignment: activeAssignment().copyWith(currentDayKey: 'day_2'),
          ),
        ),
        isTrue,
      );
    });

    test('read-only resolve has no refresh policy hook', () {
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(
          assignmentResult(ProgrammeAssignmentOperationStatus.noAssignment),
        ),
        isFalse,
      );
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(
          assignmentResult(ProgrammeAssignmentOperationStatus.noAssignment),
        ),
        isFalse,
      );
    });
  });
}
