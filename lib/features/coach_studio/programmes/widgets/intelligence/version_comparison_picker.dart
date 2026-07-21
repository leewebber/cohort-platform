import 'package:flutter/material.dart';

import '../../../../../models/programme_version.dart';
import '../../../../../models/programme_vocabulary.dart';
import '../../intelligence/programme_intelligence_copy.dart';

class VersionComparisonPicker extends StatelessWidget {
  const VersionComparisonPicker({
    super.key,
    required this.currentVersionId,
    required this.currentVersionNumber,
    required this.versions,
    required this.selectedTargetVersionId,
    required this.onChanged,
  });

  final String currentVersionId;
  final int currentVersionNumber;
  final List<ProgrammeVersion> versions;
  final String? selectedTargetVersionId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = versions
        .where((version) => version.id != currentVersionId)
        .toList();

    if (options.isEmpty) {
      return Text(ProgrammeIntelligenceCopy.noOtherVersionsMessage);
    }

    return DropdownButtonFormField<String?>(
      value: selectedTargetVersionId,
      decoration: const InputDecoration(
        labelText: 'Compare with',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Select a version'),
        ),
        for (final version in options)
          DropdownMenuItem<String?>(
            value: version.id,
            child: Text(
              '${ProgrammeIntelligenceCopy.versionLabel(version.versionNumber)}'
              ' · ${ProgrammeIntelligenceCopy.lifecycleLabel(version.lifecycleStatus)}',
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
