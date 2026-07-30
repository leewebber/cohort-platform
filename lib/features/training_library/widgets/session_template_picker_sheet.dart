import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/current_coach_identity.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../session/session_preview_screen.dart';
import '../models/session_template_taxonomy.dart';
import '../models/training_library_item_summary.dart';
import '../services/session_library_authoring_services.dart';
import '../services/training_library_service.dart';
import 'session_library_picker_sheet.dart';

/// Shared template picker for programme empty slots (copy-on-use, not live attach).
///
/// Uses the same canonical Cohort Templates catalogue as Training Library.
class SessionTemplatePickerSheet extends StatefulWidget {
  const SessionTemplatePickerSheet({
    super.key,
    this.libraryService,
    this.coachIdentity,
    this.listTemplates,
  });

  final TrainingLibraryService? libraryService;
  final CurrentCoachIdentity? coachIdentity;
  final SessionLibraryListLoader? listTemplates;

  @override
  State<SessionTemplatePickerSheet> createState() =>
      _SessionTemplatePickerSheetState();
}

class _SessionTemplatePickerSheetState
    extends State<SessionTemplatePickerSheet> {
  late final TrainingLibraryService _libraryService =
      widget.libraryService ?? TrainingLibraryService();
  late final CurrentCoachIdentity _coachIdentity =
      widget.coachIdentity ?? const AuthenticatedCoachIdentity();

  final _searchController = TextEditingController();
  List<TrainingLibraryItemSummary> _items = const [];
  bool _loading = true;
  Object? _error;
  SessionTemplateModalityFilter _modality = SessionTemplateModalityFilter.all;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = widget.listTemplates != null
          ? await widget.listTemplates!(
              searchTerm: _searchController.text.trim(),
            )
          : await _libraryService.loadCanonicalTemplateSummaries(
              searchTerm: _searchController.text.trim(),
              modality: _modality,
            );

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _items = const [];
        _loading = false;
      });
    }
  }

  Future<void> _preview(TrainingLibraryItemSummary item) async {
    try {
      final coordinator = SessionLibraryAuthoringServices.createCoordinator(
        coachIdentity: _coachIdentity,
      );
      final draft = await coordinator.loadTemplateForPreview(item.contentId);
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

  void _select(TrainingLibraryItemSummary item) {
    Navigator.pop(
      context,
      SessionLibraryPickerSelection(
        contentId: item.contentId,
        displayTitle: item.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: CohortSpacing.lg,
        right: CohortSpacing.lg,
        top: CohortSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Templates', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Use Template creates a copy for this programme slot. The source template stays unchanged.',
            style: CohortTextStyles.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CohortSpacing.md),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(labelText: 'Search templates'),
          ),
          const SizedBox(height: CohortSpacing.sm),
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
          const SizedBox(height: CohortSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(CohortSpacing.lg),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: Column(
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
            )
          else if (_items.isEmpty &&
              _searchController.text.trim().isEmpty &&
              _modality == SessionTemplateModalityFilter.all)
            const Padding(
              padding: EdgeInsets.all(CohortSpacing.lg),
              child: Text(
                'No templates yet. Deploy the Cohort template seed to populate this catalogue.',
                style: CohortTextStyles.body,
                textAlign: TextAlign.center,
              ),
            )
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(CohortSpacing.lg),
              child: Text(
                'No templates match your search.',
                style: CohortTextStyles.body,
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    title: Text(item.title, style: CohortTextStyles.cardTitle),
                    subtitle: Text(
                      [
                        'Template',
                        if (item.publicCode != null) item.publicCode!,
                        if (item.sessionType != null) item.sessionType!,
                        if (item.durationMin != null) '${item.durationMin} min',
                      ].join(' · '),
                      style: CohortTextStyles.small,
                    ),
                    trailing: TextButton(
                      onPressed: () => _preview(item),
                      child: const Text('Preview'),
                    ),
                    onTap: () => _select(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
