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
