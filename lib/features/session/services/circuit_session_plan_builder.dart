import 'package:flutter/foundation.dart';

import '../../../models/circuit_format.dart';
import '../../../models/circuit_movement_prescription.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/circuit_session_plan.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_step.dart';

/// Compiles [Protocol] + [ProtocolStep] rows into a device-neutral
/// [CircuitSessionPlan].
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md` §4.3.
class CircuitSessionPlanBuilder {
  const CircuitSessionPlanBuilder();

  CircuitSessionPlan build({
    required Protocol protocol,
    required List<ProtocolStep> steps,
  }) {
    if (steps.isEmpty) {
      throw StateError(
        'CircuitSessionPlanBuilder: cannot compile plan for '
        '${_protocolLabel(protocol)} — no protocol steps were provided.',
      );
    }

    final sortedSteps = List<ProtocolStep>.from(steps)
      ..sort((left, right) => left.stepOrder.compareTo(right.stepOrder));

    final sessionMetadata = _collectSessionMetadata(protocol, sortedSteps);
    final movements = _compileMovements(sortedSteps);

    if (movements.isEmpty) {
      throw StateError(
        'CircuitSessionPlanBuilder: cannot compile plan for '
        '${_protocolLabel(protocol)} — no executable movements were detected.',
      );
    }

    final format = _deriveFormat(protocol, sortedSteps, sessionMetadata);
    final scoreType = _deriveScoreType(
      format: format,
      sessionMetadata: sessionMetadata,
      protocol: protocol,
    );
    _validateFormatScoreCompatibility(
      protocol: protocol,
      format: format,
      scoreType: scoreType,
    );

    final prescribedRounds = _parsePositiveInt(
      sessionMetadata,
      const ['rounds', 'repeats'],
    );
    final intervalCount = _parsePositiveInt(
      sessionMetadata,
      const ['interval_count', 'intervals', 'sets'],
    );
    final timeCap = _parseDuration(
      _metadataString(sessionMetadata, 'time_cap') ??
          _metadataString(sessionMetadata, 'timecap'),
    );
    final totalDuration = _parseDuration(
      _metadataString(sessionMetadata, 'duration') ??
          _metadataString(sessionMetadata, 'total_duration'),
    );
    final workInterval = _parseDuration(
      _metadataString(sessionMetadata, 'work') ??
          _metadataString(sessionMetadata, 'work_interval') ??
          _metadataString(sessionMetadata, 'interval'),
    );
    final restInterval = _parseDuration(
      _metadataString(sessionMetadata, 'rest') ??
          _metadataString(sessionMetadata, 'rest_interval'),
    );

    return CircuitSessionPlan(
      sessionTitle: _sessionTitle(protocol),
      format: format,
      scoreType: scoreType,
      movements: movements,
      protocolId: protocol.protocolId,
      prescribedRounds: _resolvedPrescribedRounds(
        format: format,
        prescribedRounds: prescribedRounds,
      ),
      timeCap: timeCap,
      totalDuration: totalDuration,
      workInterval: _resolvedWorkInterval(
        format: format,
        workInterval: workInterval,
      ),
      restInterval: restInterval,
      intervalCount: _resolvedIntervalCount(
        format: format,
        intervalCount: intervalCount,
      ),
      scoringMethodLabel: _metadataString(
        sessionMetadata,
        'scoring_method',
      ),
      instructions: _compileInstructions(protocol, sortedSteps),
      benchmarkName: _resolveBenchmarkName(protocol, sessionMetadata),
    );
  }

  /// Temporary diagnostics helper for debug hooks and manual verification.
  static void debugPrintPlan(CircuitSessionPlan plan) {
    debugPrint(
      '[CircuitSessionPlanBuilder] protocolId: ${plan.protocolId ?? '—'}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] sessionTitle: ${plan.sessionTitle}',
    );
    debugPrint('[CircuitSessionPlanBuilder] format: ${plan.format.name}');
    debugPrint('[CircuitSessionPlanBuilder] scoreType: ${plan.scoreType.name}');
    debugPrint(
      '[CircuitSessionPlanBuilder] movementCount: ${plan.movementCount}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] prescribedRounds: '
      '${_display(plan.prescribedRounds)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] timeCap: ${_displayDuration(plan.timeCap)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] totalDuration: '
      '${_displayDuration(plan.totalDuration)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] workInterval: '
      '${_displayDuration(plan.workInterval)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] restInterval: '
      '${_displayDuration(plan.restInterval)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] intervalCount: '
      '${_display(plan.intervalCount)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] scoringMethodLabel: '
      '${_display(plan.scoringMethodLabel)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] instructions: ${_display(plan.instructions)}',
    );
    debugPrint(
      '[CircuitSessionPlanBuilder] benchmarkName: ${_display(plan.benchmarkName)}',
    );

    for (final movement in plan.movements) {
      debugPrint(
        '[CircuitSessionPlanBuilder] #${movement.orderIndex} ${movement.title}',
      );
      debugPrint(
        '[CircuitSessionPlanBuilder]    reps=${_display(movement.reps)} '
        'distance=${_display(movement.distance)} '
        'duration=${_display(movement.duration)} '
        'load=${_display(movement.load)} '
        'cue=${_display(movement.coachCue)}',
      );
    }
  }

  static String _display(Object? value) => value?.toString() ?? '—';

  static String _displayDuration(Duration? value) {
    if (value == null) {
      return '—';
    }

    final totalSeconds = value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  List<CircuitMovementPrescription> _compileMovements(
    List<ProtocolStep> sortedSteps,
  ) {
    final movements = <CircuitMovementPrescription>[];
    var orderIndex = 0;

    for (final step in sortedSteps) {
      if (!_isExecutableMovement(step)) {
        continue;
      }

      orderIndex++;
      movements.add(
        CircuitMovementPrescription(
          localId: 'movement-${step.id}',
          orderIndex: orderIndex,
          title: step.title.trim(),
          protocolStepId: step.id,
          exerciseId: _nullableString(step.exerciseId),
          reps: _nullableString(step.reps),
          distance: _nullableString(step.distance),
          duration: _nullableString(step.duration),
          load: _nullableString(step.load),
          coachCue: _nullableString(step.notes),
        ),
      );
    }

    return List<CircuitMovementPrescription>.unmodifiable(movements);
  }

  Map<String, dynamic> _collectSessionMetadata(
    Protocol protocol,
    List<ProtocolStep> sortedSteps,
  ) {
    final merged = <String, dynamic>{};

    if (protocol.durationMin != null && protocol.durationMin! > 0) {
      merged['duration_min'] = protocol.durationMin;
    }

    for (final step in sortedSteps) {
      if (_isSessionConfigStep(step)) {
        merged.addAll(step.metadata);
      }
    }

    return merged;
  }

  CircuitFormat _deriveFormat(
    Protocol protocol,
    List<ProtocolStep> sortedSteps,
    Map<String, dynamic> sessionMetadata,
  ) {
    final explicitFormat = _parseFormat(
      _metadataString(sessionMetadata, 'format') ??
          _metadataString(sessionMetadata, 'session_format'),
    );
    if (explicitFormat != null) {
      return explicitFormat;
    }

    final sessionTypeFormat = _formatFromSessionType(protocol.sessionType);
    if (sessionTypeFormat != null) {
      return _refineSessionTypeFormat(
        sessionTypeFormat: sessionTypeFormat,
        sessionMetadata: sessionMetadata,
        movementCount: _countExecutableMovements(sortedSteps),
      );
    }

    final structuralFormat = _deriveFormatFromStructure(
      sortedSteps: sortedSteps,
      sessionMetadata: sessionMetadata,
    );
    if (structuralFormat != null) {
      return structuralFormat;
    }

    final titleFallback = _inferFormatFromTitleFallback(protocol);
    if (titleFallback != null) {
      return titleFallback;
    }

    return CircuitFormat.forTime;
  }

  CircuitFormat? _formatFromSessionType(String? sessionType) {
    return switch (_normalize(sessionType)) {
      'amrap' => CircuitFormat.amrap,
      'emom' => CircuitFormat.emom,
      'chipper' => CircuitFormat.chipper,
      'benchmark' => CircuitFormat.benchmark,
      'fixed duration' || 'fixed_duration' || 'max reps' => CircuitFormat.fixedDuration,
      'circuit' || 'conditioning' || 'hybrid' => CircuitFormat.forTime,
      'e2mom' || 'e3mom' || 'interval clock' || 'interval_clock' =>
        CircuitFormat.intervalClock,
      _ => null,
    };
  }

  CircuitFormat _refineSessionTypeFormat({
    required CircuitFormat sessionTypeFormat,
    required Map<String, dynamic> sessionMetadata,
    required int movementCount,
  }) {
    if (sessionTypeFormat != CircuitFormat.forTime) {
      return sessionTypeFormat;
    }

    final rounds = _parsePositiveInt(
      sessionMetadata,
      const ['rounds', 'repeats'],
    );
    final timeCap = _parseDuration(
      _metadataString(sessionMetadata, 'time_cap') ??
          _metadataString(sessionMetadata, 'timecap'),
    );
    final workInterval = _parseDuration(
      _metadataString(sessionMetadata, 'work') ??
          _metadataString(sessionMetadata, 'work_interval'),
    );

    if (workInterval != null) {
      return workInterval.inSeconds == 60
          ? CircuitFormat.emom
          : CircuitFormat.intervalClock;
    }

    if (timeCap != null && rounds == null) {
      return CircuitFormat.amrap;
    }

    if (rounds != null && rounds > 0 && movementCount > 0) {
      return CircuitFormat.roundsForTime;
    }

    if (movementCount >= 5 && rounds == null) {
      return CircuitFormat.chipper;
    }

    return sessionTypeFormat;
  }

  CircuitFormat? _deriveFormatFromStructure({
    required List<ProtocolStep> sortedSteps,
    required Map<String, dynamic> sessionMetadata,
  }) {
    for (final step in sortedSteps) {
      if (!_isSessionConfigStep(step)) {
        continue;
      }

      final displayStyle = _normalize(step.displayStyle);
      final stepType = _normalize(step.stepType);
      final section = _normalize(step.section);

      if (displayStyle == 'amrap' || stepType == 'amrap' || section.contains('amrap')) {
        return CircuitFormat.amrap;
      }
      if (displayStyle == 'emom' || stepType == 'emom' || section.contains('emom')) {
        return CircuitFormat.emom;
      }
      if (displayStyle == 'chipper' ||
          stepType == 'chipper' ||
          section.contains('chipper')) {
        return CircuitFormat.chipper;
      }
      if (displayStyle == 'benchmark' ||
          stepType == 'benchmark' ||
          section.contains('benchmark')) {
        return CircuitFormat.benchmark;
      }
    }

    final rounds = _parsePositiveInt(
      sessionMetadata,
      const ['rounds', 'repeats'],
    );
    final timeCap = _parseDuration(
      _metadataString(sessionMetadata, 'time_cap') ??
          _metadataString(sessionMetadata, 'timecap'),
    );
    final workInterval = _parseDuration(
      _metadataString(sessionMetadata, 'work') ??
          _metadataString(sessionMetadata, 'work_interval'),
    );
    final movementCount = _countExecutableMovements(sortedSteps);

    if (workInterval != null) {
      return workInterval.inSeconds == 60
          ? CircuitFormat.emom
          : CircuitFormat.intervalClock;
    }

    if (timeCap != null && rounds == null) {
      return CircuitFormat.amrap;
    }

    if (rounds != null && rounds > 0 && movementCount > 0) {
      return CircuitFormat.roundsForTime;
    }

    if (movementCount >= 5 && rounds == null && timeCap == null) {
      return CircuitFormat.chipper;
    }

    return null;
  }

  /// Title and original-workout text matching is isolated here as a last resort.
  CircuitFormat? _inferFormatFromTitleFallback(Protocol protocol) {
    final text = [
      protocol.name,
      protocol.mainSession,
      protocol.description,
    ].whereType<String>().join(' ').toLowerCase();

    if (text.trim().isEmpty) {
      return null;
    }

    if (_containsAny(text, const ['amrap', 'as many rounds as possible'])) {
      return CircuitFormat.amrap;
    }
    if (_containsAny(text, const ['e3mom', 'every 3 min'])) {
      return CircuitFormat.intervalClock;
    }
    if (_containsAny(text, const ['e2mom', 'every 2 min'])) {
      return CircuitFormat.intervalClock;
    }
    if (_containsAny(text, const ['emom', 'every minute'])) {
      return CircuitFormat.emom;
    }
    if (_containsAny(text, const ['chipper'])) {
      return CircuitFormat.chipper;
    }
    if (_containsAny(text, const ['rounds for time', 'rounds-for-time'])) {
      return CircuitFormat.roundsForTime;
    }
    if (_containsAny(text, const ['for time', 'for-time'])) {
      return CircuitFormat.forTime;
    }
    if (_containsAny(text, const ['benchmark', 'hero wod'])) {
      return CircuitFormat.benchmark;
    }
    if (_containsAny(text, const ['max reps', 'fixed duration'])) {
      return CircuitFormat.fixedDuration;
    }

    return null;
  }

  CircuitScoreType _deriveScoreType({
    required CircuitFormat format,
    required Map<String, dynamic> sessionMetadata,
    required Protocol protocol,
  }) {
    final explicitScoreType = _parseScoreType(
      _metadataString(sessionMetadata, 'score_type') ??
          _metadataString(sessionMetadata, 'scoreType'),
    );
    if (explicitScoreType != null) {
      return explicitScoreType;
    }

    if (format == CircuitFormat.fixedDuration) {
      final scoreMode = _normalize(
        _metadataString(sessionMetadata, 'score_mode'),
      );
      if (scoreMode.contains('round') || scoreMode.contains('rep_plus')) {
        return CircuitScoreType.roundsAndReps;
      }
    }

    if (format == CircuitFormat.chipper) {
      final hasTimeCap = _parseDuration(
            _metadataString(sessionMetadata, 'time_cap') ??
                _metadataString(sessionMetadata, 'timecap'),
          ) !=
          null;
      if (hasTimeCap) {
        return CircuitScoreType.movementsCompleted;
      }
    }

    if (format == CircuitFormat.benchmark) {
      return CircuitScoreType.benchmarkScore;
    }

    return format.defaultScoreType;
  }

  void _validateFormatScoreCompatibility({
    required Protocol protocol,
    required CircuitFormat format,
    required CircuitScoreType scoreType,
  }) {
    final compatible = switch (format) {
      CircuitFormat.amrap => const {
          CircuitScoreType.roundsAndReps,
          CircuitScoreType.totalReps,
        },
      CircuitFormat.forTime ||
      CircuitFormat.roundsForTime =>
        const {CircuitScoreType.elapsedTime},
      CircuitFormat.emom ||
      CircuitFormat.intervalClock =>
        const {CircuitScoreType.roundsCompleted},
      CircuitFormat.chipper => const {
          CircuitScoreType.elapsedTime,
          CircuitScoreType.movementsCompleted,
        },
      CircuitFormat.fixedDuration => const {
          CircuitScoreType.totalReps,
          CircuitScoreType.roundsAndReps,
        },
      CircuitFormat.benchmark => const {
          CircuitScoreType.benchmarkScore,
          CircuitScoreType.elapsedTime,
          CircuitScoreType.roundsAndReps,
          CircuitScoreType.totalReps,
          CircuitScoreType.roundsCompleted,
          CircuitScoreType.movementsCompleted,
        },
    };

    if (!compatible.contains(scoreType)) {
      throw StateError(
        'CircuitSessionPlanBuilder: cannot compile plan for '
        '${_protocolLabel(protocol)} — score type ${scoreType.name} is not '
        'compatible with format ${format.name}.',
      );
    }
  }

  int? _resolvedPrescribedRounds({
    required CircuitFormat format,
    required int? prescribedRounds,
  }) {
    if (prescribedRounds == null) {
      return null;
    }

    return switch (format) {
      CircuitFormat.roundsForTime ||
      CircuitFormat.emom ||
      CircuitFormat.intervalClock =>
        prescribedRounds,
      _ => null,
    };
  }

  Duration? _resolvedWorkInterval({
    required CircuitFormat format,
    required Duration? workInterval,
  }) {
    if (workInterval == null) {
      return null;
    }

    return switch (format) {
      CircuitFormat.emom || CircuitFormat.intervalClock => workInterval,
      _ => null,
    };
  }

  int? _resolvedIntervalCount({
    required CircuitFormat format,
    required int? intervalCount,
  }) {
    if (intervalCount == null) {
      return null;
    }

    return switch (format) {
      CircuitFormat.emom || CircuitFormat.intervalClock => intervalCount,
      _ => null,
    };
  }

  String? _resolveBenchmarkName(
    Protocol protocol,
    Map<String, dynamic> sessionMetadata,
  ) {
    return _metadataString(sessionMetadata, 'benchmark_name') ??
        _metadataString(sessionMetadata, 'benchmark') ??
        _nullableString(protocol.name);
  }

  String? _compileInstructions(
    Protocol protocol,
    List<ProtocolStep> sortedSteps,
  ) {
    final parts = <String>[];

    final coachingNotes = _nullableString(protocol.coachingNotes);
    if (coachingNotes != null) {
      parts.add(coachingNotes);
    }

    for (final step in sortedSteps) {
      if (!_isSessionConfigStep(step)) {
        continue;
      }

      final title = step.title.trim();
      if (title.isNotEmpty) {
        parts.add(title);
      }

      final notes = _nullableString(step.notes);
      if (notes != null) {
        parts.add(notes);
      }
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join('\n');
  }

  bool _isExecutableMovement(ProtocolStep step) {
    if (_isExcludedSection(step.section)) {
      return false;
    }

    if (_isRestStep(step)) {
      return false;
    }

    if (_isSessionConfigStep(step) && !_hasMovementPrescription(step)) {
      return false;
    }

    final title = step.title.trim();
    if (title.isEmpty && !_hasMovementPrescription(step)) {
      return false;
    }

    return true;
  }

  bool _isSessionConfigStep(ProtocolStep step) {
    final stepType = _normalize(step.stepType);
    final displayStyle = _normalize(step.displayStyle);
    final section = _normalize(step.section);

    return stepType == 'instruction' ||
        displayStyle == 'instruction' ||
        section == 'session' ||
        section == 'overview' ||
        section == 'instructions';
  }

  bool _isRestStep(ProtocolStep step) {
    final stepType = _normalize(step.stepType);
    final displayStyle = _normalize(step.displayStyle);
    return stepType == 'rest' || displayStyle == 'rest';
  }

  bool _isExcludedSection(String? section) {
    final normalized = _normalize(section);
    return normalized.contains('warm up') ||
        normalized.contains('warm-up') ||
        normalized.contains('warmup') ||
        normalized.contains('cool down') ||
        normalized.contains('cool-down') ||
        normalized.contains('cooldown');
  }

  bool _hasMovementPrescription(ProtocolStep step) {
    return _nullableString(step.reps) != null ||
        _nullableString(step.distance) != null ||
        _nullableString(step.duration) != null ||
        _nullableString(step.load) != null ||
        _nullableString(step.exerciseId) != null;
  }

  int _countExecutableMovements(List<ProtocolStep> sortedSteps) {
    return sortedSteps.where(_isExecutableMovement).length;
  }

  CircuitFormat? _parseFormat(String? raw) {
    final normalized = _normalize(raw).replaceAll('-', '_').replaceAll(' ', '_');

    return switch (normalized) {
      'amrap' => CircuitFormat.amrap,
      'for_time' || 'fortime' => CircuitFormat.forTime,
      'rounds_for_time' || 'roundsfortime' => CircuitFormat.roundsForTime,
      'emom' => CircuitFormat.emom,
      'e2mom' || 'e3mom' || 'custom_interval' || 'interval_clock' ||
      'intervalclock' =>
        CircuitFormat.intervalClock,
      'chipper' => CircuitFormat.chipper,
      'fixed_duration' || 'fixedduration' || 'max_reps' => CircuitFormat.fixedDuration,
      'benchmark' => CircuitFormat.benchmark,
      _ => null,
    };
  }

  CircuitScoreType? _parseScoreType(String? raw) {
    final normalized = _normalize(raw).replaceAll('-', '_').replaceAll(' ', '_');

    return switch (normalized) {
      'rounds_and_reps' ||
      'rounds_plus_reps' ||
      'roundsplusreps' ||
      'rounds_reps' =>
        CircuitScoreType.roundsAndReps,
      'elapsed_time' || 'elapsedtime' || 'time' => CircuitScoreType.elapsedTime,
      'rounds_completed' ||
      'roundscompleted' ||
      'completed_intervals' ||
      'intervals_completed' =>
        CircuitScoreType.roundsCompleted,
      'total_reps' || 'totalreps' || 'reps' => CircuitScoreType.totalReps,
      'movements_completed' || 'movementscompleted' =>
        CircuitScoreType.movementsCompleted,
      'benchmark_score' || 'benchmarkscore' || 'benchmark' =>
        CircuitScoreType.benchmarkScore,
      _ => null,
    };
  }

  int? _parsePositiveInt(
    Map<String, dynamic> metadata,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = metadata[key];
      final parsed = int.tryParse(value?.toString().trim() ?? '');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return null;
  }

  Duration? _parseDuration(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final clockMatch = RegExp(r'^(\d+):(\d{2})$').firstMatch(trimmed);
    if (clockMatch != null) {
      final minutes = int.parse(clockMatch.group(1)!);
      final seconds = int.parse(clockMatch.group(2)!);
      return Duration(minutes: minutes, seconds: seconds);
    }

    final minuteMatch =
        RegExp(r'^(\d+(?:\.\d+)?)\s*(min|mins|minute|minutes)$',
                caseSensitive: false)
            .firstMatch(trimmed);
    if (minuteMatch != null) {
      final minutes = double.parse(minuteMatch.group(1)!);
      return Duration(seconds: (minutes * 60).round());
    }

    final secondMatch =
        RegExp(r'^(\d+(?:\.\d+)?)\s*(sec|secs|second|seconds|s)$',
                caseSensitive: false)
            .firstMatch(trimmed);
    if (secondMatch != null) {
      final seconds = double.parse(secondMatch.group(1)!);
      return Duration(milliseconds: (seconds * 1000).round());
    }

    final plainSeconds = int.tryParse(trimmed);
    if (plainSeconds != null && plainSeconds > 0) {
      return Duration(seconds: plainSeconds);
    }

    return null;
  }

  String? _metadataString(Map<String, dynamic> metadata, String key) {
    return _nullableString(metadata[key]?.toString());
  }

  String _sessionTitle(Protocol protocol) {
    final name = protocol.name.trim();
    if (name.isNotEmpty) {
      return name;
    }

    return protocol.protocolId;
  }

  String _protocolLabel(Protocol protocol) {
    final name = protocol.name.trim();
    if (name.isEmpty) {
      return protocol.protocolId;
    }

    return '${protocol.protocolId} ($name)';
  }

  bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) {
        return true;
      }
    }

    return false;
  }

  String _normalize(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
