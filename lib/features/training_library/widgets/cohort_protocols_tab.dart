import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/coach_studio_ui.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_filtering.dart';
import '../../../models/protocol_filters.dart';
import '../../programme_builder/models/cohort_protocol_customisation_result.dart';
import '../../programme_builder/services/cohort_protocol_customisation_services.dart';
import '../../protocols/protocol_detail/protocol_detail_screen.dart';
import '../../session_builder/models/cohort_protocol_copy_destination.dart';
import '../screens/library_session_builder_screen.dart';
import '../services/session_library_authoring_services.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/training_library_item_summary.dart';
import '../services/training_library_service.dart';
import 'training_library_cards.dart';

class CohortProtocolsTab extends StatefulWidget {
  const CohortProtocolsTab({
    super.key,
    this.libraryService,
    this.protocolRepository,
  });

  final TrainingLibraryService? libraryService;
  final ProtocolRepository? protocolRepository;

  @override
  State<CohortProtocolsTab> createState() => _CohortProtocolsTabState();
}

class _CohortProtocolsTabState extends State<CohortProtocolsTab> {
  late final TrainingLibraryService _libraryService =
      widget.libraryService ?? TrainingLibraryService();
  late final ProtocolRepository _protocolRepository =
      widget.protocolRepository ?? ProtocolRepository();

  List<TrainingLibraryItemSummary> _summaries = const [];
  List<Protocol> _protocols = const [];
  bool _loading = true;
  Object? _error;
  String _search = '';
  ProtocolFilters _filters = ProtocolFilters.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summaries = await _libraryService.loadCohortProtocolSummaries();
      final protocols = await _protocolRepository.listCohortProtocols();
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _protocols = protocols;
        _loading = false;
      });
      TrainingLibraryDiagnostics.log('opened tab=cohortProtocols');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<TrainingLibraryItemSummary> get _visibleSummaries {
    final filteredProtocols = filterProtocols(
      protocols: _protocols,
      search: _search,
      filters: _filters,
    );
    final allowedIds = filteredProtocols.map((p) => p.protocolId).toSet();
    return _summaries
        .where((item) => allowedIds.contains(item.contentId))
        .toList();
  }

  Protocol? _protocolForSummary(TrainingLibraryItemSummary summary) {
    for (final protocol in _protocols) {
      if (protocol.protocolId == summary.contentId) return protocol;
    }
    return null;
  }

  void _openPreview(TrainingLibraryItemSummary summary) {
    final protocol = _protocolForSummary(summary);
    if (protocol == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProtocolDetailScreen(
          protocol: protocol,
          onCopyToSessionLibrary: () {
            Navigator.pop(context);
            _copyToSessionLibrary(summary);
          },
        ),
      ),
    );
  }

  Future<void> _copyToSessionLibrary(TrainingLibraryItemSummary summary) async {
    final customisationCoordinator =
        CohortProtocolCustomisationServices.forTrainingLibrary();

    final prepared = await customisationCoordinator.prepareCopy(
      sourceProtocolId: summary.contentId,
      destination: CohortProtocolCopyDestination.sessionLibrary,
    );

    if (!mounted) return;

    if (prepared.status != CohortProtocolCustomisationStatus.prepared ||
        prepared.copiedDraft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prepared.coachMessage ??
                'This Cohort Protocol could not be copied right now.',
          ),
        ),
      );
      return;
    }

    final libraryCoordinator = SessionLibraryAuthoringServices.createCoordinator();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LibrarySessionBuilderScreen(
          coordinator: libraryCoordinator,
          initialDraft: prepared.copiedDraft,
        ),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CoachStudioLoadingState(
        message: 'Loading Cohort Protocols…',
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'We could not load Cohort Protocols right now.',
              style: CohortTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CohortSpacing.md),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final visible = _visibleSummaries;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Official Cohort-endorsed training content.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.lg),
        CohortSearchBar(
          hintText: 'Search Cohort Protocols...',
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: CohortSpacing.lg),
        Text('${visible.length} protocols', style: CohortTextStyles.muted),
        const SizedBox(height: CohortSpacing.lg),
        if (visible.isEmpty)
          CoachStudioEmptyState(
            title: _search.trim().isEmpty
                ? 'No Cohort Protocols available'
                : 'No matches found',
            message: _search.trim().isEmpty
                ? 'Official Cohort Protocols will appear here when published.'
                : 'Try a different search term.',
          )
        else
          ...visible.map(
            (summary) => Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.md),
              child: CohortProtocolLibraryCard(
                summary: summary,
                onPreview: () => _openPreview(summary),
                onCopyToSessionLibrary: () => _copyToSessionLibrary(summary),
                onTap: () => _openPreview(summary),
              ),
            ),
          ),
      ],
    );
  }
}
