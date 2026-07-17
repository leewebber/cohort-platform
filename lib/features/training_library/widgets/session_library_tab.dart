import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/current_coach_identity.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../models/protocol_draft.dart';
import '../../session/session_preview_screen.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/session_library_authoring_result.dart';
import '../models/training_library_item_summary.dart';
import '../screens/library_session_builder_screen.dart';
import '../services/session_library_authoring_coordinator.dart';
import '../services/session_library_authoring_services.dart';
import '../services/training_library_service.dart';
import 'training_library_cards.dart';

class SessionLibraryTab extends StatefulWidget {
  const SessionLibraryTab({
    super.key,
    this.libraryService,
    this.coordinator,
    this.coachIdentity,
    this.protocolBuilderService,
  });

  final TrainingLibraryService? libraryService;
  final SessionLibraryAuthoringCoordinator? coordinator;
  final CurrentCoachIdentity? coachIdentity;
  final ProtocolBuilderService? protocolBuilderService;

  @override
  State<SessionLibraryTab> createState() => _SessionLibraryTabState();
}

class _SessionLibraryTabState extends State<SessionLibraryTab> {
  late final TrainingLibraryService _libraryService =
      widget.libraryService ?? TrainingLibraryService();
  late final SessionLibraryAuthoringCoordinator _coordinator =
      widget.coordinator ??
          SessionLibraryAuthoringServices.createCoordinator(
            protocolBuilderService: widget.protocolBuilderService,
            coachIdentity: widget.coachIdentity,
          );
  late final CurrentCoachIdentity _coachIdentity =
      widget.coachIdentity ?? const DevCoachIdentity();

  List<TrainingLibraryItemSummary> _summaries = const [];
  bool _loading = true;
  Object? _error;
  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    TrainingLibraryDiagnostics.log('opened tab=sessionLibrary');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ownerId = _coachIdentity.coachId ?? '';
      final summaries = await _libraryService.loadReusableSessionSummaries(
        ownerId: ownerId,
        searchTerm: _search,
      );
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _createSession() async {
    final result = await Navigator.of(context).push<SessionLibraryAuthoringResult>(
      MaterialPageRoute<SessionLibraryAuthoringResult>(
        builder: (_) => LibrarySessionBuilderScreen(
          coordinator: _coordinator,
          coachIdentity: _coachIdentity,
        ),
      ),
    );

    if (!mounted) return;
    if (result?.isSuccess == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result!.coachMessage ?? 'Session saved')),
      );
    }
  }

  Future<void> _editSession(TrainingLibraryItemSummary summary) async {
    ProtocolDraft initialDraft;
    try {
      initialDraft = await _coordinator.loadSession(summary.contentId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This session could not be loaded.')),
      );
      return;
    }

    final result = await Navigator.of(context).push<SessionLibraryAuthoringResult>(
      MaterialPageRoute<SessionLibraryAuthoringResult>(
        builder: (_) => LibrarySessionBuilderScreen(
          coordinator: _coordinator,
          coachIdentity: _coachIdentity,
          initialDraft: initialDraft,
          isEdit: true,
        ),
      ),
    );

    if (!mounted) return;
    if (result?.isSuccess == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result!.coachMessage ?? 'Session updated')),
      );
    }
  }

  Future<void> _previewSession(TrainingLibraryItemSummary summary) async {
    try {
      final draft = await _coordinator.loadSession(summary.contentId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SessionPreviewScreen(draft: draft),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview is not available right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _summaries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'We could not load your Sessions right now.',
              style: CohortTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CohortSpacing.md),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final isEmptyLibrary = _summaries.isEmpty && _search.trim().isEmpty;
    final isEmptySearch = _summaries.isEmpty && _search.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Reusable coach-authored Sessions for any programme.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.lg),
        CohortButton(label: 'New Session', onPressed: _createSession),
        const SizedBox(height: CohortSpacing.lg),
        CohortSearchBar(
          hintText: 'Search Sessions...',
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: CohortSpacing.lg),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(CohortSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (isEmptyLibrary)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No Sessions yet', style: CohortTextStyles.h2),
              const SizedBox(height: CohortSpacing.sm),
              const Text(
                'Create reusable Sessions here, then add them to any programme.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(label: 'New Session', onPressed: _createSession),
            ],
          )
        else if (isEmptySearch)
          const Text(
            'No Sessions match your search.',
            style: CohortTextStyles.body,
          )
        else
          ..._summaries.map(
            (summary) => Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.md),
              child: SessionLibraryCard(
                summary: summary,
                onPreview: () => _previewSession(summary),
                onEdit: () => _editSession(summary),
              ),
            ),
          ),
      ],
    );
  }
}
