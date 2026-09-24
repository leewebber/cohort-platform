import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/widgets/local_preview_banner.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/domain/athlete_programme_continuity.dart';
import 'package:cohort_platform/features/programme/domain/enrolment_iana_timezone.dart';
import 'package:cohort_platform/features/programme/domain/enrolment_timezone_capture.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_enrolment_review_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_switch_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_status_state.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';

/// Fixture-only Sprint 2 preview. Not imported by `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4193 --web-hostname 127.0.0.1 \
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
      home: EnrolmentContinuityPreviewScreen(
        key: ValueKey(initialState),
        initialState: initialState,
      ),
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
  final _controllers = <EnrolmentContinuityPreviewState,
      Future<AthleteProgrammeSelectionController>>{};

  Future<AthleteProgrammeSelectionController> _controllerFor(
    EnrolmentContinuityPreviewState state,
  ) {
    return _controllers.putIfAbsent(state, () => _loadedController(state));
  }

  @override
  Widget build(BuildContext context) {
    final narrow = _state == EnrolmentContinuityPreviewState.narrow320;
    final large = _state == EnrolmentContinuityPreviewState.largeText;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(large ? 2 : 1),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enrolment continuity preview'),
        ),
        body: Column(
          children: [
            const LocalPreviewBanner(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: CohortSpacing.md),
              child: Text('PREVIEW ONLY', style: CohortTextStyles.small),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: CohortSpacing.md),
                children: [
                  for (final state in EnrolmentContinuityPreviewState.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(state.name),
                        selected: _state == state,
                        onSelected: (_) => setState(() => _state = state),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: narrow ? 320 : 390,
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case EnrolmentContinuityPreviewState.currentDefault:
        return ListView(
          padding: const EdgeInsets.all(CohortSpacing.md),
          children: [
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus.currentDefault,
                timezoneHealth: AssignmentTimezoneHealth.valid,
              ),
            ),
          ],
        );
      case EnrolmentContinuityPreviewState.currentPinned:
        return ListView(
          padding: const EdgeInsets.all(CohortSpacing.md),
          children: [
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus.currentPinned,
                timezoneHealth: AssignmentTimezoneHealth.valid,
              ),
            ),
          ],
        );
      case EnrolmentContinuityPreviewState.differentVersionAvailable:
        return ListView(
          padding: const EdgeInsets.all(CohortSpacing.md),
          children: [
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus
                    .currentPinnedWithDifferentAvailable,
                timezoneHealth: AssignmentTimezoneHealth.valid,
              ),
            ),
          ],
        );
      case EnrolmentContinuityPreviewState.pinnedUnavailable:
        return ListView(
          padding: const EdgeInsets.all(CohortSpacing.md),
          children: [
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus.pinnedUnavailable,
                timezoneHealth: AssignmentTimezoneHealth.valid,
              ),
            ),
          ],
        );
      case EnrolmentContinuityPreviewState.timezoneRepairRequired:
        return ListView(
          padding: const EdgeInsets.all(CohortSpacing.md),
          children: [
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus.currentPinned,
                timezoneHealth: AssignmentTimezoneHealth.repairRequired,
              ),
            ),
          ],
        );
      case EnrolmentContinuityPreviewState.enrolmentSuccess:
        return ListView(
          padding: const EdgeInsets.all(CohortSpacing.md),
          children: [
            EnrolmentSuccessState(
              programmeTitle: 'Apollo',
              startDate: DateTime(2026, 6, 16),
              timezoneIana: EnrolmentIanaTimezone.bali,
            ),
          ],
        );
      default:
        return FutureBuilder<AthleteProgrammeSelectionController>(
          future: _controllerFor(_state),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return AthleteProgrammeEnrolmentReviewScreen(
              key: ValueKey(_state),
              controller: snapshot.data!,
              versionId: 'preview-apollo',
              timezoneSource: _sourceFor(_state),
              clock: () => DateTime.utc(2026, 6, 15, 16, 30),
            );
          },
        );
    }
  }
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
      timezone: timezone ?? EnrolmentIanaTimezone.bali,
    );
  }
}
