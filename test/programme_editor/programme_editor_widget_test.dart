import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_editor_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_editor_selection.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_editor_view_state.dart';
import 'package:cohort_platform/features/coach_studio/programmes/programme_editor_screen.dart';
import 'package:cohort_platform/features/coach_studio/programmes/widgets/programme_editor_unsaved_dialog.dart';
import 'package:cohort_platform/features/coach_studio/programmes/widgets/programme_protocol_picker_sheet.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_preview.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_validation_result.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_preview_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_name_resolver.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_picker_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_publish_coordinator.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProgrammeEditorController buildReadyController({bool dirty = false}) {
    final document = ProgrammeBuilderDocument.clean(
      metadata: const ProgrammeVersionDraftMetadata(
        versionId: 'version-1',
        lineageId: 'lineage-1',
        lineageCode: 'COHORT-TEST',
        versionNumber: 1,
        name: 'Foundation Test',
      ),
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
                    protocolId: 'BW-001',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).copyWith(
      isDirty: dirty,
      hasUnsavedChanges: dirty,
    );

    final controller = ProgrammeEditorController(
      builderService: _NoopBuilderService(document),
      validationService: _NoopValidationService(),
      publishCoordinator: _NoopPublishCoordinator(),
      previewService: _FakePreviewService(),
      protocolPickerService: _FakeProtocolPickerService(),
      protocolNameResolver: _FakeProtocolNameResolver(),
      coachId: 'dev-coach',
      versionId: 'version-1',
    );

    controller.document = document;
    controller.viewState = ProgrammeEditorViewState.ready;
    controller.validation = ProgrammeValidationResult.empty();
    controller.selection = const ProgrammeEditorSelection(
      weekLocalId: 'week-1',
      dayLocalId: 'day-1',
      slotLocalId: 'slot-1',
    );

    return controller;
  }

  testWidgets('header shows unsaved indicator when dirty', (tester) async {
    final controller = buildReadyController(dirty: true);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgrammeEditorScreen(
          versionId: 'version-1',
          controller: controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('● Unsaved'), findsOneWidget);
  });

  testWidgets('save disabled while saving', (tester) async {
    final controller = buildReadyController();
    controller.isSaving = true;

    await tester.pumpWidget(
      MaterialApp(
        home: ProgrammeEditorScreen(
          versionId: 'version-1',
          controller: controller,
        ),
      ),
    );
    await tester.pump();

    final saveButton = find.widgetWithText(FilledButton, 'Saving…');
    expect(saveButton, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('mobile week chips render', (tester) async {
    final controller = buildReadyController();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: ProgrammeEditorScreen(
            versionId: 'version-1',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Week 1'), findsWidgets);
    expect(find.byType(ChoiceChip), findsWidgets);
  });

  testWidgets('protocol picker search filters list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => ProgrammeProtocolPickerSheet(
                    listProtocols:
                        _FakeProtocolPickerService().listSelectableProtocols,
                  ),
                );
              },
              child: const Text('Open picker'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('Bodyweight Grinder'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mobility');
    await tester.pumpAndSettle();

    expect(find.text('Bodyweight Grinder'), findsNothing);
    expect(find.text('Mobility Flow'), findsOneWidget);
  });

  testWidgets('unsaved exit dialog shown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showProgrammeEditorUnsavedDialog(context: context);
              },
              child: const Text('Exit'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Save and exit'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });
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
    final options = [
      const ProgrammeBuilderProtocolOption(
        protocolId: 'BW-001',
        name: 'Bodyweight Grinder',
      ),
      const ProgrammeBuilderProtocolOption(
        protocolId: 'BW-002',
        name: 'Mobility Flow',
      ),
    ];

    final term = searchTerm?.trim().toLowerCase();
    if (term == null || term.isEmpty) return options;

    return options
        .where(
          (option) =>
              option.name.toLowerCase().contains(term) ||
              option.protocolId.toLowerCase().contains(term),
        )
        .toList();
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
