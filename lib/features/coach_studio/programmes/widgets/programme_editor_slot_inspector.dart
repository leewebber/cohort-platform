import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/programme_session_slot_draft.dart';
import '../../../../models/programme_vocabulary.dart';
import '../../../programme_builder/models/programme_builder_constants.dart';
import '../../../programme_builder/services/programme_builder_protocol_picker_service.dart';
import '../controllers/programme_editor_controller.dart';
import 'programme_protocol_picker_sheet.dart';

class ProgrammeEditorSlotInspector extends StatefulWidget {
  const ProgrammeEditorSlotInspector({
    super.key,
    required this.controller,
    required this.weekLocalId,
    required this.dayLocalId,
    required this.slot,
    this.readOnly = false,
  });

  final ProgrammeEditorController controller;
  final String weekLocalId;
  final String dayLocalId;
  final ProgrammeSessionSlotDraft slot;
  final bool readOnly;

  @override
  State<ProgrammeEditorSlotInspector> createState() =>
      _ProgrammeEditorSlotInspectorState();
}

class _ProgrammeEditorSlotInspectorState
    extends State<ProgrammeEditorSlotInspector> {
  late final TextEditingController _displayTitleController;
  late final TextEditingController _coachNoteController;
  late final TextEditingController _athleteNoteController;
  ProgrammeSessionTimeOfDay _timeOfDay = ProgrammeSessionTimeOfDay.any;
  bool _isOptional = false;

  @override
  void initState() {
    super.initState();
    _displayTitleController = TextEditingController();
    _coachNoteController = TextEditingController();
    _athleteNoteController = TextEditingController();
    _syncFromSlot(widget.slot);
  }

  @override
  void didUpdateWidget(covariant ProgrammeEditorSlotInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.localId != widget.slot.localId) {
      _syncFromSlot(widget.slot);
    }
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
    _displayTitleController.dispose();
    _coachNoteController.dispose();
    _athleteNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final protocolLabel = ProgrammeBuilderConstants.isUnassignedProtocolId(
      widget.slot.protocolId,
    )
        ? 'No protocol selected'
        : widget.slot.protocolId;

    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.md),
      child: ListView(
        children: [
          Text('Slot ${widget.slot.sessionOrder}', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          Text('Protocol', style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.xs),
          Text(protocolLabel, style: CohortTextStyles.cardTitle),
          if (!widget.readOnly) ...[
            const SizedBox(height: CohortSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: _pickProtocol,
                  child: const Text('Choose protocol'),
                ),
                if (!ProgrammeBuilderConstants.isUnassignedProtocolId(
                  widget.slot.protocolId,
                ))
                  TextButton(
                    onPressed: () =>
                        widget.controller.clearProtocol(widget.slot.localId),
                    child: const Text('Remove protocol'),
                  ),
              ],
            ),
          ],
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
                    child: Text(value.name),
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

  Future<void> _pickProtocol() async {
    final selected = await showModalBottomSheet<ProgrammeBuilderProtocolOption>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProgrammeProtocolPickerSheet(
        listProtocols: widget.controller.listProtocols,
      ),
    );

    if (selected == null) return;

    await widget.controller.assignProtocol(
      slotLocalId: widget.slot.localId,
      protocolId: selected.protocolId,
      displayTitle: selected.name,
    );
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
