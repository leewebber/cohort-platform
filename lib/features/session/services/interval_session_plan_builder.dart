import 'package:flutter/foundation.dart';

import '../../../models/interval_block.dart';
import '../../../models/interval_modality.dart';
import '../../../models/interval_phase_type.dart';
import '../../../models/interval_rep_entry.dart';
import '../../../models/interval_session_plan.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_step.dart';

/// Compiles [Protocol] + [ProtocolStep] rows into a device-neutral
/// [IntervalSessionPlan].
///
/// See `07 Documentation/37_Interval_Execution_Engine.md` §3.6.
class IntervalSessionPlanBuilder {
  const IntervalSessionPlanBuilder();

  IntervalSessionPlan build({
    required Protocol protocol,
    required List<ProtocolStep> steps,
  }) {
    if (steps.isEmpty) {
      throw StateError(
        'IntervalSessionPlanBuilder: cannot compile plan for '
        '${protocol.protocolId} — no protocol steps were provided.',
      );
    }

    final sortedSteps = List<ProtocolStep>.from(steps)
      ..sort((left, right) => left.stepOrder.compareTo(right.stepOrder));

    final modality = _deriveModality(protocol, sortedSteps);
    final blocks = _compileBlocks(sortedSteps);
    final workPhaseCount = blocks
        .expand((block) => block.entries)
        .where((entry) => entry.isWorkPhase)
        .length;

    if (workPhaseCount == 0) {
      throw StateError(
        'IntervalSessionPlanBuilder: cannot compile plan for '
        '${protocol.protocolId} — no executable work phases were detected.',
      );
    }

    return IntervalSessionPlan(
      sessionTitle: protocol.name.trim().isEmpty
          ? protocol.protocolId
          : protocol.name.trim(),
      modality: modality,
      blocks: blocks,
      protocolId: protocol.protocolId,
    );
  }

  /// Temporary diagnostics helper for debug hooks and manual verification.
  static void debugPrintPlan(IntervalSessionPlan plan) {
    debugPrint('[IntervalSessionPlanBuilder] protocolId: ${plan.protocolId}');
    debugPrint('[IntervalSessionPlanBuilder] sessionTitle: ${plan.sessionTitle}');
    debugPrint('[IntervalSessionPlanBuilder] modality: ${plan.modality.name}');
    debugPrint('[IntervalSessionPlanBuilder] blockCount: ${plan.blocks.length}');
    debugPrint('[IntervalSessionPlanBuilder] phaseCount: ${plan.totalPhases}');
    debugPrint(
      '[IntervalSessionPlanBuilder] workPhaseCount: ${plan.totalWorkPhases}',
    );

    for (final block in plan.blocks) {
      debugPrint(
        '[IntervalSessionPlanBuilder] block ${block.blockIndex}: '
        '${block.blockType.name} — ${block.title}',
      );
    }

    var order = 0;
    for (final entry in plan.timelineEntries) {
      order++;
      final label = _phaseLabel(entry);
      debugPrint(
        '[IntervalSessionPlanBuilder] #$order $label '
        '(block ${entry.blockIndex}, rep ${entry.repNumber})',
      );
      debugPrint(
        '[IntervalSessionPlanBuilder]    distance=${_display(entry.targetDistance)} '
        'duration=${_display(entry.targetDuration)} '
        'pace=${_display(entry.targetPace)} '
        'intensity=${_display(entry.targetIntensity)} '
        'recovery=${_display(entry.recoveryDuration)}',
      );
    }
  }

  static String _phaseLabel(IntervalRepEntry entry) {
    return switch (entry.phaseType) {
      IntervalPhaseType.warmUp => 'WARM-UP',
      IntervalPhaseType.work => 'WORK',
      IntervalPhaseType.recovery => 'RECOVERY',
      IntervalPhaseType.coolDown => 'COOL-DOWN',
      IntervalPhaseType.instruction => 'INSTRUCTION',
    };
  }

  static String _display(String? value) => value ?? '—';

  List<IntervalBlock> _compileBlocks(List<ProtocolStep> sortedSteps) {
    final blocks = <IntervalBlock>[];
    _BlockAccumulator? current;
    var blockIndex = 0;

    for (final step in sortedSteps) {
      final phaseType = _detectPhaseType(step);
      final repCount = phaseType == IntervalPhaseType.work
          ? _parseRepCount(step)
          : 1;
      final startsRepeatedWork =
          phaseType == IntervalPhaseType.work && repCount > 1;

      if (!_shouldMergeWithCurrentBlock(
        current: current,
        phaseType: phaseType,
        step: step,
        startsRepeatedWork: startsRepeatedWork,
      )) {
        if (current != null && current.entries.isNotEmpty) {
          blocks.add(current.build());
          blockIndex++;
        }
        current = _BlockAccumulator(
          blockIndex: blockIndex,
          blockType: _blockTypeFor(
            phaseType: phaseType,
            startsRepeatedWork: startsRepeatedWork,
          ),
          title: _blockTitle(step),
          section: _nullableString(step.section),
          protocolStepId: startsRepeatedWork ? step.id : null,
        );
      } else if (startsRepeatedWork) {
        current!.protocolStepId = step.id;
      }

      final entries = _compileEntriesForStep(
        step: step,
        phaseType: phaseType,
        blockIndex: current!.blockIndex,
        repCount: repCount,
      );
      current.addEntries(entries);

      if (startsRepeatedWork) {
        current.blockType = IntervalBlockType.repeated;
        current.title = _blockTitle(step);
        current.protocolStepId = step.id;
      }
    }

    if (current != null && current.entries.isNotEmpty) {
      blocks.add(current.build());
    }

    return blocks;
  }

  List<IntervalRepEntry> _compileEntriesForStep({
    required ProtocolStep step,
    required IntervalPhaseType phaseType,
    required int blockIndex,
    required int repCount,
  }) {
    switch (phaseType) {
      case IntervalPhaseType.work:
        return _expandWorkStep(
          step: step,
          blockIndex: blockIndex,
          repCount: repCount,
        );
      case IntervalPhaseType.recovery:
        return [
          _singlePhaseEntry(
            step: step,
            blockIndex: blockIndex,
            phaseType: IntervalPhaseType.recovery,
            repNumber: 1,
            suffix: 'recovery-${step.id}',
            targetDuration: step.duration ?? step.rest,
          ),
        ];
      case IntervalPhaseType.warmUp:
      case IntervalPhaseType.coolDown:
      case IntervalPhaseType.instruction:
        return [
          _singlePhaseEntry(
            step: step,
            blockIndex: blockIndex,
            phaseType: phaseType,
            repNumber: 1,
            suffix: phaseType.name,
            targetDistance: step.distance,
            targetDuration: step.duration,
            targetPace: _targetPace(step),
            targetIntensity: _targetIntensity(step),
          ),
        ];
    }
  }

  List<IntervalRepEntry> _expandWorkStep({
    required ProtocolStep step,
    required int blockIndex,
    required int repCount,
  }) {
    final recoveryDuration = _nullableString(step.rest);
    final entries = <IntervalRepEntry>[];

    for (var rep = 1; rep <= repCount; rep++) {
      entries.add(
        IntervalRepEntry(
          localId: 'phase-$blockIndex-work-$rep',
          blockIndex: blockIndex,
          repNumber: rep,
          phaseType: IntervalPhaseType.work,
          targetDistance: _nullableString(step.distance),
          targetDuration: _nullableString(step.duration),
          targetPace: _targetPace(step),
          targetIntensity: _targetIntensity(step),
          recoveryDuration: rep < repCount ? recoveryDuration : null,
        ),
      );

      if (recoveryDuration != null && rep < repCount) {
        entries.add(
          IntervalRepEntry(
            localId: 'phase-$blockIndex-recovery-$rep',
            blockIndex: blockIndex,
            repNumber: rep,
            phaseType: IntervalPhaseType.recovery,
            targetDuration: recoveryDuration,
          ),
        );
      }
    }

    return entries;
  }

  IntervalRepEntry _singlePhaseEntry({
    required ProtocolStep step,
    required int blockIndex,
    required IntervalPhaseType phaseType,
    required int repNumber,
    required String suffix,
    String? targetDistance,
    String? targetDuration,
    String? targetPace,
    String? targetIntensity,
  }) {
    return IntervalRepEntry(
      localId: 'phase-$blockIndex-$suffix-${step.id}',
      blockIndex: blockIndex,
      repNumber: repNumber,
      phaseType: phaseType,
      targetDistance: targetDistance,
      targetDuration: targetDuration,
      targetPace: targetPace,
      targetIntensity: targetIntensity,
    );
  }

  bool _shouldMergeWithCurrentBlock({
    required _BlockAccumulator? current,
    required IntervalPhaseType phaseType,
    required ProtocolStep step,
    required bool startsRepeatedWork,
  }) {
    if (current == null) {
      return false;
    }

    if (startsRepeatedWork) {
      return false;
    }

    return switch (phaseType) {
      IntervalPhaseType.warmUp => current.blockType == IntervalBlockType.warmUp,
      IntervalPhaseType.coolDown =>
        current.blockType == IntervalBlockType.coolDown,
      IntervalPhaseType.instruction =>
        current.blockType == IntervalBlockType.instruction,
      IntervalPhaseType.recovery =>
        current.blockType == IntervalBlockType.repeated ||
        current.blockType == IntervalBlockType.single,
      IntervalPhaseType.work =>
        current.blockType == IntervalBlockType.repeated ||
        current.blockType == IntervalBlockType.single &&
            _sectionsMatch(current.section, step.section),
    };
  }

  IntervalBlockType _blockTypeFor({
    required IntervalPhaseType phaseType,
    required bool startsRepeatedWork,
  }) {
    if (startsRepeatedWork) {
      return IntervalBlockType.repeated;
    }

    return switch (phaseType) {
      IntervalPhaseType.warmUp => IntervalBlockType.warmUp,
      IntervalPhaseType.coolDown => IntervalBlockType.coolDown,
      IntervalPhaseType.instruction => IntervalBlockType.instruction,
      IntervalPhaseType.recovery => IntervalBlockType.single,
      IntervalPhaseType.work => IntervalBlockType.single,
    };
  }

  IntervalPhaseType _detectPhaseType(ProtocolStep step) {
    final stepType = step.stepType.trim().toLowerCase();
    final section = step.section.trim().toLowerCase();
    final title = step.title.trim().toLowerCase();
    final displayStyle = step.displayStyle.trim().toLowerCase();

    if (stepType == 'instruction' || displayStyle == 'instruction') {
      return IntervalPhaseType.instruction;
    }

    if (stepType == 'rest' || displayStyle == 'rest') {
      return IntervalPhaseType.recovery;
    }

    if (_containsAny(title, const [
      'recovery interval',
      'rest interval',
      'standing rest',
      'active recovery',
    ])) {
      return IntervalPhaseType.recovery;
    }

    if (_isWarmUpSection(section) ||
        _containsAny(title, const ['warm up', 'warm-up', 'warmup'])) {
      return IntervalPhaseType.warmUp;
    }

    if (_isCoolDownSection(section) ||
        _containsAny(title, const ['cool down', 'cool-down', 'cooldown'])) {
      return IntervalPhaseType.coolDown;
    }

    if (stepType == 'run' || displayStyle == 'run') {
      return IntervalPhaseType.work;
    }

    if (stepType == 'exercise' || displayStyle == 'exercise') {
      if (_hasAerobicPrescription(step)) {
        return IntervalPhaseType.work;
      }

      return IntervalPhaseType.instruction;
    }

    if (_hasAerobicPrescription(step)) {
      return IntervalPhaseType.work;
    }

    return IntervalPhaseType.instruction;
  }

  IntervalModality _deriveModality(
    Protocol protocol,
    List<ProtocolStep> steps,
  ) {
    final sessionType = protocol.sessionType?.trim().toLowerCase() ?? '';
    if (sessionType == 'running' || protocol.runningRequired == true) {
      return IntervalModality.running;
    }

    final equipmentText = [
      protocol.requiredEquipment,
      protocol.optionalEquipment,
      protocol.equipment,
      protocol.environment,
    ].whereType<String>().join(' ').toLowerCase();

    if (_containsAny(equipmentText, const [
      'bike',
      'cycle',
      'cycling',
      'trainer',
      'zwift',
    ])) {
      return IntervalModality.cycling;
    }

    if (_containsAny(equipmentText, const [
      'row',
      'erg',
      'rowing',
      'concept2',
      'c2',
    ])) {
      return IntervalModality.rowing;
    }

    if (_containsAny(equipmentText, const [
      'ski',
      'skierg',
      'xc ski',
      'cross country ski',
    ])) {
      return IntervalModality.skiing;
    }

    for (final step in steps) {
      final stepText = [
        step.title,
        step.stepType,
        step.displayStyle,
        step.notes,
      ].join(' ').toLowerCase();

      if (_containsAny(stepText, const ['run', 'jog', 'track', 'mile', 'km'])) {
        return IntervalModality.running;
      }
      if (_containsAny(stepText, const ['bike', 'cycle', 'ride', 'watt'])) {
        return IntervalModality.cycling;
      }
      if (_containsAny(stepText, const ['row', 'erg', '/500'])) {
        return IntervalModality.rowing;
      }
      if (_containsAny(stepText, const ['ski', 'skierg'])) {
        return IntervalModality.skiing;
      }
    }

    if (sessionType == 'intervals') {
      return IntervalModality.running;
    }

    return IntervalModality.other;
  }

  int _parseRepCount(ProtocolStep step) {
    for (final key in const ['sets', 'repeats', 'rounds']) {
      final value = step.metadata[key];
      final parsed = int.tryParse(value?.toString().trim() ?? '');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    final sets = int.tryParse(step.sets?.trim() ?? '');
    if (sets != null && sets > 0) {
      return sets;
    }

    return 1;
  }

  String? _targetPace(ProtocolStep step) {
    final pace = _metadataString(step, 'pace');
    if (pace != null) {
      return pace;
    }

    final load = _nullableString(step.load);
    if (load != null && _looksLikePace(load)) {
      return load;
    }

    return null;
  }

  String? _targetIntensity(ProtocolStep step) {
    final intensity = _metadataString(step, 'intensity');
    if (intensity != null) {
      return intensity;
    }

    final notes = _nullableString(step.notes);
    if (notes != null) {
      return notes;
    }

    final load = _nullableString(step.load);
    if (load != null && !_looksLikePace(load)) {
      return load;
    }

    return null;
  }

  String? _metadataString(ProtocolStep step, String key) {
    return _nullableString(step.metadata[key]?.toString());
  }

  bool _hasAerobicPrescription(ProtocolStep step) {
    return _nullableString(step.distance) != null ||
        _nullableString(step.duration) != null ||
        _targetPace(step) != null ||
        _targetIntensity(step) != null;
  }

  bool _looksLikePace(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('/km') ||
        normalized.contains('/mi') ||
        normalized.contains('/500') ||
        RegExp(r'\d+:\d+').hasMatch(normalized);
  }

  bool _isWarmUpSection(String section) {
    return section.contains('warm up') || section.contains('warm-up');
  }

  bool _isCoolDownSection(String section) {
    return section.contains('cool down') || section.contains('cool-down');
  }

  bool _sectionsMatch(String? left, String? right) {
    final normalizedLeft = left?.trim().toLowerCase() ?? '';
    final normalizedRight = right?.trim().toLowerCase() ?? '';

    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return normalizedLeft == normalizedRight;
    }

    return normalizedLeft == normalizedRight;
  }

  String _blockTitle(ProtocolStep step) {
    final title = step.title.trim();
    if (title.isNotEmpty) {
      return title;
    }

    final section = step.section.trim();
    if (section.isNotEmpty) {
      return section;
    }

    return 'Interval block';
  }

  bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) {
        return true;
      }
    }

    return false;
  }

  String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}

class _BlockAccumulator {
  _BlockAccumulator({
    required this.blockIndex,
    required this.blockType,
    required this.title,
    this.section,
    this.protocolStepId,
  });

  final int blockIndex;
  IntervalBlockType blockType;
  String title;
  final String? section;
  int? protocolStepId;
  final List<IntervalRepEntry> entries = [];

  void addEntries(List<IntervalRepEntry> newEntries) {
    entries.addAll(newEntries);
  }

  IntervalBlock build() {
    return IntervalBlock(
      blockIndex: blockIndex,
      title: title,
      blockType: blockType,
      entries: List<IntervalRepEntry>.unmodifiable(entries),
      protocolStepId: protocolStepId,
      section: section,
    );
  }
}
