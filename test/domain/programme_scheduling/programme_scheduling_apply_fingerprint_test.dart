import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgrammeSchedulingApplyFingerprint', () {
    test('conformance vector matches PostgreSQL Gate N hash', () {
      final payload = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'type': 'move',
          'sessionSlotId': '11111111-1111-4111-8111-111111111111',
          'targetDate': '2026-07-05',
        },
        assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        programmeVersionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        packageContentHash: 'hash-conformance-1',
        scheduleRevision: 0,
        timezone: 'Pacific/Auckland',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: '11111111-1111-4111-8111-111111111111',
            programmedSessionKey: 'psk-1',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-05',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 0,
            protocolId: 'protocol-1',
          ),
        ],
        collidingDates: const [],
      );

      expect(
        ProgrammeSchedulingApplyFingerprint.compute(payload),
        '39d418875d9d57153fed1e8690f40021d72bf10803f5071e19b2d455984699c4',
      );
    });

    test('Push conformance vector matches PostgreSQL Gate O hash', () {
      final payload = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'type': 'push',
          'fromSessionSlotId': '11111111-1111-4111-8111-111111111111',
          'dayDelta': 2,
        },
        assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        programmeVersionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        packageContentHash: 'hash-conformance-push',
        scheduleRevision: 0,
        timezone: 'Pacific/Auckland',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: '11111111-1111-4111-8111-111111111111',
            programmedSessionKey: 'psk-push-1',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-03',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 1,
            protocolId: 'protocol-push-1',
          ),
        ],
        collidingDates: const [],
      );

      expect(
        ProgrammeSchedulingApplyFingerprint.compute(payload),
        '4b2dfec57b1db700813029778f717734c0f6d7a0f12130274dfc11b09a973a3a',
      );
    });

    test('Skip conformance vector matches PostgreSQL Gate O hash', () {
      final payload = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'type': 'skip',
          'sessionSlotId': '11111111-1111-4111-8111-111111111111',
        },
        assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        programmeVersionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        packageContentHash: 'hash-conformance-skip',
        scheduleRevision: 0,
        timezone: 'Pacific/Auckland',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: '11111111-1111-4111-8111-111111111111',
            programmedSessionKey: 'psk-skip-1',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-01',
            originalDisposition: 'scheduled',
            proposedDisposition: 'skipped',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 1,
            protocolId: 'protocol-skip-1',
          ),
        ],
        collidingDates: const [],
        cursorBefore: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: '11111111-1111-4111-8111-111111111111',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
        ),
        cursorAfter: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: '22222222-2222-4222-8222-222222222222',
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
        ),
      );

      expect(
        ProgrammeSchedulingApplyFingerprint.compute(payload),
        '60ca198c39d2625ac882b4a7d6667e2a305be1b0abfa5bff2c759e4a96a4f162',
      );
    });

    test('Undo-move conformance vector matches PostgreSQL Gate P hash', () {
      final payload = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'type': 'undo',
          'operationId': '33333333-3333-4333-8333-333333333333',
        },
        assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        programmeVersionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        packageContentHash: 'hash-conformance-undo-move',
        scheduleRevision: 1,
        timezone: 'Pacific/Auckland',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: '11111111-1111-4111-8111-111111111111',
            programmedSessionKey: 'psk-undo-move-1',
            originalDate: '2026-07-05',
            proposedDate: '2026-07-01',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 1,
            protocolId: 'protocol-undo-move-1',
          ),
        ],
        collidingDates: const [],
      );
      expect(
        ProgrammeSchedulingApplyFingerprint.compute(payload),
        'd5d7aeaf1a41d957f77ed9b29dca70446f240e18f29f445adcf56e799cab9bb5',
      );
    });

    test('Undo-skip conformance vector matches PostgreSQL Gate P hash', () {
      final payload = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'type': 'undo',
          'operationId': '33333333-3333-4333-8333-333333333333',
        },
        assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        programmeVersionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        packageContentHash: 'hash-conformance-undo-skip',
        scheduleRevision: 2,
        timezone: 'Pacific/Auckland',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: '11111111-1111-4111-8111-111111111111',
            programmedSessionKey: 'psk-undo-skip-1',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-01',
            originalDisposition: 'skipped',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 1,
            protocolId: 'protocol-undo-skip-1',
          ),
        ],
        collidingDates: const [],
        cursorBefore: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: '22222222-2222-4222-8222-222222222222',
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
        ),
        cursorAfter: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: '11111111-1111-4111-8111-111111111111',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
        ),
      );
      expect(
        ProgrammeSchedulingApplyFingerprint.compute(payload),
        'befab0de8d00747f873bc135e570c11a43731059f2ff38c893c2286be5c5a5c7',
      );
    });

    test('Move+horizon conformance vector matches PostgreSQL Gate P hash', () {
      final payload = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'type': 'move',
          'sessionSlotId': '11111111-1111-4111-8111-111111111111',
          'targetDate': '2026-07-31',
        },
        assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        programmeVersionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        packageContentHash: 'hash-conformance-horizon-move',
        scheduleRevision: 0,
        timezone: 'Pacific/Auckland',
        schedulingHorizonEnd: '2026-07-31',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: '11111111-1111-4111-8111-111111111111',
            programmedSessionKey: 'psk-horizon-1',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-31',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 1,
            protocolId: 'protocol-horizon-1',
          ),
        ],
        collidingDates: const [],
      );
      expect(
        ProgrammeSchedulingApplyFingerprint.compute(payload),
        '6dafec7ad0b1091acf9ea41743fe23292a11dfdec8f344e70855386fbb993f5f',
      );
    });

    test('Skip cursor change invalidates fingerprint', () {
      final base = ProgrammeSchedulingApplyFingerprint.payload(
        operation: const {
          'type': 'skip',
          'sessionSlotId': 'slot-1',
        },
        assignmentId: 'a1',
        programmeVersionId: 'v1',
        packageContentHash: 'h1',
        scheduleRevision: 1,
        timezone: 'UTC',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: 'slot-1',
            programmedSessionKey: 'psk-1',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-01',
            originalDisposition: 'scheduled',
            proposedDisposition: 'skipped',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 0,
            protocolId: 'p-1',
          ),
        ],
        collidingDates: const [],
        cursorBefore: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: 'slot-1',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
        ),
        cursorAfter: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: 'slot-2',
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 0,
        ),
      );
      final changed = ProgrammeSchedulingApplyFingerprint.payload(
        operation: const {
          'type': 'skip',
          'sessionSlotId': 'slot-1',
        },
        assignmentId: 'a1',
        programmeVersionId: 'v1',
        packageContentHash: 'h1',
        scheduleRevision: 1,
        timezone: 'UTC',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: 'slot-1',
            programmedSessionKey: 'psk-1',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-01',
            originalDisposition: 'scheduled',
            proposedDisposition: 'skipped',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 0,
            protocolId: 'p-1',
          ),
        ],
        collidingDates: const [],
        cursorBefore: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: 'slot-1',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
        ),
        cursorAfter: null,
      );
      expect(
        ProgrammeSchedulingApplyFingerprint.compute(base),
        isNot(ProgrammeSchedulingApplyFingerprint.compute(changed)),
      );
    });

    test('key order and collision sort are deterministic', () {
      final a = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'type': 'swap',
          'sessionSlotIdA': 'slot-b',
          'sessionSlotIdB': 'slot-a',
        },
        assignmentId: 'a1',
        programmeVersionId: 'v1',
        packageContentHash: 'h1',
        scheduleRevision: 2,
        timezone: 'UTC',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: 'slot-b',
            programmedSessionKey: 'psk-b',
            originalDate: '2026-07-02',
            proposedDate: '2026-07-01',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_2',
            sessionOrder: 0,
            protocolId: 'p-b',
          ),
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: 'slot-a',
            programmedSessionKey: 'psk-a',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-02',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 0,
            protocolId: 'p-a',
          ),
        ],
        collidingDates: const ['2026-07-03', '2026-07-01'],
      );
      final b = ProgrammeSchedulingApplyFingerprint.payload(
        operation: {
          'sessionSlotIdB': 'slot-a',
          'type': 'swap',
          'sessionSlotIdA': 'slot-b',
        },
        assignmentId: 'a1',
        programmeVersionId: 'v1',
        packageContentHash: 'h1',
        scheduleRevision: 2,
        timezone: 'UTC',
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: 'slot-a',
            programmedSessionKey: 'psk-a',
            originalDate: '2026-07-01',
            proposedDate: '2026-07-02',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 0,
            protocolId: 'p-a',
          ),
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: 'slot-b',
            programmedSessionKey: 'psk-b',
            originalDate: '2026-07-02',
            proposedDate: '2026-07-01',
            originalDisposition: 'scheduled',
            proposedDisposition: 'scheduled',
            weekNumber: 1,
            dayKey: 'day_2',
            sessionOrder: 0,
            protocolId: 'p-b',
          ),
        ],
        collidingDates: const ['2026-07-01', '2026-07-03'],
      );
      expect(
        ProgrammeSchedulingApplyFingerprint.compute(a),
        ProgrammeSchedulingApplyFingerprint.compute(b),
      );
    });
  });
}
