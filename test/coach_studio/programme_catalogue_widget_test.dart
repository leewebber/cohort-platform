import 'dart:io';

import 'package:cohort_platform/features/coach_studio/coach_studio_home_screen.dart';
import 'package:cohort_platform/features/coach_studio/models/coach_studio_navigation_state.dart';
import 'package:cohort_platform/features/coach_studio/models/coach_studio_section.dart';
import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_catalogue_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_catalogue_tab.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_catalogue_view_state.dart';
import 'package:cohort_platform/features/coach_studio/programmes/programme_catalogue_screen.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_publishing_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_publish_coordinator.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCatalogueController extends ProgrammeCatalogueController {
  _FakeCatalogueController()
      : super(
          builderService: _NoopBuilderService(),
          catalogService: _NoopCatalogService(),
          publishCoordinator: _NoopPublishCoordinator(),
          publishingService: _NoopPublishingService(),
          validationService: _NoopValidationService(),
          coachId: 'dev-coach',
        ) {
    viewState = ProgrammeCatalogueViewState.ready;
    loadedEntries = [
      ProgrammeCatalogEntry(
        versionId: 'v1',
        lineageCode: 'COHORT-TEST',
        versionNumber: 1,
        name: 'Foundation Test',
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        libraryScope: ProgrammeLibraryScope.coachPrivate,
        ownerType: ProgrammeOwnerType.coach,
        ownerId: 'dev-coach',
        durationWeeks: 8,
        sessionsPerWeek: 5,
        updatedAt: DateTime.utc(2026, 7, 16),
        ownerDisplayLabel: 'You',
      ),
    ];
  }

  @override
  Future<void> loadTab(ProgrammeCatalogueTab tab) async {
    activeTab = tab;
    notifyListeners();
  }

  void notifyListeners() {
    // Uses protected listener list via public addListener contract.
    setSearchTerm(searchTerm);
  }
}

class _NoopBuilderService implements ProgrammeBuilderService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopCatalogService implements ProgrammeCatalogService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopPublishCoordinator implements ProgrammeBuilderPublishCoordinator {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopPublishingService implements ProgrammePublishingService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopValidationService implements ProgrammeBuilderValidationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('Coach Studio landing shows sections and SOON labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CoachStudioHomeScreen()),
    );

    expect(find.text('Programmes'), findsOneWidget);
    expect(find.text('Training Library'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Soon'), findsWidgets);
  });

  testWidgets('Programmes navigation from landing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoachStudioHomeScreen(
          catalogueController: _FakeCatalogueController(),
        ),
      ),
    );

    await tester.tap(find.text('Programmes'));
    await tester.pumpAndSettle();

    expect(find.text('New programme'), findsOneWidget);
    expect(find.text('Drafts'), findsOneWidget);
  });

  testWidgets('catalogue renders four tabs and card metadata', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProgrammeCatalogueScreen(
          controller: _FakeCatalogueController(),
        ),
      ),
    );

    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Cohort Global'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Foundation Test'), findsOneWidget);
    expect(find.text('COHORT-TEST'), findsOneWidget);
  });

  testWidgets('empty state shows create CTA', (tester) async {
    final controller = _FakeCatalogueController();
    controller.viewState = ProgrammeCatalogueViewState.empty;
    controller.loadedEntries = [];

    await tester.pumpWidget(
      MaterialApp(
        home: ProgrammeCatalogueScreen(controller: controller),
      ),
    );

    expect(find.text('No drafts yet.'), findsOneWidget);
    expect(find.text('Create programme'), findsOneWidget);
  });

  test('architecture: coach studio screens/widgets do not import supabase stores', () {
    final coachStudioDir = Directory('lib/features/coach_studio');

    for (final entity in coachStudioDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/services/')) continue;

      final content = entity.readAsStringSync();
      expect(
        content.contains('programme_version_supabase_store'),
        isFalse,
        reason: '${entity.path} must not import Supabase stores',
      );
      expect(
        content.contains('SupabaseService'),
        isFalse,
        reason: '${entity.path} must not call Supabase directly',
      );
    }
  });

  test('navigation state remembers programmes in session', () {
    final state = CoachStudioNavigationState.instance;
    state.rememberSection(CoachStudioSection.programmes);
    expect(state.shouldOpenProgrammesDirectly, isTrue);
  });
}
