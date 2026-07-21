import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/protocol_draft.dart';
import '../../../session_builder/services/programme_session_persistence_validation.dart';
import '../../../session_revision/models/session_revision_action_decision.dart';
import '../../../session_revision/models/session_revision_action_vocabulary.dart';
import '../../../session_revision/services/session_revision_service.dart';
import '../controllers/session_governance_controller.dart';
import '../governance_copy.dart';
import 'session_revision_action_panel.dart';
import 'session_revision_identity_header.dart';
import 'session_revision_usage_panel.dart';

typedef SessionGovernanceDraftChanged = void Function(ProtocolDraft draft);
typedef SessionGovernanceDeleted = void Function();

class SessionGovernanceSection extends StatefulWidget {
  const SessionGovernanceSection({
    super.key,
    required this.controller,
    required this.revisionService,
    required this.draft,
    required this.onDraftChanged,
    required this.onDeleted,
    this.onOpenProgrammeVersion,
  });

  final SessionGovernanceController controller;
  final SessionRevisionService revisionService;
  final ProtocolDraft draft;
  final SessionGovernanceDraftChanged onDraftChanged;
  final SessionGovernanceDeleted onDeleted;
  final void Function(String programmeVersionId)? onOpenProgrammeVersion;

  @override
  State<SessionGovernanceSection> createState() =>
      _SessionGovernanceSectionState();
}

class _SessionGovernanceSectionState extends State<SessionGovernanceSection> {
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.load();
  }

  @override
  void didUpdateWidget(SessionGovernanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.protocolId != widget.draft.protocolId) {
      widget.controller.load();
    }
    widget.controller.updateSessionDisplayName(widget.draft.name);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleAction(
    SessionRevisionAction action,
    SessionRevisionActionDecision decision,
  ) async {
    if (!decision.allowed || _isExecuting) return;

    switch (action) {
      case SessionRevisionAction.edit:
        return;
      case SessionRevisionAction.createNewRevision:
        await _createNewRevision(decision);
      case SessionRevisionAction.publish:
        await _publish(decision);
      case SessionRevisionAction.archive:
        await _archive(decision);
      case SessionRevisionAction.delete:
        await _delete(decision);
    }
  }

  Future<void> _createNewRevision(SessionRevisionActionDecision decision) async {
    final priorRevisionNumber = widget.controller.state.revisionNumber;
    setState(() => _isExecuting = true);
    try {
      final result = await widget.revisionService.createNewSessionRevision(
        sourceProtocolId: widget.draft.protocolId,
      );
      if (!mounted) return;
      widget.onDraftChanged(result.draft);
      await widget.controller.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            GovernanceCopy.createRevisionSuccessMessage(
              newRevisionNumber: result.revisionNumber,
              priorRevisionNumber: priorRevisionNumber ?? result.revisionNumber - 1,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Future<void> _publish(SessionRevisionActionDecision decision) async {
    final validationMessages =
        ProgrammeSessionPersistenceValidation.validateForSave(widget.draft);
    if (validationMessages.isNotEmpty) {
      _showError(validationMessages.first);
      return;
    }

    if (decision.severity == SessionRevisionActionSeverity.warning) {
      final confirmed = await _confirm(
        title: 'Publish Session Revision',
        message: decision.userMessage,
      );
      if (confirmed != true) return;
    }

    setState(() => _isExecuting = true);
    try {
      final published =
          await widget.revisionService.publishRevision(widget.draft);
      if (!mounted) return;
      widget.onDraftChanged(published);
      await widget.controller.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session Revision published.')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Future<void> _archive(SessionRevisionActionDecision decision) async {
    final confirmed = await _confirm(
      title: 'Archive Session Revision',
      message: decision.userMessage,
    );
    if (confirmed != true) return;

    setState(() => _isExecuting = true);
    try {
      final archived = await widget.revisionService.archiveRevision(
        widget.draft.protocolId,
      );
      if (!mounted) return;
      widget.onDraftChanged(archived);
      await widget.controller.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session Revision archived.')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Future<void> _delete(SessionRevisionActionDecision decision) async {
    if (!decision.allowed) return;

    final confirmed = await _confirm(
      title: 'Delete Session Revision',
      message: decision.userMessage,
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;

    setState(() => _isExecuting = true);
    try {
      await widget.revisionService.deleteRevision(widget.draft.protocolId);
      if (!mounted) return;
      widget.onDeleted();
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Continue',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: isDestructive
                  ? TextButton.styleFrom(foregroundColor: CohortColors.danger)
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;

    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: CohortSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.revisionNotFound) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CohortSpacing.xl),
        child: Text(
          'This session revision could not be found.',
          style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
        ),
      );
    }

    if (state.loadError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CohortSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Governance information could not be loaded.',
              style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
            ),
            const SizedBox(height: CohortSpacing.sm),
            TextButton(
              onPressed: widget.controller.refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final lifecycleStatus = state.lifecycleStatus;
    final revisionNumber = state.revisionNumber;
    final sessionName = state.sessionDisplayName ?? widget.draft.name;
    final policy = state.policy;
    final usageLookup = state.usageLookup;

    if (lifecycleStatus == null ||
        revisionNumber == null ||
        policy == null ||
        usageLookup == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionRevisionIdentityHeader(
          sessionDisplayName: sessionName,
          revisionNumber: revisionNumber,
          lifecycleStatus: lifecycleStatus,
        ),
        const SizedBox(height: CohortSpacing.xl),
        SessionRevisionActionPanel(
          policy: policy,
          onAction: _handleAction,
          isExecuting: _isExecuting,
        ),
        const SizedBox(height: CohortSpacing.xl),
        SessionRevisionUsagePanel(
          usageLookup: usageLookup,
          onOpenProgrammeVersion: widget.onOpenProgrammeVersion,
        ),
        const SizedBox(height: CohortSpacing.xl),
      ],
    );
  }
}
