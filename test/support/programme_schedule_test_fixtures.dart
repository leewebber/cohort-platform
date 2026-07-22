import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';

/// Shared programme schedule fixtures using persisted UUID ids so in-memory
/// stores do not remap slot/day/week ids during saveTemplateTree.
class ProgrammeScheduleTestFixtures {
  static const versionId = 'version-1';
  static const lineageId = 'lineage-1';
  static const week1Id = '00000000-0000-4000-8000-000000000011';
  static const week2Id = '00000000-0000-4000-8000-000000000012';
  static const day1Id = '00000000-0000-4000-8000-000000000101';
  static const day2Id = '00000000-0000-4000-8000-000000000102';
  static const day3Id = '00000000-0000-4000-8000-000000000103';
  static const day4Id = '00000000-0000-4000-8000-000000000104';
  static const day5Id = '00000000-0000-4000-8000-000000000105';
  static const slot1Id = '00000000-0000-4000-8000-000000000001';
  static const slot2Id = '00000000-0000-4000-8000-000000000002';
  static const slot3Id = '00000000-0000-4000-8000-000000000003';
  static const slot4Id = '00000000-0000-4000-8000-000000000004';
  static const slot5Id = '00000000-0000-4000-8000-000000000005';
  static const assignmentId = 'assignment-1';

  static ProgrammeTemplateTree foundationWeekOneTree({
    String programmeVersionId = versionId,
  }) {
    return twoWeekTree(
      versionIdParam: programmeVersionId,
      weekOneDays: [
        trainingDay(
          id: day1Id,
          weekId: week1Id,
          dayKey: 'day_1',
          dayOrder: 1,
          slots: [
            requiredSlot(
              id: slot1Id,
              dayId: day1Id,
              sessionOrder: 1,
              protocolId: 'BW-001',
            ),
          ],
        ),
        trainingDay(
          id: day2Id,
          weekId: week1Id,
          dayKey: 'day_2',
          dayOrder: 2,
          slots: [
            requiredSlot(
              id: slot2Id,
              dayId: day2Id,
              sessionOrder: 1,
              protocolId: 'RN-006',
            ),
          ],
        ),
        restDay(
          id: day3Id,
          weekId: week1Id,
          dayKey: 'day_3',
          dayOrder: 3,
        ),
        trainingDay(
          id: day4Id,
          weekId: week1Id,
          dayKey: 'day_4',
          dayOrder: 4,
          slots: [
            requiredSlot(
              id: slot4Id,
              dayId: day4Id,
              sessionOrder: 1,
              protocolId: 'FG-009',
            ),
          ],
        ),
      ],
    );
  }

  static ProgrammeTemplateTree twoSlotDayTree() {
    return singleWeekTree(
      days: [
        trainingDay(
          id: day1Id,
          weekId: week1Id,
          dayKey: 'day_1',
          dayOrder: 1,
          slots: [
            requiredSlot(
              id: slot1Id,
              dayId: day1Id,
              sessionOrder: 1,
              protocolId: 'BW-001',
            ),
            requiredSlot(
              id: slot2Id,
              dayId: day1Id,
              sessionOrder: 2,
              protocolId: 'RN-006',
            ),
          ],
        ),
      ],
    );
  }

  static ProgrammeTemplateTree optionalSlotDayTree() {
    return singleWeekTree(
      days: [
        trainingDay(
          id: day1Id,
          weekId: week1Id,
          dayKey: 'day_1',
          dayOrder: 1,
          slots: [
            requiredSlot(
              id: slot1Id,
              dayId: day1Id,
              sessionOrder: 1,
              protocolId: 'BW-001',
            ),
            optionalSlot(
              id: slot2Id,
              dayId: day1Id,
              sessionOrder: 2,
              protocolId: 'FG-009',
            ),
          ],
        ),
        trainingDay(
          id: day2Id,
          weekId: week1Id,
          dayKey: 'day_2',
          dayOrder: 2,
          slots: [
            requiredSlot(
              id: slot3Id,
              dayId: day2Id,
              sessionOrder: 1,
              protocolId: 'RN-006',
            ),
          ],
        ),
      ],
    );
  }

  static ProgrammeTemplateTree twoWeekTree({
    required List<ProgrammeTemplateDayNode> weekOneDays,
    List<ProgrammeTemplateDayNode>? weekTwoDays,
    String versionIdParam = versionId,
  }) {
    final weekOne = ProgrammeVersionWeek(
      id: week1Id,
      versionId: versionIdParam,
      weekNumber: 1,
      title: 'Week 1',
    );
    final weekTwo = ProgrammeVersionWeek(
      id: week2Id,
      versionId: versionIdParam,
      weekNumber: 2,
      title: 'Week 2',
    );

    return ProgrammeTemplateTree(
      template: ProgrammeTemplate(
        version: version().copyWith(id: versionIdParam),
        weeks: [weekOne, weekTwo],
      ),
      weekNodes: [
        ProgrammeTemplateWeekNode(week: weekOne, days: weekOneDays),
        ProgrammeTemplateWeekNode(
          week: weekTwo,
          days: weekTwoDays ??
              [
                trainingDay(
                  id: day5Id,
                  weekId: week2Id,
                  dayKey: 'day_1',
                  dayOrder: 1,
                  slots: [
                    requiredSlot(
                      id: slot5Id,
                      dayId: day5Id,
                      sessionOrder: 1,
                      protocolId: 'BW-001',
                    ),
                  ],
                ),
              ],
        ),
      ],
    );
  }

  static ProgrammeTemplateTree singleWeekTree({
    required List<ProgrammeTemplateDayNode> days,
    String programmeVersionId = versionId,
  }) {
    final week = ProgrammeVersionWeek(
      id: week1Id,
      versionId: programmeVersionId,
      weekNumber: 1,
    );

    return ProgrammeTemplateTree(
      template: ProgrammeTemplate(
        version: version().copyWith(id: programmeVersionId),
        weeks: [week],
      ),
      weekNodes: [ProgrammeTemplateWeekNode(week: week, days: days)],
    );
  }

  static ProgrammeVersion version() {
    return ProgrammeVersion(
      id: versionId,
      lineageId: lineageId,
      versionNumber: 1,
      lifecycleStatus: ProgrammeLifecycleStatus.draft,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      name: 'Cohort Foundation Test',
    );
  }

  static ProgrammeAssignment assignment({
    int week = 1,
    String dayKey = 'day_1',
    int slotOrder = 1,
    String athleteId = 'lee',
    String? id,
    String? programmeVersionId,
  }) {
    return ProgrammeAssignment(
      id: id ?? assignmentId,
      athleteId: athleteId,
      programmeVersionId: programmeVersionId ?? versionId,
      lineageCode: 'COHORT-FOUNDATION-TEST',
      status: ProgrammeAssignmentStatus.active,
      startedAt: DateTime.utc(2026, 7, 15),
      currentWeek: week,
      currentDayKey: dayKey,
      currentSessionOrder: slotOrder,
    );
  }

  static ProgrammeTemplateDayNode trainingDay({
    required String id,
    required String weekId,
    required String dayKey,
    required int dayOrder,
    required List<ProgrammeVersionSessionSlot> slots,
    String? title,
  }) {
    return ProgrammeTemplateDayNode(
      day: ProgrammeVersionDay(
        id: id,
        weekId: weekId,
        dayKey: dayKey,
        dayOrder: dayOrder,
        title: title,
        dayType: ProgrammeDayType.training,
      ),
      slots: slots,
    );
  }

  static ProgrammeTemplateDayNode restDay({
    required String id,
    required String weekId,
    required String dayKey,
    required int dayOrder,
  }) {
    return ProgrammeTemplateDayNode(
      day: ProgrammeVersionDay(
        id: id,
        weekId: weekId,
        dayKey: dayKey,
        dayOrder: dayOrder,
        title: 'Rest',
        dayType: ProgrammeDayType.rest,
      ),
      slots: const [],
    );
  }

  static ProgrammeVersionSessionSlot requiredSlot({
    required String id,
    required String dayId,
    required int sessionOrder,
    required String protocolId,
    String? displayTitle,
  }) {
    return ProgrammeVersionSessionSlot(
      id: id,
      dayId: dayId,
      sessionOrder: sessionOrder,
      protocolId: protocolId,
      displayTitle: displayTitle,
    );
  }

  static ProgrammeVersionSessionSlot optionalSlot({
    required String id,
    required String dayId,
    required int sessionOrder,
    required String protocolId,
  }) {
    return ProgrammeVersionSessionSlot(
      id: id,
      dayId: dayId,
      sessionOrder: sessionOrder,
      protocolId: protocolId,
      isOptional: true,
      completionExpectation: ProgrammeSessionCompletionExpectation.optional,
    );
  }

  static ProgrammeSlotOutcome outcome({
    required String slotId,
    required ProgrammeSlotOutcomeStatus status,
    String? assignmentId,
    String? replacementProtocolId,
    int weekNumber = 1,
    String dayKey = 'day_1',
    int sessionOrder = 1,
  }) {
    return ProgrammeSlotOutcome(
      id: 'outcome-$slotId',
      assignmentId: assignmentId ?? ProgrammeScheduleTestFixtures.assignmentId,
      sessionSlotId: slotId,
      weekNumber: weekNumber,
      dayKey: dayKey,
      sessionOrder: sessionOrder,
      outcomeStatus: status,
      replacementProtocolId: replacementProtocolId,
    );
  }
}
