import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/coach_studio_ui.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/programme_vocabulary.dart';
import '../../programme/models/programme_catalog_entry.dart';
import 'controllers/programme_catalogue_controller.dart';
import 'models/programme_catalogue_action.dart';
import 'models/programme_catalogue_sort_mode.dart';
import 'models/programme_catalogue_tab.dart';
import 'models/programme_catalogue_view_state.dart';
import 'new_programme_screen.dart';
import 'programme_editor_screen.dart';
import 'programme_preview_screen.dart';
import 'widgets/programme_catalogue_card.dart';
import 'widgets/programme_catalogue_empty_state.dart';
import 'widgets/programme_catalogue_skeleton.dart';

class ProgrammeCatalogueScreen extends StatefulWidget {
  const ProgrammeCatalogueScreen({
    super.key,
    required this.controller,
  });

  final ProgrammeCatalogueController controller;

  @override
  State<ProgrammeCatalogueScreen> createState() =>
      _ProgrammeCatalogueScreenState();
}

class _ProgrammeCatalogueScreenState extends State<ProgrammeCatalogueScreen> {
  ProgrammeCatalogueController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.loadTab(_controller.activeTab);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openNewProgramme() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewProgrammeScreen(controller: _controller),
      ),
    );
    await _controller.refreshCurrentTab();
  }

  Future<void> _handleCardTap(ProgrammeCatalogEntry entry) async {
    final action = _controller.activeTab == ProgrammeCatalogueTab.drafts
        ? ProgrammeCatalogueAction.open
        : ProgrammeCatalogueAction.preview;

    await _runAction(action: action, entry: entry);
  }

  Future<void> _runAction({
    required ProgrammeCatalogueAction action,
    required ProgrammeCatalogEntry entry,
  }) async {
    if (action == ProgrammeCatalogueAction.duplicateProgramme) {
      await _showDuplicateDialog(entry);
      return;
    }

    final result = await _controller.runAction(action: action, entry: entry);

    if (!mounted) return;

    if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message!)),
      );
    }

    if (result.navigateToEditor && result.versionId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgrammeEditorScreen(
            versionId: result.versionId!,
          ),
        ),
      );
      await _controller.refreshCurrentTab();
      return;
    }

    if (action == ProgrammeCatalogueAction.preview && result.versionId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgrammeCataloguePreviewLoader(
            versionId: result.versionId!,
          ),
        ),
      );
    }
  }

  Future<void> _showDuplicateDialog(ProgrammeCatalogEntry entry) async {
    final nameController = TextEditingController(text: '${entry.name} Copy');
    final lineageController = TextEditingController(
      text: '${entry.lineageCode}-COPY',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Duplicate Programme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Programme name'),
              ),
              TextField(
                controller: lineageController,
                decoration: const InputDecoration(labelText: 'New lineage code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Duplicate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final result = await _controller.duplicateProgramme(
      sourceVersionId: entry.versionId,
      newLineageCode: lineageController.text.trim(),
      newProgrammeName: nameController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Duplicate complete.')),
    );

    if (result.navigateToEditor && result.versionId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgrammeEditorScreen(
            versionId: result.versionId!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachStudioPageHeader(
                backLabel: '← Coach Studio',
                onBack: () => Navigator.pop(context),
                title: 'Programmes',
                subtitle: 'Create and manage training programmes.',
                trailing: TextButton(
                  onPressed:
                      _controller.isActionInProgress ? null : _openNewProgramme,
                  child: const Text('New programme'),
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              CohortSearchBar(
                hintText: 'Search programmes…',
                onChanged: _controller.setSearchTerm,
              ),
              const SizedBox(height: CohortSpacing.sm),
              _filtersRow(),
              const SizedBox(height: CohortSpacing.md),
              _tabBar(),
              const SizedBox(height: CohortSpacing.md),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtersRow() {
    return Wrap(
      spacing: CohortSpacing.sm,
      runSpacing: CohortSpacing.sm,
      children: [
        DropdownButton<ProgrammeLibraryScope?>(
          value: _controller.libraryScopeFilter,
          hint: const Text('Scope'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All scopes')),
            ...ProgrammeLibraryScope.values.map(
              (scope) => DropdownMenuItem(
                value: scope,
                child: Text(scope.displayLabel),
              ),
            ),
          ],
          onChanged: _controller.setScopeFilter,
        ),
        if (_controller.availablePrimaryGoals.isNotEmpty)
          DropdownButton<String?>(
            value: _controller.primaryGoalFilter,
            hint: const Text('Goal'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All goals')),
              ..._controller.availablePrimaryGoals.map(
                (goal) => DropdownMenuItem(value: goal, child: Text(goal)),
              ),
            ],
            onChanged: _controller.setPrimaryGoalFilter,
          ),
        DropdownButton<ProgrammeCatalogueSortMode>(
          value: _controller.sortMode,
          items: [
            ProgrammeCatalogueSortMode.lastEdited,
            ProgrammeCatalogueSortMode.nameAZ,
            ProgrammeCatalogueSortMode.versionNewest,
          ]
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(mode.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) _controller.setSortMode(value);
          },
        ),
      ],
    );
  }

  Widget _tabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ProgrammeCatalogueTab.values.map((tab) {
          final selected = _controller.activeTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: CohortSpacing.sm),
            child: ChoiceChip(
              label: Text(tab.label),
              selected: selected,
              onSelected: (_) => _controller.loadTab(tab),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body() {
    return switch (_controller.viewState) {
      ProgrammeCatalogueViewState.loading => const ProgrammeCatalogueSkeleton(),
      ProgrammeCatalogueViewState.empty => ProgrammeCatalogueEmptyState(
          tab: _controller.activeTab,
          onCreate: _openNewProgramme,
        ),
      ProgrammeCatalogueViewState.permissionDenied => _errorBody(
          'You do not have access to these programmes.',
        ),
      ProgrammeCatalogueViewState.error => _errorBody(
          _controller.errorMessage ?? 'We could not load programmes right now.',
          showRetry: true,
        ),
      ProgrammeCatalogueViewState.ready => RefreshIndicator(
          onRefresh: _controller.refreshCurrentTab,
          child: ListView.separated(
            itemCount: _controller.displayedEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: CohortSpacing.md),
            itemBuilder: (context, index) {
              final entry = _controller.displayedEntries[index];
              final disabled =
                  _controller.actionInProgressVersionId == entry.versionId;

              return ProgrammeCatalogueCard(
                entry: entry,
                tab: _controller.activeTab,
                disabled: disabled,
                onTap: () => _handleCardTap(entry),
                onAction: (action) => _runAction(action: action, entry: entry),
              );
            },
          ),
        ),
    };
  }

  Widget _errorBody(String message, {bool showRetry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: CohortTextStyles.body, textAlign: TextAlign.center),
          if (showRetry) ...[
            const SizedBox(height: CohortSpacing.md),
            TextButton(
              onPressed: _controller.refreshCurrentTab,
              child: Text(
                'Retry',
                style: CohortTextStyles.body.copyWith(color: CohortColors.olive),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
