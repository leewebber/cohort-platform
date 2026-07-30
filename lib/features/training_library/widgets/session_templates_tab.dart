import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/current_coach_identity.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../models/protocol_draft.dart';
import '../../session/session_preview_screen.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/session_library_authoring_result.dart';
import '../models/session_template_taxonomy.dart';
import '../models/training_library_item_summary.dart';
import '../screens/library_session_builder_screen.dart';
import '../services/session_library_authoring_coordinator.dart';
import '../services/session_library_authoring_services.dart';
import '../services/training_library_service.dart';
import 'session_template_library_card.dart';

/// Training Library Templates destination (Cohort starter catalogue).
class SessionTemplatesTab extends StatefulWidget {
  const SessionTemplatesTab({
    super.key,
    this.libraryService,
    this.coordinator,
    this.coachIdentity,
    this.listTemplates,
  });

  final TrainingLibraryService? libraryService;
  final SessionLibraryAuthoringCoordinator? coordinator;
  final CurrentCoachIdentity? coachIdentity;
  final Future<List<TrainingLibraryItemSummary>> Function({
    String? searchTerm,
    SessionTemplateModalityFilter modality,
    SessionTemplateEquipmentFilter equipment,
  })?
  listTemplates;

  @override
  State<SessionTemplatesTab> createState() => _SessionTemplatesTabState();
}

class _SessionTemplatesTabState extends State<SessionTemplatesTab> {
  late final TrainingLibraryService _libraryService =
      widget.libraryService ?? TrainingLibraryService();
  late final SessionLibraryAuthoringCoordinator _coordinator =
      widget.coordinator ??
      SessionLibraryAuthoringServices.createCoordinator(
        coachIdentity: widget.coachIdentity,
      );
  late final CurrentCoachIdentity _coachIdentity =
      widget.coachIdentity ?? const AuthenticatedCoachIdentity();

  List<TrainingLibraryItemSummary> _summaries = const [];
  bool _loading = true;
  Object? _error;
  String _search = '';
  SessionTemplateModalityFilter _modality = SessionTemplateModalityFilter.all;
  SessionTemplateEquipmentFilter _equipment =
      SessionTemplateEquipmentFilter.all;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    TrainingLibraryDiagnostics.log('opened tab=templates');
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
      final summaries = widget.listTemplates != null
          ? await widget.listTemplates!(
              searchTerm: _search,
              modality: _modality,
              equipment: _equipment,
            )
          : await _libraryService.loadCanonicalTemplateSummaries(
              searchTerm: _search,
              modality: _modality,
              equipment: _equipment,
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

  Future<void> _preview(TrainingLibraryItemSummary summary) async {
    try {
      final draft = await _coordinator.loadTemplateForPreview(
        summary.contentId,
      );
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

  Future<void> _useTemplate(TrainingLibraryItemSummary summary) async {
    ProtocolDraft draft;
    try {
      draft = await _coordinator.prepareDraftFromTemplate(
        templateContentId: summary.contentId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This template could not be opened right now.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final result = await Navigator.of(context)
        .push<SessionLibraryAuthoringResult>(
          MaterialPageRoute<SessionLibraryAuthoringResult>(
            builder: (_) => LibrarySessionBuilderScreen(
              coordinator: _coordinator,
              coachIdentity: _coachIdentity,
              initialDraft: draft,
            ),
          ),
        );

    if (!mounted) return;
    if (result?.isSuccess == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result!.coachMessage ??
                'Session saved to My Sessions. The template was not changed.',
          ),
        ),
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
              'We could not load templates right now.',
              style: CohortTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CohortSpacing.md),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final isEmptyCatalogue =
        _summaries.isEmpty &&
        _search.trim().isEmpty &&
        _modality == SessionTemplateModalityFilter.all &&
        _equipment == SessionTemplateEquipmentFilter.all;
    final isEmptyFiltered = _summaries.isEmpty && !isEmptyCatalogue;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CohortSearchBar(
                hintText: 'Search templates',
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: CohortSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in SessionTemplateModalityFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter.label),
                          selected: _modality == filter,
                          onSelected: (_) {
                            setState(() => _modality = filter);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CohortSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in SessionTemplateEquipmentFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter.label),
                          selected: _equipment == filter,
                          onSelected: (_) {
                            setState(() => _equipment = filter);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isEmptyCatalogue
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(CohortSpacing.lg),
                    child: Text(
                      'No templates available yet. Seeded Cohort templates will appear here after deployment.',
                      style: CohortTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : isEmptyFiltered
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(CohortSpacing.lg),
                    child: Text(
                      'No templates match these filters.',
                      style: CohortTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _summaries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: CohortSpacing.md),
                  itemBuilder: (context, index) {
                    final summary = _summaries[index];
                    return SessionTemplateLibraryCard(
                      summary: summary,
                      onPreview: () => _preview(summary),
                      onUseTemplate: () => _useTemplate(summary),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
