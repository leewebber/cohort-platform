import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_decision_copy.dart';
import 'package:cohort_platform/features/programme/presentation/programme_discovery_decision_preview_catalog.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_comparison_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_detail_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_enrolment_review_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_selection_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_switch_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';

/// Internal Programme Discovery and Decision preview. Fixtures only.
/// Not imported by `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4192 \
///     -t lib/main_programme_discovery_decision_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProgrammeDiscoveryDecisionPreviewApp());
}

class ProgrammeDiscoveryDecisionPreviewApp extends StatelessWidget {
  const ProgrammeDiscoveryDecisionPreviewApp({
    super.key,
    this.initialState =
        ProgrammeDiscoveryDecisionPreviewState.catalogueDiscovery,
  });

  final ProgrammeDiscoveryDecisionPreviewState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: ProgrammeDiscoveryDecisionPreviewScreen(
        initialState: initialState,
      ),
    );
  }
}

class ProgrammeDiscoveryDecisionPreviewScreen extends StatefulWidget {
  const ProgrammeDiscoveryDecisionPreviewScreen({
    super.key,
    this.initialState =
        ProgrammeDiscoveryDecisionPreviewState.catalogueDiscovery,
  });

  final ProgrammeDiscoveryDecisionPreviewState initialState;

  @override
  State<ProgrammeDiscoveryDecisionPreviewScreen> createState() =>
      _ProgrammeDiscoveryDecisionPreviewScreenState();
}

class _ProgrammeDiscoveryDecisionPreviewScreenState
    extends State<ProgrammeDiscoveryDecisionPreviewScreen> {
  late ProgrammeDiscoveryDecisionPreviewState _state = widget.initialState;

  @override
  Widget build(BuildContext context) {
    final narrow =
        _state == ProgrammeDiscoveryDecisionPreviewState.largeTextNarrow;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: narrow ? const Size(320, 800) : MediaQuery.of(context).size,
        textScaler: TextScaler.linear(narrow ? 2 : 1),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Decision preview (internal)')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(CohortSpacing.md),
              child: DropdownButton<ProgrammeDiscoveryDecisionPreviewState>(
                isExpanded: true,
                value: _state,
                items: ProgrammeDiscoveryDecisionPreviewState.values
                    .map(
                      (state) => DropdownMenuItem(
                        value: state,
                        child: Text(state.name, style: CohortTextStyles.small),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _state = value);
                },
              ),
            ),
            Expanded(
              child: _PreviewSurface(key: ValueKey(_state), state: _state),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSurface extends StatefulWidget {
  const _PreviewSurface({super.key, required this.state});

  final ProgrammeDiscoveryDecisionPreviewState state;

  @override
  State<_PreviewSurface> createState() => _PreviewSurfaceState();
}

class _PreviewSurfaceState extends State<_PreviewSurface> {
  late final AthleteProgrammeSelectionController _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.state);
    _prepare();
  }

  Future<void> _prepare() async {
    await _controller.load();
    final state = widget.state;
    if (state == ProgrammeDiscoveryDecisionPreviewState.comparison ||
        state ==
            ProgrammeDiscoveryDecisionPreviewState.comparisonMissingFacts) {
      if (_controller.programmes.length >= 2) {
        _controller.toggleCompare(_controller.programmes[0]);
        _controller.toggleCompare(_controller.programmes[1]);
      }
    }
    if (state == ProgrammeDiscoveryDecisionPreviewState.enrolmentReview ||
        state == ProgrammeDiscoveryDecisionPreviewState.enrolmentPending ||
        state == ProgrammeDiscoveryDecisionPreviewState.enrolmentRejected) {
      if (_controller.programmes.isNotEmpty) {
        _controller.selectProgramme(_controller.programmes.first);
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (widget.state) {
      case ProgrammeDiscoveryDecisionPreviewState.catalogueDiscovery:
      case ProgrammeDiscoveryDecisionPreviewState.largeTextNarrow:
      case ProgrammeDiscoveryDecisionPreviewState.emptyCatalogue:
      case ProgrammeDiscoveryDecisionPreviewState.catalogueUnavailable:
        return AthleteProgrammeSelectionScreen(
          athleteId: 'preview.athlete',
          controller: _controller,
        );
      case ProgrammeDiscoveryDecisionPreviewState.detailApollo:
      case ProgrammeDiscoveryDecisionPreviewState.activeCurrent:
        return AthleteProgrammeDetailScreen(
          controller: _controller,
          versionId: 'preview-apollo',
        );
      case ProgrammeDiscoveryDecisionPreviewState.detailSpartan:
      case ProgrammeDiscoveryDecisionPreviewState.activeInspectOther:
        return AthleteProgrammeDetailScreen(
          controller: _controller,
          versionId: 'preview-spartan',
        );
      case ProgrammeDiscoveryDecisionPreviewState.comparison:
      case ProgrammeDiscoveryDecisionPreviewState.comparisonMissingFacts:
        return AthleteProgrammeComparisonScreen(controller: _controller);
      case ProgrammeDiscoveryDecisionPreviewState.enrolmentReview:
      case ProgrammeDiscoveryDecisionPreviewState.enrolmentPending:
      case ProgrammeDiscoveryDecisionPreviewState.enrolmentRejected:
        return AthleteProgrammeEnrolmentReviewScreen(
          controller: _controller,
          versionId: 'preview-apollo',
        );
      case ProgrammeDiscoveryDecisionPreviewState.enrolmentSuccess:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(CohortSpacing.lg),
            child: Text(
              AthleteProgrammeDecisionCopy.enrolSuccess,
              style: CohortTextStyles.body,
            ),
          ),
        );
    }
  }
}

class _PreviewCatalog implements ProgrammeCatalogService {
  _PreviewCatalog(this.entries, {this.fail = false});
  final List<ProgrammeCatalogEntry> entries;
  final bool fail;

  @override
  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  }) async => null;

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogue({
    required ProgrammeCatalogueQuery query,
    ProgrammeLifecycleStatus? lifecycleStatus,
  }) async {
    if (fail) throw StateError('preview catalogue unavailable');
    return entries;
  }
}

class _NoopEnrolmentStore implements AthleteCatalogueEnrolmentStore {
  const _NoopEnrolmentStore();

  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    String? timezone,
    bool replaceActive = false,
  }) async {
    return const AthleteCatalogueEnrolmentResult(
      status: AthleteCatalogueEnrolmentStatus.failed,
      message: 'Preview does not enrol.',
    );
  }
}

AthleteProgrammeSelectionController _buildController(
  ProgrammeDiscoveryDecisionPreviewState state,
) {
  final missing =
      state == ProgrammeDiscoveryDecisionPreviewState.comparisonMissingFacts;
  final empty = state == ProgrammeDiscoveryDecisionPreviewState.emptyCatalogue;
  final fail =
      state == ProgrammeDiscoveryDecisionPreviewState.catalogueUnavailable;
  final active =
      state == ProgrammeDiscoveryDecisionPreviewState.activeCurrent ||
      state == ProgrammeDiscoveryDecisionPreviewState.activeInspectOther;
  final pending =
      state == ProgrammeDiscoveryDecisionPreviewState.enrolmentPending;
  final rejected =
      state == ProgrammeDiscoveryDecisionPreviewState.enrolmentRejected;

  final entries = empty
      ? const <ProgrammeCatalogEntry>[]
      : [
          ProgrammeDiscoveryPreviewFixtures.apollo(missingOptional: missing),
          ProgrammeDiscoveryPreviewFixtures.spartan(missingOptional: missing),
        ];

  if (active) {
    return _ActivePreviewController(entries: entries);
  }
  if (pending) {
    return _FlagPreviewController(entries: entries, submitting: true);
  }
  if (rejected) {
    return _FlagPreviewController(entries: entries, rejected: true);
  }
  return AthleteProgrammeSelectionController(
    athleteId: 'preview.athlete',
    catalogService: AthleteProgrammeSwitchCatalogService(
      catalogService: _PreviewCatalog(entries, fail: fail),
    ),
    enrolmentService: const AthleteCatalogueEnrolmentService(
      enrolmentStore: _NoopEnrolmentStore(),
    ),
  );
}

class _ActivePreviewController extends AthleteProgrammeSelectionController {
  _ActivePreviewController({required List<ProgrammeCatalogEntry> entries})
    : super(
        athleteId: 'preview.athlete',
        catalogService: AthleteProgrammeSwitchCatalogService(
          catalogService: _PreviewCatalog(entries),
        ),
        enrolmentService: const AthleteCatalogueEnrolmentService(
          enrolmentStore: _NoopEnrolmentStore(),
        ),
      );

  @override
  String? get activeVersionId => 'preview-apollo';

  @override
  bool get hasActiveAssignment => true;
}

class _FlagPreviewController extends AthleteProgrammeSelectionController {
  _FlagPreviewController({
    required List<ProgrammeCatalogEntry> entries,
    this.submitting = false,
    this.rejected = false,
  }) : super(
         athleteId: 'preview.athlete',
         catalogService: AthleteProgrammeSwitchCatalogService(
           catalogService: _PreviewCatalog(entries),
         ),
         enrolmentService: const AthleteCatalogueEnrolmentService(
           enrolmentStore: _NoopEnrolmentStore(),
         ),
       );

  final bool submitting;
  final bool rejected;

  @override
  bool get isSubmitting => submitting || super.isSubmitting;

  @override
  AthleteCatalogueEnrolmentResult? get lastEnrolmentResult {
    if (!rejected) return super.lastEnrolmentResult;
    return const AthleteCatalogueEnrolmentResult(
      status: AthleteCatalogueEnrolmentStatus.failed,
      programmeVersionId: 'preview-apollo',
      message: 'Enrolment could not be completed. Retry when ready.',
    );
  }
}
