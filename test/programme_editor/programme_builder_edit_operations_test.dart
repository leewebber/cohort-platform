import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_edit_operations.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const operations = ProgrammeBuilderEditOperations();

  ProgrammeBuilderDocument sampleDocument({
    String protocolId = '',
    int weekCount = 1,
    int dayCount = 1,
    int slotCount = 1,
  }) {
    return ProgrammeBuilderDocument.clean(
      metadata: const ProgrammeVersionDraftMetadata(
        versionId: 'version-1',
        lineageId: 'lineage-1',
        lineageCode: 'COHORT-TEST',
        versionNumber: 1,
        name: 'Foundation Test',
      ),
      template: ProgrammeTemplateDraft(
        weeks: [
          for (var w = 0; w < weekCount; w++)
            ProgrammeWeekDraft(
              localId: 'week-${w + 1}',
              weekNumber: w + 1,
              days: [
                for (var d = 0; d < dayCount; d++)
                  ProgrammeDayDraft(
                    localId: 'day-${w + 1}-${d + 1}',
                    dayKey: 'day_${d + 1}',
                    dayOrder: d + 1,
                    slots: [
                      for (var s = 0; s < slotCount; s++)
                        ProgrammeSessionSlotDraft(
                          localId: 'slot-${w + 1}-${d + 1}-${s + 1}',
                          sessionOrder: s + 1,
                          protocolId: protocolId,
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  group('ProgrammeBuilderEditOperations metadata', () {
    test('metadata edit marks dirty', () {
      final document = sampleDocument();
      final updated = operations.updateMetadata(
        document,
        document.metadata.copyWith(name: 'Updated Name'),
      );

      expect(updated.metadata.name, 'Updated Name');
      expect(updated.isDirty, isTrue);
      expect(updated.hasUnsavedChanges, isTrue);
    });
  });

  group('ProgrammeBuilderEditOperations weeks', () {
    test('add week assigns contiguous week numbers', () {
      final result = operations.addWeek(sampleDocument());

      expect(result.template.allWeeks, hasLength(2));
      expect(result.template.allWeeks.map((w) => w.weekNumber), [1, 2]);
      expect(result.isDirty, isTrue);
    });

    test('duplicate week appends renumbered copy', () {
      final document = sampleDocument(weekCount: 2);
      final weekId = document.template.allWeeks.first.localId;
      final result = operations.duplicateWeek(document, weekLocalId: weekId);

      expect(result.template.allWeeks, hasLength(3));
      expect(result.template.allWeeks.map((w) => w.weekNumber), [1, 2, 3]);
    });

    test('remove week renumbers remaining weeks', () {
      final document = sampleDocument(weekCount: 2);
      final weekId = document.template.allWeeks.first.localId;
      final result = operations.removeWeek(document, weekLocalId: weekId);

      expect(result.template.allWeeks, hasLength(1));
      expect(result.template.allWeeks.single.weekNumber, 1);
    });
  });

  group('ProgrammeBuilderEditOperations days', () {
    test('add day assigns next day order', () {
      final document = sampleDocument();
      final weekId = document.template.allWeeks.single.localId;
      final result = operations.addDay(document, weekLocalId: weekId);

      final days = result.template.allWeeks.single.days;
      expect(days, hasLength(2));
      expect(days.map((day) => day.dayOrder), [1, 2]);
      expect(days.last.dayKey, 'day_2');
    });

    test('set day type rest clears slots', () {
      final document = sampleDocument(slotCount: 2);
      final dayId = document.template.allWeeks.single.days.single.localId;
      final result = operations.setDayType(
        document,
        dayLocalId: dayId,
        dayType: ProgrammeDayType.rest,
      );

      final day = result.template.allWeeks.single.days.single;
      expect(day.dayType, ProgrammeDayType.rest);
      expect(day.slots, isEmpty);
    });

    test('update day metadata stores title and intent', () {
      final document = sampleDocument();
      final dayId = document.template.allWeeks.single.days.single.localId;
      final result = operations.updateDayMetadata(
        document,
        dayLocalId: dayId,
        title: 'Strength',
        intent: ProgrammeIntent.build,
      );

      final day = result.template.allWeeks.single.days.single;
      expect(day.title, 'Strength');
      expect(day.intent, ProgrammeIntent.build);
    });
  });

  group('ProgrammeBuilderEditOperations slots', () {
    test('add slot renumbers session order', () {
      final document = sampleDocument();
      final dayId = document.template.allWeeks.single.days.single.localId;
      final result = operations.addSlot(document, dayLocalId: dayId);

      final slots = result.template.allWeeks.single.days.single.slots;
      expect(slots, hasLength(2));
      expect(slots.map((slot) => slot.sessionOrder), [1, 2]);
    });

    test('assign and clear protocol', () {
      final document = sampleDocument();
      final slotId =
          document.template.allWeeks.single.days.single.slots.single.localId;

      final assigned = operations.assignProtocol(
        document,
        slotLocalId: slotId,
        protocolId: 'BW-001',
        displayTitle: 'Bodyweight Grinder',
      );
      expect(
        assigned.template.allWeeks.single.days.single.slots.single.protocolId,
        'BW-001',
      );

      final cleared = operations.clearProtocol(
        assigned,
        slotLocalId: slotId,
      );
      expect(
        cleared.template.allWeeks.single.days.single.slots.single.protocolId,
        '',
      );
    });

    test('update slot metadata stores optional flag', () {
      final document = sampleDocument(protocolId: 'BW-001');
      final slotId =
          document.template.allWeeks.single.days.single.slots.single.localId;

      final result = operations.updateSlotMetadata(
        document,
        slotLocalId: slotId,
        isOptional: true,
        displayTitle: 'Optional grinder',
      );

      final slot = result.template.allWeeks.single.days.single.slots.single;
      expect(slot.isOptional, isTrue);
      expect(slot.displayTitle, 'Optional grinder');
      expect(
        slot.completionExpectation,
        ProgrammeSessionCompletionExpectation.optional,
      );
    });
  });
}
