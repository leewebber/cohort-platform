import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/current_coach_identity.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../session/session_preview_screen.dart';
import '../models/training_library_item_summary.dart';
import '../services/session_library_authoring_coordinator.dart';
import '../services/session_library_authoring_services.dart';
import '../services/training_library_service.dart';

/// Selected reusable Session from the programme slot picker.
class SessionLibraryPickerSelection {
  const SessionLibraryPickerSelection({
    required this.contentId,
    required this.displayTitle,
  });

  final String contentId;
  final String displayTitle;
}

typedef SessionLibraryListLoader = Future<List<TrainingLibraryItemSummary>>
    Function({String? searchTerm});

class SessionLibraryPickerSheet extends StatefulWidget {
  const SessionLibraryPickerSheet({
    super.key,
    this.libraryService,
    this.coordinator,
    this.coachIdentity,
    this.listSessions,
  });

  final TrainingLibraryService? libraryService;
  final SessionLibraryAuthoringCoordinator? coordinator;
  final CurrentCoachIdentity? coachIdentity;
  final SessionLibraryListLoader? listSessions;

  @override
  State<SessionLibraryPickerSheet> createState() =>
      _SessionLibraryPickerSheetState();
}

class _SessionLibraryPickerSheetState extends State<SessionLibraryPickerSheet> {
  late final TrainingLibraryService _libraryService =
      widget.libraryService ?? TrainingLibraryService();
  late final SessionLibraryAuthoringCoordinator _coordinator =
      widget.coordinator ??
          SessionLibraryAuthoringServices.createCoordinator(
            coachIdentity: widget.coachIdentity,
          );
  late final CurrentCoachIdentity _coachIdentity =
      widget.coachIdentity ?? const DevCoachIdentity();

  final _searchController = TextEditingController();
  List<TrainingLibraryItemSummary> _items = const [];
  bool _loading = true;
  Object? _error;
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
      final items = widget.listSessions != null
          ? await widget.listSessions!(
              searchTerm: _searchController.text.trim(),
            )
          : await _libraryService.loadReusableSessionSummaries(
              ownerId: _coachIdentity.coachId ?? '',
              searchTerm: _searchController.text.trim(),
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
      final draft = await _coordinator.loadSession(item.contentId);
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
          Text('Session Library', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search Sessions',
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
                    'We could not load Sessions right now.',
                    style: CohortTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else if (_items.isEmpty && _searchController.text.trim().isEmpty)
            const Padding(
              padding: EdgeInsets.all(CohortSpacing.lg),
              child: Text(
                'No reusable Sessions yet. Create one in Training Library.',
                style: CohortTextStyles.body,
                textAlign: TextAlign.center,
              ),
            )
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(CohortSpacing.lg),
              child: Text(
                'No Sessions match your search.',
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
