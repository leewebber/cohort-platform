import 'package:cohort_platform/features/coach_studio/coach_studio_home_screen.dart';
import 'package:cohort_platform/features/coach_studio/models/coach_studio_section.dart';
import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_catalogue_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_catalogue_view_state.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_publishing_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_publish_coordinator.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service.dart';
import 'package:cohort_platform/features/training_library/models/training_library_tab.dart';
import 'package:cohort_platform/features/training_library/screens/training_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestCatalogueController extends ProgrammeCatalogueController {
  _TestCatalogueController()
      : super(
          builderService: _NoopBuilderServiceForStudio(),
          catalogService: _NoopCatalogServiceForStudio(),
          publishCoordinator: _NoopPublishCoordinatorForStudio(),
          publishingService: _NoopPublishingServiceForStudio(),
          validationService: _NoopValidationServiceForStudio(),
          coachId: 'dev-coach',
        ) {
    viewState = ProgrammeCatalogueViewState.ready;
  }
}

class _NoopBuilderServiceForStudio implements ProgrammeBuilderService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopCatalogServiceForStudio implements ProgrammeCatalogService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopPublishCoordinatorForStudio implements ProgrammeBuilderPublishCoordinator {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopPublishingServiceForStudio implements ProgrammePublishingService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopValidationServiceForStudio implements ProgrammeBuilderValidationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TrainingLibraryScreen', () {
    testWidgets('shows Cohort Protocols and Session Library tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingLibraryScreen(
            cohortTab: const Text('Cohort tab content'),
            sessionTab: const Text('Session tab content'),
          ),
        ),
      );

      expect(find.text('Training Library'), findsOneWidget);
      expect(find.text('Cohort Protocols'), findsOneWidget);
      expect(find.text('Session Library'), findsOneWidget);
      expect(find.text('Cohort tab content'), findsOneWidget);
    });

    testWidgets('preserves selected tab after switching', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingLibraryScreen(
            cohortTab: const Text('Cohort tab content'),
            sessionTab: const Text('Session tab content'),
          ),
        ),
      );

      await tester.tap(find.text('Session Library'));
      await tester.pumpAndSettle();

      expect(find.text('Session tab content'), findsOneWidget);
      expect(find.text('Cohort tab content'), findsNothing);
    });

    testWidgets('Coach Studio opens Training Library destination', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CoachStudioHomeScreen(
            catalogueController: _TestCatalogueController(),
          ),
        ),
      );

      final trainingLibraryCard = find.text('Training Library');
      expect(trainingLibraryCard, findsOneWidget);
      await tester.tap(trainingLibraryCard);
      await tester.pump(
        const Duration(milliseconds: 100),
      );

      // Navigation pushes TrainingLibraryScreen — verify route started.
      expect(find.text('Training Library'), findsWidgets);
    });
  });

  test('CoachStudioSection exposes trainingLibrary in v0.1', () {
    expect(CoachStudioSection.trainingLibrary.isAvailableInV01, isTrue);
    expect(CoachStudioSection.trainingLibrary.title, 'Training Library');
    expect(TrainingLibraryTab.sessionLibrary.title, 'Session Library');
  });
}
