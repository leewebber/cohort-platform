import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../programme_builder/services/programme_builder_protocol_picker_service.dart';

/// Coach action when selecting a Cohort Protocol for a programme slot.
enum CohortProtocolProgrammeAction {
  addUnchanged,
  copyAndCustomise,
  preview,
}

class CohortProtocolProgrammeSelection {
  const CohortProtocolProgrammeSelection({
    required this.action,
    required this.protocol,
  });

  final CohortProtocolProgrammeAction action;
  final ProgrammeBuilderProtocolOption protocol;
}

class CohortProtocolProgrammeOptionsSheet extends StatelessWidget {
  const CohortProtocolProgrammeOptionsSheet({
    super.key,
    required this.protocol,
  });

  final ProgrammeBuilderProtocolOption protocol;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(protocol.name, style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Choose how to use this Cohort Protocol.',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              CohortProtocolProgrammeSelection(
                action: CohortProtocolProgrammeAction.addUnchanged,
                protocol: protocol,
              ),
            ),
            child: const Text('Add unchanged'),
          ),
          const SizedBox(height: CohortSpacing.sm),
          OutlinedButton(
            onPressed: () => Navigator.pop(
              context,
              CohortProtocolProgrammeSelection(
                action: CohortProtocolProgrammeAction.copyAndCustomise,
                protocol: protocol,
              ),
            ),
            child: const Text('Copy and customise'),
          ),
          const SizedBox(height: CohortSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              CohortProtocolProgrammeSelection(
                action: CohortProtocolProgrammeAction.preview,
                protocol: protocol,
              ),
            ),
            child: const Text('Preview'),
          ),
        ],
      ),
    );
  }
}
