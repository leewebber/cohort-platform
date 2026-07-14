import '../../../models/interval_performance.dart';
import '../../../models/interval_rep_entry.dart';
import '../../../models/interval_session_plan.dart';
import '../models/strength_rest_timer_state.dart';

/// Maps in-session [IntervalRepEntry] rows to [IntervalPerformance] records.
class IntervalPerformanceMapper {
  const IntervalPerformanceMapper();

  IntervalPerformance fromEntry({
    required int trainingSessionId,
    required IntervalSessionPlan plan,
    required IntervalRepEntry entry,
    required bool skipped,
  }) {
    final protocolStepId = _protocolStepIdForEntry(plan, entry);

    return IntervalPerformance(
      id: 0,
      trainingSessionId: trainingSessionId,
      protocolStepId: protocolStepId,
      blockIndex: entry.blockIndex,
      repNumber: entry.repNumber,
      phaseType: entry.phaseType,
      modality: plan.modality,
      targetDistanceMeters: _parseDistanceMeters(entry.targetDistance),
      targetDurationSeconds: _parseDurationSeconds(entry.targetDuration),
      targetPaceSecondsPerKm: _parsePaceSecondsPerKm(entry.targetPace),
      targetIntensity: _nullableString(entry.targetIntensity),
      recoveryDurationSeconds: _parseDurationSeconds(entry.recoveryDuration),
      actualDistanceMeters: entry.actualDistance,
      actualDurationSeconds: entry.actualDuration?.inSeconds,
      actualPaceSecondsPerKm: entry.actualPace,
      averageHeartRate: entry.averageHeartRate,
      maxHeartRate: entry.maxHeartRate,
      rpe: entry.rpe,
      completed: entry.completed,
      skipped: skipped,
      dataSource: entry.dataSource,
      athleteNote: _nullableString(entry.athleteNote),
    );
  }

  int? _protocolStepIdForEntry(
    IntervalSessionPlan plan,
    IntervalRepEntry entry,
  ) {
    for (final block in plan.blocks) {
      if (block.blockIndex == entry.blockIndex) {
        return block.protocolStepId;
      }
    }

    return null;
  }

  int? _parseDurationSeconds(String? raw) {
    if (raw == null) {
      return null;
    }

    final parsedRest = StrengthRestParser.parse(raw);
    if (parsedRest != null) {
      return parsedRest.totalSeconds;
    }

    final clockMatch = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(raw.trim());
    if (clockMatch != null) {
      final minutes = int.tryParse(clockMatch.group(1) ?? '');
      final seconds = int.tryParse(clockMatch.group(2) ?? '');
      if (minutes != null && seconds != null) {
        return minutes * 60 + seconds;
      }
    }

    final seconds = int.tryParse(raw.trim());
    if (seconds != null && seconds > 0) {
      return seconds;
    }

    return null;
  }

  double? _parseDistanceMeters(String? raw) {
    if (raw == null) {
      return null;
    }

    final normalized = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return null;
    }

    final kmMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*km$').firstMatch(normalized);
    if (kmMatch != null) {
      final km = double.tryParse(kmMatch.group(1) ?? '');
      if (km != null) {
        return km * 1000;
      }
    }

    final meterMatch =
        RegExp(r'^(\d+(?:\.\d+)?)\s*m(?:eters?)?$').firstMatch(normalized);
    if (meterMatch != null) {
      return double.tryParse(meterMatch.group(1) ?? '');
    }

    final numeric = double.tryParse(normalized);
    if (numeric != null && numeric > 0) {
      return numeric;
    }

    return null;
  }

  double? _parsePaceSecondsPerKm(String? raw) {
    if (raw == null) {
      return null;
    }

    final normalized = raw.trim().toLowerCase();
    final clockMatch = RegExp(r'(\d+):(\d{1,2})').firstMatch(normalized);
    if (clockMatch != null) {
      final minutes = int.tryParse(clockMatch.group(1) ?? '');
      final seconds = int.tryParse(clockMatch.group(2) ?? '');
      if (minutes != null && seconds != null) {
        return (minutes * 60 + seconds).toDouble();
      }
    }

    return double.tryParse(normalized);
  }

  String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
