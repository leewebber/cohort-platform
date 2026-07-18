import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/coach_studio_ui.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../admin/services/protocol_builder_service.dart';
import '../../../programme_builder/models/programme_builder_constants.dart';
import '../../../programme_builder/models/cohort_protocol_customisation_result.dart';
import '../../../programme_builder/models/programme_session_authoring_result.dart';
import '../../../programme_builder/screens/embedded_session_builder_screen.dart';
import '../../../programme_builder/services/cohort_protocol_customisation_coordinator.dart';
import '../../../programme_builder/services/cohort_protocol_customisation_services.dart';
import '../../../programme_builder/services/programme_builder_protocol_picker_service.dart';
import '../../../programme_builder/services/programme_session_authoring_services.dart';
import '../../../session/session_preview_screen.dart';
import '../../../session_builder/models/cohort_protocol_copy_destination.dart';
import '../../../session_builder/models/programme_session_authoring_context.dart';
import '../../../session_builder/models/session_builder_host_mode.dart';
import '../../../session_builder/services/programme_session_slot_content_classifier.dart';
import '../../../training_library/widgets/session_library_picker_sheet.dart';
import '../../../../models/programme_day_draft.dart';
import '../../../../models/protocol_draft.dart';
import '../../../../models/programme_session_slot_draft.dart';
import '../../../../models/programme_week_draft.dart';
import '../../../../models/programme_vocabulary.dart';
import '../controllers/programme_editor_controller.dart';
import 'cohort_protocol_programme_options_sheet.dart';
import 'programme_protocol_picker_sheet.dart';

class ProgrammeEditorSlotInspector extends StatefulWidget {
  const ProgrammeEditorSlotInspector({
    super.key,
    required this.controller,
    required this.weekLocalId,
    required this.dayLocalId,
    required this.slot,
    this.readOnly = false,
    this.protocolBuilderService,
    this.slotContentClassifier,
  });

  final ProgrammeEditorController controller;
  final String weekLocalId;
  final String dayLocalId;
  final ProgrammeSessionSlotDraft slot;
  final bool readOnly;
  final ProtocolBuilderService? protocolBuilderService;
  final ProgrammeSessionSlotContentClassifier? slotContentClassifier;

  @override
  State<ProgrammeEditorSlotInspector> createState() =>
      _ProgrammeEditorSlotInspectorState();
}

class _ProgrammeEditorSlotInspectorState
    extends State<ProgrammeEditorSlotInspector> {
  late final TextEditingController _displayTitleController;
  late final TextEditingController _coachNoteController;
  late final TextEditingController _athleteNoteController;
  late final ProtocolBuilderService _protocolBuilderService;
  late final ProgrammeSessionSlotContentClassifier _classifier;
  ProgrammeSessionTimeOfDay _timeOfDay = ProgrammeSessionTimeOfDay.any;
  bool _isOptional = false;
  Future<ProgrammeSlotContentKind>? _contentKindFuture;

  bool get _hasAssignedProtocol =>
      !ProgrammeBuilderConstants.isUnassignedProtocolId(widget.slot.protocolId);

  @override
  void initState() {
    super.initState();
    _protocolBuilderService =
        widget.protocolBuilderService ?? ProtocolBuilderService();
    _classifier = widget.slotContentClassifier ??
        ProgrammeSessionSlotContentClassifier(
          protocolBuilderService: _protocolBuilderService,
        );
    _displayTitleController = TextEditingController();
    _coachNoteController = TextEditingController();
    _athleteNoteController = TextEditingController();
    _syncFromSlot(widget.slot);
    _reloadContentKind();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ProgrammeEditorSlotInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.localId != widget.slot.localId ||
        oldWidget.slot.protocolId != widget.slot.protocolId ||
        oldWidget.slot.displayTitle != widget.slot.displayTitle) {
      _syncFromSlot(widget.slot);
      _reloadContentKind();
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _reloadContentKind();
  }

  void _reloadContentKind() {
    if (!_hasAssignedProtocol) {
      _contentKindFuture = Future.value(ProgrammeSlotContentKind.empty);
      return;
    }

    _contentKindFuture = _classifier.classify(
      protocolId: widget.slot.protocolId,
      programmeVersionId: widget.controller.versionId,
    );
  }

  void _syncFromSlot(ProgrammeSessionSlotDraft slot) {
    _displayTitleController.text = slot.displayTitle ?? '';
    _coachNoteController.text = slot.coachNote ?? '';
    _athleteNoteController.text = slot.athleteNote ?? '';
    _timeOfDay = slot.timeOfDay;
    _isOptional = slot.isOptional;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _displayTitleController.dispose();
    _coachNoteController.dispose();
    _athleteNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.md),
      child: ListView(
        children: [
          Text('Slot ${widget.slot.sessionOrder}', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          FutureBuilder<ProgrammeSlotContentKind>(
            future: _contentKindFuture,
            builder: (context, snapshot) {
              final kind = snapshot.data ??
                  (_hasAssignedProtocol
                      ? ProgrammeSlotContentKind.unknown
                      : ProgrammeSlotContentKind.empty);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AssignedContentHeader(
                    slot: widget.slot,
                    contentKind: kind,
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    _SlotActions(
                      contentKind: kind,
                      onPickProtocol: _pickProtocol,
                      onUseSessionLibrary: _pickSessionFromLibrary,
                      onBuildNewSession: _buildNewSession,
                      onEditSession: _editSession,
                      onCopyAndCustomise: _copyAndCustomiseAssignedProtocol,
                      onPreviewProtocol: _previewAssignedProtocol,
                      onRemove: () =>
                          widget.controller.clearProtocol(widget.slot.localId),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: CohortSpacing.md),
          TextField(
            controller: _displayTitleController,
            enabled: !widget.readOnly,
            decoration: const InputDecoration(labelText: 'Display title'),
            onSubmitted: (_) => _saveMetadata(),
          ),
          const SizedBox(height: CohortSpacing.md),
          DropdownButtonFormField<ProgrammeSessionTimeOfDay>(
            value: _timeOfDay,
            decoration: const InputDecoration(labelText: 'Time of day'),
            items: ProgrammeSessionTimeOfDay.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.displayLabel),
                  ),
                )
                .toList(),
            onChanged: widget.readOnly
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _timeOfDay = value);
                    _saveMetadata();
                  },
          ),
          const SizedBox(height: CohortSpacing.md),
          SwitchListTile(
            title: const Text('Optional session'),
            value: _isOptional,
            onChanged: widget.readOnly
                ? null
                : (value) {
                    setState(() => _isOptional = value);
                    _saveMetadata();
                  },
          ),
          const SizedBox(height: CohortSpacing.md),
          TextField(
            controller: _coachNoteController,
            enabled: !widget.readOnly,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Coach note'),
            onSubmitted: (_) => _saveMetadata(),
          ),
          const SizedBox(height: CohortSpacing.md),
          TextField(
            controller: _athleteNoteController,
            enabled: !widget.readOnly,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Athlete note'),
            onSubmitted: (_) => _saveMetadata(),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(height: CohortSpacing.lg),
            TextButton(
              onPressed: () => widget.controller.removeSlot(widget.slot.localId),
              child: const Text('Remove slot'),
            ),
          ],
        ],
      ),
    );
  }

  ProgrammeWeekDraft? _findWeek() {
    final document = widget.controller.document;
    if (document == null) return null;

    for (final week in document.template.allWeeks) {
      if (week.localId == widget.weekLocalId) return week;
    }
    return null;
  }

  ProgrammeDayDraft? _findDay(ProgrammeWeekDraft week) {
    for (final day in week.days) {
      if (day.localId == widget.dayLocalId) return day;
    }
    return null;
  }

  ProgrammeSessionAuthoringContext? _authoringContext({
    required ProgrammeSessionAuthoringIntent intent,
    String? existingContentId,
    String? sourceProtocolId,
  }) {
    final week = _findWeek();
    final day = week == null ? null : _findDay(week);
    if (week == null || day == null) return null;

    return ProgrammeSessionAuthoringContext.fromEditorNodes(
      programmeVersionId: widget.controller.versionId,
      week: week,
      day: day,
      slot: widget.slot,
      authoringIntent: intent,
      existingContentId: existingContentId,
      sourceProtocolId: sourceProtocolId,
    );
  }

  Future<void> _pickSessionFromLibrary() async {
    final authoringContext = _authoringContext(
      intent: ProgrammeSessionAuthoringIntent.createBlank,
    );
    if (authoringContext == null) return;

    final selected = await showModalBottomSheet<SessionLibraryPickerSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SessionLibraryPickerSheet(),
    );

    if (selected == null) return;

    final coordinator = ProgrammeSessionAuthoringServices.createCoordinator(
      controller: widget.controller,
      protocolBuilderService: _protocolBuilderService,
    );

    final result = await coordinator.attachExistingSession(
      context: authoringContext,
      contentId: selected.contentId,
      displayTitle: selected.displayTitle,
    );

    if (!mounted) return;

    if (result.isAttached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(CoachStudioFeedback.sessionAddedToProgramme),
        ),
      );
      setState(_reloadContentKind);
    } else if (result.coachMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.coachMessage!)),
      );
    }
  }

  Future<void> _pickProtocol() async {
    final selected =
        await showModalBottomSheet<CohortProtocolProgrammeSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProgrammeProtocolPickerSheet(
        listProtocols: widget.controller.listProtocols,
      ),
    );

    if (selected == null) return;

    switch (selected.action) {
      case CohortProtocolProgrammeAction.addUnchanged:
        await widget.controller.assignProtocol(
          slotLocalId: widget.slot.localId,
          protocolId: selected.protocol.protocolId,
          displayTitle: selected.protocol.name,
        );
      case CohortProtocolProgrammeAction.copyAndCustomise:
        await _startCopyAndCustomise(
          sourceProtocolId: selected.protocol.protocolId,
        );
      case CohortProtocolProgrammeAction.preview:
        await _previewProtocol(selected.protocol.protocolId);
    }
  }

  Future<void> _previewAssignedProtocol() async {
    if (!_hasAssignedProtocol) return;
    await _previewProtocol(widget.slot.protocolId);
  }

  Future<void> _previewProtocol(String protocolId) async {
    ProtocolDraft draft;
    try {
      draft = await _protocolBuilderService.loadCohortProtocolForCopy(
        protocolId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This protocol could not be previewed right now.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionPreviewScreen(
          draft: draft,
          backLabel: '← Programme Editor',
        ),
      ),
    );
  }

  Future<void> _copyAndCustomiseAssignedProtocol() async {
    if (!_hasAssignedProtocol) return;
    await _startCopyAndCustomise(
      sourceProtocolId: widget.slot.protocolId,
      slotSourceProtocolId: widget.slot.protocolId,
    );
  }

  Future<void> _startCopyAndCustomise({
    required String sourceProtocolId,
    String? slotSourceProtocolId,
  }) async {
    final authoringContext = _authoringContext(
      intent: ProgrammeSessionAuthoringIntent.copyCohortProtocol,
      sourceProtocolId: slotSourceProtocolId,
    );
    if (authoringContext == null) return;

    final customisationCoordinator =
        CohortProtocolCustomisationServices.forProgrammeEditor(
      controller: widget.controller,
      protocolBuilderService: _protocolBuilderService,
    );

    final prepared = await customisationCoordinator.prepareCopy(
      sourceProtocolId: sourceProtocolId,
      destination: CohortProtocolCopyDestination.programmeOnly,
      programmeContext: authoringContext,
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

    await _openEmbeddedSessionBuilder(
      authoringContext,
      initialDraft: prepared.copiedDraft,
      customisationCoordinator: customisationCoordinator,
    );
  }

  Future<void> _buildNewSession() async {
    final authoringContext = _authoringContext(
      intent: ProgrammeSessionAuthoringIntent.createBlank,
    );
    if (authoringContext == null) return;

    await _openEmbeddedSessionBuilder(authoringContext);
  }

  Future<void> _editSession() async {
    final authoringContext = _authoringContext(
      intent: ProgrammeSessionAuthoringIntent.editCoachSession,
      existingContentId: widget.slot.protocolId,
    );
    if (authoringContext == null) return;

    ProtocolDraft initialDraft;
    try {
      initialDraft =
          await _protocolBuilderService.loadProtocol(widget.slot.protocolId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This session could not be loaded right now.'),
        ),
      );
      return;
    }

    await _openEmbeddedSessionBuilder(
      authoringContext,
      initialDraft: initialDraft,
    );
  }

  Future<void> _openEmbeddedSessionBuilder(
    ProgrammeSessionAuthoringContext authoringContext, {
    ProtocolDraft? initialDraft,
    CohortProtocolCustomisationCoordinator? customisationCoordinator,
  }) async {
    final coordinator = ProgrammeSessionAuthoringServices.createCoordinator(
      controller: widget.controller,
      protocolBuilderService: _protocolBuilderService,
    );

    final result = await Navigator.of(context).push<ProgrammeSessionAuthoringResult>(
      MaterialPageRoute<ProgrammeSessionAuthoringResult>(
        builder: (_) => EmbeddedSessionBuilderScreen(
          authoringContext: authoringContext,
          coordinator: coordinator,
          customisationCoordinator: customisationCoordinator,
          initialDraft: initialDraft,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result.isAttached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(CoachStudioFeedback.sessionAddedToProgramme),
        ),
      );
      setState(_reloadContentKind);
    }
  }

  Future<void> _saveMetadata() async {
    await widget.controller.updateSlotMetadata(
      slotLocalId: widget.slot.localId,
      displayTitle: _nullable(_displayTitleController.text),
      timeOfDay: _timeOfDay,
      isOptional: _isOptional,
      coachNote: _nullable(_coachNoteController.text),
      athleteNote: _nullable(_athleteNoteController.text),
      clearDisplayTitle: _displayTitleController.text.trim().isEmpty,
      clearCoachNote: _coachNoteController.text.trim().isEmpty,
      clearAthleteNote: _athleteNoteController.text.trim().isEmpty,
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _AssignedContentHeader extends StatelessWidget {
  const _AssignedContentHeader({
    required this.slot,
    required this.contentKind,
  });

  final ProgrammeSessionSlotDraft slot;
  final ProgrammeSlotContentKind contentKind;

  @override
  Widget build(BuildContext context) {
    switch (contentKind) {
      case ProgrammeSlotContentKind.empty:
        return const CoachStudioEmptyState(
          title: 'No session selected',
          message:
              'Choose a Cohort Protocol, use your Session Library, or build a new Session.',
        );
      case ProgrammeSlotContentKind.cohortProtocol:
        final title = slot.displayTitle?.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cohort Protocol', style: CohortTextStyles.body),
            const SizedBox(height: CohortSpacing.xs),
            Text(
              title != null && title.isNotEmpty ? title : 'Cohort Protocol',
              style: CohortTextStyles.cardTitle,
            ),
          ],
        );
      case ProgrammeSlotContentKind.programmeSession:
        final title = slot.displayTitle?.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title != null && title.isNotEmpty ? title : 'Programme session',
              style: CohortTextStyles.cardTitle,
            ),
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Programme session',
              style: CohortTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      case ProgrammeSlotContentKind.reusableCoachSession:
        final title = slot.displayTitle?.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title != null && title.isNotEmpty ? title : 'Session',
              style: CohortTextStyles.cardTitle,
            ),
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Session Library',
              style: CohortTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      case ProgrammeSlotContentKind.unknown:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assigned content', style: CohortTextStyles.body),
            if (slot.displayTitle != null &&
                slot.displayTitle!.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(slot.displayTitle!, style: CohortTextStyles.cardTitle),
            ],
          ],
        );
    }
  }
}

class _SlotActions extends StatelessWidget {
  const _SlotActions({
    required this.contentKind,
    required this.onPickProtocol,
    required this.onUseSessionLibrary,
    required this.onBuildNewSession,
    required this.onEditSession,
    required this.onCopyAndCustomise,
    required this.onPreviewProtocol,
    required this.onRemove,
  });

  final ProgrammeSlotContentKind contentKind;
  final VoidCallback onPickProtocol;
  final VoidCallback onUseSessionLibrary;
  final VoidCallback onBuildNewSession;
  final VoidCallback onEditSession;
  final VoidCallback onCopyAndCustomise;
  final VoidCallback onPreviewProtocol;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    switch (contentKind) {
      case ProgrammeSlotContentKind.empty:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              onPressed: onPickProtocol,
              child: const Text('Use Cohort Protocol'),
            ),
            TextButton(
              onPressed: onUseSessionLibrary,
              child: const Text('Use Session Library'),
            ),
            TextButton(
              onPressed: onBuildNewSession,
              child: const Text('Build New Session'),
            ),
          ],
        );
      case ProgrammeSlotContentKind.cohortProtocol:
        return Wrap(
          spacing: CohortSpacing.sm,
          runSpacing: CohortSpacing.xs,
          children: [
            TextButton(
              onPressed: onPreviewProtocol,
              child: const Text('Preview'),
            ),
            TextButton(
              onPressed: onCopyAndCustomise,
              child: const Text('Copy and customise'),
            ),
            TextButton(
              onPressed: onPickProtocol,
              child: const Text('Change'),
            ),
            TextButton(
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ],
        );
      case ProgrammeSlotContentKind.programmeSession:
        return Row(
          children: [
            TextButton(
              onPressed: onEditSession,
              child: const Text('Edit Session'),
            ),
            TextButton(
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ],
        );
      case ProgrammeSlotContentKind.reusableCoachSession:
        return Row(
          children: [
            TextButton(
              onPressed: onUseSessionLibrary,
              child: const Text('Change Session'),
            ),
            TextButton(
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ],
        );
      case ProgrammeSlotContentKind.unknown:
        return Row(
          children: [
            TextButton(
              onPressed: onPickProtocol,
              child: const Text('Replace'),
            ),
            TextButton(
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ],
        );
    }
  }
}
