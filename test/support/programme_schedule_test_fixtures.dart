import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';

class ProgrammeScheduleTestFixtures {
  static ProgrammeTemplateTree foundationWeekOneTree({
    String versionId = 'version-1',
  }) {
    return twoWeekTree(
      versionId: versionId,
      weekOneDays: [
        trainingDay(
          id: 'day-1',
          weekId: 'week-1',
          dayKey: 'day_1',
          dayOrder: 1,
          slots: [
            requiredSlot(
              id: 'slot-1',
              dayId: 'day-1',
              sessionOrder: 1,
              protocolId: 'BW-001',
            ),
          ],
        ),
        trainingDay(
          id: 'day-2',
          weekId: 'week-1',
          dayKey: 'day_2',
          dayOrder: 2,
          slots: [
            requiredSlot(
              id: 'slot-2',
              dayId: 'day-2',
              sessionOrder: 1,
              protocolId: 'RN-006',
            ),
          ],
        ),
        restDay(
          id: 'day-3',
          weekId: 'week-1',
          dayKey: 'day_3',
          dayOrder: 3,
        ),
        trainingDay(
          id: 'day-4',
          weekId: 'week-1',
          dayKey: 'day_4',
          dayOrder: 4,
          slots: [
            requiredSlot(
              id: 'slot-4',
              dayId: 'day-4',
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
          id: 'day-1',
          weekId: 'week-1',
          dayKey: 'day_1',
          dayOrder: 1,
          slots: [
            requiredSlot(
              id: 'slot-1',
              dayId: 'day-1',
              sessionOrder: 1,
              protocolId: 'BW-001',
            ),
            requiredSlot(
              id: 'slot-2',
              dayId: 'day-1',
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
          id: 'day-1',
          weekId: 'week-1',
          dayKey: 'day_1',
          dayOrder: 1,
          slots: [
            requiredSlot(
              id: 'slot-1',
              dayId: 'day-1',
              sessionOrder: 1,
              protocolId: 'BW-001',
            ),
            optionalSlot(
              id: 'slot-2',
              dayId: 'day-1',
              sessionOrder: 2,
              protocolId: 'FG-009',
            ),
          ],
        ),
        trainingDay(
          id: 'day-2',
          weekId: 'week-1',
          dayKey: 'day_2',
          dayOrder: 2,
          slots: [
            requiredSlot(
              id: 'slot-3',
              dayId: 'day-2',
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
    String versionId = 'version-1',
  }) {
    final weekOne = ProgrammeVersionWeek(
      id: 'week-1',
      versionId: versionId,
      weekNumber: 1,
      title: 'Week 1',
    );
    final weekTwo = ProgrammeVersionWeek(
      id: 'week-2',
      versionId: versionId,
      weekNumber: 2,
      title: 'Week 2',
    );

    return ProgrammeTemplateTree(
      template: ProgrammeTemplate(
        version: version().copyWith(id: versionId),
        weeks: [weekOne, weekTwo],
      ),
      weekNodes: [
        ProgrammeTemplateWeekNode(week: weekOne, days: weekOneDays),
        ProgrammeTemplateWeekNode(
          week: weekTwo,
          days: weekTwoDays ??
              [
                trainingDay(
                  id: 'day-5',
                  weekId: 'week-2',
                  dayKey: 'day_1',
                  dayOrder: 1,
                  slots: [
                    requiredSlot(
                      id: 'slot-5',
                      dayId: 'day-5',
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
    String versionId = 'version-1',
  }) {
    final week = ProgrammeVersionWeek(
      id: 'week-1',
      versionId: versionId,
      weekNumber: 1,
    );

    return ProgrammeTemplateTree(
      template: ProgrammeTemplate(version: version().copyWith(id: versionId), weeks: [week]),
      weekNodes: [ProgrammeTemplateWeekNode(week: week, days: days)],
    );
  }

  static ProgrammeVersion version() {
    return ProgrammeVersion(
      id: 'version-1',
      lineageId: 'lineage-1',
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
  }) {
    return ProgrammeAssignment(
      id: 'assignment-1',
      athleteId: 'lee',
      programmeVersionId: 'version-1',
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
    String assignmentId = 'assignment-1',
    String? replacementProtocolId,
    int weekNumber = 1,
    String dayKey = 'day_1',
    int sessionOrder = 1,
  }) {
    return ProgrammeSlotOutcome(
      id: 'outcome-$slotId',
      assignmentId: assignmentId,
      sessionSlotId: slotId,
      weekNumber: weekNumber,
      dayKey: dayKey,
      sessionOrder: sessionOrder,
      outcomeStatus: status,
      replacementProtocolId: replacementProtocolId,
    );
  }
}
