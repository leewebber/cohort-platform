import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_editor_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/widgets/programme_editor_slot_inspector.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_constants.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_preview_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_name_resolver.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_picker_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_publish_coordinator.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/features/session_builder/services/programme_session_slot_content_classifier.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_operation_result.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_preview.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_validation_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';

void main() {
  ProgrammeEditorController buildController({
    required ProgrammeSessionSlotDraft slot,
    ProgrammeBuilderService? builderService,
    String versionId = testProgrammeVersionId,
  }) {
    final document = ProgrammeBuilderDocument.clean(
      metadata: ProgrammeVersionDraftMetadata(
        versionId: versionId,
        lineageId: 'lineage-1',
        lineageCode: 'COHORT-TEST',
        versionNumber: 1,
        name: 'Foundation Test',
      ),
      template: ProgrammeTemplateDraft(
        weeks: [
          ProgrammeWeekDraft(
            localId: testWeekLocalId,
            weekNumber: 2,
            days: [
              ProgrammeDayDraft(
                localId: testDayLocalId,
                dayKey: 'day_1',
                dayOrder: 1,
                title: 'Tuesday',
                slots: [slot],
              ),
            ],
          ),
        ],
      ),
    );

    final controller = ProgrammeEditorController(
      builderService: builderService ?? _NoopBuilderService(document),
      validationService: _NoopValidationService(),
      publishCoordinator: _NoopPublishCoordinator(),
      previewService: _FakePreviewService(),
      protocolPickerService: _FakeProtocolPickerService(),
      protocolNameResolver: _FakeProtocolNameResolver(),
      coachId: 'dev-coach',
      versionId: versionId,
    );
    controller.document = document;
    return controller;
  }

  group('ProgrammeEditorSlotInspector M3 actions', () {
    testWidgets('empty slot shows Use Cohort Protocol, Use Session Library and Build New Session',
        (tester) async {
      const slot = ProgrammeSessionSlotDraft(
        localId: testSlotLocalId,
        sessionOrder: 1,
        protocolId: ProgrammeBuilderConstants.unassignedProtocolId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgrammeEditorSlotInspector(
              controller: buildController(slot: slot),
              weekLocalId: testWeekLocalId,
              dayLocalId: testDayLocalId,
              slot: slot,
              slotContentClassifier: _FixedClassifier(
                ProgrammeSlotContentKind.empty,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Use Cohort Protocol'), findsOneWidget);
      expect(find.text('Use Session Library'), findsOneWidget);
      expect(find.text('Build New Session'), findsOneWidget);
    });

    testWidgets('cohort protocol slot shows title and hides Edit Session',
        (tester) async {
      const slot = ProgrammeSessionSlotDraft(
        localId: 'slot-1',
        sessionOrder: 1,
        protocolId: 'RN-006',
        displayTitle: 'Classic Threshold',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgrammeEditorSlotInspector(
              controller: buildController(slot: slot),
              weekLocalId: testWeekLocalId,
              dayLocalId: testDayLocalId,
              slot: slot,
              slotContentClassifier: _FixedClassifier(
                ProgrammeSlotContentKind.cohortProtocol,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cohort Protocol'), findsOneWidget);
      expect(find.text('Classic Threshold'), findsWidgets);
      expect(find.text('RN-006'), findsNothing);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Copy and customise'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Edit Session'), findsNothing);
    });

    testWidgets('programme session slot shows title and Edit Session',
        (tester) async {
      const slot = ProgrammeSessionSlotDraft(
        localId: 'slot-1',
        sessionOrder: 1,
        protocolId: testDurableSessionId,
        displayTitle: 'Morning Strength',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgrammeEditorSlotInspector(
              controller: buildController(slot: slot),
              weekLocalId: testWeekLocalId,
              dayLocalId: testDayLocalId,
              slot: slot,
              slotContentClassifier: _FixedClassifier(
                ProgrammeSlotContentKind.programmeSession,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Programme session'), findsOneWidget);
      expect(find.text('Edit Session'), findsOneWidget);
      expect(find.text(testDurableSessionId), findsNothing);
    });

    test('assignProtocol marks document dirty for attached programme session',
        () async {
      const slot = ProgrammeSessionSlotDraft(
        localId: testSlotLocalId,
        sessionOrder: 1,
        protocolId: ProgrammeBuilderConstants.unassignedProtocolId,
      );

      final document = buildProgrammeDocumentWithSlot();
      final builderService = _RecordingBuilderService(document);
      final controller = buildController(
        slot: slot,
        builderService: builderService,
      );

      await controller.assignProtocol(
        slotLocalId: testSlotLocalId,
        protocolId: testDurableSessionId,
        displayTitle: 'Morning Strength',
      );

      expect(builderService.assignCalled, isTrue);
      expect(controller.document?.hasUnsavedChanges, isTrue);
      expect(
        controller.document?.template.weeks.first.days.first.slots.first
            .protocolId,
        testDurableSessionId,
      );
    });

    test('build new session creates valid authoring context from editor nodes',
        () {
      const slot = ProgrammeSessionSlotDraft(
        localId: testSlotLocalId,
        sessionOrder: 1,
        protocolId: ProgrammeBuilderConstants.unassignedProtocolId,
      );

      final week = ProgrammeWeekDraft(
        localId: testWeekLocalId,
        weekNumber: 2,
        days: [
          ProgrammeDayDraft(
            localId: testDayLocalId,
            dayKey: 'day_1',
            dayOrder: 1,
            title: 'Tuesday',
            slots: [slot],
          ),
        ],
      );

      final context = ProgrammeSessionAuthoringContext.fromEditorNodes(
        programmeVersionId: testProgrammeVersionId,
        week: week,
        day: week.days.first,
        slot: slot,
        authoringIntent: ProgrammeSessionAuthoringIntent.createBlank,
      );

      expect(context.programmeVersionId, testProgrammeVersionId);
      expect(context.slotLocalId, testSlotLocalId);
      expect(context.programmeLocationLabel, contains('Week 2'));
    });
  });
}

class _FixedClassifier extends ProgrammeSessionSlotContentClassifier {
  _FixedClassifier(this.kind)
      : super(protocolBuilderService: ProtocolBuilderService());

  final ProgrammeSlotContentKind kind;

  @override
  Future<ProgrammeSlotContentKind> classify({
    required String protocolId,
    required String programmeVersionId,
  }) async {
    return kind;
  }
}

class _RecordingBuilderService implements ProgrammeBuilderService {
  _RecordingBuilderService(this.document);

  ProgrammeBuilderDocument document;
  bool assignCalled = false;

  @override
  Future<ProgrammeBuilderEditResult> assignProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    required String protocolId,
    String? displayTitle,
  }) async {
    assignCalled = true;
    this.document = document.markDirty().copyWith(
          template: document.template.copyWith(
            weeks: document.template.weeks.map((week) {
              return week.copyWith(
                days: week.days.map((day) {
                  return day.copyWith(
                    slots: day.slots.map((slot) {
                      if (slot.localId != slotLocalId) return slot;
                      return slot.copyWith(
                        protocolId: protocolId,
                        displayTitle: displayTitle,
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
    return ProgrammeBuilderEditResult(document: this.document);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopBuilderService implements ProgrammeBuilderService {
  _NoopBuilderService(this.document);

  final ProgrammeBuilderDocument document;

  @override
  Future<ProgrammeBuilderDocument> loadDocument({required String versionId}) async =>
      document;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopValidationService implements ProgrammeBuilderValidationService {
  @override
  ProgrammeValidationResult validate(ProgrammeBuilderDocument document) =>
      ProgrammeValidationResult.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopPublishCoordinator implements ProgrammeBuilderPublishCoordinator {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProtocolPickerService implements ProgrammeBuilderProtocolPickerService {
  @override
  Future<ProgrammeBuilderProtocolOption?> getById(String protocolId) async {
    return ProgrammeBuilderProtocolOption(
      protocolId: protocolId,
      name: 'Protocol $protocolId',
    );
  }

  @override
  Future<List<ProgrammeBuilderProtocolOption>> listSelectableProtocols({
    String? searchTerm,
    int limit = 50,
  }) async {
    return const [
      ProgrammeBuilderProtocolOption(
        protocolId: 'RN-006',
        name: 'Classic Threshold',
      ),
    ];
  }
}

class _FakeProtocolNameResolver implements ProgrammeBuilderProtocolNameResolver {
  @override
  Future<Map<String, String>> resolveNames(Set<String> protocolIds) async {
    return {for (final id in protocolIds) id: 'Protocol $id'};
  }
}

class _FakePreviewService implements ProgrammeBuilderPreviewService {
  @override
  Future<ProgrammeBuilderPreview> buildPreview(
    ProgrammeBuilderDocument document, {
    Map<String, String> protocolNamesById = const {},
  }) async {
    return ProgrammeBuilderPreview(
      programmeName: document.metadata.name,
      lineageCode: document.metadata.lineageCode,
      versionNumber: document.metadata.versionNumber,
      weeks: const [],
    );
  }
}
