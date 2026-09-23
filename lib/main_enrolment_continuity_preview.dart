import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/widgets/cohort_card.dart';
import 'package:cohort_platform/core/widgets/local_preview_banner.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/domain/enrolment_timezone_capture.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_continuity_copy.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_enrolment_review_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_switch_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';

/// Fixture-only Sprint 2 preview. Not imported by `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4193 \
///     -t lib/main_enrolment_continuity_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnrolmentContinuityPreviewApp());
}

enum EnrolmentContinuityPreviewState {
  makassarSuggestion,
  londonSuggestion,
  athleteChangesTimezone,
  missingTimezone,
  invalidAbbreviation,
  reviewLocalDate,
  enrolmentRejected,
  enrolmentSuccess,
  currentDefault,
  currentPinned,
  differentVersionAvailable,
  pinnedUnavailable,
  timezoneRepairRequired,
  narrow320,
  largeText,
}

class EnrolmentContinuityPreviewApp extends StatelessWidget {
  const EnrolmentContinuityPreviewApp({
    super.key,
    this.initialState = EnrolmentContinuityPreviewState.makassarSuggestion,
  });

  final EnrolmentContinuityPreviewState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: EnrolmentContinuityPreviewScreen(initialState: initialState),
    );
  }
}

class EnrolmentContinuityPreviewScreen extends StatefulWidget {
  const EnrolmentContinuityPreviewScreen({
    super.key,
    required this.initialState,
  });

  final EnrolmentContinuityPreviewState initialState;

  @override
  State<EnrolmentContinuityPreviewScreen> createState() =>
      _EnrolmentContinuityPreviewScreenState();
}

class _EnrolmentContinuityPreviewScreenState
    extends State<EnrolmentContinuityPreviewScreen> {
  late EnrolmentContinuityPreviewState _state = widget.initialState;

  @override
  Widget build(BuildContext context) {
    final narrow =
        _state == EnrolmentContinuityPreviewState.narrow320 ||
        _state == EnrolmentContinuityPreviewState.largeText;
    final large = _state == EnrolmentContinuityPreviewState.largeText;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: narrow ? const Size(320, 800) : MediaQuery.of(context).size,
        textScaler: TextScaler.linear(large ? 2 : 1),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enrolment continuity preview'),
          actions: [
            DropdownButton<EnrolmentContinuityPreviewState>(
              value: _state,
              onChanged: (value) {
                if (value != null) setState(() => _state = value);
              },
              items: EnrolmentContinuityPreviewState.values
                  .map(
                    (state) => DropdownMenuItem(
                      value: state,
                      child: Text(state.name),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        body: Column(
          children: [
            const LocalPreviewBanner(),
            const Padding(
              padding: EdgeInsets.all(CohortSpacing.sm),
              child: Text('PREVIEW ONLY', style: CohortTextStyles.small),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case EnrolmentContinuityPreviewState.currentDefault:
        return _message(AthleteProgrammeContinuityCopy.currentProgramme);
      case EnrolmentContinuityPreviewState.currentPinned:
        return _message(
          AthleteProgrammeContinuityCopy.continuingStartedVersion,
        );
      case EnrolmentContinuityPreviewState.differentVersionAvailable:
        return _message(
          AthleteProgrammeContinuityCopy.differentVersionAvailable,
        );
      case EnrolmentContinuityPreviewState.pinnedUnavailable:
        return _message(AthleteProgrammeContinuityCopy.pinnedUnavailable);
      case EnrolmentContinuityPreviewState.timezoneRepairRequired:
        return _message(AthleteProgrammeContinuityCopy.timezoneRepairRequired);
      case EnrolmentContinuityPreviewState.enrolmentSuccess:
        return _message(
          '${AthleteProgrammeDecisionSuccess.confirmed} Starts 2026-06-16.',
        );
      default:
        return FutureBuilder<AthleteProgrammeSelectionController>(
          future: _loadedController(_state),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return AthleteProgrammeEnrolmentReviewScreen(
              controller: snapshot.data!,
              versionId: 'preview-apollo',
              timezoneSource: _sourceFor(_state),
              clock: () => DateTime.utc(2026, 6, 15, 16, 30),
            );
          },
        );
    }
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      child: CohortCard(child: Text(text, style: CohortTextStyles.body)),
    );
  }
}

abstract final class AthleteProgrammeDecisionSuccess {
  static const confirmed = 'Enrolled. Your programme is ready.';
}

DeviceIanaTimezoneSource _sourceFor(EnrolmentContinuityPreviewState state) {
  switch (state) {
    case EnrolmentContinuityPreviewState.londonSuggestion:
      return const StaticDeviceIanaTimezoneSource('Europe/London');
    case EnrolmentContinuityPreviewState.missingTimezone:
      return const StaticDeviceIanaTimezoneSource(null);
    case EnrolmentContinuityPreviewState.invalidAbbreviation:
      return const StaticDeviceIanaTimezoneSource('BST');
    default:
      return const StaticDeviceIanaTimezoneSource('Asia/Makassar');
  }
}

Future<AthleteProgrammeSelectionController> _loadedController(
  EnrolmentContinuityPreviewState state,
) async {
  final store = _PreviewEnrolmentStore(
    reject: state == EnrolmentContinuityPreviewState.enrolmentRejected,
  );
  final controller = AthleteProgrammeSelectionController(
    athleteId: 'preview-athlete',
    catalogService: AthleteProgrammeSwitchCatalogService(
      catalogService: _PreviewCatalog([
        ProgrammeCatalogEntry(
          versionId: 'preview-apollo',
          lineageCode: 'APOLLO',
          versionNumber: 1,
          name: 'Apollo',
          lifecycleStatus: ProgrammeLifecycleStatus.published,
          libraryScope: ProgrammeLibraryScope.cohortGlobal,
          ownerType: ProgrammeOwnerType.global,
          approvedForGlobal: true,
          primaryGoal: 'Hybrid strength',
          durationWeeks: 12,
          sessionsPerWeek: 4,
          difficulty: 'Intermediate',
        ),
      ]),
    ),
    enrolmentService: AthleteCatalogueEnrolmentService(enrolmentStore: store),
  );
  await controller.load();
  return controller;
}

class _PreviewCatalog implements ProgrammeCatalogService {
  _PreviewCatalog(this.entries);
  final List<ProgrammeCatalogEntry> entries;

  @override
  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  }) async => null;

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogue({
    required ProgrammeCatalogueQuery query,
    ProgrammeLifecycleStatus? lifecycleStatus,
  }) async => entries;
}

class _PreviewEnrolmentStore implements AthleteCatalogueEnrolmentStore {
  _PreviewEnrolmentStore({this.reject = false});
  final bool reject;

  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    String? timezone,
    bool replaceActive = false,
  }) async {
    if (reject) {
      return const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.validationFailure,
        code: 'invalid_timezone',
        message: 'Choose a valid training timezone to enrol.',
      );
    }
    return AthleteCatalogueEnrolmentResult(
      status: AthleteCatalogueEnrolmentStatus.enrolled,
      enrolmentId: 'preview-enrolment',
      programmeVersionId: programmeVersionId,
      athleteId: 'preview-athlete',
      startedAt: DateTime(2026, 6, 16),
      timezone: timezone,
    );
  }
}
