import '../../../models/programme_version.dart';
import '../../programme/models/programme_template.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_template_draft.dart';
import '../models/programme_version_draft_metadata.dart';
import '../models/programme_builder_constants.dart';
import '../../../models/programme_day_draft.dart';
import '../../../models/programme_session_slot_draft.dart';
import '../../../models/programme_week_draft.dart';
import '../../../models/programme_version_day.dart';
import '../../../models/programme_version_session_slot.dart';
import '../../../models/programme_version_week.dart';

/// Compiles [ProgrammeBuilderDocument] to engine [ProgrammeTemplateTree] and back.
///
/// No Supabase writes. See `44_Programme_Builder.md`.
class ProgrammeBuilderCompiler {
  const ProgrammeBuilderCompiler();

  static final _lineageCodePattern = RegExp(r'^[A-Z0-9][A-Z0-9-]{2,}$');
  static final _dayKeyPattern = RegExp(r'^day_[1-9][0-9]*$');

  /// Ensures every nested node has a non-empty [localId].
  ProgrammeTemplateDraft assignLocalIds(ProgrammeTemplateDraft template) {
    return ProgrammeTemplateDraft(
      weeks: template.weeks
          .map((week) => week.copyWith(localId: _ensureId(week.localId)))
          .map(
            (week) => week.copyWith(
              days: week.days
                  .map((day) => day.copyWith(localId: _ensureId(day.localId)))
                  .map(
                    (day) => day.copyWith(
                      slots: day.slots
                          .map(
                            (slot) => slot.copyWith(
                              localId: _ensureId(slot.localId),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      phases: template.phases,
    );
  }

  ProgrammeVersion toVersionRow(ProgrammeVersionDraftMetadata metadata) {
    return ProgrammeVersion(
      id: metadata.versionId ?? '',
      lineageId: metadata.lineageId ?? '',
      versionNumber: metadata.versionNumber,
      lifecycleStatus: metadata.lifecycleStatus,
      libraryScope: metadata.libraryScope,
      ownerType: metadata.ownerType,
      ownerId: metadata.ownerId,
      name: metadata.name,
      description: metadata.description,
      durationWeeks: metadata.durationWeeks,
      targetAthlete: metadata.targetAthlete,
      difficulty: metadata.difficulty,
      primaryGoal: metadata.primaryGoal,
      equipmentRequirements: metadata.equipmentRequirements,
      sessionsPerWeek: metadata.sessionsPerWeek,
      updatedAt: metadata.updatedAt,
    );
  }

  ProgrammeTemplateTree toTemplateTree(ProgrammeBuilderDocument document) {
    final metadata = document.metadata;
    final version = toVersionRow(metadata);
    final normalized = assignLocalIds(document.template);

    final weekNodes = normalized.allWeeks.map((weekDraft) {
      final weekId = weekDraft.localId;
      final week = ProgrammeVersionWeek(
        id: weekId,
        versionId: version.id,
        weekNumber: weekDraft.weekNumber,
        title: weekDraft.title,
        intent: weekDraft.intent,
        coachNote: weekDraft.coachNote,
        athleteNote: weekDraft.athleteNote,
      );

      final days = weekDraft.days.map((dayDraft) {
        final dayId = dayDraft.localId;
        final day = ProgrammeVersionDay(
          id: dayId,
          weekId: weekId,
          dayKey: dayDraft.dayKey,
          dayOrder: dayDraft.dayOrder,
          title: dayDraft.title,
          dayType: dayDraft.dayType,
          intent: dayDraft.intent,
          coachNote: dayDraft.coachNote,
          athleteNote: dayDraft.athleteNote,
        );

        final slots = dayDraft.slots.map((slotDraft) {
          final protocolId = ProgrammeBuilderConstants.isUnassignedProtocolId(
            slotDraft.protocolId,
          )
              ? ProgrammeBuilderConstants.unassignedProtocolId
              : slotDraft.protocolId;
          return ProgrammeVersionSessionSlot(
            id: slotDraft.localId,
            dayId: dayId,
            sessionOrder: slotDraft.sessionOrder,
            protocolId: protocolId,
            displayTitle: slotDraft.displayTitle,
            timeOfDay: slotDraft.timeOfDay,
            isOptional: slotDraft.isOptional,
            completionExpectation: slotDraft.completionExpectation,
            coachNote: slotDraft.coachNote,
            athleteNote: slotDraft.athleteNote,
          );
        }).toList();

        return ProgrammeTemplateDayNode(day: day, slots: slots);
      }).toList();

      return ProgrammeTemplateWeekNode(week: week, days: days);
    }).toList();

    return ProgrammeTemplateTree(
      template: ProgrammeTemplate(version: version, weeks: []),
      weekNodes: weekNodes,
    );
  }

  ProgrammeBuilderDocument fromTemplateTree({
    required ProgrammeTemplateTree tree,
    required ProgrammeVersionDraftMetadata metadata,
    DateTime? lastSavedAt,
    int saveGeneration = 0,
  }) {
    final weeks = tree.weekNodes.map((weekNode) {
      final week = weekNode.week;
      return ProgrammeWeekDraft(
        localId: week.id,
        weekNumber: week.weekNumber,
        title: week.title,
        intent: week.intent,
        coachNote: week.coachNote,
        athleteNote: week.athleteNote,
        days: weekNode.sortedDays.map((dayNode) {
          final day = dayNode.day;
          return ProgrammeDayDraft(
            localId: day.id,
            dayKey: day.dayKey,
            dayOrder: day.dayOrder,
            title: day.title,
            dayType: day.dayType,
            intent: day.intent,
            coachNote: day.coachNote,
            athleteNote: day.athleteNote,
            slots: dayNode.sortedSlots.map((slot) {
              final protocolId =
                  ProgrammeBuilderConstants.isUnassignedProtocolId(slot.protocolId)
                      ? ''
                      : slot.protocolId;
              return ProgrammeSessionSlotDraft(
                localId: slot.id,
                sessionOrder: slot.sessionOrder,
                protocolId: protocolId,
                displayTitle: slot.displayTitle,
                timeOfDay: slot.timeOfDay,
                isOptional: slot.isOptional,
                completionExpectation: slot.completionExpectation,
                coachNote: slot.coachNote,
                athleteNote: slot.athleteNote,
              );
            }).toList(),
          );
        }).toList(),
      );
    }).toList();

    final hydratedMetadata = metadata.copyWith(
      versionId: tree.template.version.id.isEmpty
          ? metadata.versionId
          : tree.template.version.id,
      lineageId: tree.template.version.lineageId.isEmpty
          ? metadata.lineageId
          : tree.template.version.lineageId,
      versionNumber: tree.template.version.versionNumber,
      lifecycleStatus: tree.template.version.lifecycleStatus,
      libraryScope: tree.template.version.libraryScope,
      ownerType: tree.template.version.ownerType,
      ownerId: tree.template.version.ownerId,
      name: tree.template.version.name,
      description: tree.template.version.description,
      durationWeeks: tree.template.version.durationWeeks,
      targetAthlete: tree.template.version.targetAthlete,
      difficulty: tree.template.version.difficulty,
      primaryGoal: tree.template.version.primaryGoal,
      equipmentRequirements: tree.template.version.equipmentRequirements,
      sessionsPerWeek: tree.template.version.sessionsPerWeek,
      updatedAt: tree.template.version.updatedAt,
    );

    return ProgrammeBuilderDocument.clean(
      metadata: hydratedMetadata,
      template: ProgrammeTemplateDraft(weeks: weeks),
      lastSavedAt: lastSavedAt,
      saveGeneration: saveGeneration,
    );
  }

  bool isValidLineageCode(String code) {
    return _lineageCodePattern.hasMatch(code.trim());
  }

  bool isValidDayKey(String dayKey) {
    return _dayKeyPattern.hasMatch(dayKey.trim());
  }

  String _ensureId(String id) {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) return trimmed;

    return 'local-${DateTime.now().microsecondsSinceEpoch}';
  }
}
