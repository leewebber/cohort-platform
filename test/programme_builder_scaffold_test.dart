import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_history.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_compiler.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service_impl.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = ProgrammeBuilderCompiler();

  ProgrammeVersionDraftMetadata metadata({
    String name = 'Foundation Test',
    String lineageCode = 'COHORT-FOUNDATION-TEST',
  }) {
    return ProgrammeVersionDraftMetadata(
      versionId: 'version-1',
      lineageId: 'lineage-1',
      lineageCode: lineageCode,
      versionNumber: 1,
      name: name,
    );
  }

  ProgrammeBuilderDocument sampleDocument({
    String protocolId = 'BW-001',
    String name = 'Foundation Test',
  }) {
    return ProgrammeBuilderDocument.clean(
      metadata: metadata(name: name),
      template: ProgrammeTemplateDraft(
        weeks: [
          ProgrammeWeekDraft(
            localId: 'week-1',
            weekNumber: 1,
            days: [
              ProgrammeDayDraft(
                localId: 'day-1',
                dayKey: 'day_1',
                dayOrder: 1,
                slots: [
                  ProgrammeSessionSlotDraft(
                    localId: 'slot-1',
                    sessionOrder: 1,
                    protocolId: protocolId,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      lastSavedAt: DateTime.utc(2026, 7, 16),
      saveGeneration: 2,
    );
  }

  group('ProgrammeBuilderDocument dirty/save state', () {
    test('clean loaded document', () {
      final document = sampleDocument();

      expect(document.isDirty, isFalse);
      expect(document.hasUnsavedChanges, isFalse);
      expect(document.lastSavedAt, isNotNull);
      expect(document.saveGeneration, 2);
    });

    test('edit marks dirty', () {
      final dirty = sampleDocument().markDirty();

      expect(dirty.isDirty, isTrue);
      expect(dirty.hasUnsavedChanges, isTrue);
    });

    test('successful save-state copy clears dirty and sets lastSavedAt', () {
      final savedAt = DateTime.utc(2026, 7, 16, 12);
      final saved = sampleDocument()
          .markDirty()
          .markSaved(savedAt: savedAt, saveGeneration: 3);

      expect(saved.isDirty, isFalse);
      expect(saved.hasUnsavedChanges, isFalse);
      expect(saved.lastSavedAt, savedAt);
      expect(saved.saveGeneration, 3);
      expect(saved.lastValidation, isNull);
      expect(saved.publishReadiness, isNull);
    });

    test('failed save preserves dirty', () {
      final dirty = sampleDocument().markDirty();

      expect(dirty.isDirty, isTrue);
      expect(dirty.hasUnsavedChanges, isTrue);
      expect(dirty.lastSavedAt, isNotNull);
    });
  });

  group('ProgrammeBuilderHistory', () {
    test('undo restores previous document', () {
      final history = ProgrammeBuilderHistory();
      final original = sampleDocument(name: 'Original');
      final edited = original.copyWith(
        metadata: metadata(name: 'Edited'),
      ).markDirty();

      history.recordBeforeEdit(original);
      final result = history.undo(edited);

      expect(result, isNotNull);
      expect(result!.document.metadata.name, 'Original');
      expect(result.canUndo, isFalse);
      expect(result.canRedo, isTrue);
    });

    test('redo restores reverted document', () {
      final history = ProgrammeBuilderHistory();
      final original = sampleDocument(name: 'Original');
      final edited = original.copyWith(
        metadata: metadata(name: 'Edited'),
      ).markDirty();

      history.recordBeforeEdit(original);
      history.undo(edited);
      final result = history.redo(original);

      expect(result, isNotNull);
      expect(result!.document.metadata.name, 'Edited');
      expect(result.canUndo, isTrue);
      expect(result.canRedo, isFalse);
    });

    test('bounded history behaviour drops oldest snapshot', () {
      final history = ProgrammeBuilderHistory(maxDepth: 2);
      final base = sampleDocument(name: 'Base');

      history.recordBeforeEdit(base);
      history.recordBeforeEdit(
        base.copyWith(metadata: metadata(name: 'Edit 1')).markDirty(),
      );
      history.recordBeforeEdit(
        base.copyWith(metadata: metadata(name: 'Edit 2')).markDirty(),
      );

      expect(history.undoDepth, 2);
    });
  });

  group('ProgrammeBuilderValidationService publish readiness', () {
    late ProgrammeBuilderValidationServiceImpl validationService;

    setUp(() {
      validationService = ProgrammeBuilderValidationServiceImpl(
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      );
    });

    test('publish readiness from valid validation result', () {
      final document = sampleDocument();
      final validation = validationService.validateForPublish(
        document,
        knownProtocolIds: {'BW-001'},
      );
      final readiness = validationService.buildPublishReadiness(
        document,
        validation: validation,
      );

      expect(validation.isPublishable, isTrue);
      expect(readiness.isReady, isTrue);
      expect(readiness.blockingIssueCount, 0);
      expect(readiness.checks.every((check) => check.passed), isTrue);
    });

    test('publish readiness blocked by errors', () {
      final document = ProgrammeBuilderDocument.clean(
        metadata: metadata(name: ''),
        template: const ProgrammeTemplateDraft(),
      );
      final validation = validationService.validateForPublish(document);
      final readiness = validationService.buildPublishReadiness(
        document,
        validation: validation,
      );

      expect(validation.isPublishable, isFalse);
      expect(readiness.isReady, isFalse);
      expect(readiness.blockingIssueCount, greaterThan(0));
      expect(
        readiness.checks.any((check) => check.id == 'name_present' && !check.passed),
        isTrue,
      );
    });
  });

  group('ProgrammeBuilderCompiler', () {
    test('compile flat-week document to ProgrammeTemplateTree', () {
      final tree = compiler.toTemplateTree(sampleDocument());

      expect(tree.weekNodes, hasLength(1));
      expect(tree.weekNodes.first.week.weekNumber, 1);
      expect(tree.weekNodes.first.days, hasLength(1));
      expect(tree.weekNodes.first.days.first.slots.first.protocolId, 'BW-001');
    });

    test('compile rest day with zero slots', () {
      final document = ProgrammeBuilderDocument.clean(
        metadata: metadata(),
        template: ProgrammeTemplateDraft(
          weeks: [
            ProgrammeWeekDraft(
              localId: 'week-1',
              weekNumber: 1,
              days: [
                ProgrammeDayDraft(
                  localId: 'day-1',
                  dayKey: 'day_1',
                  dayOrder: 1,
                  dayType: ProgrammeDayType.rest,
                  slots: const [],
                ),
              ],
            ),
          ],
        ),
      );

      final tree = compiler.toTemplateTree(document);
      final day = tree.weekNodes.first.days.first.day;

      expect(day.dayType, ProgrammeDayType.rest);
      expect(tree.weekNodes.first.days.first.slots, isEmpty);
    });

    test('round-trip compile/hydrate preserves order and protocol references', () {
      final source = sampleDocument(protocolId: 'RN-006');
      final tree = compiler.toTemplateTree(source);
      final hydrated = compiler.fromTemplateTree(
        tree: tree,
        metadata: source.metadata,
      );

      final week = hydrated.template.allWeeks.single;
      final day = week.days.single;
      final slot = day.slots.single;

      expect(week.weekNumber, 1);
      expect(day.dayKey, 'day_1');
      expect(day.dayOrder, 1);
      expect(slot.sessionOrder, 1);
      expect(slot.protocolId, 'RN-006');
      expect(hydrated.isDirty, isFalse);
    });
  });

  group('Copy workflow contracts', () {
    test('clone-version contract preserves lineage', () {
      const sourceLineageCode = 'COHORT-FOUNDATION-TEST';
      const sourceVersionNumber = 2;

      final clonedMetadata = metadata(
        lineageCode: sourceLineageCode,
      ).copyWith(versionNumber: sourceVersionNumber + 1);

      expect(clonedMetadata.lineageCode, sourceLineageCode);
      expect(clonedMetadata.versionNumber, 3);
      expect(clonedMetadata.lifecycleStatus, ProgrammeLifecycleStatus.draft);
    });

    test('duplicate-programme contract requires a new lineage code', () {
      const sourceLineageCode = 'COHORT-FOUNDATION-TEST';
      const newLineageCode = 'PROG-HYROX-16';

      final duplicatedMetadata = ProgrammeVersionDraftMetadata(
        lineageCode: newLineageCode,
        versionNumber: 1,
        name: 'Hyrox Variant',
      );

      expect(duplicatedMetadata.lineageCode, isNot(sourceLineageCode));
      expect(duplicatedMetadata.versionNumber, 1);
      expect(compiler.isValidLineageCode(duplicatedMetadata.lineageCode), isTrue);
    });
  });
}
