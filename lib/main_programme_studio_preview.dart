import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme_studio/domain/programme_review_models.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_app.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_catalog.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_projector.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_source.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Internal Programme Studio Stage 1 preview. Not imported by `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4195 \
///     -t lib/main_programme_studio_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProgrammeStudioPreviewApp(
      initialState: ProgrammeStudioPreviewState.realReview,
    ),
  );
}

enum ProgrammeStudioPreviewState {
  realReview,
  malformedSource,
  validationFailure,
  unsupportedPrescription,
  emptyInventory,
  missingProtocol,
  narrowViewport,
  largeText,
}

class ProgrammeStudioPreviewApp extends StatelessWidget {
  const ProgrammeStudioPreviewApp({
    super.key,
    this.initialState = ProgrammeStudioPreviewState.realReview,
  });

  final ProgrammeStudioPreviewState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: ProgrammeStudioPreviewScreen(initialState: initialState),
    );
  }
}

class ProgrammeStudioPreviewScreen extends StatefulWidget {
  const ProgrammeStudioPreviewScreen({
    super.key,
    this.initialState = ProgrammeStudioPreviewState.realReview,
  });

  final ProgrammeStudioPreviewState initialState;

  @override
  State<ProgrammeStudioPreviewScreen> createState() =>
      _ProgrammeStudioPreviewScreenState();
}

class _ProgrammeStudioPreviewScreenState
    extends State<ProgrammeStudioPreviewScreen> {
  late ProgrammeStudioPreviewState _state = widget.initialState;
  ProgrammeReviewCatalog? _realCatalog;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadReal();
  }

  Future<void> _loadReal() async {
    try {
      final assets = <String, String>{};
      for (final path in ProgrammeReviewCatalogRegistry.realReadablePaths) {
        assets[path] = await rootBundle.loadString(path);
      }
      final catalog = ProgrammeReviewWorkspace(
        readAsset: (path) => assets[path]!,
      ).loadRealCatalog();
      if (!mounted) {
        return;
      }
      setState(() => _realCatalog = catalog);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow =
        _state == ProgrammeStudioPreviewState.narrowViewport ||
        _state == ProgrammeStudioPreviewState.largeText;
    final largeText = _state == ProgrammeStudioPreviewState.largeText;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: narrow ? const Size(390, 844) : MediaQuery.of(context).size,
        textScaler: TextScaler.linear(largeText ? 1.7 : 1),
      ),
      child: Scaffold(
        body: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<ProgrammeStudioPreviewState>(
                tooltip: 'Preview fixture states',
                initialValue: _state,
                onSelected: (value) => setState(() => _state = value),
                itemBuilder: (context) => [
                  for (final state in ProgrammeStudioPreviewState.values)
                    PopupMenuItem(value: state, child: Text(_label(state))),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.more_horiz),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_state == ProgrammeStudioPreviewState.realReview ||
        _state == ProgrammeStudioPreviewState.narrowViewport ||
        _state == ProgrammeStudioPreviewState.largeText) {
      if (_loadError != null) {
        return Text('Preview could not load real review data: $_loadError');
      }
      if (_realCatalog == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return ProgrammeStudioScreen(
        catalog: _realCatalog!,
        previewStateLabel: _label(_state),
      );
    }
    return ProgrammeStudioScreen(
      catalog: _fixtureCatalog(_state),
      showDeveloperFixtures:
          _state != ProgrammeStudioPreviewState.emptyInventory,
      previewStateLabel: _label(_state),
    );
  }

  String _label(ProgrammeStudioPreviewState state) {
    return switch (state) {
      ProgrammeStudioPreviewState.realReview => 'Fixture: real review data',
      ProgrammeStudioPreviewState.malformedSource =>
        'Fixture: malformed source',
      ProgrammeStudioPreviewState.validationFailure =>
        'Fixture: validation failure',
      ProgrammeStudioPreviewState.unsupportedPrescription =>
        'Fixture: unsupported prescription',
      ProgrammeStudioPreviewState.emptyInventory => 'Fixture: empty inventory',
      ProgrammeStudioPreviewState.missingProtocol =>
        'Fixture: missing protocol',
      ProgrammeStudioPreviewState.narrowViewport => 'Fixture: narrow viewport',
      ProgrammeStudioPreviewState.largeText => 'Fixture: large text',
    };
  }
}

ProgrammeReviewCatalog _fixtureCatalog(ProgrammeStudioPreviewState state) {
  const projector = ProgrammeReviewProjector();
  if (state == ProgrammeStudioPreviewState.emptyInventory) {
    return const ProgrammeReviewCatalog(
      authority: ProgrammeReviewCatalog.derivedAuthority,
      sourceInputs: [],
      programmes: [],
      plannedFamilies: ProgrammeReviewCatalogRegistry.plannedFamilies,
    );
  }
  if (state == ProgrammeStudioPreviewState.malformedSource) {
    return projector.project(
      const ProgrammeReviewProjectionRequest(
        bundles: [
          ProgrammeReviewSourceBundle(
            spec: ProgrammeReviewSourceSpec(
              catalogId: 'fixture-malformed',
              classification: ProgrammeReviewClassification.fixtureTestExample,
              planPackagePath: 'preview/malformed.yaml',
              fixture: true,
            ),
            planPackageYaml: '::: not yaml',
          ),
        ],
      ),
    );
  }
  if (state == ProgrammeStudioPreviewState.validationFailure) {
    return projector.project(
      const ProgrammeReviewProjectionRequest(
        bundles: [
          ProgrammeReviewSourceBundle(
            spec: ProgrammeReviewSourceSpec(
              catalogId: 'fixture-invalid',
              classification: ProgrammeReviewClassification.fixtureTestExample,
              planPackagePath: 'preview/invalid.yaml',
              fixture: true,
            ),
            planPackageYaml: _invalidPackageYaml,
          ),
        ],
      ),
    );
  }
  if (state == ProgrammeStudioPreviewState.unsupportedPrescription) {
    return projector.project(
      const ProgrammeReviewProjectionRequest(
        bundles: [
          ProgrammeReviewSourceBundle(
            spec: ProgrammeReviewSourceSpec(
              catalogId: 'fixture-unsupported',
              classification: ProgrammeReviewClassification.fixtureTestExample,
              planPackagePath: 'preview/unsupported.yaml',
              fixture: true,
            ),
            planPackageYaml: _oneSessionPackageYaml,
            executableProtocolSql: [_unsupportedSql],
          ),
        ],
      ),
    );
  }
  return projector.project(
    const ProgrammeReviewProjectionRequest(
      bundles: [
        ProgrammeReviewSourceBundle(
          spec: ProgrammeReviewSourceSpec(
            catalogId: 'fixture-missing-protocol',
            classification: ProgrammeReviewClassification.fixtureTestExample,
            planPackagePath: 'preview/missing.yaml',
            fixture: true,
          ),
          planPackageYaml: _oneSessionPackageYaml,
        ),
      ],
    ),
  );
}

const _invalidPackageYaml = '''
package_schema_version: 1
programme:
  lineage_code: FIXTURE-INVALID
  version_number: 1
  name: Invalid fixture
  library_scope: organisation
  owner_type: organisation
  coaching_intent: Fixture only
sessions: []
phases: []
weeks: []
''';

const _oneSessionPackageYaml = '''
package_schema_version: 1
programme:
  lineage_code: FIXTURE-ONE
  version_number: 1
  name: Fixture one session
  library_scope: organisation
  owner_type: organisation
  coaching_intent: Fixture only
  duration_weeks: 1
  sessions_per_week: 1
sessions:
  - session_key: SES-FIX
    protocol_id: PROTO-X
    session_lineage_id: 00000000-0000-4000-8000-000000000099
    revision_number: 1
    title: Fixture session
phases: []
weeks:
  - week_number: 1
    title: Week 1
    days:
      - day_key: day_1
        day_order: 1
        day_type: training
        title: Monday
        slots:
          - slot_key: W1D1S1
            session_order: 1
            session_key: SES-FIX
            completion_expectation: required
            progression:
              prescription_summary: Fixture slot
adaptation_permissions: []
protected_invariants: []
assessments: []
performance_evidence_requirements: []
comparison_identities: []
''';

const _unsupportedSql = '''
INSERT INTO public.performance_protocols(protocol_id,name,purpose,published,content_kind,authoring_scope,endorsement_status,organisation_id,session_lineage_id,revision_number,lifecycle_status,duration_min,primary_session_intent,coaching_notes) VALUES
 ('PROTO-X','Fixture session','x','false','session','organisation','organisation_approved','x','00000000-0000-4000-8000-000000000099',1,'draft',10,'test','n');
INSERT INTO public.session_blocks(block_id,session_id,block_type,title,content,workout_format,timer_config,coach_notes,position) VALUES
 ('11111111-0000-4000-8000-000000000099','PROTO-X','mystery','Mystery block','Do the thing','unknown_format',NULL,NULL,1);
''';
