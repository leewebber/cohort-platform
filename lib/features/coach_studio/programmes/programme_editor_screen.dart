import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/programme_day_draft.dart';
import '../../../models/programme_session_slot_draft.dart';
import '../../../models/programme_week_draft.dart';
import '../../programme_builder/models/programme_builder_document.dart';
import 'controllers/programme_editor_controller.dart';
import 'controllers/programme_intelligence_controller.dart';
import 'models/programme_editor_view_state.dart';
import 'services/programme_editor_services.dart';
import 'services/programme_intelligence_services.dart';
import 'programme_preview_screen.dart';
import 'widgets/programme_editor_day_card.dart';
import 'widgets/programme_editor_header.dart';
import 'widgets/programme_editor_metadata_sheet.dart';
import 'widgets/programme_editor_slot_inspector.dart';
import 'widgets/programme_editor_unsaved_dialog.dart';
import 'widgets/programme_editor_validation_sheet.dart';
import 'widgets/programme_editor_week_nav.dart';
import 'widgets/intelligence/programme_intelligence_section.dart';

class ProgrammeEditorScreen extends StatefulWidget {
  const ProgrammeEditorScreen({
    super.key,
    required this.versionId,
    this.controller,
  });

  final String versionId;
  final ProgrammeEditorController? controller;

  @override
  State<ProgrammeEditorScreen> createState() => _ProgrammeEditorScreenState();
}

class _ProgrammeEditorScreenState extends State<ProgrammeEditorScreen> {
  late final ProgrammeEditorController _controller;
  late final bool _ownsController;
  late final ProgrammeIntelligenceController _intelligenceController;
  late final bool _ownsIntelligenceController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ProgrammeEditorServices.createController(versionId: widget.versionId);
    _controller.addListener(_onControllerChanged);
    _ownsIntelligenceController = true;
    _intelligenceController = ProgrammeIntelligenceServices.createController(
      versionId: widget.versionId,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsIntelligenceController) {
      _intelligenceController.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleExit() async {
    if (!_controller.hasUnsavedChanges) {
      Navigator.pop(context, true);
      return;
    }

    final action = await showProgrammeEditorUnsavedDialog(context: context);
    switch (action) {
      case ProgrammeEditorUnsavedAction.saveAndExit:
        final result = await _controller.save();
        if (result.success && mounted) {
          Navigator.pop(context, true);
        }
      case ProgrammeEditorUnsavedAction.discard:
        if (mounted) Navigator.pop(context, false);
      case ProgrammeEditorUnsavedAction.cancel:
      case null:
        return;
    }
  }

  ProgrammeWeekDraft? _selectedWeek(ProgrammeBuilderDocument document) {
    final weekId = _controller.selection.weekLocalId;
    if (weekId == null) return null;

    for (final week in document.template.allWeeks) {
      if (week.localId == weekId) return week;
    }
    return document.template.allWeeks.isEmpty
        ? null
        : document.template.allWeeks.first;
  }

  ProgrammeSessionSlotDraft? _selectedSlot(ProgrammeBuilderDocument document) {
    final slotId = _controller.selection.slotLocalId;
    if (slotId == null) return null;

    for (final week in document.template.allWeeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          if (slot.localId == slotId) return slot;
        }
      }
    }
    return null;
  }

  void _openSlotInspector({
    required String weekLocalId,
    required String dayLocalId,
    required String slotLocalId,
    required bool isCompact,
  }) {
    _controller.selectSlot(
      weekLocalId: weekLocalId,
      dayLocalId: dayLocalId,
      slotLocalId: slotLocalId,
    );

    final document = _controller.document;
    if (document == null) return;

    final slot = _selectedSlot(document);
    if (slot == null) return;

    if (isCompact) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: ProgrammeEditorSlotInspector(
            controller: _controller,
            weekLocalId: weekLocalId,
            dayLocalId: dayLocalId,
            slot: slot,
            readOnly: _controller.isReadOnly,
          ),
        ),
      );
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_controller.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.viewState) {
      case ProgrammeEditorViewState.loading:
      case ProgrammeEditorViewState.saving:
        return const Center(child: CircularProgressIndicator());
      case ProgrammeEditorViewState.error:
        return Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              Text(
                _controller.errorMessage ?? 'Could not load programme.',
                style: CohortTextStyles.body,
              ),
            ],
          ),
        );
      case ProgrammeEditorViewState.ready:
      case ProgrammeEditorViewState.readOnly:
        return _buildEditor();
    }
  }

  Widget _buildEditor() {
    final document = _controller.document;
    if (document == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final selectedWeek = _selectedWeek(document);
        final selectedSlot = _selectedSlot(document);

        return Column(
          children: [
            if (_controller.isReadOnly)
              Container(
                width: double.infinity,
                color: CohortColors.oliveSoft,
                padding: const EdgeInsets.all(CohortSpacing.sm),
                child: Text(
                  'Published programmes are read-only. Clone to edit.',
                  style: CohortTextStyles.small,
                ),
              ),
            ProgrammeEditorHeader(
              controller: _controller,
              onBack: _handleExit,
              onOpenMetadata: () => showProgrammeEditorMetadataSheet(
                context: context,
                controller: _controller,
              ),
              onSave: () async {
                final result = await _controller.save();
                if (!mounted) return;
                if (result.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message!)),
                  );
                }
              },
              onValidate: () async {
                await _controller.validate();
                if (!mounted) return;
                await showProgrammeEditorValidationSheet(
                  context: context,
                  controller: _controller,
                );
              },
              onPreview: () async {
                final preview = await _controller.buildPreview();
                if (!mounted || preview == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProgrammePreviewScreen(
                      preview: preview,
                      hasUnsavedChanges: _controller.hasUnsavedChanges,
                    ),
                  ),
                );
              },
              onPublish: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Publish programme?'),
                    content: const Text(
                      'Publishing freezes this version for athlete assignment.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Publish'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;

                final result = await _controller.publish();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? 'Programme published.'
                          : result.message ?? 'Publish failed.',
                    ),
                  ),
                );
              },
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: SingleChildScrollView(
                child: ProgrammeIntelligenceSection(
                  controller: _intelligenceController,
                ),
              ),
            ),
            if (isCompact)
              ProgrammeEditorWeekNav(
                controller: _controller,
                isCompact: true,
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCompact)
                    ProgrammeEditorWeekNav(
                      controller: _controller,
                      isCompact: false,
                    ),
                  Expanded(
                    child: selectedWeek == null
                        ? Center(
                            child: Text(
                              'No weeks yet.',
                              style: CohortTextStyles.body,
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(CohortSpacing.lg),
                            children: [
                              Text(
                                'Week ${selectedWeek.weekNumber}',
                                style: CohortTextStyles.h2,
                              ),
                              const SizedBox(height: CohortSpacing.md),
                              for (final day in selectedWeek.days)
                                ProgrammeEditorDayCard(
                                  controller: _controller,
                                  weekLocalId: selectedWeek.localId,
                                  day: day,
                                  onSelectSlot: (slotLocalId) =>
                                      _openSlotInspector(
                                    weekLocalId: selectedWeek.localId,
                                    dayLocalId: day.localId,
                                    slotLocalId: slotLocalId,
                                    isCompact: isCompact,
                                  ),
                                ),
                              if (!_controller.isReadOnly)
                                TextButton(
                                  onPressed: () =>
                                      _controller.addDay(selectedWeek.localId),
                                  child: const Text('+ Day'),
                                ),
                            ],
                          ),
                  ),
                  if (!isCompact &&
                      selectedSlot != null &&
                      _controller.selection.dayLocalId != null &&
                      _controller.selection.weekLocalId != null)
                    SizedBox(
                      width: 320,
                      child: ProgrammeEditorSlotInspector(
                        controller: _controller,
                        weekLocalId: _controller.selection.weekLocalId!,
                        dayLocalId: _controller.selection.dayLocalId!,
                        slot: selectedSlot,
                        readOnly: _controller.isReadOnly,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
