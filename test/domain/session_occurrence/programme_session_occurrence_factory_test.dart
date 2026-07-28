import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = ProgrammeSessionOccurrenceFactory();
  final plannedDate = SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 8, 1));
  final t0 = DateTime.utc(2026, 7, 28, 12);

  ProgrammeScheduledSlotInput input({
    String assignmentId = 'asgn-1',
    String slotId = 'slot-1',
    String protocolId = 'proto-1',
    String athleteId = 'athlete-1',
  }) {
    return ProgrammeScheduledSlotInput(
      programmeAssignmentId: assignmentId,
      programmeSessionSlotId: slotId,
      athleteId: athleteId,
      sourceSessionId: protocolId,
      plannedDate: plannedDate,
    );
  }

  group('ProgrammeSessionOccurrenceFactory', () {
    test('creates occurrence with programme references and deterministic id', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      final result = factory.createFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );

      expect(result.isSuccess, isTrue);
      final occurrence = result.occurrence!;
      expect(
        occurrence.occurrenceId,
        SessionOccurrenceId.forProgrammeSlot(
          ProgrammeSessionOccurrenceKey(
            programmeAssignmentId: 'asgn-1',
            programmeSessionSlotId: 'slot-1',
          ),
        ),
      );
      expect(occurrence.programmeAssignmentId, 'asgn-1');
      expect(occurrence.programmeSessionSlotId, 'slot-1');
      expect(occurrence.sourceSessionId, 'proto-1');
      expect(occurrence.originalPlannedDate, plannedDate);
      expect(occurrence.plannedDate, plannedDate);
      expect(occurrence.lifecycleState, SessionOccurrenceLifecycleState.scheduled);
    });

    test('registers occurrence for duplicate prevention', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      factory.createFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );
      expect(registry.containsSlot(input().slotKey), isTrue);
    });

    test('rejects duplicate slot occurrence', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      factory.createFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );
      final duplicate = factory.createFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );
      expect(duplicate.isSuccess, isFalse);
      expect(
        duplicate.issues.first.code,
        ProgrammeSessionOccurrenceCreationIssueCode.duplicateSlotOccurrence,
      );
    });

    test('rejects source session conflict on same slot key', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      factory.createFromScheduledSlot(
        input: input(protocolId: 'proto-a'),
        recordedAt: t0,
        registry: registry,
      );
      final conflict = factory.createFromScheduledSlot(
        input: input(protocolId: 'proto-b'),
        recordedAt: t0,
        registry: registry,
      );
      expect(
        conflict.issues.first.code,
        ProgrammeSessionOccurrenceCreationIssueCode.sourceSessionConflict,
      );
    });

    test('ensure is idempotent for same slot', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      final first = factory.ensureFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );
      final second = factory.ensureFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );
      expect(first.occurrence, equals(second.occurrence));
      expect(registry.occurrences.length, 1);
    });

    test('rejects invalid assignment id', () {
      final result = factory.createFromScheduledSlot(
        input: input(assignmentId: '  '),
        recordedAt: t0,
        registry: ProgrammeSessionOccurrenceRegistry(),
      );
      expect(
        result.issues.first.code,
        ProgrammeSessionOccurrenceCreationIssueCode.invalidAssignmentId,
      );
    });

    test('rejects invalid source session id', () {
      final result = factory.createFromScheduledSlot(
        input: input(protocolId: ''),
        recordedAt: t0,
        registry: ProgrammeSessionOccurrenceRegistry(),
      );
      expect(
        result.issues.first.code,
        ProgrammeSessionOccurrenceCreationIssueCode.invalidSourceSessionId,
      );
    });

    test('created occurrence satisfies aggregate invariants', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      final occurrence = factory
          .createFromScheduledSlot(
            input: input(),
            recordedAt: t0,
            registry: registry,
          )
          .occurrence!;
      final started = occurrence.startInProgress(recordedAt: t0);
      expect(started.isSuccess, isTrue);
    });

    test('factory does not mutate registry on failure', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      factory.createFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );
      factory.createFromScheduledSlot(
        input: input(),
        recordedAt: t0,
        registry: registry,
      );
      expect(registry.occurrences.length, 1);
    });

    test('transitions return new immutable instances', () {
      final registry = ProgrammeSessionOccurrenceRegistry();
      final original = factory
          .createFromScheduledSlot(
            input: input(),
            recordedAt: t0,
            registry: registry,
          )
          .occurrence!;
      final updated = original.startInProgress(recordedAt: t0).occurrence!;
      expect(identical(original, updated), isFalse);
      expect(registry.occurrenceForSlot(input().slotKey), original);
    });
  });

  group('ProgrammeSessionOccurrenceKey', () {
    test('equality by assignment and slot id', () {
      const a = ProgrammeSessionOccurrenceKey(
        programmeAssignmentId: 'asgn-1',
        programmeSessionSlotId: 'slot-1',
      );
      const b = ProgrammeSessionOccurrenceKey(
        programmeAssignmentId: 'asgn-1',
        programmeSessionSlotId: 'slot-1',
      );
      const c = ProgrammeSessionOccurrenceKey(
        programmeAssignmentId: 'asgn-1',
        programmeSessionSlotId: 'slot-2',
      );
      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });
}
