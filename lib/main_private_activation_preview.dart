import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/models/private_programme_summary.dart';
import 'package:cohort_platform/features/programme/screens/athlete_private_programme_activation_screen.dart';
import 'package:cohort_platform/features/programme/services/private_programme_discovery_store.dart';
import 'package:cohort_platform/features/programme/services/private_programme_enrolment_store.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_private_programmes_section.dart';
import 'package:flutter/material.dart';

/// Isolated private-activation preview. Not imported by `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4196 \
///     -t lib/main_private_activation_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const PrivateActivationPreviewApp(
      initialState: PrivateActivationPreviewState.listWithBali,
    ),
  );
}

enum PrivateActivationPreviewState {
  listWithBali,
  activationReview,
  typedFailure,
  success,
  emptyList,
  narrowViewport,
  largeText,
}

class _PreviewDiscoveryStore implements PrivateProgrammeDiscoveryStore {
  const _PreviewDiscoveryStore(this.programmes);
  final List<PrivateProgrammeSummary> programmes;
  @override
  Future<List<PrivateProgrammeSummary>> listMine() async => programmes;
}

class _PreviewEnrolmentStore implements PrivateProgrammeEnrolmentStore {
  const _PreviewEnrolmentStore({this.succeed = true});
  final bool succeed;
  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    required String timezone,
    required DateTime localStartDate,
    required bool replaceActive,
  }) async {
    if (!succeed) {
      return const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.failed,
        code: 'activation_failed',
        message: 'Activation could not be completed. Apollo remains current.',
      );
    }
    return AthleteCatalogueEnrolmentResult(
      status: AthleteCatalogueEnrolmentStatus.enrolled,
      programmeVersionId: programmeVersionId,
      timezone: timezone,
      startedAt: localStartDate,
    );
  }
}

final _bali = PrivateProgrammeSummary(
  versionId: 'preview-private-version',
  title: 'Bali Hybrid Base',
  summary: 'Internal 8-week hybrid base. 71 sessions. Not a public catalogue programme.',
  durationWeeks: 8,
  sessionsPerWeek: 9,
  classification: 'private',
  startEligible: true,
  authorisedTimezone: 'Asia/Makassar',
  authorisedLocalStartDate: DateTime(2026, 9, 26),
);

class PrivateActivationPreviewApp extends StatelessWidget {
  const PrivateActivationPreviewApp({
    super.key,
    this.initialState = PrivateActivationPreviewState.listWithBali,
  });

  final PrivateActivationPreviewState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: PrivateActivationPreviewScreen(initialState: initialState),
    );
  }
}

class PrivateActivationPreviewScreen extends StatefulWidget {
  const PrivateActivationPreviewScreen({
    super.key,
    this.initialState = PrivateActivationPreviewState.listWithBali,
  });

  final PrivateActivationPreviewState initialState;

  @override
  State<PrivateActivationPreviewScreen> createState() =>
      _PrivateActivationPreviewScreenState();
}

class _PrivateActivationPreviewScreenState
    extends State<PrivateActivationPreviewScreen> {
  late PrivateActivationPreviewState _state = widget.initialState;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        size: _state == PrivateActivationPreviewState.narrowViewport
            ? const Size(320, 720)
            : media.size,
        textScaler: _state == PrivateActivationPreviewState.largeText
            ? const TextScaler.linear(1.4)
            : media.textScaler,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Private activation preview'),
          actions: [
            PopupMenuButton<PrivateActivationPreviewState>(
              onSelected: (value) => setState(() => _state = value),
              itemBuilder: (context) => [
                for (final value in PrivateActivationPreviewState.values)
                  PopupMenuItem(value: value, child: Text(value.name)),
              ],
            ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case PrivateActivationPreviewState.emptyList:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: AthletePrivateProgrammesSection(
            discoveryStore: _PreviewDiscoveryStore([]),
            enrolmentStore: _PreviewEnrolmentStore(),
          ),
        );
      case PrivateActivationPreviewState.activationReview:
      case PrivateActivationPreviewState.typedFailure:
      case PrivateActivationPreviewState.success:
        return AthletePrivateProgrammeActivationScreen(
          programme: _bali,
          currentProgrammeTitle: 'Apollo Build',
          enrolmentStore: _PreviewEnrolmentStore(
            succeed: _state != PrivateActivationPreviewState.typedFailure,
          ),
        );
      case PrivateActivationPreviewState.listWithBali:
      case PrivateActivationPreviewState.narrowViewport:
      case PrivateActivationPreviewState.largeText:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: AthletePrivateProgrammesSection(
            discoveryStore: _PreviewDiscoveryStore([_bali]),
            enrolmentStore: const _PreviewEnrolmentStore(),
            currentProgrammeTitle: 'Apollo Build',
          ),
        );
    }
  }
}
