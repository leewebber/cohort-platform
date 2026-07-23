import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_editor_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_editor_view_state.dart';
import 'package:cohort_platform/features/coach_studio/programmes/programme_editor_screen.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_operation_result.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_preview.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_publish_readiness.dart';
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
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProgrammeBuilderDocument buildDocument() {
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
    );
  }

  ProgrammeEditorController buildPublishReadyController({
    required ProgrammeBuilderPublishCoordinator publishCoordinator,
  }) {
    final document = buildDocument();
    final controller = ProgrammeEditorController(
      builderService: _NoopBuilderService(document),
      validationService: _NoopValidationService(),
      publishCoordinator: publishCoordinator,
      previewService: _FakePreviewService(),
      protocolPickerService: _FakeProtocolPickerService(),
      protocolNameResolver: _FakeProtocolNameResolver(),
      coachId: 'coach-1',
      versionId: 'version-1',
    );
    controller.document = document;
    controller.viewState = ProgrammeEditorViewState.ready;
    controller.validation = ProgrammeValidationResult.empty();
    controller.publishReadiness = ProgrammePublishReadiness.ready(checks: []);
    return controller;
  }

  testWidgets('successful publish shows confirmation snackbar', (tester) async {
    final controller = buildPublishReadyController(
      publishCoordinator: _SuccessPublishCoordinator(buildDocument()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProgrammeEditorScreen(
          versionId: 'version-1',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await controller.validate();
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish').last);
    await tester.pumpAndSettle();

    expect(find.text('Programme published.'), findsOneWidget);
  });

  testWidgets('failed publish after dispose does not access stale context', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final controller = buildPublishReadyController(
      publishCoordinator: const _DelayedFailPublishCoordinator(),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: ProgrammeEditorScreen(
          versionId: 'version-1',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await controller.validate();
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish').last);
    await tester.pump();

    navigatorKey.currentState!.pop();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
  });
}

class _NoopBuilderService implements ProgrammeBuilderService {
  _NoopBuilderService(this.document);

  final ProgrammeBuilderDocument document;

  @override
  Future<ProgrammeBuilderDocument> loadDocument({
    required String versionId,
  }) async => document;

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

class _FakeProtocolPickerService
    implements ProgrammeBuilderProtocolPickerService {
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
    return [
      const ProgrammeBuilderProtocolOption(
        protocolId: 'BW-001',
        name: 'Bodyweight Grinder',
      ),
    ];
  }
}

class _FakeProtocolNameResolver
    implements ProgrammeBuilderProtocolNameResolver {
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

class _SuccessPublishCoordinator implements ProgrammeBuilderPublishCoordinator {
  _SuccessPublishCoordinator(this.document);

  final ProgrammeBuilderDocument document;

  @override
  ProgrammePublishReadiness validateReadiness(
    ProgrammeBuilderDocument document, {
    Set<String>? knownProtocolIds,
  }) {
    return ProgrammePublishReadiness.ready(checks: []);
  }

  @override
  Future<ProgrammeBuilderOperationResult> publish({
    required ProgrammeBuilderDocument document,
    required String coachId,
    Set<String>? knownProtocolIds,
  }) async {
    return ProgrammeBuilderOperationResult(
      status: ProgrammeBuilderOperationStatus.published,
      document: document,
      publishedVersionId: document.metadata.versionId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedFailPublishCoordinator
    implements ProgrammeBuilderPublishCoordinator {
  const _DelayedFailPublishCoordinator();

  @override
  ProgrammePublishReadiness validateReadiness(
    ProgrammeBuilderDocument document, {
    Set<String>? knownProtocolIds,
  }) {
    return ProgrammePublishReadiness.ready(checks: []);
  }

  @override
  Future<ProgrammeBuilderOperationResult> publish({
    required ProgrammeBuilderDocument document,
    required String coachId,
    Set<String>? knownProtocolIds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return ProgrammeBuilderOperationResult(
      status: ProgrammeBuilderOperationStatus.storeFailed,
      document: document,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
